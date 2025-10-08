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
}

# ---------------------------
# Foundation (VPC, subnets, NAT, KMS base)
# ---------------------------
module "foundation" {
  source           = "../../modules/foundation"
  name             = local.name
  region           = var.region
  vpc_cidr         = var.vpc_cidr
  private_cidrs    = var.private_cidrs
  public_cidrs     = var.public_cidrs
  nat_gateway_mode = var.nat_gateway_mode
  tags             = local.tags
}

# ---------------------------
# IAM roles for EKS control plane and nodes
# ---------------------------
module "iam_eks" {
  source = "../../modules/iam-eks"
  name   = local.name
  tags   = local.tags
}

# ---------------------------
# EKS cluster (terraform-aws-modules/eks via our wrapper)
# ---------------------------
module "eks_core" {
  source                       = "../../modules/eks-core"
  name                         = local.name
  region                       = var.region
  vpc_id                       = module.foundation.vpc_id
  private_subnet_ids           = module.foundation.private_subnet_ids
  cluster_role_arn             = module.iam_eks.cluster_role_arn
  node_role_arn                = module.iam_eks.node_role_arn
  secrets_kms_key_arn          = module.foundation.kms_logs_arn
  cluster_version              = var.cluster_version
  endpoint_public_access       = var.endpoint_public_access
  enable_irsa                  = var.enable_irsa
  enable_cni_prefix_delegation = var.enable_cni_prefix_delegation
  system_node_type             = var.system_node_type
  system_node_min              = var.system_node_min
  system_node_max              = var.system_node_max
  tags                         = local.tags
}

# ---------------------------
# Aurora MySQL (Serverless v2)
# ---------------------------
module "data_aurora" {
  source             = "../../modules/data-aurora"
  name               = local.name
  region             = var.region
  vpc_id             = module.foundation.vpc_id
  private_subnet_ids = module.foundation.private_subnet_ids

  db_name                = var.db_name
  admin_username         = var.db_admin_username
  create_random_password = var.db_create_random_password

  storage_kms_key_arn         = module.foundation.kms_logs_arn
  secrets_manager_kms_key_arn = module.foundation.kms_logs_arn

  source_node_sg_id   = module.eks_core.node_security_group_id
  allowed_cidr_blocks = [] # or ["x.x.x.x/32"] temporarily for migrations

  serverless_v2      = true
  serverless_min_acu = var.db_serverless_min_acu
  serverless_max_acu = var.db_serverless_max_acu

  backup_retention_days        = var.db_backup_retention_days
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = var.db_maintenance_window
  deletion_protection          = var.db_deletion_protection

  enable_backup            = var.db_enable_backup
  backup_vault_name        = var.backup_vault_name
  backup_schedule_cron     = var.db_backup_cron
  backup_delete_after_days = var.db_backup_delete_after_days

  # cross-region copy intentionally omitted for now
  tags = local.tags
}

# ---------------------------
# EFS (wp-content)
# ---------------------------
module "data_efs" {
  source             = "../../modules/data-efs"
  name               = local.name
  region             = var.region
  vpc_id             = module.foundation.vpc_id
  private_subnet_ids = module.foundation.private_subnet_ids

  allowed_security_group_ids = [module.eks_core.node_security_group_id]

  kms_key_arn         = var.efs_kms_key_arn
  performance_mode    = var.efs_performance_mode
  throughput_mode     = var.efs_throughput_mode
  enable_lifecycle_ia = var.efs_enable_lifecycle_ia

  create_fixed_access_point = true
  ap_path                   = var.efs_ap_path
  ap_owner_uid              = var.efs_ap_owner_uid
  ap_owner_gid              = var.efs_ap_owner_gid

  cluster_name            = module.eks_core.cluster_name
  oidc_provider_arn       = module.eks_core.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks_core.cluster_oidc_issuer_url

  enable_backup            = var.efs_enable_backup
  backup_vault_name        = var.backup_vault_name
  backup_schedule_cron     = var.efs_backup_cron
  backup_delete_after_days = var.efs_backup_delete_after_days

  tags = local.tags
}

# ---------------------------
# Security baseline (CloudTrail, Config, GuardDuty, Budgets)
# ---------------------------
module "security_baseline" {
  source = "../../modules/security-baseline"

  name = local.name
  # Optional: pin a bucket name; leave "" to auto-generate a unique one
  trail_bucket_name             = ""
  logs_expire_after_days        = 365
  cloudtrail_cwl_retention_days = 90

  create_cloudtrail = true
  create_config     = true
  create_guardduty  = true

  tags = local.tags
}

# ---------------------------
# Secrets + IAM for ESO and app secrets
# ---------------------------
module "secrets_iam" {
  source = "../../modules/secrets-iam"
  name   = local.name
  region = var.region
  tags   = local.tags

  cluster_oidc_provider_arn = module.eks_core.oidc_provider_arn
  eso_namespace             = "external-secrets"
  eso_service_account_name  = "external-secrets"
  eso_validate_audience     = true

  create_wpapp_db_secret = true
  wpapp_db_secret_name   = "${local.name}-wpapp-db"

  create_wp_admin_secret = true
  wp_admin_secret_name   = "${local.name}-wp-admin"

  create_redis_auth_secret = true
  redis_auth_secret_name   = "${local.name}-redis-auth"
}

# ---------------------------
# ElastiCache (Redis) for object cache
# ---------------------------
module "elasticache" {
  source                   = "../../modules/elasticache"
  name                     = local.name
  vpc_id                   = module.foundation.vpc_id
  subnet_ids               = module.foundation.private_subnet_ids
  node_sg_source_ids       = [module.eks_core.node_security_group_id]
  enable_auth_token_secret = true
  auth_token_secret_arn    = module.secrets_iam.redis_auth_secret_arn
  tags                     = local.tags
}

# ---------------------------
# Cost-budget alarms
# ---------------------------
module "cost_budgets" {
  source       = "../../modules/cost-budgets"
  name         = "${local.name}-monthly-budget"
  limit_amount = 2500
  time_unit    = "MONTHLY"

  alert_emails            = ["finops@example.com", "platform-alerts@example.com"]
  create_sns_topic        = true
  sns_topic_name          = "${local.name}-budgets-alerts"
  sns_subscription_emails = ["noc@example.com"]

  forecast_threshold_percent = 80
  actual_threshold_percent   = 100
}
