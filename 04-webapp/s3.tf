# ================================================================================
# File: s3.tf
# ================================================================================
# Purpose:
#   Creates an S3 bucket to host a static HTML web page (index.html).
#   Steps:
#     1. Create a private bucket.
#     2. Disable "Block Public Access" flags.
#     3. Apply a public-read bucket policy.
#     4. Upload the HTML file as text/html with public-read ACL.
# ================================================================================

# ------------------------------------------------------------------------------
# Random suffix for unique bucket naming
# ------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 4
}

# ------------------------------------------------------------------------------
# Create S3 bucket (private by default)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "web_bucket" {
  bucket = "keygen-web-${random_id.suffix.hex}"

  tags = {
    Name = "keygen-web"
  }
}

# ------------------------------------------------------------------------------
# Disable public access blocking for this specific bucket
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "allow_public" {
  bucket                  = aws_s3_bucket.web_bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

# ------------------------------------------------------------------------------
# Attach a public-read bucket policy (depends on block disable)
# ------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.web_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.web_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.allow_public]
}

# ------------------------------------------------------------------------------
# Upload index.html (public-read, correct MIME type)
# ------------------------------------------------------------------------------
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.web_bucket.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  acl          = "public-read"

  depends_on = [aws_s3_bucket_policy.public_policy]
}

# ------------------------------------------------------------------------------
# Output: HTTPS URL to the hosted index.html file
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

output "website_https_url" {
  description = "Direct HTTPS link to the hosted index.html page."
  value = format(
    "https://%s.s3.%s.amazonaws.com/index.html",
    aws_s3_bucket.web_bucket.bucket,
    data.aws_region.current.id,
  )
}
