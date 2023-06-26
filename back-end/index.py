import json
import boto3
import logging
import ipaddress

def lambda_handler(event, context):

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('VisitorsCount')

    ip_address = event['requestContext']['http']['sourceIp']
    logging.info('*********** ip address - ' + ip_address)

    try:
        ipaddress.ip_address(ip_address)
        if ip_address:
            ip_address_hash = str(hash(ip_address))

            try:
                read_resp = table.get_item(Key={
                    'ip_hash': ip_address_hash
                })

                if 'Item' not in read_resp.keys():
                    print('adding a new item')
                    resp = table.put_item(
                        Item={
                            'ip_hash': ip_address_hash,
                        }
                    )
                else:
                    logging.info('Skipping since item already exists')
            except Exception:
                logging.exception("Error occured while updating")
                return {
                    'statusCode': 400,
                    'body': json.dumps('Something went wrong!')
                }
        else:
            logging.info("No IP found.")
    except ValueError:
        logging.exception('Address/netmask is invalid: %s' % ip_address)

    response = table.scan()

    if 'Items' in response.keys():
        items = response['Items']
        return {
            'statusCode': 200,
            'body': len(items)
        }
    else:
        return {
            'statusCode': 200,
            'body': 0
        }