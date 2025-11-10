variable "name" {
  description = "Budget name. Appears in console and notifications."
  type        = string
}

variable "limit_amount" {
  description = "Numeric cost limit for the budget period."
  type        = number
}

variable "currency" {
  description = "Currency code for the budget."
  type        = string
  default     = "USD"
}

variable "time_unit" {
  description = "Budget period."
  type        = string
  default     = "MONTHLY"
  validation {
    condition     = contains(["MONTHLY", "QUARTERLY", "ANNUALLY"], var.time_unit)
    error_message = "time_unit must be one of MONTHLY, QUARTERLY, ANNUALLY."
  }
}

variable "alert_emails" {
  description = "Email recipients for notifications."
  type        = list(string)
  default     = []
}

# --- SNS options (either create or reuse) ---

variable "create_sns_topic" {
  description = "Create an SNS topic for Budgets notifications."
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "Name of SNS topic to create (used only when create_sns_topic=true)."
  type        = string
  default     = null
}

variable "sns_topic_kms_key_id" {
  description = "KMS key ID/ARN for SNS encryption (optional; null uses AWS managed)."
  type        = string
  default     = null
}

variable "existing_sns_topic_arn" {
  description = "Use an existing SNS topic ARN instead of creating one."
  type        = string
  default     = ""
}

# Optional: create basic email subscriptions on the created topic
variable "sns_subscription_emails" {
  description = "Email addresses to subscribe to the created SNS topic (create_sns_topic=true). Confirmation required by recipients."
  type        = list(string)
  default     = []
}

# Thresholds
variable "forecast_threshold_percent" {
  description = "Send FORECASTED alert when forecasted spend exceeds this percent."
  type        = number
  default     = 80
}

variable "actual_threshold_percent" {
  description = "Send ACTUAL alert when spend exceeds this percent."
  type        = number
  default     = 100
}

variable "tags" {
  description = "Tags for created resources (SNS)."
  type        = map(string)
  default     = {}
}
