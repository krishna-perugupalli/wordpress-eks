# Exporters module variables - placeholder structure
variable "name" {
  description = "Logical name for exporter resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "enable_wordpress_exporter" {
  description = "Enable WordPress exporter"
  type        = bool
}

variable "wordpress_namespace" {
  description = "WordPress namespace"
  type        = string
}

variable "wordpress_service_name" {
  description = "WordPress service name"
  type        = string
}

variable "enable_mysql_exporter" {
  description = "Enable MySQL exporter"
  type        = bool
}

variable "mysql_connection_config" {
  description = "MySQL connection config"
  type = object({
    host                = string
    port                = number
    username            = string
    password_secret_ref = string
    database            = string
  })
  default   = null
  sensitive = true
}

variable "enable_redis_exporter" {
  description = "Enable Redis exporter"
  type        = bool
}

variable "redis_connection_config" {
  description = "Redis connection config"
  type = object({
    host                = string
    port                = number
    password_secret_ref = string
    tls_enabled         = bool
  })
  default   = null
  sensitive = true
}

variable "enable_cloudwatch_exporter" {
  description = "Enable CloudWatch exporter"
  type        = bool
}

variable "cloudwatch_metrics_config" {
  description = "CloudWatch metrics config"
  type = object({
    discovery_jobs = list(object({
      type        = string
      regions     = list(string)
      search_tags = map(string)
      custom_tags = map(string)
      metrics     = list(string)
    }))
  })
  default = null
}

variable "enable_cloudfront_monitoring" {
  description = "Enable CloudFront CDN monitoring"
  type        = bool
  default     = false
}

variable "cloudfront_distribution_ids" {
  description = "List of CloudFront distribution IDs to monitor"
  type        = list(string)
  default     = []
}

variable "enable_cost_monitoring" {
  description = "Enable cost monitoring"
  type        = bool
}

variable "cost_allocation_tags" {
  description = "Cost allocation tags"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}