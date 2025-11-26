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

  # DNS coordination validation
  dns_coordination_valid = (
    # If CloudFront is enabled, domain name and hosted zone must be provided
    var.enable_cloudfront ?
    var.wordpress_domain_name != "" && var.wordpress_hosted_zone_id != "" : true
    ) && (
    # If CloudFront is enabled, ALB should not create Route53 records
    var.enable_cloudfront ? !var.create_alb_route53_record : true
  )
}

## Get current AWS account ID
data "aws_caller_identity" "current" {}

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

  source_node_sg_id   = module.eks.node_security_group_id
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

  allowed_security_group_ids = [module.eks.node_security_group_id]

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
  create_trail_bucket           = false
  trail_bucket_name             = module.foundation.logs_bucket
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
  readable_secret_arn_map = {
    aurora_master_user = coalesce(module.data_aurora.master_user_secret_arn, "")
  }

  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
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
  source             = "../../modules/elasticache"
  name               = local.name
  vpc_id             = module.foundation.vpc_id
  subnet_ids         = module.foundation.private_subnet_ids
  node_sg_source_ids = [module.eks.node_security_group_id]
  # Prefer passing the token directly from secrets-iam to avoid plan-time data reads
  enable_auth_token_secret = false
  auth_token               = module.secrets_iam.redis_auth_token
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
# WAF WebACL for ALB (Regional) - conditional creation
#############################################
module "waf_regional" {
  count  = var.create_waf ? 1 : 0
  source = "../../modules/waf-regional"

  name                 = local.name
  rate_limit           = var.waf_rate_limit
  enable_managed_rules = var.waf_enable_managed_rules
  tags                 = local.tags
}

#############################################
# Standalone ALB for WordPress
# Prerequisites:
# - ACM certificate must be created and validated manually
# - Certificate ARN must be provided via alb_certificate_arn variable
#############################################
module "standalone_alb" {
  source = "../../modules/standalone-alb"

  name                          = local.name
  vpc_id                        = module.foundation.vpc_id
  public_subnet_ids             = module.foundation.public_subnet_ids
  certificate_arn               = var.alb_certificate_arn
  waf_acl_arn                   = var.create_waf ? module.waf_regional[0].waf_arn : var.waf_acl_arn
  enable_waf                    = var.create_waf || var.waf_acl_arn != ""
  domain_name                   = var.wordpress_domain_name
  hosted_zone_id                = var.wordpress_hosted_zone_id
  create_route53_record         = var.create_alb_route53_record && !var.enable_cloudfront
  wordpress_pod_port            = var.wordpress_pod_port
  worker_node_security_group_id = module.eks.node_security_group_id
  enable_cloudfront_restriction = var.enable_cloudfront_restriction
  enable_deletion_protection    = var.alb_enable_deletion_protection

  # Origin Protection Configuration
  enable_origin_protection        = var.enable_alb_origin_protection
  origin_secret_value             = var.cloudfront_origin_secret
  origin_protection_response_code = var.alb_origin_protection_response_code
  origin_protection_response_body = var.alb_origin_protection_response_body

  tags = local.tags

  depends_on = [module.foundation, module.eks]
}

#############################################
# CloudFront Distribution (Optional)
# Prerequisites:
# - ACM certificate must be created and validated manually in us-east-1
# - Certificate ARN must be provided via cloudfront_certificate_arn variable
# - ALB must be deployed and healthy with valid DNS name
# - Route53 hosted zone must exist for DNS record creation
#############################################
module "cloudfront" {
  count  = var.enable_cloudfront ? 1 : 0
  source = "../../modules/cloudfront"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name                = local.name
  domain_name         = var.wordpress_domain_name
  aliases             = var.cloudfront_aliases
  alb_dns_name        = module.standalone_alb.alb_dns_name
  acm_certificate_arn = var.cloudfront_certificate_arn
  log_bucket_name     = module.foundation.logs_bucket
  price_class         = var.cloudfront_price_class
  enable_http3        = var.cloudfront_enable_http3
  origin_secret_value = var.cloudfront_origin_secret

  # Geo-restrictions configuration
  geo_restriction_type      = var.cloudfront_geo_restriction_type
  geo_restriction_locations = var.cloudfront_geo_restriction_locations

  # Compression and performance features
  compress             = var.cloudfront_enable_compression
  enable_origin_shield = var.cloudfront_enable_origin_shield
  origin_shield_region = var.cloudfront_origin_shield_region

  # Logging configuration
  enable_logging           = var.cloudfront_enable_logging
  log_prefix               = var.cloudfront_log_prefix
  log_include_cookies      = var.cloudfront_log_include_cookies
  enable_real_time_logs    = var.cloudfront_enable_real_time_logs
  real_time_log_config_arn = var.cloudfront_real_time_log_config_arn

  # Custom error responses
  custom_error_responses = var.cloudfront_custom_error_responses

  # Security and protocol configuration
  waf_web_acl_arn          = var.cloudfront_waf_web_acl_arn
  minimum_protocol_version = var.cloudfront_minimum_protocol_version
  is_ipv6_enabled          = var.cloudfront_enable_ipv6
  default_root_object      = var.cloudfront_default_root_object
  enable_smooth_streaming  = var.cloudfront_enable_smooth_streaming

  # Route53 Integration
  hosted_zone_id        = var.wordpress_hosted_zone_id
  create_route53_record = var.create_cloudfront_route53_record

  tags = local.tags

  # Explicit dependencies to ensure proper deployment order and validation
  depends_on = [
    terraform_data.infrastructure_readiness_validation,
    terraform_data.cloudfront_dependencies_validation,
    terraform_data.dns_coordination_validation,
    terraform_data.cloudfront_certificate_validation
  ]
}
