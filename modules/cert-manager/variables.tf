variable "name" {
  description = "Logical name for cert-manager resources"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.16.2"
}

variable "enable_prometheus_metrics" {
  description = "Enable Prometheus metrics for cert-manager"
  type        = bool
  default     = true
}

variable "resource_requests" {
  description = "Resource requests for cert-manager controller"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "10m"
    memory = "32Mi"
  }
}

variable "resource_limits" {
  description = "Resource limits for cert-manager controller"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "128Mi"
  }
}

variable "create_letsencrypt_issuer" {
  description = "Create Let's Encrypt ClusterIssuers (prod and staging)"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt account registration"
  type        = string
  default     = ""
}

variable "create_selfsigned_issuer" {
  description = "Create self-signed ClusterIssuer for internal certificates"
  type        = bool
  default     = true
}

variable "additional_helm_values" {
  description = "Additional Helm values as YAML string"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
