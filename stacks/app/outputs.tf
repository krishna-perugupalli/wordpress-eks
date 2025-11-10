output "wordpress_namespace" {
  description = "Namespace where WordPress is installed"
  value       = var.wp_namespace
}

output "wordpress_hostname" {
  description = "Public hostname for WordPress"
  value       = var.wp_domain_name
}

output "debug_alb_arn" {
  value       = var.enable_alb_traffic ? local.alb_arn : null
  description = "Temporary: ALB ARN discovered via tag lookup"
}
