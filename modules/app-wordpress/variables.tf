variable "name" {
  description = "Logical app name (used for release name and defaults)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for WordPress"
  type        = string
  default     = "wordpress"
}

variable "domain_name" {
  description = "Public hostname for the site (Ingress host)"
  type        = string
}

# ----- Ingress / ALB / WAF -----
variable "alb_certificate_arn" {
  description = "ACM cert ARN for ALB listener; empty = no TLS annotation"
  type        = string
  default     = ""
}

variable "waf_acl_arn" {
  description = "WAFv2 WebACL ARN to attach to ALB; empty = none"
  type        = string
  default     = ""
}

variable "alb_tags" {
  description = "Tags to attach to the ALB via ingress annotation"
  type        = map(string)
  default     = {}
}

# Optional Helm name overrides (used by locals in main.tf)
variable "fullname_override" {
  description = "Helm fullnameOverride"
  type        = string
  default     = ""
}

variable "name_override" {
  description = "Helm nameOverride (used only when fullname_override is empty)"
  type        = string
  default     = ""
}

# ----- Storage (EFS PVC) -----
variable "storage_class_name" {
  description = "StorageClass name (e.g., efs-ap)"
  type        = string
  default     = "efs-ap"
}

variable "pvc_size" {
  description = "PVC size for wp-content"
  type        = string
  default     = "10Gi"
}

# ----- Image / runtime tuning -----
variable "image_tag" {
  description = "WordPress image tag (Bitnami)"
  type        = string
  default     = "sha256-08a8a1c86a0ea118986d629c1c41d15d5a3a45cffa48aea010033e7dad404201"
}

variable "wordpress_chart_version" {
  description = "Bitnami WordPress Helm chart version"
  type        = string
  default     = "27.0.10"
}

variable "php_max_input_vars" {
  description = "php.ini max_input_vars appended via phpConfiguration"
  type        = number
  default     = 2000
}

# ----- External DB (Aurora) -----
variable "db_host" {
  description = "Aurora writer endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "wordpress"
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "wpapp"
}

variable "db_port" {
  description = "DB port"
  type        = number
  default     = 3306
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN that contains {password} for the DB user"
  type        = string
}

variable "db_secret_property" {
  description = "Property key within the app DB secret JSON that stores the password"
  type        = string
  default     = "password"
}

variable "db_admin_secret_arn" {
  description = "Optional Secrets Manager ARN that contains the Aurora admin credentials"
  type        = string
  default     = ""
}

variable "db_admin_secret_property" {
  description = "Property key within the admin secret JSON that stores the password"
  type        = string
  default     = "password"
}

variable "db_admin_secret_key" {
  description = "Key name to store the admin password under in the generated Kubernetes Secret"
  type        = string
  default     = "password"
}

variable "db_admin_username_property" {
  description = "Property key within the admin secret JSON that stores the username (empty to skip)"
  type        = string
  default     = "username"
}

variable "db_admin_username_key" {
  description = "Key name to store the admin username under in the generated Kubernetes Secret"
  type        = string
  default     = "username"
}

variable "db_grant_job_enabled" {
  description = "When true, run a Kubernetes Job to ensure the DB user has required privileges."
  type        = bool
  default     = true
}

variable "db_grant_job_image" {
  description = "Container image (with mysql client) used by the DB grant Job."
  type        = string
  default     = "docker.io/library/mysql:8.0"
}

variable "db_grant_job_backoff_limit" {
  description = "Backoff limit for the DB grant Job retries."
  type        = number
  default     = 5
}

variable "db_grant_login_user" {
  description = "Database user the Job should authenticate as when issuing GRANT statements. Defaults to db_user."
  type        = string
  default     = null
  nullable    = true
}

variable "db_grant_login_password_key" {
  description = "Key inside the wp-db Secret that stores the password for db_grant_login_user."
  type        = string
  default     = "password"
}

# ----- Optional admin bootstrap (one-time) -----
variable "admin_bootstrap_enabled" {
  description = "When true, create wp-admin ExternalSecret and wire chart to use it for initial admin password"
  type        = bool
  default     = false
}

variable "admin_secret_arn" {
  description = "Secrets Manager ARN with admin {password} (and optionally username/email) used when admin_bootstrap_enabled=true"
  type        = string
  default     = ""
}

variable "admin_user" {
  description = "Admin username (non-secret, chart value)"
  type        = string
  default     = "wpadmin"
}

variable "admin_email" {
  description = "Admin email (non-secret, chart value)"
  type        = string
  default     = "admin@example.com"
}

# ----- HPA / resources -----
variable "replicas_min" {
  description = "HPA min replicas"
  type        = number
  default     = 2
}

variable "replicas_max" {
  description = "HPA max replicas"
  type        = number
  default     = 6
}

variable "target_cpu_percent" {
  description = "Target CPU utilization percentage for HPA"
  type        = number
  default     = 80
}

variable "target_memory_percent" {
  description = "Target memory utilization percentage for HPA (integer, e.g., 80)"
  type        = number
  default     = 80
}

variable "resources_requests_cpu" {
  description = "Container requests.cpu"
  type        = string
  default     = "250m"
}

variable "resources_requests_memory" {
  description = "Container requests.memory"
  type        = string
  default     = "512Mi"
}

variable "resources_limits_cpu" {
  description = "Container limits.cpu"
  type        = string
  default     = "1000m"
}

variable "resources_limits_memory" {
  description = "Container limits.memory"
  type        = string
  default     = "1Gi"
}

# ----- Extra environment (plain, non-secret) -----
variable "env_extra" {
  description = "Map of extra non-secret env vars injected into the chart"
  type        = map(string)
  default     = {}
}
