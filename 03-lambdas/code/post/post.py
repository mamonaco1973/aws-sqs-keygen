import json, os, boto3, uuid
sqs = boto3.client("sqs")

def lambda_handler(event, context):
    body = json.loads(event["body"])
    corr_id = str(uuid.uuid4())
    msg = {
        "correlation_id": corr_id,
        "key_type": body.get("key_type", "rsa"),
        "key_bits": body.get("key_bits", 2048)
    }
    sqs.send_message(QueueUrl=os.environ["REQ_QUEUE_URL"],
                     MessageBody=json.dumps(msg))
    return {"statusCode": 202,
            "body": json.dumps({"request_id": corr_id, "status": "queued"})}
