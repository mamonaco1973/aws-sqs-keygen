

# ------------------------------------------------------------------------------
# Global Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"  # Default AWS region for deployment
set -euo pipefail                      # Exit on error, unset var, or pipe fail

# ------------------------------------------------------------------------------
# Environment Pre-Check
# ------------------------------------------------------------------------------
echo "NOTE: Running environment validation..."
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment validation failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Build SQS and ECR Resources
# ------------------------------------------------------------------------------
echo "NOTE: Building SQS and ECR resources..."

cd 01-sqs || { echo "ERROR: 01-sqs not found."; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------
# Build ssh-keygen Docker Image and Push to ECR
# ------------------------------------------------------------------------------
# Builds the ssh-keygen Docker image and pushes it to AWS ECR for later use
# in the EKS cluster.
echo "NOTE: Building ssh-keygen Docker image and pushing to ECR..."

cd 02-docker/ssh-keygen || { echo "ERROR: ssh-keygen directory missing."; exit 1; }

# Retrieve AWS Account ID dynamically for ECR reference
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "ERROR: Failed to retrieve AWS Account ID. Exiting."
  exit 1
fi

# Authenticate Docker with AWS ECR using token-based login
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | \
docker login --username AWS --password-stdin \
"${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com" || {
  echo "ERROR: Docker authentication failed. Exiting."
  exit 1
}
# ==============================================================================
# Build and Push RStudio Docker Image (only if missing from ECR)
# ==============================================================================

IMAGE_TAG="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/ssh-keygen:keygen-worker-rc1"

echo "NOTE: Checking if image already exists in ECR..." 

# Query ECR for the image
if aws ecr describe-images \
    --repository-name ssh-keygen \
    --image-ids imageTag="keygen-worker-rc1" \
    --region "${AWS_DEFAULT_REGION}" >/dev/null 2>&1; then
  echo "NOTE: Image already exists in ECR: ${IMAGE_TAG}"
else
  echo "WARNING: Image not found in ECR. Building and pushing..."

  docker build \
    -t "${IMAGE_TAG}" . || {
      echo "ERROR: Docker build failed. Exiting."
      exit 1
    }

  docker push "${IMAGE_TAG}" || {
    echo "ERROR: Docker push failed. Exiting."
    exit 1
  }

  echo "NOTE: Image successfully built and pushed to ECR: ${IMAGE_TAG}"
fi

cd ../.. || exit

# ------------------------------------------------------------------------------
# Build Lambdas and API gateway
# ------------------------------------------------------------------------------
# Deploys the Lambdas and API gateway via Terraform.

echo "NOTE: Building Lambdas and API gateway..."

cd 03-lambdas || { echo "ERROR: 03-lambdas directory missing."; exit 1; }

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------
# Build Simple Web Application around this service
# ------------------------------------------------------------------------------
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

export API_ENDPOINT="${URL}"
echo "NOTE: API Gateway URL - ${API_ENDPOINT}"

echo "NOTE: Building Simple Web Application..."

cd 04-webapp || { echo "ERROR: 04-webapp directory missing."; exit 1; }

envsubst < index.html.tmpl > index.html || {
    echo "ERROR: Failed to generate index.html file. Exiting."
    exit 1
}

terraform init
terraform apply -auto-approve

cd .. || exit

# ------------------------------------------------------------------------------
# Build Validation
# ------------------------------------------------------------------------------

echo "NOTE: Running build validation..."

#./validate.sh  # Uncomment once validation script is implemented

# ==============================================================================
# End of Script
# ==============================================================================
