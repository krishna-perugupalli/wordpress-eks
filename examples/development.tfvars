############################################
# Development Environment Profile
# Expected Monthly Cost: $200-350 (60% savings vs Production)
############################################
# This configuration provides:
# - Single NAT Gateway (cost optimization)
# - Aurora Serverless v2: 0.5-2 ACU with 1-day backups
# - CloudFront disabled (direct ALB access)
# - Single-AZ deployment where possible
# - Optimized for development and testing workloads

############################################
# Environment Profile (Cost Optimization)
############################################
environment_profile = "development"

############################################
# Environment / Metadata
############################################
region      = "us-east-1"
project     = "wp-dev"
env         = "development"
owner_email = "dev-team@example.com"

# Extra global tags (merged with Project/Env/Owner)
tags = {
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
  Environment = "Development"
  Criticality = "Low"
}

############################################
# VPC / Networking
############################################
vpc_cidr      = "10.20.0.0/16"
private_cidrs = ["10.20.0.0/20", "10.20.16.0/20", "10.20.32.0/20"]
public_cidrs  = ["10.20.128.0/24", "10.20.129.0/24", "10.20.130.0/24"]
# NAT Gateway mode is controlled by environment_profile (development = single)
# nat_gateway_mode will be automatically set to "single" by the profile

############################################
# EKS Core
############################################
cluster_version        = "1.30"
endpoint_public_access = false
system_node_type       = "t3.medium"
system_node_min        = 2
system_node_max        = 3
admin_role_arns        = [] # add developer IAM role ARNs if needed

############################################
# Edge / Ingress (ALB + ACM + WAF)
############################################
wordpress_domain_name    = "dev.example.com"
wordpress_hosted_zone_id = "Z1234567890ABC"                                                                      # Replace with your Route53 zone ID
alb_certificate_arn      = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012" # Replace with your ACM cert ARN

create_waf               = false # Optional for development
waf_rate_limit           = 100
waf_enable_managed_rules = false

############################################
# CloudFront (CDN) - Disabled for Development
############################################
# CloudFront is automatically disabled by the development profile
# Traffic goes directly to ALB for cost savings
enable_cloudfront = false

############################################
# Karpenter (capacity)
############################################
karpenter_subnet_selector_tags = {
  "kubernetes.io/cluster/wp-dev" = "shared"
}
karpenter_sg_selector_tags = {
  "kubernetes.io/cluster/wp-dev" = "owned"
}

karpenter_enable_interruption_queue = true
karpenter_instance_types            = ["t3.medium", "t3.large", "c6i.large"]
karpenter_capacity_types            = ["spot"] # Spot-only for development
karpenter_ami_family                = "AL2"
karpenter_consolidation_policy      = "WhenUnderutilized"
karpenter_expire_after              = "168h" # 7 days
karpenter_cpu_limit                 = "32"
karpenter_labels                    = { role = "web", environment = "development" }

############################################
# Aurora MySQL (Serverless v2)
# Development Profile: 0.5-2 ACU, 1-day backups
############################################
db_name           = "wordpress"
db_admin_username = "wpadmin"
# ACU limits are controlled by environment_profile
# db_serverless_min_acu will be set to 0.5
# db_serverless_max_acu will be set to 2
# db_backup_retention_days will be set to 1

db_backup_window       = "03:00-04:00"
db_maintenance_window  = "sun:04:00-sun:05:00"
db_deletion_protection = false # Disabled for development
db_skip_final_snapshot = true  # Skip final snapshot for development

# AWS Backup for Aurora
db_enable_backup            = false # Optional for development
backup_vault_name           = "dev-backup-vault"
db_backup_cron              = "cron(0 3 * * ? *)"
db_backup_delete_after_days = 3 # Minimal retention for development

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
efs_enable_backup            = false # Optional for development
efs_backup_cron              = "cron(0 2 * * ? *)"
efs_backup_delete_after_days = 7 # Minimal retention for development

############################################
# Security Baseline
############################################
create_cloudtrail = false # Not needed for development
create_config     = false # Not needed for development
create_guardduty  = false # Not needed for development

############################################
# Observability
############################################
control_plane_log_retention_days = 7 # Minimal retention for development
install_cloudwatch_agent         = true
install_fluent_bit               = true

############################################
# WordPress App (Bitnami chart)
############################################
wp_domain_name   = "dev.example.com" # must match wordpress_domain_name
wp_storage_class = "efs-ap"
wp_pvc_size      = "10Gi"

wp_db_app_user     = "wpapp"
wp_admin_user      = "admin"
wp_admin_email     = "dev@example.com"
wp_admin_bootstrap = true # set false after initial setup

wp_replicas_min        = 1 # Minimal replicas for development
wp_replicas_max        = 3
wp_image_tag           = "latest" # Use latest for development
wp_target_cpu_percent  = 70
wp_target_memory_value = "512Mi"

############################################
# Budgets (Cost guardrails)
############################################
budget_limit_amount            = 400 # Lower budget for development
budget_alert_emails            = ["dev-team@example.com"]
budget_create_sns_topic        = false # Optional for development
budget_sns_subscription_emails = []

budget_forecast_threshold_percent = 80
budget_actual_threshold_percent   = 100

############################################
# Cost Breakdown (Estimated Monthly)
############################################
# NAT Gateway (Single):    $32  (1 NAT × $32)
# Aurora (0.5-2 ACU avg):  $87  (avg 1 ACU × $87.60)
# CloudFront:              $0   (disabled)
# EKS Control Plane:       $73
# EFS:                     $15
# ElastiCache:             $40
# EC2 (Karpenter):         $50  (spot instances, varies with load)
# Data Transfer:           $10
# Other Services:          $15
# ----------------------------------------
# Total:                   $200-350/month
#
# Savings vs Production:   ~60% ($300-550 saved)
#
# Cost optimizations:
# - Single NAT Gateway saves $64/month
# - Minimal Aurora ACU (0.5-2) saves ~$263/month
# - No CloudFront saves ~$50/month
# - Spot-only compute saves ~$100/month
# - Reduced storage and backups
# - Minimal logging retention
#
# Trade-offs:
# - Single NAT = no HA for internet connectivity
# - Lower Aurora capacity = slower for heavy queries
# - No CloudFront = no global CDN
# - Spot instances = potential interruptions
# - Suitable for development and testing only
