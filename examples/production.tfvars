############################################
# Production Environment Profile
# Expected Monthly Cost: $500-900
############################################
# This configuration provides:
# - High Availability NAT Gateway (3 NATs across AZs)
# - Aurora Serverless v2: 2-16 ACU with 7-day backups
# - CloudFront CDN enabled for global performance
# - Multi-AZ deployment for all services
# - Full production-grade resilience and performance

############################################
# Environment Profile (Cost Optimization)
############################################
environment_profile = "production"

############################################
# Environment / Metadata
############################################
region      = "us-east-1"
project     = "wp-prod"
env         = "production"
owner_email = "platform-team@example.com"

# Extra global tags (merged with Project/Env/Owner)
tags = {
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
  Environment = "Production"
  Criticality = "High"
}

############################################
# VPC / Networking
############################################
vpc_cidr      = "10.0.0.0/16"
private_cidrs = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
public_cidrs  = ["10.0.128.0/24", "10.0.129.0/24", "10.0.130.0/24"]
# NAT Gateway mode is controlled by environment_profile (production = ha)
# nat_gateway_mode will be automatically set to "ha" by the profile

############################################
# EKS Core
############################################
cluster_version        = "1.30"
endpoint_public_access = false
system_node_type       = "t3.medium"
system_node_min        = 3
system_node_max        = 6
admin_role_arns        = [] # add platform admin IAM role ARNs if needed

############################################
# Edge / Ingress (ALB + ACM + WAF)
############################################
wordpress_domain_name    = "www.example.com"
wordpress_hosted_zone_id = "Z1234567890ABC"                                                                      # Replace with your Route53 zone ID
alb_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012" # Replace with your ACM cert ARN

create_waf               = true
waf_rate_limit           = 100
waf_enable_managed_rules = true

############################################
# CloudFront (CDN) - Enabled for Production
############################################
enable_cloudfront             = true
cloudfront_certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012" # Replace with us-east-1 cert
cloudfront_aliases            = ["www.example.com"]
cloudfront_price_class        = "PriceClass_All" # Global distribution
cloudfront_enable_http3       = true
cloudfront_enable_logging     = true
cloudfront_log_prefix         = "cloudfront-logs/production/"
cloudfront_enable_compression = true

# CloudFront Origin Protection (recommended for production)
enable_alb_origin_protection = true
cloudfront_origin_secret     = "" # Set via TFC sensitive variable

############################################
# Karpenter (capacity)
############################################
karpenter_subnet_selector_tags = {
  "kubernetes.io/cluster/wp-prod" = "shared"
}
karpenter_sg_selector_tags = {
  "kubernetes.io/cluster/wp-prod" = "owned"
}

karpenter_enable_interruption_queue = true
karpenter_instance_types            = ["c6i.large", "c6i.xlarge", "m6i.large", "m6i.xlarge"]
karpenter_capacity_types            = ["spot", "on-demand"]
karpenter_ami_family                = "AL2"
karpenter_consolidation_policy      = "WhenUnderutilized"
karpenter_expire_after              = "720h"
karpenter_cpu_limit                 = "128"
karpenter_labels                    = { role = "web", environment = "production" }

############################################
# Aurora MySQL (Serverless v2)
# Production Profile: 2-16 ACU, 7-day backups
############################################
db_name           = "wordpress"
db_admin_username = "wpadmin"
# ACU limits are controlled by environment_profile
# db_serverless_min_acu will be set to 2
# db_serverless_max_acu will be set to 16
# db_backup_retention_days will be set to 7

db_backup_window       = "03:00-04:00"
db_maintenance_window  = "sun:04:00-sun:05:00"
db_deletion_protection = true

# AWS Backup for Aurora
db_enable_backup            = true
backup_vault_name           = "production-backup-vault"
db_backup_cron              = "cron(0 3 * * ? *)" # daily at 03:00 UTC
db_backup_delete_after_days = 30                  # Extended retention for production

############################################
# EFS (wp-content RWX)
############################################
efs_performance_mode    = "generalPurpose"
efs_throughput_mode     = "bursting"
efs_enable_lifecycle_ia = true
efs_ap_path             = "/wp-content"
efs_ap_owner_uid        = 33
efs_ap_owner_gid        = 33

# AWS Backup for EFS
efs_enable_backup            = true
efs_backup_cron              = "cron(0 2 * * ? *)" # daily at 02:00 UTC
efs_backup_delete_after_days = 90                  # Extended retention for production

############################################
# Security Baseline
############################################
create_cloudtrail = true
create_config     = true
create_guardduty  = true

############################################
# Observability
############################################
control_plane_log_retention_days = 90 # Extended retention for production
install_cloudwatch_agent         = true
install_fluent_bit               = true

############################################
# WordPress App (Bitnami chart)
############################################
wp_domain_name   = "www.example.com" # must match wordpress_domain_name
wp_storage_class = "efs-ap"
wp_pvc_size      = "50Gi"

wp_db_app_user     = "wpapp"
wp_admin_user      = "admin"
wp_admin_email     = "admin@example.com"
wp_admin_bootstrap = true # set false after initial setup

wp_replicas_min        = 3 # Higher minimum for production
wp_replicas_max        = 12
wp_image_tag           = "6.4.2" # Pin to specific version in production
wp_target_cpu_percent  = 70
wp_target_memory_value = "800Mi"

############################################
# Budgets (Cost guardrails)
############################################
budget_limit_amount            = 1000 # Higher budget for production
budget_alert_emails            = ["finops@example.com", "platform-alerts@example.com"]
budget_create_sns_topic        = true
budget_sns_subscription_emails = ["oncall@example.com"]

budget_forecast_threshold_percent = 80
budget_actual_threshold_percent   = 100

############################################
# Cost Breakdown (Estimated Monthly)
############################################
# NAT Gateway (HA):        $96  (3 NATs × $32)
# Aurora (2-16 ACU avg):   $350 (avg 4 ACU × $87.60)
# CloudFront:              $50  (baseline + data transfer)
# EKS Control Plane:       $73
# EFS:                     $30
# ElastiCache:             $40
# EC2 (Karpenter):         $150 (varies with load)
# Data Transfer:           $50
# Other Services:          $61
# ----------------------------------------
# Total:                   $500-900/month
#
# This is the baseline production configuration.
# Actual costs vary based on traffic and usage patterns.
