# data source

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# record set for tf2t.mansipandey.in
resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  # zone id -> for public hosted zone
  name = "${var.subdomain_name}.${var.domain_name}"
  type = "A"

  alias {
    name = aws_alb.app.dns_name
    # zone id -> for alb
    zone_id                = aws_alb.app.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate" "app_cert" {
  domain_name       = "${var.subdomain_name}.${var.domain_name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}



resource "aws_route53_record" "cert_validation" {
  for_each = { for dvo in aws_acm_certificate.app_cert.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    type   = dvo.resource_record_type
    record = dvo.resource_record_value
  } }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}