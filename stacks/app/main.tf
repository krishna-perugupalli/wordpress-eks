resource "null_resource" "require_infra_state" {
  lifecycle {
    precondition {
      condition     = local._ensure_infra_ready
      error_message = "Infra remote state has no outputs. Apply the Infra workspace first, then re-run the App workspace."
    }
  }
}

# ---------------------------
# External Secrets Operator (IRSA + Helm)
# ---------------------------
module "secrets_operator" {
  source                  = "../../modules/secrets-operator"
  name                    = local.name
  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  oidc_provider_arn       = local.oidc_provider_arn
  aws_region              = var.region

  # Option A: use module-managed read policy (recommended via secrets-iam)
  secrets_read_policy_arn = local.secrets_read_policy_arn
  eso_role_arn            = local.infra_outputs.eso_role_arn

  tags = local.tags

  depends_on = [module.edge_ingress]
}

# ---------------------------
# Edge / Ingress (AWS Load Balancer Controller for TargetGroupBinding)
# ---------------------------
module "edge_ingress" {
  source = "../../modules/edge-ingress"
  name   = local.name
  region = var.region

  cluster_name            = local.cluster_name
  oidc_provider_arn       = local.oidc_provider_arn
  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  vpc_id                  = local.vpc_id

  create_regional_certificate = var.create_regional_certificate
  alb_domain_name             = var.alb_domain_name
  alb_hosted_zone_id          = var.alb_hosted_zone_id

  create_cf_certificate = var.create_cf_certificate

  tags = local.tags
}

# ---------------------------
# cert-manager (TLS Certificate Management)
# ---------------------------
module "cert_manager" {
  source = "../../modules/cert-manager"
  count  = var.enable_cert_manager ? 1 : 0

  name      = local.name
  namespace = var.cert_manager_namespace

  cert_manager_version      = var.cert_manager_version
  enable_prometheus_metrics = var.enable_prometheus_stack

  # ClusterIssuer configuration
  create_letsencrypt_issuer = var.create_letsencrypt_issuer
  letsencrypt_email         = var.letsencrypt_email
  create_selfsigned_issuer  = var.create_selfsigned_issuer

  # Resource configuration
  resource_requests = var.cert_manager_resource_requests
  resource_limits   = var.cert_manager_resource_limits

  tags = local.tags

  depends_on = [module.edge_ingress]
}

# ---------------------------
# Enhanced Observability (CloudWatch + Prometheus Stack)
# ---------------------------
module "observability" {
  source                  = "../../modules/observability"
  name                    = local.name
  region                  = var.region
  cluster_name            = local.cluster_name
  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  oidc_provider_arn       = local.oidc_provider_arn

  namespace = var.observability_namespace

  # KMS encryption
  kms_key_arn = local.kms_logs_arn

  # CloudWatch configuration (legacy support)
  enable_cloudwatch        = var.enable_cloudwatch
  kms_logs_key_arn         = local.kms_logs_arn
  cw_retention_days        = var.cw_retention_days
  install_cloudwatch_agent = var.install_cloudwatch_agent
  install_fluent_bit       = var.install_fluent_bit

  # Prometheus stack configuration
  enable_prometheus_stack = var.enable_prometheus_stack
  enable_grafana          = var.enable_grafana
  enable_alertmanager     = var.enable_alertmanager

  # Prometheus configuration
  prometheus_storage_size      = var.prometheus_storage_size
  prometheus_retention_days    = var.prometheus_retention_days
  prometheus_storage_class     = var.prometheus_storage_class
  prometheus_replica_count     = var.prometheus_replica_count
  prometheus_resource_requests = var.prometheus_resource_requests
  prometheus_resource_limits   = var.prometheus_resource_limits

  # Service discovery
  enable_service_discovery     = var.enable_service_discovery
  service_discovery_namespaces = var.service_discovery_namespaces

  # Grafana configuration
  grafana_storage_size         = var.grafana_storage_size
  grafana_storage_class        = var.grafana_storage_class
  grafana_admin_password       = var.grafana_admin_password
  grafana_resource_requests    = var.grafana_resource_requests
  grafana_resource_limits      = var.grafana_resource_limits
  enable_aws_iam_auth          = var.enable_aws_iam_auth
  grafana_iam_role_arns        = var.grafana_iam_role_arns
  enable_default_dashboards    = var.enable_default_dashboards
  custom_dashboard_configs     = var.custom_dashboard_configs
  enable_cloudwatch_datasource = var.enable_cloudwatch_datasource

  # AlertManager configuration
  alertmanager_storage_size      = var.alertmanager_storage_size
  alertmanager_storage_class     = var.alertmanager_storage_class
  alertmanager_replica_count     = var.alertmanager_replica_count
  alertmanager_resource_requests = var.alertmanager_resource_requests
  alertmanager_resource_limits   = var.alertmanager_resource_limits
  smtp_config                    = var.smtp_config
  sns_topic_arn                  = var.sns_topic_arn
  slack_webhook_url              = var.slack_webhook_url
  pagerduty_integration_key      = var.pagerduty_integration_key
  alert_routing_config           = var.alert_routing_config

  # Exporters configuration
  enable_wordpress_exporter  = var.enable_wordpress_exporter
  wordpress_namespace        = var.wp_namespace
  wordpress_service_name     = module.app_wordpress.service_name
  enable_mysql_exporter      = var.enable_mysql_exporter
  mysql_connection_config    = var.mysql_connection_config
  enable_redis_exporter      = var.enable_redis_exporter
  redis_connection_config    = var.redis_connection_config
  enable_cloudwatch_exporter = var.enable_cloudwatch_exporter
  cloudwatch_metrics_config  = var.cloudwatch_metrics_config
  enable_cost_monitoring     = var.enable_cost_monitoring
  cost_allocation_tags       = var.cost_allocation_tags

  # Security configuration
  enable_security_features = var.enable_security_features
  enable_tls_encryption    = var.enable_tls_encryption
  tls_cert_manager_issuer  = var.tls_cert_manager_issuer
  enable_pii_scrubbing     = var.enable_pii_scrubbing
  pii_scrubbing_rules      = var.pii_scrubbing_rules
  enable_audit_logging     = var.enable_audit_logging
  audit_log_retention_days = var.audit_log_retention_days
  rbac_policies            = var.rbac_policies

  tags = local.tags

  depends_on = [
    module.edge_ingress,
    module.cert_manager
  ]
}

#############################################
# StorageClass for EFS (dynamic access points)
#############################################
resource "kubernetes_storage_class_v1" "efs_ap" {
  metadata {
    name = var.efs_id # this is the name your WordPress chart references
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = var.efs_id
    fileSystemId     = local.file_system_id
    directoryPerms   = "0770"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    basePath         = "/k8s" # optional
  }

  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}

# ---------------------------
# WordPress (Bitnami) + ESO-fed Secrets + EFS
# ---------------------------
module "app_wordpress" {
  source = "../../modules/app-wordpress"

  name        = local.name
  namespace   = var.wp_namespace
  domain_name = var.wp_domain_name

  # NEW: Pass target group ARN from infra stack
  target_group_arn = local.target_group_arn

  storage_class_name = var.wp_storage_class
  pvc_size           = var.wp_pvc_size

  enable_redis_cache      = var.enable_redis_cache
  redis_endpoint          = coalesce(local.redis_endpoint, "")
  redis_port              = var.redis_port
  redis_database          = var.redis_database
  redis_connection_scheme = var.redis_connection_scheme
  redis_auth_secret_arn   = coalesce(local.redis_auth_secret_arn, "")

  db_host             = local.writer_endpoint
  db_name             = var.db_name
  db_user             = var.db_user
  db_secret_arn       = local.wpapp_db_secret_arn
  db_admin_secret_arn = try(local.aurora_master_secret_arn, null)

  behind_cloudfront = var.enable_cloudfront

  admin_secret_arn        = local.wp_admin_secret_arn
  admin_user              = var.wp_admin_user
  admin_email             = var.wp_admin_email
  admin_bootstrap_enabled = var.wp_admin_bootstrap_enabled

  replicas_min          = var.wp_replicas_min
  replicas_max          = var.wp_replicas_max
  image_tag             = var.wp_image_tag
  target_cpu_percent    = var.wp_target_cpu_percent
  target_memory_percent = var.wp_target_memory_value
  depends_on            = [module.secrets_operator]
}