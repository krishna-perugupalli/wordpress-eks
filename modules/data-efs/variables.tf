variable "name" {
  description = "Prefix/cluster name for resource naming"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for EFS SG"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (min 2) for EFS mount targets"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "SGs allowed to mount EFS (e.g., EKS node SG or SG-for-Pods)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "Optional CIDRs allowed to mount (temporary admin/migration)"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for EFS encryption (null to use AWS-managed)"
  type        = string
  default     = null
}

variable "performance_mode" {
  description = "EFS performance mode: generalPurpose or maxIO"
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode must be generalPurpose or maxIO."
  }
}

variable "throughput_mode" {
  description = "EFS throughput mode: bursting or provisioned"
  type        = string
  default     = "bursting"
  validation {
    condition     = contains(["bursting", "provisioned"], var.throughput_mode)
    error_message = "throughput_mode must be bursting or provisioned."
  }
}

variable "provisioned_throughput_mibps" {
  description = "MiB/s if throughput_mode = provisioned"
  type        = number
  default     = 0
}

variable "enable_lifecycle_ia" {
  description = "Enable lifecycle policy to move to IA after 30 days"
  type        = bool
  default     = true
}

# Fixed Access Point (optional) for /wp-content
variable "create_fixed_access_point" {
  description = "Create a fixed AP for /wp-content"
  type        = bool
  default     = true
}

variable "ap_path" {
  description = "Directory for the fixed Access Point"
  type        = string
  default     = "/wp-content"
}

variable "ap_owner_uid" {
  description = "POSIX UID for AP owner (www-data=33)"
  type        = number
  default     = 33
}

variable "ap_owner_gid" {
  description = "POSIX GID for AP owner (www-data=33)"
  type        = number
  default     = 33
}

variable "controller_namespace" {
  description = "Namespace to install EFS CSI controller"
  type        = string
  default     = "kube-system"
}

variable "cluster_name" {
  description = "EKS cluster name (for Helm chart wiring)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (IRSA)"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "Cluster OIDC issuer URL (https://...)"
  type        = string
}

variable "enable_backup" {
  description = "Enable AWS Backup for this EFS file system."
  type        = bool
  default     = false
}

variable "backup_vault_name" {
  description = "Backup vault to store recovery points. Leave empty to auto-create `${var.name}-efs-backup`."
  type        = string
  default     = ""
}

variable "backup_schedule_cron" {
  description = "AWS cron expression (UTC)."
  type        = string
  default     = "cron(0 1 * * ? *)" # 01:00 UTC daily
}

variable "backup_delete_after_days" {
  description = "Retention in days."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "backup_service_role_arn" {
  description = <<-EOT
    Optional existing IAM role ARN for AWS Backup service to assume.
    If null, the module creates a new role with policy:
      arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup
  EOT
  type        = string
  default     = null
}
