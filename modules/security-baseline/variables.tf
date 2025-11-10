variable "name" {
  description = "Logical prefix, e.g., project-env"
  type        = string
}

variable "trail_bucket_name" {
  description = "Existing S3 bucket name for security logs (CloudTrail/ALB/Config). Required when create_trail_bucket=false. Leave empty when create_trail_bucket=true to auto-generate."
  type        = string
  default     = ""
}

variable "create_trail_bucket" {
  description = "If true, create the security logs S3 bucket in this module; otherwise, use trail_bucket_name (can be a module output)."
  type        = bool
  default     = false
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
  default     = false
}

variable "guardduty_use_existing" {
  description = "Set to true if a GuardDuty detector already exists in this account/region and should be reused instead of creating a new one."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
