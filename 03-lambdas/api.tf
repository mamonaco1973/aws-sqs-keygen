# ================================================================================================
# API Gateway: Keygen Service (HTTP API)
# ================================================================================================
# Purpose:
#   Provides REST-style endpoints for key generation workflow:
#     - POST /keygen        → Enqueue key generation request
#     - GET  /result/{id}   → Retrieve key generation result
#
# Notes:
#   - Uses HTTP API (v2) for simplicity and cost efficiency.
#   - Each route integrates directly with a Lambda function.
# ================================================================================================

# --------------------------------------------------------------------------------
# Create HTTP API
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "keygen_api" {
  name          = "keygen-api"
  protocol_type = "HTTP"
}

# --------------------------------------------------------------------------------
# API Integration: POST /keygen → keygen-requester Lambda
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "post_keygen_integration" {
  api_id                 = aws_apigatewayv2_api.keygen_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_requester.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# --------------------------------------------------------------------------------
# API Integration: GET /result/{id} → keygen-get Lambda
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_integration" "get_result_integration" {
  api_id                 = aws_apigatewayv2_api.keygen_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_get.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# --------------------------------------------------------------------------------
# Route: POST /keygen
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_route" "post_keygen_route" {
  api_id    = aws_apigatewayv2_api.keygen_api.id
  route_key = "POST /keygen"
  target    = "integrations/${aws_apigatewayv2_integration.post_keygen_integration.id}"
}

# --------------------------------------------------------------------------------
# Route: GET /result/{id}
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_route" "get_result_route" {
  api_id    = aws_apigatewayv2_api.keygen_api.id
  route_key = "GET /result/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_result_integration.id}"
}

# --------------------------------------------------------------------------------
# Deployment and Stage
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_stage" "keygen_stage" {
  api_id      = aws_apigatewayv2_api.keygen_api.id
  name        = "$default"
  auto_deploy = true
}

# --------------------------------------------------------------------------------
# Lambda Permissions: Allow API Gateway to invoke both Lambdas
# --------------------------------------------------------------------------------
resource "aws_lambda_permission" "allow_post_invoke" {
  statement_id  = "AllowAPIGatewayInvokePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_requester.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.keygen_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_get_invoke" {
  statement_id  = "AllowAPIGatewayInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_get.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.keygen_api.execution_arn}/*/*"
}

# --------------------------------------------------------------------------------
# Output: API Endpoint
# --------------------------------------------------------------------------------
output "keygen_api_endpoint" {
  description = "Invoke URL for the Keygen API Gateway"
  value       = aws_apigatewayv2_stage.keygen_stage.invoke_url
}

# --------------------------------------------------------------------------------
# Create HTTP API with CORS configuration
# --------------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "keygen_api" {
  name          = "keygen-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]              # or restrict to your domain later
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
    expose_headers = ["content-type"]
    max_age = 300
  }
}
