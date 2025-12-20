# ============================================================================
# Cluster Configuration Variables
# ============================================================================

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster Kubernetes version"
  type        = string
}

variable "cluster_ca_data" {
  description = "EKS cluster certificate authority data"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  type        = string
}

# ============================================================================
# Component Toggle Variables
# ============================================================================

variable "enable_prometheus" {
  description = "Enable Prometheus (kube-prometheus-stack)"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "enable_alertmanager" {
  description = "Enable Alertmanager"
  type        = bool
  default     = true
}

variable "enable_fluentbit" {
  description = "Enable Fluent Bit for log forwarding"
  type        = bool
  default     = true
}

variable "enable_yace" {
  description = "Enable YACE CloudWatch exporter"
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Enable Tempo for distributed tracing"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Enable Metrics Server"
  type        = bool
  default     = true
}

# ============================================================================
# Dashboard Toggle Variables
# ============================================================================

variable "enable_wp_dashboards" {
  description = "Enable WordPress-specific dashboards"
  type        = bool
  default     = true
}

variable "enable_aws_dashboards" {
  description = "Enable AWS service dashboards (RDS, ElastiCache, etc.)"
  type        = bool
  default     = true
}

variable "enable_cost_dashboards" {
  description = "Enable cost allocation dashboards"
  type        = bool
  default     = true
}

# ============================================================================
# Optional Override Variables
# ============================================================================

variable "prometheus_namespace" {
  description = "Namespace for Prometheus stack (default: managed by Blueprints)"
  type        = string
  default     = ""
}

variable "grafana_namespace" {
  description = "Namespace for Grafana (default: managed by Blueprints)"
  type        = string
  default     = ""
}

variable "wordpress_namespace" {
  description = "Namespace where WordPress is deployed (for ServiceMonitor targeting)"
  type        = string
  default     = "wordpress"
}

# ============================================================================
# Infrastructure Endpoint Variables
# ============================================================================

variable "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint address"
  type        = string
  default     = ""
}

variable "mysql_endpoint" {
  description = "Aurora MySQL writer endpoint"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name for resource tagging (used in YACE discovery)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name for resource tagging (used in YACE discovery)"
  type        = string
  default     = ""
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "loki_retention_days" {
  description = "Retention period for Loki logs in days"
  type        = number
  default     = 30
}

variable "tempo_retention_hours" {
  description = "Retention period for Tempo traces in hours"
  type        = number
  default     = 168 # 7 days
}

# ============================================================================
# Alerting Configuration Variables
# ============================================================================

variable "enable_alerting" {
  description = "Enable PrometheusRule alert definitions"
  type        = bool
  default     = false
}

variable "notification_provider" {
  description = "Primary notification provider: 'slack' or 'sns'"
  type        = string
  default     = "slack"

  validation {
    condition     = contains(["slack", "sns"], var.notification_provider)
    error_message = "Notification provider must be 'slack' or 'sns'."
  }
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications (when provider=slack)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alert notifications (when provider=sns)"
  type        = string
  default     = ""
}

# ============================================================================
# Secrets Variables
# ============================================================================

variable "grafana_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Grafana admin credentials"
  type        = string
  default     = ""
}

# ============================================================================
# Common Variables
# ============================================================================

variable "tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default     = {}
}
