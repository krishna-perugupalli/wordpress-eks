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
  value = var.create_route53_record ? (
    var.route53_points_to_cloudfront ?
    aws_route53_record.wordpress_cloudfront[0].fqdn :
    aws_route53_record.wordpress[0].fqdn
  ) : ""
}

output "route53_record_type" {
  description = "Type of Route53 record created (alb or cloudfront)"
  value = var.create_route53_record ? (
    var.route53_points_to_cloudfront ? "cloudfront" : "alb"
  ) : "none"
}
