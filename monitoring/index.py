"""Turns CloudWatch alarm notifications (via SNS) into readable Slack alerts."""
import json
import os
import re
from datetime import datetime, timedelta
from urllib.parse import quote

import boto3
import urllib3

slack_url = os.environ['SLACK_WEBHOOK']
http = urllib3.PoolManager()
logs = boto3.client('logs')
cloudwatch = boto3.client('cloudwatch')

COLORS = {'ALARM': '#d93f3f', 'OK': '#2eb67d'}
OPERATORS = {
    'GreaterThanThreshold': '>',
    'GreaterThanOrEqualToThreshold': '≥',
    'LessThanThreshold': '<',
    'LessThanOrEqualToThreshold': '≤',
}
# Lines worth surfacing from a Lambda's logs when its alarm fires.
ERROR_FILTER = '?ERROR ?Traceback ?"Task timed out" ?"Status: timeout" ?"Runtime exited"'


def parse_time(value):
    return datetime.strptime(value, '%Y-%m-%dT%H:%M:%S.%f%z')


def slack_time(dt):
    """Renders in each reader's own timezone in Slack."""
    epoch = int(dt.timestamp())
    return f'<!date^{epoch}^{{date_short_pretty}} {{time}}|{dt:%Y-%m-%d %H:%M UTC}>'


def humanize(delta):
    minutes = round(delta.total_seconds() / 60)
    if minutes < 1:
        return 'under a minute'
    if minutes < 60:
        return f'{minutes} min'
    return f'{minutes // 60} h {minutes % 60} min'


def console_links(region, alarm_name, function_name):
    base = f'https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}'
    links = [('View alarm', f'{base}#alarmsV2:alarm/{quote(alarm_name, safe="")}')]
    if function_name:
        group = quote(quote(f'/aws/lambda/{function_name}', safe=''), safe='').replace('%', '$')
        links.append(('View logs', f'{base}#logsV2:log-groups/log-group/{group}'))
    return links


def observed_value(reason):
    # e.g. "Threshold Crossed: 1 datapoint [3.0 (03/11/26 10:05:00)] was greater ..."
    match = re.search(r'\[([-\d.]+) \(', reason)
    return match.group(1) if match else None


def recent_errors(function_name, changed_at, window_seconds):
    start = changed_at - timedelta(seconds=window_seconds + 120)
    try:
        resp = logs.filter_log_events(
            logGroupName=f'/aws/lambda/{function_name}',
            startTime=int(start.timestamp() * 1000),
            endTime=int(changed_at.timestamp() * 1000) + 60_000,
            filterPattern=ERROR_FILTER,
            limit=50,
        )
    except Exception as e:  # alerts must still go out without log context
        print({'log_lookup_failed': str(e)})
        return []
    counts = {}  # most recent first; dict keeps insertion order
    for event in reversed(resp.get('events', [])):
        line = event['message']
        line = re.sub(r'\d{4}-\d{2}-\d{2}T[\d:.]+Z?', '', line)  # timestamps
        line = re.sub(r'[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}', '', line)  # request ids
        line = re.sub(r'\s+', ' ', line).strip()[:300]
        if line:
            counts[line] = counts.get(line, 0) + 1
    return [f'{line} (×{n})' if n > 1 else line for line, n in list(counts.items())[:3]]


def alarm_started_at(alarm_name):
    """When the alarm last went into ALARM, so a resolve can say how long it lasted."""
    try:
        history = cloudwatch.describe_alarm_history(
            AlarmName=alarm_name,
            HistoryItemType='StateUpdate',
            ScanBy='TimestampDescending',
            MaxRecords=10,
        )['AlarmHistoryItems']
    except Exception as e:
        print({'history_lookup_failed': str(e)})
        return None
    for item in history:
        data = json.loads(item.get('HistoryData', '{}'))
        if data.get('newState', {}).get('stateValue') == 'ALARM':
            return item['Timestamp']
    return None


def build_message(msg):
    name = msg['AlarmName']
    state = msg['NewStateValue']
    trigger = msg.get('Trigger', {})
    region = msg['AlarmArn'].split(':')[3]
    changed_at = parse_time(msg['StateChangeTime'])
    dims = {d['name']: d['value'] for d in trigger.get('Dimensions', [])}
    function_name = dims.get('FunctionName')
    title = msg.get('AlarmDescription') or name

    metric = trigger.get('MetricName', '?')
    stat = trigger.get('Statistic') or trigger.get('ExtendedStatistic', '')
    period = trigger.get('Period', 60)
    window = period * trigger.get('EvaluationPeriods', 1)
    op = OPERATORS.get(trigger.get('ComparisonOperator'), trigger.get('ComparisonOperator', ''))
    threshold = trigger.get('Threshold')
    value = observed_value(msg.get('NewStateReason', ''))

    fields = [f'*Function*\n{function_name}' if function_name else f'*Alarm*\n{name}']
    if state == 'ALARM':
        emoji, heading = ':rotating_light:', title
        condition = f'{metric} ({stat.lower()} per {humanize(timedelta(seconds=period))})'
        fields += [
            f'*Observed*\n{value if value is not None else "?"} (alert when {op} {threshold:g})',
            f'*Metric*\n{condition}',
            f'*Since*\n{slack_time(changed_at)}',
        ]
    else:
        emoji, heading = ':white_check_mark:', f'Resolved: {title}'
        started = alarm_started_at(name)
        if started:
            fields.append(f'*Lasted*\n{humanize(changed_at - started)}')
        fields.append(f'*Resolved at*\n{slack_time(changed_at)}')

    blocks = [
        {'type': 'section', 'text': {'type': 'mrkdwn', 'text': f'{emoji} *{heading}*'}},
        {'type': 'section', 'fields': [{'type': 'mrkdwn', 'text': f} for f in fields]},
    ]

    if state == 'ALARM' and function_name and metric in ('Errors', 'Duration'):
        lines = recent_errors(function_name, changed_at, window)
        text = '\n'.join(lines) if lines else 'No error lines found in the logs for this window.'
        blocks.append({'type': 'section', 'text': {
            'type': 'mrkdwn', 'text': f'*Recent log errors*\n```{text}```'}})

    blocks.append({'type': 'actions', 'elements': [
        {'type': 'button', 'text': {'type': 'plain_text', 'text': label}, 'url': url}
        for label, url in console_links(region, name, function_name)
    ]})
    blocks.append({'type': 'context', 'elements': [
        {'type': 'mrkdwn', 'text': f'`{name}` · {msg.get("Region", region)}'}]})

    return {
        'text': f'{"Resolved: " if state == "OK" else ""}{title}',  # notification preview
        'attachments': [{'color': COLORS[state], 'blocks': blocks}],
    }


def post_to_slack(payload, label):
    resp = http.request(
        'POST',
        slack_url,
        body=json.dumps(payload).encode('utf-8'),
        headers={'Content-Type': 'application/json'},
    )
    print({'sent': label, 'status_code': resp.status})
    if resp.status >= 300:
        raise RuntimeError(f'Slack webhook failed: {resp.status} {resp.data!r}')


def should_notify(old, new):
    # Only real incidents: entering ALARM, and recovering from it. Transitions
    # through INSUFFICIENT_DATA (new alarms, quiet periods) are noise.
    return new == 'ALARM' or (old == 'ALARM' and new == 'OK')


def lambda_handler(event, context):
    for record in event['Records']:
        msg = json.loads(record['Sns']['Message'])
        old, new = msg['OldStateValue'], msg['NewStateValue']
        if not should_notify(old, new):
            print({'skipped': msg['AlarmName'], 'from': old, 'to': new})
            continue
        post_to_slack(build_message(msg), f'{msg["AlarmName"]}:{new}')
