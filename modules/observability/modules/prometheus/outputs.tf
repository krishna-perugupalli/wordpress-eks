#############################################
# Prometheus Module Outputs
#############################################

output "prometheus_url" {
  description = "Prometheus server URL for internal cluster access"
  value       = "http://prometheus-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090"
}

output "prometheus_external_url" {
  description = "Prometheus external URL (if exposed via ingress)"
  value       = null # Will be configured when ingress is set up
}

output "prometheus_role_arn" {
  description = "IAM role ARN for Prometheus server (IRSA)"
  value       = aws_iam_role.prometheus.arn
}

output "prometheus_service_account_name" {
  description = "Kubernetes service account name for Prometheus"
  value       = "prometheus-kube-prometheus-prometheus"
}

output "helm_release_name" {
  description = "Helm release name for kube-prometheus-stack"
  value       = helm_release.kube_prometheus_stack.name
}

output "helm_release_namespace" {
  description = "Namespace where Prometheus stack is deployed"
  value       = helm_release.kube_prometheus_stack.namespace
}

output "storage_class_name" {
  description = "Storage class name used for Prometheus persistent volumes"
  value       = var.prometheus_storage_class
}

output "prometheus_retention_period" {
  description = "Prometheus metrics retention period"
  value       = "${var.prometheus_retention_days}d"
}

output "prometheus_storage_size" {
  description = "Prometheus persistent storage size"
  value       = var.prometheus_storage_size
}

output "prometheus_replica_count" {
  description = "Number of Prometheus server replicas"
  value       = var.prometheus_replica_count
}

output "alert_rules_deployed" {
  description = "Name of the deployed PrometheusRule resource"
  value       = kubectl_manifest.prometheus_alert_rules.name
}

output "alert_rules_namespace" {
  description = "Namespace where alert rules are deployed"
  value       = var.namespace
}
