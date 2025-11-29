#############################################
# Grafana Module Outputs
#############################################

output "grafana_url" {
  description = "Grafana internal cluster URL"
  value       = "http://grafana.${var.namespace}.svc.cluster.local"
}

output "grafana_external_url" {
  description = "Grafana external URL (if exposed via ingress)"
  value       = null # Can be configured via ALB ingress controller
}

output "grafana_role_arn" {
  description = "IAM role ARN for Grafana service account (IRSA)"
  value       = aws_iam_role.grafana.arn
}

output "grafana_admin_secret_name" {
  description = "Kubernetes secret name containing Grafana admin credentials"
  value       = kubernetes_secret.grafana_admin.metadata[0].name
}

output "grafana_service_account_name" {
  description = "Grafana service account name"
  value       = local.grafana_sa_name
}

output "grafana_namespace" {
  description = "Namespace where Grafana is deployed"
  value       = var.namespace
}

output "grafana_datasources" {
  description = "Configured Grafana data sources"
  value = {
    prometheus_enabled = var.prometheus_url != null
    cloudwatch_enabled = var.enable_cloudwatch_datasource
    prometheus_url     = var.prometheus_url
  }
}

output "grafana_dashboards_enabled" {
  description = "Whether default dashboards are enabled"
  value       = var.enable_default_dashboards
}

output "grafana_storage_config" {
  description = "Grafana storage configuration"
  value = {
    storage_class = var.grafana_storage_class
    storage_size  = var.grafana_storage_size
  }
}