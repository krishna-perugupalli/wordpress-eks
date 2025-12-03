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

#############################################
# cert-manager Outputs
#############################################
output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.enable_cert_manager
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = var.enable_cert_manager ? module.cert_manager[0].namespace : null
}

output "letsencrypt_prod_issuer" {
  description = "Name of the Let's Encrypt production ClusterIssuer"
  value       = var.enable_cert_manager ? module.cert_manager[0].letsencrypt_prod_issuer : null
}

output "letsencrypt_staging_issuer" {
  description = "Name of the Let's Encrypt staging ClusterIssuer"
  value       = var.enable_cert_manager ? module.cert_manager[0].letsencrypt_staging_issuer : null
}

output "selfsigned_issuer" {
  description = "Name of the self-signed ClusterIssuer"
  value       = var.enable_cert_manager ? module.cert_manager[0].selfsigned_issuer : null
}

#############################################
# Enhanced Observability Outputs
#############################################
output "monitoring_namespace" {
  description = "Namespace used for monitoring components"
  value       = module.observability.namespace
}

output "monitoring_stack_summary" {
  description = "Summary of enabled monitoring components"
  value       = module.observability.monitoring_stack_summary
}

# CloudWatch outputs (legacy support)
output "cloudwatch_enabled" {
  description = "Whether CloudWatch monitoring is enabled"
  value       = module.observability.cloudwatch_enabled
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value       = module.observability.log_groups
}

# Prometheus stack outputs
output "prometheus_enabled" {
  description = "Whether Prometheus monitoring stack is enabled"
  value       = module.observability.prometheus_enabled
}

output "prometheus_url" {
  description = "Prometheus server URL for internal cluster access"
  value       = module.observability.prometheus_url
}

output "prometheus_external_url" {
  description = "Prometheus server external URL (if exposed)"
  value       = module.observability.prometheus_external_url
}

# Grafana outputs
output "grafana_enabled" {
  description = "Whether Grafana is enabled"
  value       = module.observability.grafana_enabled
}

output "grafana_url" {
  description = "Grafana URL for internal cluster access"
  value       = module.observability.grafana_url
}

output "grafana_external_url" {
  description = "Grafana external URL (if exposed)"
  value       = module.observability.grafana_external_url
}

# AlertManager outputs
output "alertmanager_enabled" {
  description = "Whether AlertManager is enabled"
  value       = module.observability.alertmanager_enabled
}

output "alertmanager_url" {
  description = "AlertManager URL for internal cluster access"
  value       = module.observability.alertmanager_url
}

# Exporters outputs
output "wordpress_exporter_enabled" {
  description = "Whether WordPress exporter is enabled"
  value       = module.observability.wordpress_exporter_enabled
}

output "mysql_exporter_enabled" {
  description = "Whether MySQL exporter is enabled"
  value       = module.observability.mysql_exporter_enabled
}

output "redis_exporter_enabled" {
  description = "Whether Redis exporter is enabled"
  value       = module.observability.redis_exporter_enabled
}

output "cost_monitoring_enabled" {
  description = "Whether cost monitoring is enabled"
  value       = module.observability.cost_monitoring_enabled
}

output "cloudfront_monitoring_enabled" {
  description = "Whether CloudFront CDN monitoring is enabled"
  value       = module.observability.cloudfront_monitoring_enabled
}

# Security outputs
output "security_features_enabled" {
  description = "Whether security and compliance features are enabled"
  value       = module.observability.security_features_enabled
}

output "audit_logging_enabled" {
  description = "Whether audit logging is enabled"
  value       = module.observability.audit_logging_enabled
}

# High availability outputs
output "ha_dr_enabled" {
  description = "Whether high availability and disaster recovery features are enabled"
  value       = module.observability.ha_dr_enabled
}
