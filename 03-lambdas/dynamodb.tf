# ================================================================================
# DynamoDB Table: keygen_results
# ================================================================================
resource "aws_dynamodb_table" "keygen_results" {
  name         = "keygen_results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "correlation_id"

  attribute {
    name = "correlation_id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "keygen_results"
  }
}
