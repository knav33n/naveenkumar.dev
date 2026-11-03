resource "aws_cloudfront_origin_access_control" "cf" {
  name                              = "cf-control-setting"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Short links (/r/<id>) are served the normal homepage; the page
# reads the id from the path and hands it to the views Lambda.
resource "aws_cloudfront_function" "short_links" {
  name    = "short-link-rewrite"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-JS
    function handler(event) {
      var request = event.request;
      if (/^\/r\/[a-z0-9]{4,16}\/?$/.test(request.uri)) {
        request.uri = "/index.html";
      }
      return request;
    }
  JS
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
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "cf-s3-origin-id"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.short_links.arn
    }

    viewer_protocol_policy = "redirect-to-https"
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