#############################################
# AlertManager Module Outputs
#############################################

output "alertmanager_url" {
  description = "AlertManager internal cluster URL"
  value       = "http://${local.alertmanager_name}.${var.namespace}.svc.cluster.local:9093"
}

output "alertmanager_external_url" {
  description = "AlertManager external URL (if exposed via ingress)"
  value       = null # Can be configured via ingress in future
}

output "alertmanager_role_arn" {
  description = "IAM role ARN for AlertManager (IRSA)"
  value       = aws_iam_role.alertmanager.arn
}

output "alertmanager_service_account" {
  description = "Kubernetes service account name for AlertManager"
  value       = "alertmanager-${local.alertmanager_name}"
}

output "alertmanager_namespace" {
  description = "Kubernetes namespace where AlertManager is deployed"
  value       = var.namespace
}

output "alertmanager_replica_count" {
  description = "Number of AlertManager replicas deployed"
  value       = var.alertmanager_replica_count
}

output "notification_channels" {
  description = "Configured notification channels"
  sensitive   = true
  value = {
    smtp      = local.has_smtp
    sns       = local.has_sns
    slack     = local.has_slack
    pagerduty = local.has_pagerduty
  }
}

output "alert_routing_summary" {
  description = "Summary of alert routing configuration"
  value = {
    group_by        = var.alert_routing_config.group_by
    group_wait      = var.alert_routing_config.group_wait
    group_interval  = var.alert_routing_config.group_interval
    repeat_interval = var.alert_routing_config.repeat_interval
    custom_routes   = length(var.alert_routing_config.routes)
  }
}