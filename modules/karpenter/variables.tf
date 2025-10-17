variable "name" {
  description = "Logical name/prefix, usually the cluster name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "Cluster OIDC provider ARN (for IRSA)"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "Cluster OIDC issuer URL (https://...)"
  type        = string
}

variable "subnet_selector_tags" {
  description = "Tag selector map for subnets Karpenter may use (e.g., { \"kubernetes.io/cluster/<name>\" = \"shared\" })"
  type        = map(string)
}

variable "security_group_selector_tags" {
  description = "Tag selector map for SGs to attach to instances (often the cluster/node SG)"
  type        = map(string)
}

variable "karpenter_namespace" {
  description = "Namespace to install Karpenter"
  type        = string
  default     = "karpenter"
}

variable "controller_chart_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.5.0"
}

variable "enable_interruption_queue" {
  description = "Create SQS + EventBridge rule for interruption handling and wire to controller"
  type        = bool
  default     = false
}

variable "interruption_queue_name" {
  description = "Name for the SQS interruption queue (if enabled)"
  type        = string
  default     = ""
}

variable "instance_types" {
  description = "Allowed EC2 instance types for workloads"
  type        = list(string)
  default     = ["c6i.large", "c6i.xlarge", "m6i.large", "m6i.xlarge"]
}

variable "capacity_types" {
  description = "Allowed capacity types"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "ami_family" {
  description = "AMI family for nodes: AL2023 or Bottlerocket"
  type        = string
  default     = "AL2023"
  validation {
    condition     = contains(["AL2023", "Bottlerocket"], var.ami_family)
    error_message = "ami_family must be AL2023 or Bottlerocket."
  }
}

variable "node_role_additional_policy_arns" {
  description = "Additional IAM policies to attach to the node role"
  type        = list(string)
  default     = []
}

variable "expire_after" {
  description = "Max node lifetime (e.g., 720h)"
  type        = string
  default     = "720h"
}

variable "cpu_limit" {
  description = "Overall CPU limit for the NodePool (e.g., 64)"
  type        = string
  default     = "64"
}

variable "labels" {
  description = "Default labels for provisioned nodes"
  type        = map(string)
  default     = { role = "web" }
}

variable "taints" {
  description = "Optional taints for provisioned nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

variable "tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default     = {}
}

variable "consolidation_policy" {
  description = "Karpenter NodePool consolidation policy"
  type        = string
  default     = "WhenEmptyOrUnderutilized" # valid: WhenEmpty, WhenEmptyOrUnderutilized
}

variable "consolidate_after" {
  description = "Time to wait before consolidating underutilized nodes (e.g., 30s, 2m)"
  type        = string
  default     = "30s"
}

variable "cluster_version" {
  description = "EKS cluster minor (e.g., 1.33)"
  type        = string
  default     = "1.33"
}

variable "arch" {
  description = "EC2 architecture for workers"
  type        = string
  default     = "x86_64" # or "arm64"
}
