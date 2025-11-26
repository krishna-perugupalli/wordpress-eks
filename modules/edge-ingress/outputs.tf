output "alb_controller_role_arn" {
  description = "IRSA role ARN used by the AWS Load Balancer Controller (for TargetGroupBinding)"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_certificate_arn" {
  description = "Regional ACM certificate ARN for ALB (if created)"
  value       = try(aws_acm_certificate_validation.alb[0].certificate_arn, null)
}

output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront (if created)"
  value       = try(aws_acm_certificate_validation.cf[0].certificate_arn, null)
}
