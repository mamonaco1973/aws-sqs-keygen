# ================================================================================================
# S3 Static Website: Publicly Accessible index.html
# ================================================================================================
# Purpose:
#   - Creates an S3 bucket configured for public read access.
#   - Uploads a local index.html file.
#   - Enables S3 static website hosting for quick browser testing.
# ================================================================================================

# --------------------------------------------------------------------------------
# Bucket Definition (public)
# --------------------------------------------------------------------------------
resource "aws_s3_bucket" "web_bucket" {
     bucket = "keygen-web-${random_id.suffix.hex}"
}

# --------------------------------------------------------------------------------
# Random suffix for unique bucket naming (S3 names must be global)
# --------------------------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 4
}

# --------------------------------------------------------------------------------
# Public Access Block Configuration
# --------------------------------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.web_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# --------------------------------------------------------------------------------
# Bucket Policy: Allow public read of all objects
# --------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.web_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadGetObject",
      Effect    = "Allow",
      Principal = "*",
      Action    = "s3:GetObject",
      Resource  = "${aws_s3_bucket.web_bucket.arn}/*"
    }]
  })
}

# --------------------------------------------------------------------------------
# Upload index.html
# --------------------------------------------------------------------------------
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.web_bucket.bucket
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  acl          = "public-read"
}

# --------------------------------------------------------------------------------
# Enable S3 Static Website Hosting
# --------------------------------------------------------------------------------
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.web_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# --------------------------------------------------------------------------------
# Output: Website URL
# --------------------------------------------------------------------------------
output "website_url" {
  description = "Public S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}
