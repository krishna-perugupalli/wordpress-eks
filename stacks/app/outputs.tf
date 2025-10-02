output "alb_dns_name" {
  description = "Ingress ALB DNS name"
  value       = module.edge_ingress.alb_dns_name
}

output "wordpress_namespace" {
  description = "Namespace where WordPress is installed"
  value       = var.wp_namespace
}

output "wordpress_hostname" {
  description = "Public hostname for WordPress"
  value       = var.wp_domain_name
}
