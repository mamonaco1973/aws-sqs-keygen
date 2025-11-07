# ================================================================================================
# S3 Static Website: Public index.html (modern style, no ACLs)
# ================================================================================================

resource "random_id" "suffix" {
  byte_length = 4
}

# --------------------------------------------------------------------------------
# Bucket (no ACLs, uses bucket policy for public read)
# --------------------------------------------------------------------------------
resource "aws_s3_bucket" "web_bucket" {
  bucket        = "keygen-web-${random_id.suffix.hex}"
  force_destroy = true
}

# --------------------------------------------------------------------------------
# Explicitly disable ACLs (modern S3 requirement)
# --------------------------------------------------------------------------------
resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.web_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# --------------------------------------------------------------------------------
# Allow public reads using bucket policy only
# --------------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.web_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicRead",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = "${aws_s3_bucket.web_bucket.arn}/*"
      }
    ]
  })
}

# --------------------------------------------------------------------------------
# Website configuration (simple static hosting)
# --------------------------------------------------------------------------------
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.web_bucket.id
  index_document { suffix = "index.html" }
}

# --------------------------------------------------------------------------------
# Upload index.html (uses bucket-owner enforced ownership)
# --------------------------------------------------------------------------------
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.web_bucket.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
}

# --------------------------------------------------------------------------------
# Output: Website HTTPS URL
# --------------------------------------------------------------------------------
output "website_https_url" {
  description = "Direct HTTPS URL for index.html in S3"
  value       = "https://${aws_s3_bucket.web_bucket.bucket}.s3.${data.aws_region.current.id}.amazonaws.com/index.html"
}

# --------------------------------------------------------------------------------
# Get current region for dynamic URL construction
# --------------------------------------------------------------------------------
data "aws_region" "current" {}