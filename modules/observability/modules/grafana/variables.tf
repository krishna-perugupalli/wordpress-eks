# Grafana module variables - placeholder structure
variable "name" {
  description = "Logical name for Grafana resources"
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

variable "grafana_storage_size" {
  description = "Storage size for Grafana"
  type        = string
}

variable "grafana_storage_class" {
  description = "Storage class"
  type        = string
}

variable "grafana_admin_password" {
  description = "Admin password"
  type        = string
  default     = null
  sensitive   = true
}

variable "grafana_resource_requests" {
  description = "Resource requests"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "grafana_resource_limits" {
  description = "Resource limits"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "enable_aws_iam_auth" {
  description = "Enable AWS IAM auth"
  type        = bool
}

variable "grafana_iam_role_arns" {
  description = "IAM role ARNs"
  type        = list(string)
}

variable "enable_default_dashboards" {
  description = "Enable default dashboards"
  type        = bool
}

variable "custom_dashboard_configs" {
  description = "Custom dashboard configs"
  type        = map(string)
}

variable "prometheus_url" {
  description = "Prometheus URL"
  type        = string
  default     = null
}

variable "enable_cloudwatch_datasource" {
  description = "Enable CloudWatch datasource"
  type        = bool
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

variable "grafana_replica_count" {
  description = "Number of Grafana replicas for high availability"
  type        = number
  default     = 2
}