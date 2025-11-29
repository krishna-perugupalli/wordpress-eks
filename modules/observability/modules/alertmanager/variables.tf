# AlertManager module variables - placeholder structure
variable "name" {
  description = "Logical name for AlertManager resources"
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

variable "alertmanager_storage_size" {
  description = "Storage size"
  type        = string
}

variable "alertmanager_storage_class" {
  description = "Storage class"
  type        = string
}

variable "alertmanager_replica_count" {
  description = "Replica count"
  type        = number
}

variable "alertmanager_resource_requests" {
  description = "Resource requests"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "alertmanager_resource_limits" {
  description = "Resource limits"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "smtp_config" {
  description = "SMTP config"
  type = object({
    smarthost     = string
    from          = string
    auth_username = string
    auth_password = string
    require_tls   = bool
  })
  default   = null
  sensitive = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL"
  type        = string
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key"
  type        = string
  sensitive   = true
}

variable "alert_routing_config" {
  description = "Alert routing config"
  type = object({
    group_by        = list(string)
    group_wait      = string
    group_interval  = string
    repeat_interval = string
    routes = list(object({
      match    = map(string)
      match_re = map(string)
      receiver = string
      group_by = list(string)
      continue = bool
    }))
  })
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