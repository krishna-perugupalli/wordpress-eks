variable "name" {
  description = "Base name for Redis."
  type        = string
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "node_type" {
  description = "Instance class, e.g., cache.t4g.small."
  type        = string
  default     = "cache.t4g.small"
}

variable "num_replicas_per_shard" {
  description = "Replicas per shard (node group)."
  type        = number
  default     = 1
}

variable "subnet_ids" {
  description = "Private subnet IDs for Redis."
  type        = list(string)
}

variable "node_sg_source_ids" {
  description = "Security group IDs allowed to connect (EKS nodes SG)."
  type        = list(string)
  validation {
    condition     = length(var.node_sg_source_ids) > 0
    error_message = "You must specify at least one source SG in node_sg_source_ids."
  }
}

variable "kms_key_id" {
  description = "Optional KMS key for at-rest encryption (null = AWS managed)."
  type        = string
  default     = null
}

variable "auth_token_secret_arn" {
  description = "Secrets Manager ARN that stores JSON key 'token' for Redis AUTH."
  type        = string
}

variable "tags" {
  description = "Tags to apply."
  type        = map(string)
  default     = {}
}
