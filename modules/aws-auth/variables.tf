variable "node_role_arn" {
  description = "IAM role ARN for the EKS managed node group(s)"
  type        = string
}

variable "admin_role_arns" {
  description = "IAM role ARNs to grant cluster-admin (system:masters)"
  type        = list(string)
  default     = []
}

variable "additional_role_mappings" {
  description = "Additional aws-auth role mappings (advanced)"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable "additional_user_mappings" {
  description = "Additional aws-auth user mappings (optional)"
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}
