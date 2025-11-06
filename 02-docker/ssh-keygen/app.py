#!/usr/bin/python3
# ================================================================================================
# app.py
# ================================================================================================
# Purpose:
#   Combined microservice that:
#     1. Runs a lightweight HTTP server on port 8080 returning "ok" for health checks.
#     2. Runs a background SQS worker loop that processes SSH key generation requests.
#
# Environment Variables:
#   REQ_QUEUE_URL   - SQS queue URL for incoming keygen requests
#   RESP_QUEUE_URL  - SQS queue URL for outgoing responses
#   AWS_REGION      - AWS region (e.g., us-east-1)
#
# Behavior:
#   - Each request message must include "correlation_id", "key_type", and "key_bits".
#   - The worker generates an SSH keypair, base64-encodes both, and posts a response.
# ================================================================================================

import boto3
import json
import base64
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from cryptography.hazmat.primitives.asymmetric import rsa, ed25519
from cryptography.hazmat.primitives import serialization


# ================================================================================================
# Configuration
# ================================================================================================
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
REQ_QUEUE_URL = os.getenv("REQ_QUEUE_URL")
RESP_QUEUE_URL = os.getenv("RESP_QUEUE_URL")

sqs = boto3.client("sqs", region_name=AWS_REGION)


# ================================================================================================
# SSH Key Generation Logic
# ================================================================================================
def generate_keypair(key_type: str = "rsa", key_bits: int = 2048):
    """Generate SSH keypair and return (public, private) strings."""
    if key_type == "rsa":
        priv = rsa.generate_private_key(public_exponent=65537, key_size=key_bits)
    elif key_type == "ed25519":
        priv = ed25519.Ed25519PrivateKey.generate()
    else:
        raise ValueError(f"Unsupported key type: {key_type}")

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


# ================================================================================================
# Worker Thread: Poll SQS and Process Messages
# ================================================================================================
def worker_loop():
    print("[INFO] Keygen worker started.")
    while True:
        try:
            resp = sqs.receive_message(
                QueueUrl=REQ_QUEUE_URL,
                MaxNumberOfMessages=5,
                WaitTimeSeconds=10,
                VisibilityTimeout=60
            )

            messages = resp.get("Messages", [])
            if not messages:
                continue

            for msg in messages:
                body = json.loads(msg["Body"])
                corr_id = body.get("correlation_id")
                key_type = body.get("key_type", "rsa")
                key_bits = body.get("key_bits", 2048)

                print(f"[INFO] Processing request {corr_id} ({key_type}-{key_bits})")

                try:
                    pub, priv = generate_keypair(key_type, key_bits)
                    result = {
                        "correlation_id": corr_id,
                        "key_type": key_type,
                        "public_key_b64": base64.b64encode(pub.encode()).decode(),
                        "private_key_b64": base64.b64encode(priv.encode()).decode(),
                    }

                    sqs.send_message(
                        QueueUrl=RESP_QUEUE_URL,
                        MessageBody=json.dumps(result)
                    )

                    sqs.delete_message(
                        QueueUrl=REQ_QUEUE_URL,
                        ReceiptHandle=msg["ReceiptHandle"]
                    )
                    print(f"[OK] Completed request {corr_id}")

                except Exception as e:
                    print(f"[ERROR] Failed request {corr_id}: {e}")

        except Exception as e:
            print(f"[ERROR] Worker loop error: {e}")
            time.sleep(5)


# ================================================================================================
# HTTP Health Server (App Runner requires this)
# ================================================================================================
class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, format, *args):
        # Silence HTTP log noise
        return


def start_http_server():
    server = HTTPServer(("0.0.0.0", 8080), HealthHandler)
    print("[INFO] Health server running on port 8080.")
    server.serve_forever()


# ================================================================================================
# Entry Point
# ================================================================================================
if __name__ == "__main__":
    # Validate environment
    if not REQ_QUEUE_URL or not RESP_QUEUE_URL:
        raise SystemExit("[FATAL] Missing REQ_QUEUE_URL or RESP_QUEUE_URL environment variables.")

    # Start worker in background
    threading.Thread(target=worker_loop, daemon=True).start()

    # Start health server (keeps container alive)
    start_http_server()
