variable "name" {
  description = "Logical name/prefix (usually your cluster name)"
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
  description = "Namespace for ESO"
  type        = string
  default     = "external-secrets"
}

# ---- Choose ONE of the following two inputs ----

variable "secrets_read_policy_arn" {
  description = "(Option A) Existing IAM policy ARN granting secretsmanager:GetSecretValue on specific ARNs"
  type        = string
  default     = ""
}

variable "allowed_secret_arns" {
  description = "(Option B) Exact Secrets Manager ARNs ESO may read; module will create a policy for these"
  type        = list(string)
  default     = []
}

# -----------------------------------------------

variable "chart_version" {
  description = "External Secrets Helm chart version"
  type        = string
  default     = "0.9.13"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
