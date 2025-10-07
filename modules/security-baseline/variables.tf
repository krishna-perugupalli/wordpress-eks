variable "name" {
  description = "Logical prefix, e.g., project-env"
  type        = string
}

variable "trail_bucket_name" {
  description = "Optional fixed S3 bucket name for security logs (must be globally unique). Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "logs_expire_after_days" {
  description = "S3 lifecycle expiration in days for security logs."
  type        = number
  default     = 365
}

variable "cloudtrail_cwl_retention_days" {
  description = "CloudWatch Logs retention (days) for CloudTrail log group."
  type        = number
  default     = 90
}

variable "create_cloudtrail" {
  description = "Create a multi-region account-level CloudTrail."
  type        = bool
  default     = true
}

variable "create_config" {
  description = "Enable AWS Config recorder + delivery channel."
  type        = bool
  default     = true
}

variable "create_guardduty" {
  description = "Enable GuardDuty detector in this account/region."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
