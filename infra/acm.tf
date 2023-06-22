resource "aws_acm_certificate" "cert" {
  domain_name               = "naveenkumar.dev"
  validation_method         = "DNS"
  subject_alternative_names = ["naveenkumar.dev", "*.naveenkumar.dev"]

  tags = {
    "Name"       = "SSL Certificate - naveenkumar.dev"
    "Created By" = "Terraform"
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = aws_acm_certificate.cert.arn
}
