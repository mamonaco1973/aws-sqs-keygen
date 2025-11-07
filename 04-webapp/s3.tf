# ================================================================================
# File: s3.tf
# ================================================================================

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "web_bucket" {
  bucket = "keygen-web-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.web_bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.web_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowPublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.web_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.allow_public]
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.web_bucket.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"

  depends_on = [aws_s3_bucket_policy.public_policy]
}

data "aws_region" "current" {}

output "website_https_url" {
  description = "Direct HTTPS link to the hosted index.html page."
  value = format(
    "https://%s.s3.%s.amazonaws.com/index.html",
    aws_s3_bucket.web_bucket.bucket,
    data.aws_region.current.id,
  )
}
