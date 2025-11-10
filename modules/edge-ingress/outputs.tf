output "alb_controller_role_arn" {
  description = "IRSA role ARN used by the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "waf_regional_arn" {
  description = "WAFv2 Web ACL ARN (REGIONAL) to use in Ingress annotation alb.ingress.kubernetes.io/wafv2-acl-arn"
  value       = try(aws_wafv2_web_acl.regional[0].arn, null)
}

output "alb_certificate_arn" {
  description = "Regional ACM certificate ARN for ALB (if created)"
  value       = try(aws_acm_certificate_validation.alb[0].certificate_arn, null)
}

output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront (if created)"
  value       = try(aws_acm_certificate_validation.cf[0].certificate_arn, null)
}

output "controller_namespace" {
  description = "Namespace where the AWS Load Balancer Controller is installed"
  value       = var.controller_namespace
}

output "restricted_to_cloudfront" {
  description = "True if ALB ingress was restricted to CloudFront prefix list"
  value       = var.restrict_alb_to_cloudfront
}
