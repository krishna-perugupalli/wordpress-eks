############################################
# Environment / Metadata
############################################
region      = "eu-north-1"
project     = "wp-sbx"
env         = "sandbox"
owner_email = "admin@example.com"

# Extra global tags (merged with Project/Env/Owner)
tags = {
  CostCenter = "ENG"
  ManagedBy  = "Terraform"
}

############################################
# VPC / Networking
############################################
vpc_cidr             = "10.80.0.0/16"
private_subnet_cidrs = ["10.80.0.0/20", "10.80.16.0/20", "10.80.32.0/20"]
public_subnet_cidrs  = ["10.80.128.0/24", "10.80.129.0/24", "10.80.130.0/24"]
nat_gateway_mode     = "single" # single | ha

############################################
# EKS Core
############################################
cluster_version        = "1.30"
endpoint_public_access = false
system_node_type       = "t3.medium"
system_node_min        = 2
system_node_max        = 3
admin_role_arns        = [] # add platform admin IAM role ARNs if needed

# Optional: only for very first bootstrap if you want providers to init
# against an existing cluster name. Otherwise leave null and use Makefile deploy.
eks_cluster_name_override = null

############################################
# Edge / Ingress (ALB + ACM + WAF)
############################################
create_regional_certificate = true
alb_domain_name             = "wp-sbx.example.com" # <-- set your domain
alb_hosted_zone_id          = "ZXXXXXXXXXXXX"      # <-- set your Route53 zone ID
create_cf_certificate       = false                # CloudFront cert (not used now)

create_waf_regional = true
waf_ruleset_level   = "baseline" # baseline | strict (module-specific)

############################################
# Karpenter (capacity)
############################################
karpenter_subnet_selector_tags = {
  # must match tags applied by foundation module to private subnets
  "kubernetes.io/cluster/wp-sbx" = "shared"
}
karpenter_sg_selector_tags = {
  # must match tags applied by eks-core to node SG
  "kubernetes.io/cluster/wp-sbx" = "owned"
}

karpenter_enable_interruption_queue = true
karpenter_instance_types            = ["c6i.large", "c6i.xlarge", "m6i.large", "m6i.xlarge"]
karpenter_capacity_types            = ["spot", "on-demand"]
karpenter_ami_family                = "AL2"
karpenter_consolidation_policy      = "WhenUnderutilized"
karpenter_expire_after              = "720h"
karpenter_cpu_limit                 = "64"
karpenter_labels                    = { role = "web" }
karpenter_taints                    = [] # e.g., [{ key = "workload", value = "jobs", effect = "NoSchedule" }]

############################################
# Aurora MySQL (Serverless v2)
############################################
db_name                  = "wordpress"
db_admin_username        = "wpadmin"
db_serverless_min_acu    = 2
db_serverless_max_acu    = 16
db_backup_retention_days = 7
db_backup_window         = "02:00-03:00"
db_maintenance_window    = "sun:03:00-sun:04:00"
db_enable_backup         = true

# AWS Backup for Aurora
backup_vault_name           = "default"           # use default vault or pre-create another
db_backup_cron              = "cron(0 2 * * ? *)" # daily at 02:00 UTC
db_backup_delete_after_days = 7

############################################
# EFS (wp-content RWX)
############################################
efs_kms_key_arn         = null             # null => AWS-managed key; or set to a CMK ARN
efs_performance_mode    = "generalPurpose" # or "maxIO"
efs_throughput_mode     = "bursting"       # or "provisioned"
efs_enable_lifecycle_ia = true
efs_ap_path             = "/wp-content"
efs_ap_owner_uid        = 33
efs_ap_owner_gid        = 33

# AWS Backup for EFS
efs_enable_backup            = true
efs_backup_cron              = "cron(0 1 * * ? *)" # daily at 01:00 UTC
efs_backup_delete_after_days = 30

############################################
# Security Baseline
############################################
security_trail_bucket_name = "" # leave "" to let module generate a unique S3 name
create_budget              = true
budget_amount              = 500
budget_emails              = ["alerts@example.com"]

############################################
# Observability
############################################
cw_retention_days        = 30
install_cloudwatch_agent = true
install_fluent_bit       = true
create_alb_alarms        = true # if first-ever deploy fails due to discovery, set false once

############################################
# WordPress App (Bitnami chart)
############################################
wp_namespace     = "wordpress"
wp_domain_name   = "wp-sbx.example.com" # must match alb_domain_name
wp_storage_class = "efs-ap"
wp_pvc_size      = "10Gi"

wp_db_app_user     = "wpapp"
wp_admin_user      = "wpadmin"
wp_admin_email     = "admin@example.com"
wp_admin_bootstrap = true # set true for first deploy, then false after admin set

wp_replicas_min        = 2
wp_replicas_max        = 6
wp_image_tag           = "latest"
wp_target_cpu_percent  = 60
wp_target_memory_value = "600Mi"

############################################
# Budgets (Cost guardrails)
############################################
budget_limit_amount            = 2500
budget_alert_emails            = ["finops@example.com", "platform-alerts@example.com"]
budget_create_sns_topic        = true
budget_sns_subscription_emails = ["noc@example.com"]

budget_forecast_threshold_percent = 80
budget_actual_threshold_percent   = 100
