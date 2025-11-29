# Security module variables - placeholder structure
variable "name" {
  description = "Logical name for security resources"
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

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "enable_tls_encryption" {
  description = "Enable TLS encryption"
  type        = bool
}

variable "tls_cert_manager_issuer" {
  description = "Cert-manager issuer"
  type        = string
}

variable "enable_pii_scrubbing" {
  description = "Enable PII scrubbing"
  type        = bool
}

variable "pii_scrubbing_rules" {
  description = "PII scrubbing rules"
  type = list(object({
    pattern     = string
    replacement = string
    description = string
  }))
}

variable "enable_audit_logging" {
  description = "Enable audit logging"
  type        = bool
}

variable "audit_log_retention_days" {
  description = "Audit log retention days"
  type        = number
}

variable "rbac_policies" {
  description = "RBAC policies"
  type = map(object({
    subjects = list(object({
      kind      = string
      name      = string
      namespace = string
    }))
    role_ref = object({
      kind      = string
      name      = string
      api_group = string
    })
  }))
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