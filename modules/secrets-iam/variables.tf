variable "name" {
  description = "Logical prefix (e.g., project-env)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "create_ssm_kms_key" {
  description = "Also create a CMK for SSM Parameter Store"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# -------------------------------
# Optional: create common secrets
# -------------------------------
variable "create_wpapp_db_secret" {
  description = "Create Secrets Manager secret for the app DB user"
  type        = bool
  default     = false
}

variable "wpapp_db_secret_name" {
  description = "Name for the app DB secret (without arn); must be unique per account"
  type        = string
  default     = "wpapp-db"
}

variable "wpapp_db_username" {
  description = "DB username for the app (ignored if create_wpapp_db_secret=false)"
  type        = string
  default     = "wpapp"
}

variable "wpapp_db_password" {
  description = "If empty, a strong random password is generated"
  type        = string
  default     = ""
  sensitive   = true
}

variable "wpapp_db_database" {
  description = "Database name"
  type        = string
  default     = "wordpress"
}

variable "wpapp_db_host" {
  description = "DB hostname (e.g., module.data_aurora.writer_endpoint). Can be blank initially; update later."
  type        = string
  default     = ""
}

variable "wpapp_db_port" {
  description = "DB port"
  type        = number
  default     = 3306
}

variable "create_wp_admin_secret" {
  description = "Create Secrets Manager secret for WP admin creds"
  type        = bool
  default     = false
}

variable "wp_admin_secret_name" {
  description = "Name for the admin secret"
  type        = string
  default     = "wp-admin"
}

variable "wp_admin_username" {
  description = "WP admin username"
  type        = string
  default     = "wpadmin"
}

variable "wp_admin_password" {
  description = "If empty, a strong random password is generated"
  type        = string
  default     = ""
  sensitive   = true
}

variable "wp_admin_email" {
  description = "Admin email"
  type        = string
  default     = "admin@example.com"
}

# -----------------------------------------
# IAM policies for readers (ESO, etc.)
# List the ARNs that readers should access.
# -----------------------------------------
variable "readable_secret_arns" {
  description = "Secrets Manager ARNs that a 'secrets-read' policy should allow"
  type        = list(string)
  default     = []
}

variable "readable_ssm_parameter_arns" {
  description = "SSM Parameter ARNs that a 'ssm-read' policy should allow (if using SSM)"
  type        = list(string)
  default     = []
}

variable "restrict_to_version_stage" {
  description = "Limit ESO reads to a specific Secrets Manager version stage (e.g., AWSCURRENT). Empty = no restriction."
  type        = string
  default     = "AWSCURRENT"
}

variable "required_secret_tag_key" {
  description = "Optional: require this tag key on secrets ESO may read (for SCP/ABAC-like control). Empty = disabled."
  type        = string
  default     = ""
}

variable "required_secret_tag_value" {
  description = "Optional: required tag value when required_secret_tag_key is set."
  type        = string
  default     = ""
}

## -----------------------------------------
## IAM Policis for Redis auth secret and token
## Redis auth secret and auth token
## -----------------------------------------

variable "kms_key_arn" {
  description = "KMS key ARN to encrypt Secrets Manager secrets (null = AWS managed)."
  type        = string
  default     = null
}

variable "create_redis_auth_secret" {
  description = "If true, create a Secrets Manager secret with a random Redis AUTH token."
  type        = bool
  default     = false
}

variable "redis_auth_secret_name" {
  description = "Name/path for the Redis auth secret (e.g., app/redis/auth). Required if create_redis_auth_secret=true."
  type        = string
  default     = null
}

variable "redis_auth_token_length" {
  description = "Length of the generated Redis token."
  type        = number
  default     = 64
}

variable "existing_redis_auth_secret_arn" {
  description = "If provided, use this existing secret instead of creating one."
  type        = string
  default     = ""
}

# EKS OIDC provider ARN (from your eks-core outputs)
variable "cluster_oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (for IRSA)."
  type        = string
}

# ESO service account identity (Kubernetes)
variable "eso_namespace" {
  description = "Namespace where External Secrets Operator runs."
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "ServiceAccount name used by the ESO controller."
  type        = string
  default     = "external-secrets"
}

# Optional: also validate audience claim (recommended)
variable "eso_validate_audience" {
  description = "If true, require OIDC token audience to be sts.amazonaws.com."
  type        = bool
  default     = true
}
