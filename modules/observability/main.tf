#############################################
# Enhanced Observability Module
# Supports both CloudWatch and Prometheus stack
#############################################

data "aws_caller_identity" "current" {}

#############################################
# Locals
#############################################
locals {
  ns                = var.namespace
  oidc_hostpath     = replace(var.cluster_oidc_issuer_url, "https://", "")
  kms_logs_key_trim = var.kms_logs_key_arn != null ? trimspace(var.kms_logs_key_arn) : ""
  has_kms_logs_key  = local.kms_logs_key_trim != ""

  lg_app       = "/aws/eks/${var.cluster_name}/application"
  lg_dataplane = "/aws/eks/${var.cluster_name}/dataplane"
  lg_host      = "/aws/eks/${var.cluster_name}/host"

  account_number = data.aws_caller_identity.current.account_id

  # Prometheus stack configuration
  prometheus_enabled   = var.enable_prometheus_stack
  grafana_enabled      = var.enable_grafana
  alertmanager_enabled = var.enable_alertmanager
}

#############################################
# Namespace
#############################################
resource "kubernetes_namespace" "ns" {
  metadata {
    name = local.ns
    labels = {
      "name"       = local.ns
      "monitoring" = "enabled"
    }
  }
}

#############################################
# CloudWatch Components (Legacy Support)
#############################################
module "cloudwatch" {
  source = "./modules/cloudwatch"
  count  = var.enable_cloudwatch ? 1 : 0

  name                     = var.name
  region                   = var.region
  cluster_name             = var.cluster_name
  cluster_oidc_issuer_url  = var.cluster_oidc_issuer_url
  oidc_provider_arn        = var.oidc_provider_arn
  namespace                = local.ns
  kms_logs_key_arn         = var.kms_logs_key_arn
  cw_retention_days        = var.cw_retention_days
  install_cloudwatch_agent = var.install_cloudwatch_agent
  install_fluent_bit       = var.install_fluent_bit
  tags                     = var.tags

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Prometheus Stack Components
#############################################
module "prometheus" {
  source = "./modules/prometheus"
  count  = local.prometheus_enabled ? 1 : 0

  name                    = var.name
  region                  = var.region
  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  oidc_provider_arn       = var.oidc_provider_arn
  namespace               = local.ns

  # Prometheus configuration
  prometheus_storage_size      = var.prometheus_storage_size
  prometheus_retention_days    = var.prometheus_retention_days
  prometheus_storage_class     = var.prometheus_storage_class
  prometheus_replica_count     = var.prometheus_replica_count
  prometheus_resource_requests = var.prometheus_resource_requests
  prometheus_resource_limits   = var.prometheus_resource_limits

  # Service discovery configuration
  enable_service_discovery     = var.enable_service_discovery
  service_discovery_namespaces = var.service_discovery_namespaces

  # Network resilience configuration
  enable_network_resilience   = var.enable_network_resilience
  remote_write_queue_capacity = var.remote_write_queue_capacity
  remote_write_max_backoff    = var.remote_write_max_backoff

  # KMS encryption
  kms_key_arn = var.kms_key_arn
  tags        = var.tags

  depends_on = [
    kubernetes_namespace.ns,
    module.exporters
  ]
}

module "grafana" {
  source = "./modules/grafana"
  count  = local.grafana_enabled ? 1 : 0

  name                    = var.name
  region                  = var.region
  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  oidc_provider_arn       = var.oidc_provider_arn
  namespace               = local.ns

  # Grafana configuration
  grafana_storage_size      = var.grafana_storage_size
  grafana_storage_class     = var.grafana_storage_class
  grafana_admin_password    = var.grafana_admin_password
  grafana_resource_requests = var.grafana_resource_requests
  grafana_resource_limits   = var.grafana_resource_limits
  grafana_replica_count     = var.grafana_replica_count

  # Authentication configuration
  enable_aws_iam_auth   = var.enable_aws_iam_auth
  grafana_iam_role_arns = var.grafana_iam_role_arns

  # Dashboard configuration
  enable_default_dashboards = var.enable_default_dashboards
  custom_dashboard_configs  = var.custom_dashboard_configs

  # Data source configuration
  prometheus_url               = local.prometheus_enabled ? module.prometheus[0].prometheus_url : null
  enable_cloudwatch_datasource = var.enable_cloudwatch_datasource

  # KMS encryption
  kms_key_arn = var.kms_key_arn
  tags        = var.tags

  depends_on = [kubernetes_namespace.ns]
}

module "alertmanager" {
  source = "./modules/alertmanager"
  count  = local.alertmanager_enabled ? 1 : 0

  name                    = var.name
  region                  = var.region
  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  oidc_provider_arn       = var.oidc_provider_arn
  namespace               = local.ns

  # AlertManager configuration
  alertmanager_storage_size      = var.alertmanager_storage_size
  alertmanager_storage_class     = var.alertmanager_storage_class
  alertmanager_replica_count     = var.alertmanager_replica_count
  alertmanager_resource_requests = var.alertmanager_resource_requests
  alertmanager_resource_limits   = var.alertmanager_resource_limits

  # Notification configuration
  smtp_config               = var.smtp_config
  sns_topic_arn             = var.sns_topic_arn
  slack_webhook_url         = var.slack_webhook_url
  pagerduty_integration_key = var.pagerduty_integration_key

  # Alert routing configuration
  alert_routing_config = var.alert_routing_config

  # KMS encryption
  kms_key_arn = var.kms_key_arn
  tags        = var.tags

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Exporters and Metrics Collection
#############################################
module "exporters" {
  source = "./modules/exporters"
  count  = local.prometheus_enabled ? 1 : 0

  name                    = var.name
  region                  = var.region
  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = var.cluster_oidc_issuer_url
  oidc_provider_arn       = var.oidc_provider_arn
  namespace               = local.ns

  # WordPress exporter configuration
  enable_wordpress_exporter = var.enable_wordpress_exporter
  wordpress_namespace       = var.wordpress_namespace
  wordpress_service_name    = var.wordpress_service_name

  # Database exporter configuration
  enable_mysql_exporter   = var.enable_mysql_exporter
  mysql_connection_config = var.mysql_connection_config

  # Cache exporter configuration
  enable_redis_exporter   = var.enable_redis_exporter
  redis_connection_config = var.redis_connection_config

  # AWS service monitoring
  enable_cloudwatch_exporter = var.enable_cloudwatch_exporter
  cloudwatch_metrics_config  = var.cloudwatch_metrics_config

  # Cost monitoring
  enable_cost_monitoring = var.enable_cost_monitoring
  cost_allocation_tags   = var.cost_allocation_tags

  # CloudFront monitoring
  enable_cloudfront_monitoring = var.enable_cloudfront_monitoring
  cloudfront_distribution_ids  = var.cloudfront_distribution_ids

  # KMS encryption
  kms_key_arn = var.kms_key_arn
  tags        = var.tags

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Security and Compliance
#############################################
module "security" {
  source = "./modules/security"
  count  = var.enable_security_features ? 1 : 0

  name         = var.name
  region       = var.region
  cluster_name = var.cluster_name
  namespace    = local.ns

  # Encryption configuration
  enable_tls_encryption   = var.enable_tls_encryption
  tls_cert_manager_issuer = var.tls_cert_manager_issuer

  # PII scrubbing configuration
  enable_pii_scrubbing = var.enable_pii_scrubbing
  pii_scrubbing_rules  = var.pii_scrubbing_rules

  # Audit logging configuration
  enable_audit_logging     = var.enable_audit_logging
  audit_log_retention_days = var.audit_log_retention_days

  # RBAC configuration
  rbac_policies = var.rbac_policies

  # KMS encryption
  kms_key_arn = var.kms_key_arn
  tags        = var.tags

  depends_on = [kubernetes_namespace.ns]
}