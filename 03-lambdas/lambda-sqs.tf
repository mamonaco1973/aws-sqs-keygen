# ================================================================================================
# File: lambda-sqs.tf
# ================================================================================================
# Purpose:
#   Defines an AWS Lambda function that runs from a container image and processes
#   SQS messages for SSH key generation. Automatically attaches the Lambda to the
#   input queue trigger and injects environment variables.
#
# Prerequisites:
#   - Existing ECR repository containing your Lambda image.
#   - Existing SQS queues for input (REQ) and optionally output (RESP).
#
# Variables required:
#   - var.aws_region
#   - var.lambda_image_uri  (ECR image URI with tag)
#   - var.req_queue_arn, var.req_queue_url
#   - var.resp_queue_url
# ================================================================================================

# --------------------------------------------------------------------------------
# IAM Role for Lambda Execution
# --------------------------------------------------------------------------------
resource "aws_iam_role" "lambda_exec_role" {
  name = "sqs-keygen-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = { Service = "lambda.amazonaws.com" }
        Effect = "Allow"
      }
    ]
  })
}

# --------------------------------------------------------------------------------
# IAM Policies: CloudWatch + SQS access
# --------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

# --------------------------------------------------------------------------------
# Inline Policy: Allow Lambda to send results to output queue
# --------------------------------------------------------------------------------
resource "aws_iam_role_policy" "lambda_send_output_policy" {
  name = "lambda-send-output-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSendToOutputQueue"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = data.aws_sqs_queue.keygen_output.arn
      }
    ]
  })
}
# --------------------------------------------------------------------------------
# Lambda Function (Container Image)
# --------------------------------------------------------------------------------
resource "aws_lambda_function" "sqs_keygen_lambda" {
  function_name = "sqs-keygen-processor"
  role          = aws_iam_role.lambda_exec_role.arn
  package_type  = "Image"
  image_uri     =  "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com/ssh-keygen:keygen-worker-rc1"
  timeout       = 60
  memory_size   = 512

  # Inject environment variables (output queue + region)
  environment {
    variables = {
      AWS_REGION     = "us-east-1"
      RESP_QUEUE_URL = data.aws_sqs_queue.keygen_output.url
    }
  }

  # Optional: enable X-Ray tracing or tags
  tracing_config {
    mode = "PassThrough"
  }

  tags = {
    Project = "keygen-service"
    Env     = "dev"
  }
}

# --------------------------------------------------------------------------------
# Event Source Mapping: Connect SQS input queue to Lambda
# --------------------------------------------------------------------------------
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn  = data.aws_sqs_queue.keygen_input.arn
  function_name     = aws_lambda_function.sqs_keygen_lambda.arn
  batch_size        = 10
  enabled           = true
}

