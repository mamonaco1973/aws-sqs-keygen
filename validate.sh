#!/bin/bash
# ================================================================================================
# File: validate.sh
# ================================================================================================
# Purpose:
#   End-to-end validation for the KeyGen microservice.
#   - Discovers the deployed API Gateway endpoint automatically via AWS CLI.
#   - Submits a key generation request to the Lambda-based API.
#   - Parses the returned request_id.
#   - Polls the result endpoint until the generated SSH keypair is ready.
#
# Requirements:
#   - curl, jq, and AWS CLI installed and authenticated.
#   - Terraform deployment of 'keygen-api' completed successfully.
#   - Optional env vars:
#       KEY_TYPE = rsa | ed25519            (default: rsa)
#       KEY_BITS = 2048 | 4096 (RSA only)   (default: 2048)
# ================================================================================================
set -euo pipefail
export AWS_DEFAULT_REGION="us-east-1"

# -----------------------------------------------------------------------------------------------
# Step 1: Discover API Gateway endpoint
# -----------------------------------------------------------------------------------------------
echo "NOTE: Locating API Gateway endpoint..."

API_ID=$(aws apigatewayv2 get-apis \
  --query "Items[?Name=='keygen-api'].ApiId" \
  --output text)

if [[ -z "${API_ID}" || "${API_ID}" == "None" ]]; then
  echo "ERROR: No API found with name 'keygen-api'"
  exit 1
fi

URL=$(aws apigatewayv2 get-api \
  --api-id "${API_ID}" \
  --query "ApiEndpoint" \
  --output text)

export API_BASE="${URL}"
echo "NOTE: API Gateway URL - ${API_BASE}"

# -----------------------------------------------------------------------------------------------
# Step 2: Submit SSH key generation request
# -----------------------------------------------------------------------------------------------
KEY_TYPE="${KEY_TYPE:-rsa}"
KEY_BITS="${KEY_BITS:-2048}"

REQ_PAYLOAD=$(jq -n --arg kt "$KEY_TYPE" --arg kb "$KEY_BITS" \
  '{ key_type: $kt, key_bits: ($kb | tonumber) }')

echo "NOTE: Sending request - key_type=${KEY_TYPE}, key_bits=${KEY_BITS}"
RESPONSE=$(curl -s -X POST "${API_BASE}/keygen" \
  -H "Content-Type: application/json" \
  -d "$REQ_PAYLOAD")

REQUEST_ID=$(echo "$RESPONSE" | jq -r '.request_id // empty')

if [[ -z "$REQUEST_ID" ]]; then
  echo "ERROR: No request_id returned."
  echo "NOTE: Response was: $RESPONSE"
  exit 1
fi

echo "NOTE: Submitted keygen request ($REQUEST_ID)."
echo "NOTE: Polling for result..."

# -----------------------------------------------------------------------------------------------
# Step 3: Poll result endpoint until response available
# -----------------------------------------------------------------------------------------------
MAX_ATTEMPTS=30
SLEEP_SECONDS=2

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  RESULT=$(curl -s "${API_BASE}/result/${REQUEST_ID}")
  STATUS=$(echo "$RESULT" | jq -r '.status // empty')

  if [[ "$STATUS" == "complete" ]]; then
    echo "NOTE: Key generation complete."
    echo "$RESULT" | jq
    exit 0
  fi

  if [[ "$STATUS" == "error" ]]; then
    echo "ERROR: Service reported an error."
    echo "$RESULT" | jq
    exit 1
  fi

  echo "WARNING: Attempt ${i}/${MAX_ATTEMPTS}: pending..."
  sleep "$SLEEP_SECONDS"
done

echo "ERROR: Key generation did not complete after ${MAX_ATTEMPTS} attempts."
exit 1
