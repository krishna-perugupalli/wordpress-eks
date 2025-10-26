variable "name" { type = string } # cluster name
variable "tags" {
  type    = map(string)
  default = {}
}

# Optional extra policies you might want to attach to the node role
variable "extra_node_policy_arns" {
  type    = list(string)
  default = []
}

# Optional extra policies for cluster role (rarely needed)
variable "extra_cluster_policy_arns" {
  type    = list(string)
  default = []
}

variable "eks_cluster_management_role_trust_principals" {
  default = []
}

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS cluster OIDC provider ARN (for IRSA)."
}

variable "oidc_issuer_url" {
  type        = string
  description = "EKS cluster OIDC issuer URL (for IRSA)."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN for encrypting"
}
