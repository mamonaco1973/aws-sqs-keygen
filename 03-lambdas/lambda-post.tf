# ================================================================================================
# Lambdaa Function: Keygen Post (SQS Requester)
# ================================================================================================
resource "aws_iam_role" "lambda_post_role" {
  name = "lambda-post-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_post_basic" {
  role       = aws_iam_role.lambda_post_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_post_sqs" {
  name = "lambda-requester-sqs"
  role = aws_iam_role.lambda_post_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = data.aws_sqs_queue.keygen_input.arn
    }]
  })
}

resource "aws_lambda_function" "lambda_post" {
  function_name = "keygen-post"
  role          = aws_iam_role.lambda_post_role.arn
  runtime       = "python3.11"
  handler       = "post.lambda_handler"
  filename      = data.archive_file.lambdas_zip.output_path
  source_code_hash = data.archive_file.lambdas_zip.output_base64sha256
  timeout       = 15

  environment {
    variables = {
      REQ_QUEUE_URL = data.aws_sqs_queue.keygen_input.url
    }
  }
}
