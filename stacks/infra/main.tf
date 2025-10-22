#############################################
# Locals
#############################################
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

## Get current AWS account ID
data "aws_caller_identity" "current" {}

##############################################
# EKS Admin Access Entries
##############################################
locals {
  eks_access_entries_roles = {
    for idx, arn in var.eks_admin_role_arns :
    "admin_role_${idx}" => {
      principal_arn = arn
      type          = "STANDARD"
      policy_associations = [{
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }]
    }
  }

  eks_access_entries_users = {
    for idx, arn in var.eks_admin_user_arns :
    "admin_user_${idx}" => {
      principal_arn = arn
      type          = "STANDARD"
      policy_associations = [{
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }]
    }
  }

  eks_access_entries = merge(local.eks_access_entries_roles, local.eks_access_entries_users)
}

#############################################
# Foundation (VPC, subnets, NAT, KMS base)
#############################################
module "foundation" {
  source           = "../../modules/foundation"
  name             = local.name
  vpc_cidr         = var.vpc_cidr
  private_cidrs    = var.private_cidrs
  public_cidrs     = var.public_cidrs
  nat_gateway_mode = var.nat_gateway_mode
  tags             = local.tags
}

#############################################
# IAM roles for EKS control plane and nodes
#############################################
module "iam_eks" {
  source            = "../../modules/iam-eks"
  name              = local.name
  tags              = local.tags
  account_number    = data.aws_caller_identity.current.account_id
  region            = var.region
  oidc_provider_arn = module.eks_core.oidc_provider_arn
  oidc_issuer_url   = module.eks_core.oidc_provider_url
  cluster_name      = module.eks_core.cluster_name
  depends_on        = [module.eks_core]
}

#############################################
# EKS cluster (terraform-aws-modules/eks via our wrapper)
#############################################
module "eks_core" {
  source                           = "../../modules/eks-core"
  name                             = local.name
  region                           = var.region
  vpc_id                           = module.foundation.vpc_id
  private_subnet_ids               = module.foundation.private_subnet_ids
  service_account_role_arn_vpc_cni = module.vpc_cni_irsa[0].iam_role_arn
  service_account_role_arn_efs_csi = module.efs_csi_irsa[0].iam_role_arn
  cluster_role_arn                 = module.iam_eks.cluster_role_arn
  node_role_arn                    = module.iam_eks.node_role_arn
  secrets_kms_key_arn              = module.secrets_iam.kms_secrets_arn
  cluster_version                  = var.cluster_version
  endpoint_public_access           = var.endpoint_public_access
  enable_irsa                      = var.enable_irsa
  enable_cni_prefix_delegation     = var.enable_cni_prefix_delegation
  system_node_type                 = var.system_node_type
  system_node_min                  = var.system_node_min
  system_node_max                  = var.system_node_max
  access_entries                   = local.eks_access_entries
  tags                             = local.tags
}

#############################################
# Minimal k8s provider for aws-auth only
# Note: Replaced with aws eks module auth mechanism (autentication_mode = "API_AND_CONFIG_MAP")
#############################################
/* provider "kubernetes" {
  host                   = module.eks_core.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_core.cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_core.cluster_name, "--region", var.region]
  }
} 

resource "time_sleep" "wait_for_eks" {
  depends_on      = [module.eks_core]
  create_duration = "30s"
}

#############################################
# aws-auth ConfigMap (map node role + optional admins)
#############################################
module "aws_auth" {
  source = "../../modules/aws-auth"

  node_role_arn   = module.iam_eks.node_role_arn
  admin_role_arns = var.admin_role_arns

  depends_on = [module.eks_core]
} */

#############################################
# Aurora MySQL (Serverless v2)
#############################################
module "data_aurora" {
  source             = "../../modules/data-aurora"
  name               = local.name
  vpc_id             = module.foundation.vpc_id
  private_subnet_ids = module.foundation.private_subnet_ids

  db_name                = var.db_name
  admin_username         = var.db_admin_username
  create_random_password = var.db_create_random_password

  storage_kms_key_arn = module.foundation.kms_rds_arn
  # secrets_manager_kms_key_arn = module.secrets_iam.kms_secrets_arn

  source_node_sg_id   = module.eks_core.node_security_group_id
  allowed_cidr_blocks = [] # or ["x.x.x.x/32"] temporarily for migrations

  serverless_v2      = true
  serverless_min_acu = var.db_serverless_min_acu
  serverless_max_acu = var.db_serverless_max_acu

  backup_retention_days        = var.db_backup_retention_days
  preferred_backup_window      = var.db_backup_window
  preferred_maintenance_window = var.db_maintenance_window
  deletion_protection          = var.db_deletion_protection
  skip_final_snapshot          = var.db_skip_final_snapshot

  enable_backup            = var.db_enable_backup
  backup_vault_name        = var.backup_vault_name
  backup_schedule_cron     = var.db_backup_cron
  backup_delete_after_days = var.db_backup_delete_after_days

  tags = local.tags
}

#############################################
# EFS (wp-content)
#############################################
module "data_efs" {
  source             = "../../modules/data-efs"
  name               = local.name
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

  enable_backup            = var.efs_enable_backup
  backup_vault_name        = var.backup_vault_name
  backup_schedule_cron     = var.efs_backup_cron
  backup_delete_after_days = var.efs_backup_delete_after_days

  tags = local.tags
}

#############################################
# Security baseline (CloudTrail, Config, GuardDuty, Budgets)
#############################################
module "security_baseline" {
  source = "../../modules/security-baseline"

  name                          = local.name
  trail_bucket_name             = ""
  logs_expire_after_days        = 365
  cloudtrail_cwl_retention_days = 90

  create_cloudtrail = var.create_cloudtrail
  create_config     = var.create_config
  create_guardduty  = var.create_guardduty

  tags = local.tags
}

#############################################
# Secrets + IAM for ESO and app secrets
#############################################
module "secrets_iam" {
  source = "../../modules/secrets-iam"
  name   = local.name
  region = var.region
  tags   = local.tags

  wpapp_db_host = module.data_aurora.writer_endpoint

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

  depends_on = [module.data_aurora]
}

#############################################
# ElastiCache (Redis) for object cache
#############################################
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

#############################################
# Cost-budget alarms
#############################################
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
    fileSystemId     = module.data_efs.file_system_id # <-- from your EFS module output
    directoryPerms   = "0770"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    basePath         = "/k8s" # optional
  }

  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  # Make sure the cluster and EFS exist before creating the SC
  depends_on = [
    module.eks_core,
    module.data_efs
  ]
}
