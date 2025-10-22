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

variable "account_number" {
  description = "The AWS Account number where the resources will be provisioned. This account will be used for billing and access control."
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
