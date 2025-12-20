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
# Basic Observability (CloudWatch + Fluent Bit)
# ---------------------------
module "observability" {
  source = "../../modules/observability"

  # Cluster configuration
  cluster_name      = local.cluster_name
  cluster_endpoint  = local.cluster_endpoint
  cluster_version   = local.cluster_version
  cluster_ca_data   = local.cluster_ca_data
  oidc_provider_arn = local.oidc_provider_arn

  # Component toggles
  enable_prometheus     = var.enable_prometheus
  enable_grafana        = var.enable_grafana
  enable_alertmanager   = var.enable_alertmanager
  enable_fluentbit      = var.enable_fluentbit
  enable_loki           = var.enable_loki
  enable_tempo          = var.enable_tempo
  enable_yace           = var.enable_yace
  enable_metrics_server = var.enable_metrics_server

  # Dashboard toggles
  enable_wp_dashboards   = var.enable_wp_dashboards
  enable_aws_dashboards  = var.enable_aws_dashboards
  enable_cost_dashboards = var.enable_cost_dashboards

  # WordPress namespace for ServiceMonitor targeting
  wordpress_namespace = var.wp_namespace

  # Infrastructure endpoints from infra stack
  redis_endpoint = local.redis_endpoint
  mysql_endpoint = local.writer_endpoint
  project_name   = local.tags.Project
  environment    = local.tags.Env

  # Common tags
  tags = local.tags

  # Secrets
  grafana_secret_arn = local.grafana_admin_secret_arn

  depends_on = [module.edge_ingress]
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

  # Enable WordPress metrics exporter for Prometheus monitoring
  enable_metrics_exporter = var.enable_prometheus

  replicas_min          = var.wp_replicas_min
  replicas_max          = var.wp_replicas_max
  image_tag             = var.wp_image_tag
  target_cpu_percent    = var.wp_target_cpu_percent
  target_memory_percent = var.wp_target_memory_value
  depends_on            = [module.secrets_operator]
}
