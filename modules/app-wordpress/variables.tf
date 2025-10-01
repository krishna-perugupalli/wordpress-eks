variable "name" {
  description = "Name prefix for release and related objects."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy WordPress into."
  type        = string
  default     = "wordpress"
}

variable "region" {
  description = "AWS region (not directly used; kept for consistency)."
  type        = string
}

variable "domain_name" {
  description = "Ingress FQDN for WordPress (ALB)."
  type        = string
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS."
  type        = string
}

variable "waf_acl_arn" {
  description = "Optional WAFv2 WebACL ARN to associate with ALB."
  type        = string
  default     = ""
}

variable "alb_tags" {
  description = "Map of tags to apply to the ALB via ingress annotation (k=v,k=v)."
  type        = map(string)
  default     = {}
}

variable "storage_class_name" {
  description = "StorageClass for PVC (e.g., EFS). If null, use cluster default."
  type        = string
  default     = null
}

variable "pvc_size" {
  description = "PVC size for wp-content."
  type        = string
  default     = "10Gi"
}

variable "db_host" {
  description = "Aurora writer endpoint hostname."
  type        = string
}

variable "db_name" {
  description = "Database name."
  type        = string
  default     = "wordpress"
}

variable "db_user" {
  description = "Database username."
  type        = string
  default     = "wpapp"
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN with JSON key 'password' for the DB user."
  type        = string
}

variable "admin_bootstrap_enabled" {
  description = "If true, create admin password secret and let the chart bootstrap admin on first run."
  type        = bool
  default     = false
}

variable "admin_secret_arn" {
  description = "Secrets Manager ARN with JSON key 'password' for the admin user (used only if admin_bootstrap_enabled=true)."
  type        = string
  default     = null
}

variable "admin_user" {
  description = "Admin username (chart value)."
  type        = string
  default     = "wpadmin"
}

variable "admin_email" {
  description = "Admin email (chart value)."
  type        = string
  default     = "admin@example.com"
}

variable "replicas_min" {
  description = "HPA min replicas."
  type        = number
  default     = 2
}

variable "replicas_max" {
  description = "HPA max replicas."
  type        = number
  default     = 6
}

variable "image_tag" {
  description = "WordPress container image tag (Bitnami)."
  type        = string
  default     = "latest"
}

variable "target_cpu_percent" {
  description = "Autoscaling target CPU percentage."
  type        = number
  default     = 60
}

variable "target_memory_value" {
  description = "Autoscaling target memory average value (e.g., 600Mi)."
  type        = string
  default     = "600Mi"
}
