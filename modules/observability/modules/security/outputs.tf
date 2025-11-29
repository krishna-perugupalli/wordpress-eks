#############################################
# Security Module Outputs
#############################################

output "tls_enabled" {
  description = "Whether TLS encryption is enabled"
  value       = var.enable_tls_encryption
}

output "pii_scrubbing_enabled" {
  description = "Whether PII scrubbing is enabled"
  value       = var.enable_pii_scrubbing
}

output "audit_logging_enabled" {
  description = "Whether audit logging is enabled"
  value       = var.enable_audit_logging
}

output "audit_log_group_name" {
  description = "CloudWatch log group name for audit logs"
  value       = var.enable_audit_logging ? aws_cloudwatch_log_group.audit_logs[0].name : null
}

output "audit_log_group_arn" {
  description = "CloudWatch log group ARN for audit logs"
  value       = var.enable_audit_logging ? aws_cloudwatch_log_group.audit_logs[0].arn : null
}

output "monitoring_viewer_role_name" {
  description = "Name of the monitoring viewer role"
  value       = kubernetes_role.monitoring_viewer.metadata[0].name
}

output "monitoring_admin_role_name" {
  description = "Name of the monitoring admin role"
  value       = kubernetes_role.monitoring_admin.metadata[0].name
}

output "pii_scrubbing_rules_configmap" {
  description = "Name of the ConfigMap containing PII scrubbing rules"
  value       = var.enable_pii_scrubbing ? kubernetes_config_map.pii_scrubbing_rules[0].metadata[0].name : null
}