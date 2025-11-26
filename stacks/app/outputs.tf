output "wordpress_namespace" {
  description = "Namespace where WordPress is installed"
  value       = var.wp_namespace
}

output "wordpress_hostname" {
  description = "Public hostname for WordPress"
  value       = var.wp_domain_name
}

output "target_group_arn" {
  description = "Target group ARN from infrastructure stack"
  value       = local.target_group_arn
}
