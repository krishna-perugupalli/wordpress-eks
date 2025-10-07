variable "name" {
  description = "Cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for control plane and node groups"
  type        = list(string)
}

variable "cluster_role_arn" {
  description = "IAM role ARN for the EKS control plane (from iam-eks module)"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS managed node groups (from iam-eks module)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.30"
}

variable "endpoint_public_access" {
  description = "Expose public API endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "Allowed CIDRs for public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "enable_cluster_logs" {
  description = "Enable control plane logs"
  type        = bool
  default     = true
}

variable "control_plane_log_retention_days" {
  description = "CloudWatch retention for control plane logs"
  type        = number
  default     = 30
}

variable "secrets_kms_key_arn" {
  description = "KMS key ARN for EKS secrets encryption (null to disable)"
  type        = string
  default     = null
}

variable "addon_versions" {
  description = "Pin versions for EKS managed addons"
  type = object({
    vpc_cni    = string
    kube_proxy = string
    coredns    = string
    ebs_csi    = string
  })
  default = {
    vpc_cni    = "v1.16.3-eksbuild.1"
    kube_proxy = "v1.30.0-eksbuild.1"
    coredns    = "v1.11.1-eksbuild.4"
    ebs_csi    = "v1.30.0-eksbuild.1"
  }
}

variable "enable_cni_prefix_delegation" {
  description = "Enable prefix delegation to increase pod density"
  type        = bool
  default     = false
}

variable "cni_prefix_warm_target" {
  description = "WARM_PREFIX_TARGET for VPC CNI when prefix delegation is enabled"
  type        = number
  default     = 1
}

variable "system_node_type" {
  description = "Instance type for system node group"
  type        = string
  default     = "t3.medium"
}

variable "system_node_min" {
  description = "Min size for system node group"
  type        = number
  default     = 2
}

variable "system_node_max" {
  description = "Max size for system node group"
  type        = number
  default     = 4
}

variable "node_disk_size_gb" {
  description = "Root disk size for system node group"
  type        = number
  default     = 50
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT (keep ON_DEMAND for system NG)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_ami_type" {
  description = "EKS AMI type (e.g., AL2_x86_64, AL2_ARM_64, BOTTLEROCKET_x86_64)"
  type        = string
  default     = "AL2_x86_64"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
