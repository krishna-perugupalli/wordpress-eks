variable "name" {
  description = "Logical name / cluster name (used in log group names)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "EKS OIDC issuer URL (https://...)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}

variable "namespace" {
  description = "Namespace for agents"
  type        = string
  default     = "observability"
}

variable "kms_logs_key_arn" {
  description = "KMS key ARN to encrypt CloudWatch log groups (use your security-baseline key)"
  type        = string
  default     = null
}

variable "cw_retention_days" {
  description = "CloudWatch Logs retention (days)"
  type        = number
  default     = 30
}

variable "install_cloudwatch_agent" {
  description = "Install CloudWatch Agent for Container Insights"
  type        = bool
  default     = true
}

variable "install_fluent_bit" {
  description = "Install aws-for-fluent-bit for logs"
  type        = bool
  default     = true
}

# Optional ALB alarms (REGIONAL). Pass arn_suffixes from edge-ingress outputs.
variable "create_alb_alarms" {
  description = "Create ALB 5XX/latency alarms if ALB/TargetGroup identifiers are provided"
  type        = bool
  default     = false
}

variable "alb_arn_suffixes" {
  description = "List of ALB ARN suffixes (e.g., app/xxx/yyy) for alarms"
  type        = list(string)
  default     = []
}

variable "target_group_arn_suffixes" {
  description = "List of Target Group ARN suffixes (e.g., targetgroup/xxx/yyy) to pair with ALBs"
  type        = list(string)
  default     = []
}

variable "alarm_email_sns_topic_arn" {
  description = "SNS Topic ARN to receive alarm notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "ingress_name" {
  description = "K8s Ingress name (to auto-discover the ALB via tags)"
  type        = string
  default     = ""
}

variable "ingress_namespace" {
  description = "K8s Ingress namespace"
  type        = string
  default     = "wordpress"
}
variable "service_name" {
  description = "K8s Service name backing the Ingress (to auto-discover TG via tags)"
  type        = string
  default     = "wordpress"
}
variable "service_namespace" {
  description = "K8s Service namespace"
  type        = string
  default     = "wordpress"
}

