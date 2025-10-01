variable "name" {
  description = "Logical name/prefix (e.g., project-env)"
  type        = string
}

variable "region" {
  description = "AWS region for regional resources"
  type        = string
}

variable "trail_bucket_name" {
  description = "Optional pre-set bucket name for CloudTrail/Config logs; if empty a name is generated"
  type        = string
  default     = ""
}

variable "create_budget" {
  description = "Create a monthly cost budget"
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly cost budget amount in your account currency"
  type        = number
  default     = 500
}

variable "budget_emails" {
  description = "Email addresses to notify for budget alerts"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "enable_malware_protection" {
  description = "Enable GuardDuty malware protection for EC2 (EBS volume scanning)"
  type        = bool
  default     = true
}
