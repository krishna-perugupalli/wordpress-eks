variable "name" {
  description = "Base name; used for resource names and k8s subnet discovery tags"
  type        = string
}

# VPC / Subnets
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "private_cidrs" {
  description = "Private subnet CIDRs (one per AZ)"
  type        = list(string)
  validation {
    condition     = length(var.private_cidrs) >= 2 && length(var.private_cidrs) <= 3
    error_message = "private_cidrs must have 2 or 3 entries."
  }
}

variable "public_cidrs" {
  description = "Public subnet CIDRs (one per AZ)"
  type        = list(string)
  validation {
    condition     = length(var.public_cidrs) >= 2 && length(var.public_cidrs) <= 3
    error_message = "public_cidrs must have 2 or 3 entries."
  }
}

variable "nat_gateway_mode" {
  description = "NAT strategy: 'single' (one NAT in AZ0), 'per_az' (one per AZ), or 'none' (use VPC Endpoints)"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "per_az", "none"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be 'single', 'per_az', or 'none'."
  }
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC Endpoints for AWS services (S3, ECR, Secrets Manager) instead of NAT Gateway"
  type        = bool
  default     = false
}

# Feature toggles
variable "create_public_hosted_zone" {
  description = "Create a Route53 public hosted zone for domain"
  type        = bool
  default     = false
}

variable "domain" {
  description = "Root domain (when creating Route53 zone)"
  type        = string
  default     = ""
}

# Buckets
variable "media_bucket_name" {
  description = "S3 bucket name for WordPress media (offload). If empty, module will name it."
  type        = string
  default     = ""
}

# Tagging
variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
