#!/bin/bash

# ------------------------------------------------------------------------------
# Global Configuration
# ------------------------------------------------------------------------------
export AWS_DEFAULT_REGION="us-east-1"  # AWS region for all deployed resources
set -euo pipefail                      # Exit on error, unset var, or pipe fail

# ------------------------------------------------------------------------------
# Destroy Web Application
# ------------------------------------------------------------------------------
echo "NOTE: Destroying Web Application..."

cd 05-webapp || { echo "ERROR: Directory 05-webapp not found."; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

aws ecr delete-repository --repository-name "ssh-keygen" --force || {
  echo "WARN: Failed to delete ECR repository. It may not exist."
}

# ------------------------------------------------------------------------------
# Destroy Lambdas and API Gateway
# ------------------------------------------------------------------------------
echo "NOTE: Destroying Lambdas and API Gateway..."

cd 04-lambdas || { echo "ERROR: Directory 04-lambdas not found."; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------
# Destroy Apprunner Instance
# ------------------------------------------------------------------------------
echo "NOTE: Destroying Apprunner Instance..."

cd 03-apprunner || { echo "ERROR: Directory 03-apprunner not found."; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------
# Destroy SQS and ECR Resources
# ------------------------------------------------------------------------------

aws ecr delete-repository --repository-name "ssh-keygen" --force || {
  echo "WARN: Failed to delete ECR repository. It may not exist."
}

echo "NOTE: Destroying SQS and ECR..."

cd 01-sqs || { echo "ERROR: Directory 01-sqs not found."; exit 1; }
terraform init
terraform destroy -auto-approve
cd .. || exit

# ------------------------------------------------------------------------------
# Completion
# ------------------------------------------------------------------------------
echo "NOTE: Infrastructure teardown complete."
# ==============================================================================
# End of Script
# ==============================================================================
