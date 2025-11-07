# ================================================================================================
# app.py  (for Lambda container)
# ================================================================================================
# Purpose:
#   Lambda function invoked by SQS trigger to process SSH key generation requests.
#   Each SQS message must contain:
#       {
#         "correlation_id": "abc123",
#         "key_type": "rsa" | "ed25519",
#         "key_bits": 2048
#       }
#
# Environment Variables:
#   RESP_QUEUE_URL - (Optional) if set, responses are pushed to this queue.
#   AWS_REGION     - AWS region, defaults to us-east-1
#
# Behavior:
#   - Generates SSH keypair per message
#   - Base64-encodes keys
#   - Sends result to response queue (if configured)
#   - Logs progress to CloudWatch
# ================================================================================================

import json
import base64
import os
import logging
import boto3
from cryptography.hazmat.primitives.asymmetric import rsa, ed25519
from cryptography.hazmat.primitives import serialization

# --------------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------------
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
RESP_QUEUE_URL = os.getenv("RESP_QUEUE_URL")

sqs = boto3.client("sqs", region_name=AWS_REGION)
logger = logging.getLogger()
logger.setLevel(logging.INFO)


# --------------------------------------------------------------------------------
# SSH Key Generation Logic (extracted from App Runner microservice)
# --------------------------------------------------------------------------------
def generate_keypair(key_type: str = "rsa", key_bits: int = 2048):
    """Generate SSH keypair and return (public, private) strings."""
    if key_type == "rsa":
        priv = rsa.generate_private_key(public_exponent=65537, key_size=key_bits)
    elif key_type == "ed25519":
        priv = ed25519.Ed25519PrivateKey.generate()
    else:
        logger.warning(f"Unknown key type '{key_type}', defaulting to RSA.")
        priv = rsa.generate_private_key(public_exponent=65537, key_size=key_bits)

    pub_ssh = priv.public_key().public_bytes(
        serialization.Encoding.OpenSSH,
        serialization.PublicFormat.OpenSSH
    ).decode()

    priv_pem = priv.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption()
    ).decode()

    return pub_ssh, priv_pem


# --------------------------------------------------------------------------------
# Lambda Handler
# --------------------------------------------------------------------------------
def lambda_handler(event, context):
    """Triggered automatically by SQS."""
    for record in event.get("Records", []):
        try:
            body = json.loads(record["body"])
            corr_id = body.get("correlation_id", "unknown")
            key_type = body.get("key_type", "rsa")
            key_bits = int(body.get("key_bits", 2048))

            logger.info(f"Processing request {corr_id} ({key_type}-{key_bits})")

            # Generate SSH keypair
            pub, priv = generate_keypair(key_type, key_bits)

            result = {
                "correlation_id": corr_id,
                "key_type": key_type,
                "public_key_b64": base64.b64encode(pub.encode()).decode(),
                "private_key_b64": base64.b64encode(priv.encode()).decode(),
            }

            # Optionally send response to output queue
            if RESP_QUEUE_URL:
                sqs.send_message(
                    QueueUrl=RESP_QUEUE_URL,
                    MessageBody=json.dumps(result)
                )
                logger.info(f"Sent response for {corr_id} to response queue.")
            else:
                logger.info(f"Generated keypair (not sent): {corr_id}")

        except Exception as e:
            logger.exception(f"Failed processing message: {e}")

    return {"statusCode": 200, "body": "Batch processed"}


# ================================================================================================
# End of File
# ================================================================================================
