import json
import boto3
import hashlib
import logging
import ipaddress

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Created once per container so warm invocations reuse the connection.
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VisitorsCount')


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


def lambda_handler(event, context):
    ip_address = event.get('requestContext', {}).get('http', {}).get('sourceIp', '')

    try:
        ipaddress.ip_address(ip_address)
        # hashlib is stable across processes; built-in hash() is randomized
        # per interpreter, which made every cold start count visitors again.
        ip_address_hash = hashlib.sha256(ip_address.encode()).hexdigest()
        try:
            table.put_item(
                Item={'ip_hash': ip_address_hash},
                ConditionExpression='attribute_not_exists(ip_hash)',
            )
        except table.meta.client.exceptions.ConditionalCheckFailedException:
            pass  # already counted
        except Exception:
            logger.exception('Error occurred while updating')
            return response(500, 'Something went wrong!')
    except ValueError:
        logger.warning('Invalid source IP: %s', ip_address)

    try:
        return response(200, count_items())
    except Exception:
        logger.exception('Error occurred while counting')
        return response(500, 'Something went wrong!')
