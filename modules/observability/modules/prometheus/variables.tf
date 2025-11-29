# Prometheus module variables - placeholder structure
variable "name" {
  description = "Logical name for Prometheus resources"
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

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
}

variable "prometheus_retention_days" {
  description = "Retention period in days"
  type        = number
}

variable "prometheus_storage_class" {
  description = "Storage class"
  type        = string
}

variable "prometheus_replica_count" {
  description = "Number of replicas"
  type        = number
}

variable "prometheus_resource_requests" {
  description = "Resource requests"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "prometheus_resource_limits" {
  description = "Resource limits"
  type = object({
    cpu    = string
    memory = string
  })
}

variable "enable_service_discovery" {
  description = "Enable service discovery"
  type        = bool
}

variable "service_discovery_namespaces" {
  description = "Namespaces for service discovery"
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

variable "enable_network_resilience" {
  description = "Enable network resilience features"
  type        = bool
  default     = true
}

variable "remote_write_queue_capacity" {
  description = "Remote write queue capacity"
  type        = number
  default     = 10000
}

variable "remote_write_max_backoff" {
  description = "Maximum backoff for remote write retries"
  type        = string
  default     = "30s"
}