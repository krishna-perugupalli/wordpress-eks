variable "name" {
  description = "Base name for WAF resources"
  type        = string
}

variable "rate_limit" {
  description = "Rate limit for wp-login.php requests per 5 minutes from a single IP"
  type        = number
  default     = 100

  validation {
    condition     = var.rate_limit >= 100 && var.rate_limit <= 20000000
    error_message = "Rate limit must be between 100 and 20,000,000 requests per 5 minutes."
  }
}

variable "enable_managed_rules" {
  description = "Enable AWS Managed Rules (Common Rule Set) for OWASP Top 10 protection"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to WAF resources"
  type        = map(string)
  default     = {}
}
