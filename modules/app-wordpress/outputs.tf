output "release_name" {
  description = "Helm release name."
  value       = helm_release.wordpress.name
}

output "namespace" {
  description = "Namespace where WordPress was deployed."
  value       = var.namespace
}

output "ingress_hostname" {
  description = "Ingress hostname configured for WordPress."
  value       = var.domain_name
}

output "ingress_name" {
  description = "Kubernetes Ingress name created by the WordPress Helm release."
  value       = helm_release.wordpress.name
}

output "service_name" {
  description = "Kubernetes Service name created by the WordPress Helm release."
  value       = helm_release.wordpress.name
}
