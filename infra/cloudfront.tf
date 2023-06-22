resource "aws_cloudfront_origin_access_control" "cf" {
  name                              = "cf-control-setting"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cf" {
  origin {
    domain_name              = aws_s3_bucket.s3.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cf.id
    origin_id                = "cf-s3-origin-id"
  }

  enabled             = true
  default_root_object = "index.html"

  aliases = ["naveenkumar.dev", "www.naveenkumar.dev"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "cf-s3-origin-id"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method  = "sni-only"
  }

  depends_on = [
    aws_s3_bucket.s3,
    aws_acm_certificate.cert,
    aws_cloudfront_origin_access_control.cf
  ]
}

output "cf_id" {
  value = aws_cloudfront_distribution.cf.id
}