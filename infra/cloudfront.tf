data "aws_caller_identity" "current" {}

# Bucket names are globally unique across every AWS account - the account
# ID suffix avoids a collision with someone else's "rfp-template-frontend".
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project_name}-frontend-${data.aws_caller_identity.current.account_id}"
}

# Explicit, even though a bucket is private by default - defense in depth,
# and it's what actually stops the bucket from ever becoming public
# through some future policy/ACL change.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # cheapest tier: US/Canada/Europe edge locations only

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # No custom_error_response SPA-fallback block on purpose: that pattern
  # (404 -> index.html) exists for apps with client-side routing. This app
  # is a single page with no router, so there's no second route to fall
  # back to.

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # No custom domain (see the earlier CloudFront discussion) - the default
  # *.cloudfront.net certificate covers HTTPS on the distribution's own
  # domain, no ACM cert needed.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

# Only this specific CloudFront distribution may read from the bucket -
# not "anyone," not "anyone with the right IP" - one exact resource ARN,
# same pattern as the security groups referencing each other by ID back
# in the VPC step.
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}
