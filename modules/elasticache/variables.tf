variable "name" {
  description = "Logical prefix (project-env)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for ElastiCache subnet group (typically private)"
  type        = list(string)
}

variable "node_sg_source_ids" {
  description = "Security groups allowed to reach Redis (e.g., EKS node SG or pod SG-for-Pods)"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "Optional CIDR blocks allowed to reach Redis (use sparingly)"
  type        = list(string)
  default     = []
}

variable "engine_family" {
  description = "ElastiCache parameter group family, e.g., redis7"
  type        = string
  default     = "redis7"
}

variable "engine_version" {
  description = "Redis engine version, e.g., 7.1"
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "Node instance class"
  type        = string
  default     = "cache.t4g.small"
}

variable "replicas_per_node_group" {
  description = "Number of replicas per shard (exclude primary). Example: 1 => total 2 nodes."
  type        = number
  default     = 1
}

variable "automatic_failover" {
  description = "Enable automatic failover (required for Multi-AZ with replicas)"
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Enable Multi-AZ placement"
  type        = bool
  default     = true
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "UTC window for snapshots, e.g., 03:00-04:00"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window, e.g., sun:04:00-sun:05:00"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "auth_token_secret_arn" {
  description = "Secrets Manager ARN containing JSON {\"token\":\"...\"} for Redis AUTH. Optional; if empty, AUTH is disabled."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
