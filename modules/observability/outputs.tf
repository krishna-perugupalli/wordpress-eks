#############################################
# Core Outputs
#############################################
output "namespace" {
  value       = var.namespace
  description = "Namespace used for monitoring components"
}

#############################################
# CloudWatch Outputs (Legacy Support)
#############################################
output "cloudwatch_enabled" {
  value       = var.enable_cloudwatch
  description = "Whether CloudWatch monitoring is enabled"
}

output "log_groups" {
  description = "CloudWatch log group names for app/dataplane/host"
  value = var.enable_cloudwatch ? {
    application = try(module.cloudwatch[0].log_groups.application, null)
    dataplane   = try(module.cloudwatch[0].log_groups.dataplane, null)
    host        = try(module.cloudwatch[0].log_groups.host, null)
  } : {}
}

output "cwagent_role_arn" {
  description = "IAM role ARN for CloudWatch Agent"
  value       = var.enable_cloudwatch ? try(module.cloudwatch[0].cwagent_role_arn, null) : null
}

output "fluentbit_role_arn" {
  description = "IAM role ARN for Fluent Bit"
  value       = var.enable_cloudwatch ? try(module.cloudwatch[0].fluentbit_role_arn, null) : null
}

#############################################
# Prometheus Stack Outputs
#############################################
output "prometheus_enabled" {
  value       = var.enable_prometheus_stack
  description = "Whether Prometheus monitoring stack is enabled"
}

output "prometheus_url" {
  description = "Prometheus server URL for internal cluster access"
  value       = var.enable_prometheus_stack ? try(module.prometheus[0].prometheus_url, null) : null
}

output "prometheus_external_url" {
  description = "Prometheus server external URL (if exposed)"
  value       = var.enable_prometheus_stack ? try(module.prometheus[0].prometheus_external_url, null) : null
}

output "prometheus_role_arn" {
  description = "IAM role ARN for Prometheus server"
  value       = var.enable_prometheus_stack ? try(module.prometheus[0].prometheus_role_arn, null) : null
}

output "prometheus_storage_class" {
  description = "Storage class used for Prometheus persistent volumes"
  value       = var.enable_prometheus_stack ? var.prometheus_storage_class : null
}

#############################################
# Grafana Outputs
#############################################
output "grafana_enabled" {
  value       = var.enable_grafana
  description = "Whether Grafana is enabled"
}

output "grafana_url" {
  description = "Grafana URL for internal cluster access"
  value       = var.enable_grafana ? try(module.grafana[0].grafana_url, null) : null
}

output "grafana_external_url" {
  description = "Grafana external URL (if exposed)"
  value       = var.enable_grafana ? try(module.grafana[0].grafana_external_url, null) : null
}

output "grafana_role_arn" {
  description = "IAM role ARN for Grafana"
  value       = var.enable_grafana ? try(module.grafana[0].grafana_role_arn, null) : null
}

output "grafana_admin_secret_name" {
  description = "Kubernetes secret name containing Grafana admin credentials"
  value       = var.enable_grafana ? try(module.grafana[0].grafana_admin_secret_name, null) : null
}

#############################################
# AlertManager Outputs
#############################################
output "alertmanager_enabled" {
  value       = var.enable_alertmanager
  description = "Whether AlertManager is enabled"
}

output "alertmanager_url" {
  description = "AlertManager URL for internal cluster access"
  value       = var.enable_alertmanager ? try(module.alertmanager[0].alertmanager_url, null) : null
}

output "alertmanager_external_url" {
  description = "AlertManager external URL (if exposed)"
  value       = var.enable_alertmanager ? try(module.alertmanager[0].alertmanager_external_url, null) : null
}

output "alertmanager_role_arn" {
  description = "IAM role ARN for AlertManager"
  value       = var.enable_alertmanager ? try(module.alertmanager[0].alertmanager_role_arn, null) : null
}

#############################################
# Exporters Outputs
#############################################
output "exporters_enabled" {
  value       = var.enable_prometheus_stack
  description = "Whether metrics exporters are enabled"
}

output "wordpress_exporter_enabled" {
  value       = var.enable_wordpress_exporter && var.enable_prometheus_stack
  description = "Whether WordPress exporter is enabled"
}

output "mysql_exporter_enabled" {
  value       = var.enable_mysql_exporter && var.enable_prometheus_stack
  description = "Whether MySQL exporter is enabled"
}

output "redis_exporter_enabled" {
  value       = var.enable_redis_exporter && var.enable_prometheus_stack
  description = "Whether Redis exporter is enabled"
}

output "cloudwatch_exporter_enabled" {
  value       = var.enable_cloudwatch_exporter && var.enable_prometheus_stack
  description = "Whether CloudWatch exporter is enabled"
}

output "cost_monitoring_enabled" {
  value       = var.enable_cost_monitoring && var.enable_prometheus_stack
  description = "Whether cost monitoring is enabled"
}

output "cloudfront_monitoring_enabled" {
  value       = var.enable_cloudfront_monitoring && var.enable_prometheus_stack
  description = "Whether CloudFront CDN monitoring is enabled"
}

output "cloudfront_distribution_ids" {
  value       = var.enable_cloudfront_monitoring ? var.cloudfront_distribution_ids : []
  description = "List of CloudFront distribution IDs being monitored"
}

output "mysql_exporter_info" {
  description = "MySQL exporter deployment information"
  value       = var.enable_prometheus_stack ? try(module.exporters[0].mysql_exporter, null) : null
}

output "redis_exporter_info" {
  description = "Redis exporter deployment information"
  value       = var.enable_prometheus_stack ? try(module.exporters[0].redis_exporter, null) : null
}

output "service_monitors" {
  description = "Created ServiceMonitor resources for metrics collection"
  value       = var.enable_prometheus_stack ? try(module.exporters[0].service_monitors, {}) : {}
}

output "pod_monitors" {
  description = "Created PodMonitor resources for metrics collection"
  value       = var.enable_prometheus_stack ? try(module.exporters[0].pod_monitors, {}) : {}
}

#############################################
# Security Outputs
#############################################
output "security_features_enabled" {
  value       = var.enable_security_features
  description = "Whether security and compliance features are enabled"
}

output "tls_encryption_enabled" {
  value       = var.enable_tls_encryption && var.enable_security_features
  description = "Whether TLS encryption is enabled for monitoring communications"
}

output "pii_scrubbing_enabled" {
  value       = var.enable_pii_scrubbing && var.enable_security_features
  description = "Whether PII scrubbing is enabled"
}

output "audit_logging_enabled" {
  value       = var.enable_audit_logging && var.enable_security_features
  description = "Whether audit logging is enabled"
}

output "audit_log_group_name" {
  description = "CloudWatch log group name for audit logs"
  value       = var.enable_security_features && var.enable_audit_logging ? try(module.security[0].audit_log_group_name, null) : null
}

output "audit_log_group_arn" {
  description = "CloudWatch log group ARN for audit logs"
  value       = var.enable_security_features && var.enable_audit_logging ? try(module.security[0].audit_log_group_arn, null) : null
}

output "monitoring_viewer_role_name" {
  description = "Name of the monitoring viewer role for RBAC"
  value       = var.enable_security_features ? try(module.security[0].monitoring_viewer_role_name, null) : null
}

output "monitoring_admin_role_name" {
  description = "Name of the monitoring admin role for RBAC"
  value       = var.enable_security_features ? try(module.security[0].monitoring_admin_role_name, null) : null
}

output "pii_scrubbing_rules_configmap" {
  description = "Name of the ConfigMap containing PII scrubbing rules"
  value       = var.enable_security_features && var.enable_pii_scrubbing ? try(module.security[0].pii_scrubbing_rules_configmap, null) : null
}

#############################################
# Service Discovery Outputs
#############################################
output "service_discovery_enabled" {
  value       = var.enable_service_discovery && var.enable_prometheus_stack
  description = "Whether automatic service discovery is enabled"
}

output "monitored_namespaces" {
  value       = var.enable_service_discovery && var.enable_prometheus_stack ? var.service_discovery_namespaces : []
  description = "List of namespaces being monitored for service discovery"
}

#############################################
# Configuration Summary
#############################################
output "monitoring_stack_summary" {
  description = "Summary of enabled monitoring components"
  value = {
    cloudwatch_enabled        = var.enable_cloudwatch
    prometheus_enabled        = var.enable_prometheus_stack
    grafana_enabled           = var.enable_grafana
    alertmanager_enabled      = var.enable_alertmanager
    security_enabled          = var.enable_security_features
    service_discovery_enabled = var.enable_service_discovery && var.enable_prometheus_stack
    namespace                 = var.namespace
    storage_class             = var.prometheus_storage_class
  }
}

#############################################
# High Availability and Disaster Recovery Outputs
#############################################
output "ha_dr_enabled" {
  value       = var.enable_backup_policies || var.enable_cloudwatch_fallback || var.enable_automatic_recovery
  description = "Whether high availability and disaster recovery features are enabled"
}

output "backup_vault_name" {
  description = "AWS Backup vault name for monitoring data"
  value       = var.enable_backup_policies ? aws_backup_vault.monitoring[0].name : null
}

output "backup_vault_arn" {
  description = "AWS Backup vault ARN for monitoring data"
  value       = var.enable_backup_policies ? aws_backup_vault.monitoring[0].arn : null
}

output "backup_plan_id" {
  description = "AWS Backup plan ID for monitoring data"
  value       = var.enable_backup_policies ? aws_backup_plan.monitoring[0].id : null
}

output "cloudwatch_fallback_topic_arn" {
  description = "SNS topic ARN for CloudWatch fallback alerts"
  value       = var.enable_cloudwatch_fallback ? aws_sns_topic.cloudwatch_fallback[0].arn : null
}

output "cloudwatch_fallback_alarms" {
  description = "CloudWatch fallback alarm names"
  value = var.enable_cloudwatch_fallback ? {
    prometheus_unavailable        = local.prometheus_enabled ? aws_cloudwatch_metric_alarm.prometheus_unavailable[0].alarm_name : null
    grafana_unavailable           = local.grafana_enabled ? aws_cloudwatch_metric_alarm.grafana_unavailable[0].alarm_name : null
    alertmanager_unavailable      = local.alertmanager_enabled ? aws_cloudwatch_metric_alarm.alertmanager_unavailable[0].alarm_name : null
    wordpress_critical            = var.enable_wordpress_exporter ? aws_cloudwatch_metric_alarm.wordpress_critical_fallback[0].alarm_name : null
    database_connections_critical = var.enable_mysql_exporter ? aws_cloudwatch_metric_alarm.database_connections_critical_fallback[0].alarm_name : null
  } : {}
}

output "pod_disruption_budgets" {
  description = "Pod disruption budgets for monitoring components"
  value = {
    prometheus   = local.prometheus_enabled ? kubernetes_pod_disruption_budget_v1.prometheus[0].metadata[0].name : null
    grafana      = local.grafana_enabled ? kubernetes_pod_disruption_budget_v1.grafana[0].metadata[0].name : null
    alertmanager = local.alertmanager_enabled ? kubernetes_pod_disruption_budget_v1.alertmanager[0].metadata[0].name : null
  }
}

output "automatic_recovery_enabled" {
  value       = var.enable_automatic_recovery
  description = "Whether automatic recovery mechanisms are enabled"
}

output "health_check_cronjob_name" {
  description = "Name of the health check CronJob for automatic recovery"
  value       = var.enable_automatic_recovery ? kubernetes_cron_job_v1.monitoring_health_check[0].metadata[0].name : null
}