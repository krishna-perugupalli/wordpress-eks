variable "region" {
  description = "AWS region (e.g., eu-north-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project/environment short name; used as cluster name and tag prefix (e.g., wp-sbx)"
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

variable "account_number" {
  description = "The AWS Account number where the resources will be provisioned. This account will be used for billing and access control."
}

variable "tags" {
  description = "Extra tags merged into all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------
# Foundation (VPC / networking)
# ---------------------------
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.80.0.0/16"
}

variable "private_cidrs" {
  description = "Private subnet CIDRs (3 AZs)"
  type        = list(string)
  default     = ["10.80.0.0/20", "10.80.16.0/20", "10.80.32.0/20"]
}

variable "public_cidrs" {
  description = "Public subnet CIDRs (3 AZs)"
  type        = list(string)
  default     = ["10.80.128.0/24", "10.80.129.0/24", "10.80.130.0/24"]
}

variable "nat_gateway_mode" {
  description = "NAT gateway strategy: single or ha"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "ha"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of: single, ha."
  }
}

# ---------------------------
# EKS Core
# ---------------------------
variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "endpoint_public_access" {
  description = "Expose EKS public endpoint"
  type        = bool
  default     = false
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (OIDC)"
  type        = bool
  default     = true
}

variable "enable_cni_prefix_delegation" {
  description = "Enable CNI prefix delegation for higher pod density"
  type        = bool
  default     = true
}

variable "system_node_type" {
  description = "Instance type for system/nodegroup"
  type        = string
  default     = "t3.medium"
}

variable "system_node_min" {
  description = "Min nodes for system node group"
  type        = number
  default     = 2
}

variable "system_node_max" {
  description = "Max nodes for system node group"
  type        = number
  default     = 3
}

variable "admin_role_arns" {
  type    = list(string)
  default = []
}

# ---------------------------
# Aurora MySQL (Serverless v2)
# ---------------------------
variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "wordpress"
}

variable "db_admin_username" {
  description = "Aurora admin username"
  type        = string
  default     = "wpadmin"
}

variable "db_create_random_password" {
  description = "Create random admin password"
  type        = bool
  default     = true
}

variable "db_serverless_min_acu" {
  description = "Aurora Serverless v2 min ACUs"
  type        = number
  default     = 2
}

variable "db_serverless_max_acu" {
  description = "Aurora Serverless v2 max ACUs"
  type        = number
  default     = 16
}

variable "db_backup_retention_days" {
  description = "Aurora backup retention in days"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Aurora preferred backup window (UTC)"
  type        = string
  default     = "02:00-03:00"
}

variable "db_maintenance_window" {
  description = "Aurora preferred maintenance window (UTC)"
  type        = string
  default     = "sun:03:00-sun:04:00"
}

variable "db_deletion_protection" {
  description = "Enable Aurora deletion protection"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip creating a final snapshot when destroying the Aurora cluster"
  type        = bool
  default     = true
}

# AWS Backup for Aurora
variable "db_enable_backup" {
  description = "Enable AWS Backup for Aurora"
  type        = bool
  default     = true
}

variable "backup_vault_name" {
  description = "AWS Backup vault name to use"
  type        = string
  default     = ""
}

variable "db_backup_cron" {
  description = "AWS Backup cron for Aurora"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "db_backup_delete_after_days" {
  description = "Days to retain Aurora backups in Backup vault"
  type        = number
  default     = 7
}

# ---------------------------
# EFS
# ---------------------------
variable "efs_kms_key_arn" {
  description = "KMS key ARN for EFS; null for AWS-managed key"
  type        = string
  default     = null
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

variable "efs_enable_lifecycle_ia" {
  description = "Enable lifecycle to IA (transition after 30 days)"
  type        = bool
  default     = true
}

variable "efs_ap_path" {
  description = "EFS access point path"
  type        = string
  default     = "/wp-content"
}

variable "efs_ap_owner_uid" {
  description = "UID owner for EFS AP"
  type        = number
  default     = 33
}

variable "efs_ap_owner_gid" {
  description = "GID owner for EFS AP"
  type        = number
  default     = 33
}

# AWS Backup for EFS
variable "efs_enable_backup" {
  description = "Enable AWS Backup for EFS"
  type        = bool
  default     = true
}

variable "efs_backup_cron" {
  description = "AWS Backup cron for EFS"
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "efs_backup_delete_after_days" {
  description = "Days to retain EFS backups in Backup vault"
  type        = number
  default     = 30
}

# ---------------------------
# Security baseline
# ---------------------------
variable "create_cloudtrail" {
  description = "Create a multi-region account-level CloudTrail."
  type        = bool
  default     = false
}

variable "create_config" {
  description = "Enable AWS Config recorder + delivery channel."
  type        = bool
  default     = false
}

variable "create_guardduty" {
  description = "Enable GuardDuty detector in this account/region."
  type        = bool
  default     = false
}

# --------------------
# EKS Admin Users/Roles
# --------------------

variable "eks_admin_role_arns" {
  description = "IAM Role ARNs (incl. SSO permission-set roles) to grant EKS cluster-admin."
  type        = list(string)
  default     = []
}

variable "eks_admin_user_arns" {
  description = "IAM User ARNs to grant EKS cluster-admin."
  type        = list(string)
  default     = []
}

# --------------------
# EFS Access Point
# --------------------

variable "efs_id" {
  description = "EFS File System ID"
  type        = string
  default     = "efs-ap"
}
