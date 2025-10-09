variable "name" {
  description = "Logical name/prefix for DB resources (e.g., project-env)"
  type        = string
}

variable "engine_version" {
  description = "Aurora MySQL engine version (v3.x uses MySQL 8.0 compatibility)"
  type        = string
  default     = "8.0.mysql_aurora.3.05.2"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the cluster will live"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for DB subnet group (min 2 AZs)"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "wordpress"
}

variable "admin_username" {
  description = "Master/admin username"
  type        = string
  default     = "wpadmin"
}

variable "create_random_password" {
  description = "Generate a strong random password for the admin user if true"
  type        = bool
  default     = true
}

variable "admin_password" {
  description = "If not generating, provide the admin password (min 8 chars)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "secrets_manager_kms_key_arn" {
  description = "KMS key ARN for Secrets Manager secret encryption (optional)"
  type        = string
  default     = null
}

variable "storage_kms_key_arn" {
  description = "KMS key ARN for Aurora storage encryption (required)"
  type        = string
}

variable "backup_retention_days" {
  description = "Automated backup retention days"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Daily backup window in UTC (hh24:mi-hh24:mi)"
  type        = string
  default     = "02:00-03:00"
}

variable "preferred_maintenance_window" {
  description = "Weekly maintenance window in UTC (ddd:hh24:mi-ddd:hh24:mi)"
  type        = string
  default     = "sun:03:00-sun:04:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection for cluster"
  type        = bool
  default     = true
}

variable "copy_tags_to_snapshot" {
  description = "Copy tags to DB snapshots"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip creating a final snapshot when destroying the cluster."
  default     = false
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights on instances"
  type        = bool
  default     = true
}

variable "performance_insights_kms_key_arn" {
  description = "KMS key ARN for Performance Insights (optional)"
  type        = string
  default     = null
}

variable "port" {
  description = "DB port"
  type        = number
  default     = 3306
}

variable "serverless_v2" {
  description = "Use Aurora Serverless v2 if true; else provisioned instances"
  type        = bool
  default     = true
}

variable "serverless_min_acu" {
  description = "Serverless v2 minimum ACU"
  type        = number
  default     = 2
}

variable "serverless_max_acu" {
  description = "Serverless v2 maximum ACU"
  type        = number
  default     = 16
}

variable "instance_class" {
  description = "Instance class for provisioned replicas (ignored if serverless_v2 = true)"
  type        = string
  default     = "db.r6g.large"
}

variable "provisioned_replica_count" {
  description = "Number of reader instances when not using Serverless v2"
  type        = number
  default     = 1
}

variable "apply_immediately" {
  description = "Apply changes immediately (vs during maintenance window)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "allowed_security_group_ids" {
  description = "Security Group IDs allowed to connect to the DB port (e.g., EKS node SG)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect (for temporary admin/migration access)"
  type        = list(string)
  default     = []
}

## ---------------------------------------------
## Aurora Backup
## ---------------------------------------------
variable "enable_backup" {
  description = "Enable AWS Backup for this Aurora cluster."
  type        = bool
  default     = false
}

variable "backup_vault_name" {
  description = "Backup vault to store recovery points. Leave empty to auto-create."
  type        = string
}

variable "backup_schedule_cron" {
  description = "AWS cron expression (UTC)."
  type        = string
  default     = "cron(0 2 * * ? *)" # 02:00 UTC daily
}

variable "backup_delete_after_days" {
  description = "Retention in days."
  type        = number
  default     = 7
}

# NOTE: Cross-region copy is intentionally disabled by default.
# Reason:
# - Keep initial cost/complexity low (no extra vault/traffic/KMS).
# - Most teams first validate RTO/RPO with same-region restores + PITR.
# - Easier to operate while building out DR runbooks.
# When ready for regional DR, set enabled=true and pass an aliased provider in the stack.
variable "backup_cross_region_copy" {
  description = <<EOT
Optional cross-region copy configuration for Aurora backups.
Disabled by default to avoid cost/complexity until DR is formally adopted.
To enable later:
  1) Create or choose a backup vault in the target region.
  2) In the STACK, declare provider 'aws' alias for the destination region.
  3) Set enabled=true and provide destination_vault_name and destination_region.
EOT
  type = object({
    enabled                = bool
    destination_vault_name = string
    destination_region     = string
    delete_after_days      = number
  })
  default = {
    enabled                = false
    destination_vault_name = ""
    destination_region     = ""
    delete_after_days      = 30
  }
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

variable "enable_source_node_sg_rule" {
  description = "Create the ingress rule that allows traffic from source_node_sg_id. Set to false if you are not supplying a source security group."
  type        = bool
  default     = true
}

variable "source_node_sg_id" {
  description = "Primary SG allowed to reach Aurora (e.g., EKS node SG)."
  type        = string
  default     = null
}
