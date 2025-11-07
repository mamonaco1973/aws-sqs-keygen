# ================================================================================================
# Lambda: Responder  (retrieve job result)
# ================================================================================================
resource "aws_iam_role" "lambda_get_role" {
  name = "lambda-get-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
      Effect = "Allow"
    }]
  })
}

# --------------------------------------------------------------------------------
# Attach basic CloudWatch Logs policy
# --------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_get_basic" {
  role       = aws_iam_role.lambda_get_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --------------------------------------------------------------------------------
# Inline Policy: Allow Lambda to read from DynamoDB table
# --------------------------------------------------------------------------------
resource "aws_iam_role_policy" "lambda_get_dynamo" {
  name = "lambda-get-dynamo"
  role = aws_iam_role.lambda_get_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["dynamodb:GetItem"],
      Resource = aws_dynamodb_table.keygen_results.arn
    }]
  })
}

# --------------------------------------------------------------------------------
# Lambda Function Definition
# --------------------------------------------------------------------------------
resource "aws_lambda_function" "lambda_get" {
  function_name = "keygen-get"
  role          = aws_iam_role.lambda_get_role.arn
  runtime       = "python3.11"
  handler       = "get.lambda_handler"
  filename      = data.archive_file.lambda_get_zip.output_path
  timeout       = 15

  environment {
    variables = {
      RESULTS_TABLE = aws_dynamodb_table.keygen_results.name
    }
  }
}

# --------------------------------------------------------------------------------
# Archive Lambda Code (ZIP packaging)
# --------------------------------------------------------------------------------
data "archive_file" "lambda_get_zip" {
  type        = "zip"
  source_dir  = "${path.module}/code/get"
  output_path = "${path.module}/code/get.zip"
}
