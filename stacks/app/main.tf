locals {
  name = var.project
  tags = merge(
    {
      Project = var.project
      Env     = var.env
      Owner   = var.owner_email
    },
    var.tags
  )

  # azs           = data.aws_availability_zones.available.names
  infra_outputs = data.terraform_remote_state.infra.outputs

  cluster_name                      = local.infra_outputs.cluster_name
  cluster_endpoint                  = local.infra_outputs.cluster_endpoint
  karpenter_controller_iam_role_arn = local.infra_outputs.karpenter_role_arn
  karpenter_sqs_queue_name          = local.infra_outputs.karpenter_sqs_queue_name
  karpenter_node_iam_role_name      = local.infra_outputs.karpenter_node_iam_role_name
  cluster_oidc_issuer_url           = local.infra_outputs.cluster_oidc_issuer_url
  oidc_provider_arn                 = local.infra_outputs.oidc_provider_arn
  vpc_id                            = local.infra_outputs.vpc_id
  azs                               = local.infra_outputs.azs
  secrets_read_policy_arn           = local.infra_outputs.secrets_read_policy_arn
  kms_logs_arn                      = local.infra_outputs.kms_logs_arn
  writer_endpoint                   = local.infra_outputs.writer_endpoint
  wpapp_db_secret_arn               = local.infra_outputs.wpapp_db_secret_arn
  wp_admin_secret_arn               = local.infra_outputs.wp_admin_secret_arn
  cf_log_bucket_name                = local.infra_outputs.log_bucket_name
  file_system_id                    = local.infra_outputs.file_system_id

  _ensure_infra_ready = length(keys(local.infra_outputs)) > 0
}

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
# Edge / Ingress (ALB + ACM + WAF)
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

  create_waf_regional = var.create_waf_regional
  waf_ruleset_level   = var.waf_ruleset_level

  tags = local.tags
}

# ---------------------------
# Edge CDN (Cloudfront + ACM)
# ---------------------------
module "edge_cdn" {
  # Create CloudFront only when enabled and ALB has been discovered
  count  = var.enable_cloudfront && local.alb_found ? 1 : 0
  source = "../../modules/edge-cdn"
  name   = local.name

  domain_name = var.alb_domain_name
  aliases     = var.cf_aliases
  # Use the actual ALB DNS name as CloudFront origin
  alb_dns_name        = data.aws_lb.wp_alb[0].dns_name
  acm_certificate_arn = var.cf_acm_certificate_arn
  waf_web_acl_arn     = ""
  log_bucket_name     = local.cf_log_bucket_name
  origin_secret_value = ""

  tags = local.tags

  # Ensure the ALB/Ingress exists before CF (origin dependency)
  depends_on = [module.app_wordpress]
}

# ---------------------------
# Karpenter (controller + NodePool)
# ---------------------------
/* module "karpenter" {
  source                  = "../../modules/karpenter"
  name                    = local.name
  cluster_name            = local.cluster_name
  oidc_provider_arn       = local.oidc_provider_arn
  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url

  subnet_selector_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  security_group_selector_tags = {
    "kubernetes.io/cluster/${local.name}" = "owned"
  }

  enable_interruption_queue = true

  instance_types       = var.karpenter_instance_types
  capacity_types       = var.karpenter_capacity_types
  ami_family           = var.karpenter_ami_family
  consolidation_policy = var.karpenter_consolidation_policy
  expire_after         = var.karpenter_expire_after
  cpu_limit            = var.karpenter_cpu_limit
  labels               = { role = "web" }
  taints               = []

  tags = local.tags
} */

# ---------------------------
# Observability (CW Agent + Fluent Bit + ALB alarms)
# ---------------------------
module "observability" {
  source                  = "../../modules/observability"
  name                    = local.name
  region                  = var.region
  cluster_name            = local.cluster_name
  cluster_oidc_issuer_url = local.cluster_oidc_issuer_url
  oidc_provider_arn       = local.oidc_provider_arn

  namespace         = var.observability_namespace
  kms_logs_key_arn  = local.kms_logs_arn
  cw_retention_days = var.cw_retention_days

  install_cloudwatch_agent = var.install_cloudwatch_agent
  install_fluent_bit       = var.install_fluent_bit

  create_alb_alarms = var.create_alb_alarms

  ingress_name      = module.app_wordpress.ingress_name
  ingress_namespace = module.app_wordpress.namespace
  service_name      = module.app_wordpress.service_name
  service_namespace = module.app_wordpress.namespace

  tags = local.tags
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

  alb_certificate_arn = var.acm_certificate_arn
  waf_acl_arn         = module.edge_ingress.waf_regional_arn
  # Tag ALB via Ingress annotation so we can discover it for DNS/CF
  alb_tags = { project = local.name, env = var.env, dns = var.wp_domain_name }

  storage_class_name = var.wp_storage_class
  pvc_size           = var.wp_pvc_size

  db_host       = local.writer_endpoint
  db_name       = var.db_name
  db_user       = var.db_user
  db_secret_arn = local.wpapp_db_secret_arn

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

#############################################
# DNS resolution + conditional records
#############################################

# Discover the ALB created by AWS Load Balancer Controller using our tags
data "aws_resourcegroupstaggingapi_resources" "wp_alb" {
  resource_type_filters = ["elasticloadbalancing:loadbalancer"]
  tag_filter {
    key    = "project"
    values = [local.name]
  }
  tag_filter {
    key    = "env"
    values = [var.env]
  }
  tag_filter {
    key    = "dns"
    values = [var.wp_domain_name]
  }

  depends_on = [module.app_wordpress]
}

locals {
  alb_arn   = try(data.aws_resourcegroupstaggingapi_resources.wp_alb.resource_tag_mapping_list[0].resource_arn, null)
  alb_found = local.alb_arn != null && local.alb_arn != ""
}

# Materialize ALB details when found
data "aws_lb" "wp_alb" {
  count = local.alb_found ? 1 : 0
  arn   = local.alb_arn
}

# If CloudFront is enabled, alias the domain to the distribution
resource "aws_route53_record" "wp_cf_alias" {
  count = var.enable_cloudfront && local.alb_found ? 1 : 0

  zone_id = var.alb_hosted_zone_id
  name    = var.alb_domain_name
  type    = "A"

  alias {
    name                   = module.edge_cdn[0].distribution_domain_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = false
  }
}

# If CloudFront is disabled, alias the domain directly to the ALB
resource "aws_route53_record" "wp_alb_alias" {
  count = var.enable_alb_traffic ? 0 : (local.alb_found ? 1 : 0)

  zone_id = var.alb_hosted_zone_id
  name    = var.alb_domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.wp_alb[0].dns_name
    zone_id                = data.aws_lb.wp_alb[0].zone_id
    evaluate_target_health = true
  }
  depends_on = [module.app_wordpress]
}
