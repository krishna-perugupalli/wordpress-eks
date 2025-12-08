#############################################
# Module Outputs
#############################################
# These outputs expose key information about deployed observability
# components for consumption by other modules or stacks.
#
# All outputs use try() to gracefully handle cases where the
# EKS Blueprints Addons module doesn't expose expected values.

output "grafana_url" {
  description = "Grafana service URL (placeholder for Phase 2)"
  value       = try(module.eks_blueprints_addons.grafana_url, "")
}

output "grafana_admin_secret_name" {
  description = "Kubernetes secret containing Grafana admin credentials"
  value       = try(module.eks_blueprints_addons.grafana_admin_secret, "")
}

output "prometheus_namespace" {
  description = "Namespace where Prometheus is deployed"
  value       = try(module.eks_blueprints_addons.prometheus_namespace, local.prometheus_namespace)
}

output "alertmanager_namespace" {
  description = "Namespace where Alertmanager is deployed"
  value       = try(module.eks_blueprints_addons.alertmanager_namespace, local.prometheus_namespace)
}

output "fluentbit_namespace" {
  description = "Namespace where Fluent Bit is deployed"
  value       = try(module.eks_blueprints_addons.fluentbit_namespace, "logging")
}