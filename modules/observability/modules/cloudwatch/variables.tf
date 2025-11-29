variable "name" {
  description = "Logical name / cluster name (used in resource names)"
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
  description = "EKS OIDC issuer URL (https://...)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "namespace" {
  description = "Namespace for CloudWatch agents"
  type        = string
}

variable "kms_logs_key_arn" {
  description = "KMS key ARN to encrypt CloudWatch log groups"
  type        = string
  default     = null
}

variable "cw_retention_days" {
  description = "CloudWatch Logs retention (days)"
  type        = number
  default     = 30
}

variable "install_cloudwatch_agent" {
  description = "Install CloudWatch Agent for Container Insights"
  type        = bool
  default     = true
}

variable "install_fluent_bit" {
  description = "Install aws-for-fluent-bit for logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}