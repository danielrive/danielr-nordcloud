import json
import requests
import jwt 
from datetime import datetime as date
import boto3
import os
##
def lambda_handler(event, context):
     
    secret_name = os.environ['ARN_SECRET_MANAGER']
    region_name = os.environ['REGION']

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )
   
    get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
    )
    secret = get_secret_value_response['SecretString']
    data = json.loads(secret)
    api_key=data['ghost_api_key']
    url = data['url']+"/ghost/api/v3/admin/posts/"
    
    id, secret = api_key.split(':')
    
    # Prepare header and payload
    iat = int(date.now().timestamp())
    
    header = {'alg': 'HS256', 'typ': 'JWT', 'kid': id}
    payload = {
        'iat': iat,
        'exp': iat + 5 * 60,
        'aud': '/v3/admin/'
    }
    
    # Create the token (including decoding secret)
    token = jwt.encode(payload, bytes.fromhex(secret), algorithm='HS256', headers=header)

    # Make an authenticated request to create a post
    headers = {'Authorization': 'Ghost {}'.format(token)}
    body = {'posts': [{'title': 'Hello World'}]}
    payload = {'limit': '1'}
    
    r = requests.get(url, headers=headers)

    dict_bytes = r.content
    mydata=json.loads(dict_bytes.decode('utf-8'))
    ids = [val['id'] for val in mydata['posts']]

    ### Delete post
    for x in ids:
        r_delete = requests.delete(url + x, headers=headers)
        print(r_delete)
    
    return {
        'statusCode': 200,
        'body': json.dumps('work done')
    }

