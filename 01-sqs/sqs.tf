# ================================================================================================
# File: sqs.tf
# ================================================================================================
# Purpose:
#   Creates two Amazon SQS queues for a key generation pipeline:
#     - keygen_input   : Receives key generation requests
#     - keygen_output  : Publishes key generation results
#
# Notes:
#   - SQS is fully managed; no network or VPC configuration required.
#   - Messages can be sent via AWS SDK, CLI, or Lambda/ECS services.
# ================================================================================================

# -----------------------------------------------------------------------------------------------
# Input Queue: keygen_input
# -----------------------------------------------------------------------------------------------
resource "aws_sqs_queue" "keygen_input" {
  name                        = "keygen_input"
  visibility_timeout_seconds   = 60
  message_retention_seconds    = 86400
  delay_seconds                = 0
  max_message_size             = 262144
  receive_wait_time_seconds    = 10

  tags = {
    Name        = "keygen_input"
    Environment = "dev"
    Purpose     = "keygen-service"
  }
}

# -----------------------------------------------------------------------------------------------
# Output Queue: keygen_output
# -----------------------------------------------------------------------------------------------
resource "aws_sqs_queue" "keygen_output" {
  name                        = "keygen_output"
  visibility_timeout_seconds   = 60
  message_retention_seconds    = 86400
  delay_seconds                = 0
  max_message_size             = 262144
  receive_wait_time_seconds    = 10

  tags = {
    Name        = "keygen_output"
    Environment = "dev"
    Purpose     = "keygen-service"
  }
}


