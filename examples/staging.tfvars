############################################
# Staging Environment Profile
# Expected Monthly Cost: $250-450 (50% savings vs Production)
############################################
# This configuration provides:
# - Single NAT Gateway (cost optimization)
# - Aurora Serverless v2: 1-8 ACU with 1-day backups
# - CloudFront disabled (direct ALB access)
# - Multi-AZ deployment for data services
# - Suitable for pre-production testing and QA

############################################
# Environment Profile (Cost Optimization)
############################################
environment_profile = "staging"

############################################
# Environment / Metadata
############################################
region      = "us-east-1"
project     = "wp-staging"
env         = "staging"
owner_email = "platform-team@example.com"

# Extra global tags (merged with Project/Env/Owner)
tags = {
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
  Environment = "Staging"
  Criticality = "Medium"
}

############################################
# VPC / Networking
############################################
vpc_cidr      = "10.10.0.0/16"
private_cidrs = ["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"]
public_cidrs  = ["10.10.128.0/24", "10.10.129.0/24", "10.10.130.0/24"]
# NAT Gateway mode is controlled by environment_profile (staging = single)
# nat_gateway_mode will be automatically set to "single" by the profile

############################################
# EKS Core
############################################
cluster_version        = "1.30"
endpoint_public_access = false
system_node_type       = "t3.medium"
system_node_min        = 2
system_node_max        = 4
admin_role_arns        = [] # add platform admin IAM role ARNs if needed

############################################
# Edge / Ingress (ALB + ACM + WAF)
############################################
wordpress_domain_name    = "staging.example.com"
wordpress_hosted_zone_id = "Z1234567890ABC"                                                                      # Replace with your Route53 zone ID
alb_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012" # Replace with your ACM cert ARN

create_waf               = true
waf_rate_limit           = 100
waf_enable_managed_rules = true

############################################
# CloudFront (CDN) - Disabled for Staging
############################################
# CloudFront is automatically disabled by the staging profile
# Traffic goes directly to ALB for cost savings
enable_cloudfront = false

############################################
# Karpenter (capacity)
############################################
karpenter_subnet_selector_tags = {
  "kubernetes.io/cluster/wp-staging" = "shared"
}
karpenter_sg_selector_tags = {
  "kubernetes.io/cluster/wp-staging" = "owned"
}

karpenter_enable_interruption_queue = true
karpenter_instance_types            = ["c6i.large", "m6i.large", "t3.large"]
karpenter_capacity_types            = ["spot", "on-demand"]
karpenter_ami_family                = "AL2"
karpenter_consolidation_policy      = "WhenUnderutilized"
karpenter_expire_after              = "720h"
karpenter_cpu_limit                 = "64"
karpenter_labels                    = { role = "web", environment = "staging" }

############################################
# Aurora MySQL (Serverless v2)
# Staging Profile: 1-8 ACU, 1-day backups
############################################
db_name           = "wordpress"
db_admin_username = "wpadmin"
# ACU limits are controlled by environment_profile
# db_serverless_min_acu will be set to 1
# db_serverless_max_acu will be set to 8
# db_backup_retention_days will be set to 1

db_backup_window       = "03:00-04:00"
db_maintenance_window  = "sun:04:00-sun:05:00"
db_deletion_protection = false # Can be disabled for staging

# AWS Backup for Aurora
db_enable_backup            = true
backup_vault_name           = "staging-backup-vault"
db_backup_cron              = "cron(0 3 * * ? *)" # daily at 03:00 UTC
db_backup_delete_after_days = 7                   # Shorter retention for staging

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
efs_backup_delete_after_days = 14                  # Shorter retention for staging

############################################
# Security Baseline
############################################
create_cloudtrail = false # Optional for staging
create_config     = false # Optional for staging
create_guardduty  = false # Optional for staging

############################################
# Observability
############################################
control_plane_log_retention_days = 30 # Standard retention
install_cloudwatch_agent         = true
install_fluent_bit               = true

############################################
# WordPress App (Bitnami chart)
############################################
wp_domain_name   = "staging.example.com" # must match wordpress_domain_name
wp_storage_class = "efs-ap"
wp_pvc_size      = "20Gi"

wp_db_app_user     = "wpapp"
wp_admin_user      = "admin"
wp_admin_email     = "admin@example.com"
wp_admin_bootstrap = true # set false after initial setup

wp_replicas_min        = 2 # Lower minimum for staging
wp_replicas_max        = 6
wp_image_tag           = "latest" # Can use latest for staging
wp_target_cpu_percent  = 70
wp_target_memory_value = "600Mi"

############################################
# Budgets (Cost guardrails)
############################################
budget_limit_amount            = 500 # Lower budget for staging
budget_alert_emails            = ["finops@example.com", "platform-alerts@example.com"]
budget_create_sns_topic        = true
budget_sns_subscription_emails = ["platform-team@example.com"]

budget_forecast_threshold_percent = 80
budget_actual_threshold_percent   = 100

############################################
# Cost Breakdown (Estimated Monthly)
############################################
# NAT Gateway (Single):    $32  (1 NAT × $32)
# Aurora (1-8 ACU avg):    $175 (avg 2 ACU × $87.60)
# CloudFront:              $0   (disabled)
# EKS Control Plane:       $73
# EFS:                     $20
# ElastiCache:             $40
# EC2 (Karpenter):         $80  (varies with load)
# Data Transfer:           $20
# Other Services:          $30
# ----------------------------------------
# Total:                   $250-450/month
#
# Savings vs Production:   ~50% ($250-450 saved)
#
# Cost optimizations:
# - Single NAT Gateway saves $64/month
# - Lower Aurora ACU saves ~$175/month
# - No CloudFront saves ~$50/month
# - Reduced compute and storage
