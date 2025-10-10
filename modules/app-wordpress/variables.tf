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
  default     = "latest"
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

variable "db_secret_arn" {
  description = "Secrets Manager ARN that contains {password} for the DB user"
  type        = string
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
  description = "HPA target CPU utilization percentage"
  type        = number
  default     = 60
}

variable "target_memory_value" {
  description = "HPA target average memory value (e.g., 600Mi); empty disables memory target"
  type        = string
  default     = ""
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
