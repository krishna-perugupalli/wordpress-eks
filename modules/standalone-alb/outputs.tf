# Standalone ALB Module Outputs

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.wordpress.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.wordpress.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.wordpress.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group for WordPress pods"
  value       = aws_lb_target_group.wordpress.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.wordpress.name
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "route53_record_fqdn" {
  description = "FQDN of the created Route53 record"
  value       = var.create_route53_record && var.hosted_zone_id != "" ? aws_route53_record.wordpress[0].fqdn : ""
}

output "route53_record_type" {
  description = "Type of Route53 record created"
  value       = var.create_route53_record && var.hosted_zone_id != "" ? "alb" : "none"
}

# DNS Configuration Validation Outputs
output "dns_validation" {
  description = "DNS configuration validation information"
  value = {
    alb_dns_name      = aws_lb.wordpress.dns_name
    alb_zone_id       = aws_lb.wordpress.zone_id
    hosted_zone_id    = var.hosted_zone_id
    hosted_zone_valid = var.create_route53_record && var.hosted_zone_id != "" ? data.aws_route53_zone.selected[0].zone_id == var.hosted_zone_id : null
    domain_name       = var.domain_name
    route53_created   = var.create_route53_record && var.hosted_zone_id != ""
  }
}

# Origin Protection Outputs
output "origin_protection_enabled" {
  description = "Whether origin protection is enabled on the ALB"
  value       = var.enable_origin_protection
}

output "origin_protection_config" {
  description = "Origin protection configuration details"
  value = {
    enabled               = var.enable_origin_protection
    response_code         = var.origin_protection_response_code
    response_body         = var.origin_protection_response_body
    secret_header_name    = "X-Origin-Secret"
    has_secret_configured = var.origin_secret_value != ""
  }
  sensitive = true
}

output "listener_rule_arns" {
  description = "ARNs of the origin secret validation listener rules"
  value = {
    http_rule  = var.enable_origin_protection && var.origin_secret_value != "" ? aws_lb_listener_rule.origin_secret_validation_http[0].arn : null
    https_rule = var.enable_origin_protection && var.origin_secret_value != "" ? aws_lb_listener_rule.origin_secret_validation_https[0].arn : null
  }
}
