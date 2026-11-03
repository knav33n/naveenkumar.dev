import hashlib
import json
import logging
import ipaddress
import os
import re
from datetime import datetime, timezone

import boto3
from botocore.config import Config

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Created once per container so warm invocations reuse connections.
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VisitorsCount')

# Visit notifications must never slow down or break the views response.
_fast = Config(connect_timeout=2, read_timeout=2, retries={'max_attempts': 1})
links_table = boto3.resource('dynamodb', config=_fast).Table(
    os.environ.get('SHARE_LINKS_TABLE', 'ShareLinks'))
lambda_client = boto3.client('lambda', config=_fast)

NOTIFIER_FUNCTION = os.environ.get('NOTIFIER_FUNCTION')
LINK_ID = re.compile(r'^[a-z0-9]{4,16}$')  # matches the CloudFront rewrite


def response(status, body):
    return {
        'statusCode': status,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps(body),
    }


def count_items():
    # Select=COUNT avoids transferring items; paginate past the 1MB scan limit.
    total = 0
    kwargs = {'Select': 'COUNT'}
    while True:
        resp = table.scan(**kwargs)
        total += resp.get('Count', 0)
        if 'LastEvaluatedKey' not in resp:
            return total
        kwargs['ExclusiveStartKey'] = resp['LastEvaluatedKey']


def record_visit(ip_address):
    """Returns True for a first-time visitor, False for returning, None if unknown."""
    try:
        ipaddress.ip_address(ip_address)
    except ValueError:
        logger.warning('Invalid source IP: %s', ip_address)
        return None

    # hashlib is stable across processes; built-in hash() is randomized
    # per interpreter, which made every cold start count visitors again.
    ip_address_hash = hashlib.sha256(ip_address.encode()).hexdigest()
    try:
        table.put_item(
            Item={'ip_hash': ip_address_hash},
            ConditionExpression='attribute_not_exists(ip_hash)',
        )
        return True
    except table.meta.client.exceptions.ConditionalCheckFailedException:
        return False


def lookup_link(link_id):
    """Looks up a short link id created out of band."""
    if not LINK_ID.match(link_id):
        return None
    try:
        item = links_table.get_item(Key={'id': link_id}).get('Item')
    except Exception:
        logger.warning('Could not look up short link', exc_info=True)
        return None
    if not item:
        logger.info('Unknown short link id: %s', link_id)
    return item


def notify_link_visit(link_id, first_visit, user_agent):
    link = lookup_link(link_id)
    if not link or not NOTIFIER_FUNCTION:
        return
    company = link.get('company', 'Unknown company')
    try:
        lambda_client.invoke(
            FunctionName=NOTIFIER_FUNCTION,
            InvocationType='Event',  # async: don't wait on Slack
            Payload=json.dumps({
                'type': 'link_visit',
                'company': company,
                'note': link.get('note', ''),
                'link_id': link_id,
                'first_visit': first_visit,
                'user_agent': user_agent,
                'opened_at': datetime.now(timezone.utc).isoformat(),
            }).encode(),
        )
        logger.info('Short link visited: %s', company)
    except Exception:
        logger.warning('Could not send visit notification', exc_info=True)


def lambda_handler(event, context):
    http = event.get('requestContext', {}).get('http', {})

    try:
        first_visit = record_visit(http.get('sourceIp', ''))
    except Exception:
        logger.exception('Error occurred while updating')
        return response(500, 'Something went wrong!')

    link_id = (event.get('queryStringParameters') or {}).get('ref')
    if link_id:
        notify_link_visit(link_id, first_visit, http.get('userAgent', ''))

    try:
        return response(200, count_items())
    except Exception:
        logger.exception('Error occurred while counting')
        return response(500, 'Something went wrong!')
