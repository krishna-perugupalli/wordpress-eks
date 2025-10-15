variable "region" {
  description = "AWS region (e.g., eu-north-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project/environment short name; used as release/ingress prefix"
  type        = string
  default     = "wordpress"
}

variable "env" {
  description = "Environment name for the project"
  type        = string
  default     = "sandbox"
}

variable "owner_email" {
  description = "Owner/Contact email tag"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Extra tags merged into all resources (where supported)"
  type        = map(string)
  default     = {}
}

# ---------------------------
# DB
# ---------------------------
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "wordpress"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "wpapp"
}

# ---------------------------
# Edge/Ingress
# ---------------------------
variable "alb_domain_name" {
  description = "Hostname for WordPress (ALB Ingress)"
  type        = string
  default     = "wp-sbx.example.com"
}

variable "alb_hosted_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
  default     = "ZXXXXXXXXXXXX"
}

variable "create_regional_certificate" {
  description = "Create ACM certificate in region for ALB"
  type        = bool
  default     = true
}

variable "create_cf_certificate" {
  description = "Create ACM cert in us-east-1 for CloudFront (unused now)"
  type        = bool
  default     = false
}

variable "create_waf_regional" {
  description = "Create WAF v2 Web ACL (REGIONAL) and associate to ALB"
  type        = bool
  default     = true
}

variable "waf_ruleset_level" {
  description = "WAF ruleset level: baseline or strict"
  type        = string
  default     = "baseline"
}

# ---------------------------
# Karpenter
# ---------------------------
variable "karpenter_instance_types" {
  description = "Allowed instance types"
  type        = list(string)
  default     = ["c6i.large", "c6i.xlarge", "m6i.large", "m6i.xlarge"]
}

variable "karpenter_capacity_types" {
  description = "Capacity types mix"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "karpenter_ami_family" {
  description = "AMI family (AL2, Bottlerocket)"
  type        = string
  default     = "AL2"
}

variable "karpenter_consolidation_policy" {
  description = "Consolidation policy"
  type        = string
  default     = "WhenUnderutilized"
}

variable "karpenter_expire_after" {
  description = "Node expiration (e.g., 720h)"
  type        = string
  default     = "720h"
}

variable "karpenter_cpu_limit" {
  description = "NodePool CPU limit across nodes"
  type        = string
  default     = "64"
}

# ---------------------------
# Observability
# ---------------------------
variable "observability_namespace" {
  description = "Namespace to install CW Agent/Fluent Bit"
  type        = string
  default     = "observability"
}

variable "cw_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 30
}

variable "install_cloudwatch_agent" {
  description = "Install CW Agent via Helm"
  type        = bool
  default     = true
}

variable "install_fluent_bit" {
  description = "Install Fluent Bit via Helm"
  type        = bool
  default     = true
}

variable "create_alb_alarms" {
  description = "Create ALB/TG CloudWatch alarms"
  type        = bool
  default     = true
}

# ---------------------------
# WordPress App (Bitnami)
# ---------------------------
variable "wp_namespace" {
  description = "Kubernetes namespace for WordPress"
  type        = string
  default     = "wordpress"
}

variable "wp_storage_class" {
  description = "StorageClass to use (EFS Access Point)"
  type        = string
  default     = "efs-ap"
}

variable "wp_pvc_size" {
  description = "PVC size"
  type        = string
  default     = "10Gi"
}

variable "wp_domain_name" {
  description = "Public hostname (must match alb_domain_name)"
  type        = string
  default     = "wp-sbx.example.com"
}

variable "wp_replicas_min" {
  description = "Min replicas for HPA"
  type        = number
  default     = 2
}

variable "wp_replicas_max" {
  description = "Max replicas for HPA"
  type        = number
  default     = 6
}

variable "wp_image_tag" {
  description = "WordPress image tag"
  type        = string
  default     = "latest"
}

variable "wp_target_cpu_percent" {
  description = "HPA target CPU %"
  type        = number
  default     = 60
}

variable "wp_target_memory_value" {
  description = "HPA target memory value"
  type        = string
  default     = "600Mi"
}

variable "wp_admin_user" {
  description = "Initial admin username (non-sensitive)"
  type        = string
  default     = "wpadmin"
}

variable "wp_admin_email" {
  description = "Initial admin email (non-sensitive)"
  type        = string
  default     = "admin@example.com"
}

variable "wp_admin_bootstrap_enabled" {
  description = "Enable one-time admin bootstrap initContainer"
  type        = bool
  default     = true
}

# ---------------------------
# Infra integration overrides
# ---------------------------
variable "infra_cluster_name" {
  description = "Override EKS cluster name when remote state is unavailable."
  type        = string
  default     = null
}

variable "infra_cluster_oidc_issuer_url" {
  description = "Override cluster OIDC issuer URL when remote state is unavailable."
  type        = string
  default     = null
}

variable "infra_oidc_provider_arn" {
  description = "Override OIDC provider ARN when remote state is unavailable."
  type        = string
  default     = null
}

variable "infra_vpc_id" {
  description = "Override VPC ID when remote state is unavailable."
  type        = string
  default     = null
}

variable "infra_secrets_read_policy_arn" {
  description = "Override Secrets Manager read policy ARN when remote state is unavailable."
  type        = string
  default     = null
}

variable "infra_kms_logs_arn" {
  description = "Override KMS key ARN for logs when remote state is unavailable."
  type        = string
  default     = null
}

variable "db_writer_endpoint" {
  description = "Aurora writer endpoint to use when remote state is unavailable."
  type        = string
  default     = null
}

variable "wpapp_db_secret_arn" {
  description = "Secrets Manager ARN for the WordPress DB credentials when remote state is unavailable."
  type        = string
  default     = null
}

variable "wp_admin_secret_arn" {
  description = "Secrets Manager ARN for the WordPress admin bootstrap credentials when remote state is unavailable."
  type        = string
  default     = null
}
