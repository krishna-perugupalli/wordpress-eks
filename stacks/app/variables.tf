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

variable "acm_certificate_arn" {
  description = "Pre-created ACM certificate ARN for the ALB (regional). If set, ACM creation/validation is skipped."
  type        = string
  default     = ""
}

variable "cf_acm_certificate_arn" {
  description = "Pre-created ACM certificate ARN for the CloudFront (regional). If set, ACM creation/validation is skipped."
  type        = string
  default     = ""
}

variable "cf_aliases" {
  description = "Additional CNAMEs."
  type        = list(string)
  default     = []
}

# ---------------------------
# Karpenter
# ---------------------------
variable "karpenter_instance_types" {
  description = "Allowed instance types"
  type        = list(string)
  default     = ["t3a.medium", "t3a.large", "t3a.xlarge", "m6a.large", "m6a.xlarge", "c6a.large", "c6a.xlarge"]
}

variable "karpenter_instance_families" {
  description = "Allowed Family types"
  type        = list(string)
  default     = ["t3a", "m6a", "c6a"]
}

variable "karpenter_cpu_allowed" {
  description = "Allowed CPU types"
  type        = list(string)
  default     = ["2", "4", "8", "16"]
}

variable "karpenter_arch_types" {
  description = "Allowed arch types"
  type        = list(string)
  default     = ["amd64", "arm64"]
}

variable "karpenter_os_types" {
  description = "Allowed OS types"
  type        = list(string)
  default     = ["linux"]
}

variable "karpenter_capacity_types" {
  description = "Capacity types mix"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "karpenter_ami_family" {
  description = "AMI family (AL2023, Bottlerocket)"
  type        = string
  default     = "AL2023"
}

variable "karpenter_consolidation_policy" {
  description = "Consolidation policy"
  type        = string
  default     = "WhenEmptyOrUnderutilized"
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

variable "karpenter_volume_size" {
  description = "Node volume size in GB"
  type        = string
  default     = "50Gi"
}

variable "karpenter_volume_type" {
  description = "Node volume type"
  type        = string
  default     = "gp2"
}

variable "karpenter_taints" {
  description = "Optional taints for provisioned nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
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
  description = "HPA target memory %"
  type        = string
  default     = "80"
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
# Remote state (Terraform Cloud)
# ---------------------------
variable "remote_state_organization" {
  description = "Terraform Cloud organization for remote state"
  type        = string
  default     = "WpOrbit"
}

variable "remote_state_infra_workspace" {
  description = "Terraform Cloud workspace name for infra remote state"
  type        = string
  default     = "wp-infra"
}

variable "cluster_version" {
  description = "EKS cluster minor (e.g., 1.33)"
  type        = string
  default     = "1.33"
}

variable "arch" {
  description = "EC2 architecture for workers"
  type        = string
  default     = "x86_64" # or "arm64"
}
