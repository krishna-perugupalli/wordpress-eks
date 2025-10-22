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

variable "service_account_role_arn_vpc_cni" {
  description = "IAM Role ARN for the VPC CNI Service Account (IRSA)"
  type        = string
}

variable "service_account_role_arn_efs_csi" {
  description = "IAM Role ARN for the EFS CSI Service Account (IRSA)"
  type        = string
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
  description = "EKS AMI type (e.g., AL2023_x86_64_STANDARD, BOTTLEROCKET_x86_64)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# --------------------
# EKS Admin Access Config
# --------------------
variable "access_entries" {
  description = "Map of EKS access entries to create (forwarded to terraform-aws-modules/eks/aws)."
  type        = map(any)
  default     = {}
}
