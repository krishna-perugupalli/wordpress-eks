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

# YACE Exporter Outputs
output "yace_namespace" {
  description = "Namespace where YACE exporter is deployed"
  value       = var.enable_yace ? local.monitoring_namespace : null
}

output "yace_service_name" {
  description = "Service name for YACE exporter"
  value       = var.enable_yace ? "yace-yet-another-cloudwatch-exporter" : null
}

output "yace_role_arn" {
  description = "IAM role ARN for YACE IRSA"
  value       = var.enable_yace ? try(aws_iam_role.yace[0].arn, null) : null
}

# Dashboard Outputs
output "dashboard_configmaps" {
  description = "List of dashboard ConfigMap names created for Grafana provisioning"
  value = compact([
    var.enable_prometheus ? "wordpress-dashboard" : "",
    var.enable_prometheus ? "kubernetes-dashboard" : "",
    var.enable_prometheus && var.enable_yace ? "aws-services-dashboard" : "",
    var.enable_prometheus && var.enable_yace ? "cost-dashboard" : ""
  ])
}

output "grafana_dashboard_folders" {
  description = "List of Grafana folders created for dashboard organization"
  value = compact([
    var.enable_prometheus ? "WordPress" : "",
    var.enable_prometheus ? "Kubernetes" : "",
    var.enable_prometheus && var.enable_yace ? "AWS Services" : "",
    var.enable_prometheus && var.enable_yace ? "Cost Tracking" : ""
  ])
}

# Alerting Outputs (Phase 4)
output "alerting_enabled" {
  description = "Current alerting toggle state"
  value       = var.enable_alerting
}

output "prometheus_rules_count" {
  description = "Number of deployed PrometheusRule resources"
  value = var.enable_alerting ? length([
    "wordpress-alerts",
    "kubernetes-alerts",
    "aws-alerts",
    "cost-alerts"
  ]) : 0
}

output "prometheus_rules_deployed" {
  description = "List of deployed PrometheusRule resource names"
  value = var.enable_alerting ? [
    "wordpress-alerts",
    "kubernetes-alerts",
    "aws-alerts",
    "cost-alerts"
  ] : []
}

output "alertmanager_config_deployed" {
  description = "Alertmanager configuration deployment status"
  value       = var.enable_alerting
}

output "notification_provider" {
  description = "Configured notification provider for alerts"
  value       = var.enable_alerting ? var.notification_provider : null
}