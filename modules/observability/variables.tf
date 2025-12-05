#############################################
# Core Configuration
#############################################
variable "name" {
  description = "Logical name / cluster name (used in resource names)"
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
  description = "Namespace for monitoring components"
  type        = string
  default     = "observability"
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (logs, storage, secrets)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

#############################################
# Stack Selection
#############################################
variable "enable_cloudwatch" {
  description = "Enable CloudWatch monitoring components"
  type        = bool
  default     = true
}

variable "enable_prometheus_stack" {
  description = "Enable Prometheus monitoring stack"
  type        = bool
  default     = false
}

variable "enable_grafana" {
  description = "Enable Grafana dashboard and visualization"
  type        = bool
  default     = false
}

variable "enable_alertmanager" {
  description = "Enable AlertManager for alert routing and notifications"
  type        = bool
  default     = false
}

#############################################
# CloudWatch Configuration (Legacy)
#############################################
variable "kms_logs_key_arn" {
  description = "KMS key ARN to encrypt CloudWatch log groups (deprecated, use kms_key_arn)"
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

#############################################
# Prometheus Configuration
#############################################
variable "prometheus_storage_size" {
  description = "Persistent storage size for Prometheus (e.g., '50Gi')"
  type        = string
  default     = "50Gi"
}

variable "prometheus_retention_days" {
  description = "Prometheus metrics retention period in days"
  type        = number
  default     = 30
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus persistent volumes"
  type        = string
  default     = "gp3"
}

variable "prometheus_replica_count" {
  description = "Number of Prometheus server replicas for high availability"
  type        = number
  default     = 2
}

variable "prometheus_resource_requests" {
  description = "Resource requests for Prometheus pods"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "500m"
    memory = "2Gi"
  }
}

variable "prometheus_resource_limits" {
  description = "Resource limits for Prometheus pods"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "2"
    memory = "8Gi"
  }
}

#############################################
# Service Discovery Configuration
#############################################
variable "enable_service_discovery" {
  description = "Enable automatic service discovery for metrics collection"
  type        = bool
  default     = true
}

variable "service_discovery_namespaces" {
  description = "List of namespaces to monitor for service discovery"
  type        = list(string)
  default     = ["default", "wordpress", "kube-system"]
}

#############################################
# Grafana Configuration
#############################################
variable "grafana_storage_size" {
  description = "Persistent storage size for Grafana (e.g., '10Gi')"
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_class" {
  description = "Storage class for Grafana persistent volumes"
  type        = string
  default     = "gp3"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana (use AWS Secrets Manager reference)"
  type        = string
  default     = null
  sensitive   = true
}

variable "grafana_resource_requests" {
  description = "Resource requests for Grafana pods"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "256Mi"
  }
}

variable "grafana_resource_limits" {
  description = "Resource limits for Grafana pods"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "500m"
    memory = "1Gi"
  }
}

variable "grafana_replica_count" {
  description = "Number of Grafana replicas for high availability"
  type        = number
  default     = 2
}

variable "enable_aws_iam_auth" {
  description = "Enable AWS IAM authentication for Grafana"
  type        = bool
  default     = true
}

variable "grafana_iam_role_arns" {
  description = "List of IAM role ARNs allowed to access Grafana"
  type        = list(string)
  default     = []
}

variable "enable_default_dashboards" {
  description = "Enable pre-configured dashboards for WordPress, Kubernetes, and AWS services"
  type        = bool
  default     = true
}

variable "custom_dashboard_configs" {
  description = "Custom dashboard configurations as JSON strings"
  type        = map(string)
  default     = {}
}

variable "enable_cloudwatch_datasource" {
  description = "Enable CloudWatch as a data source in Grafana"
  type        = bool
  default     = true
}

#############################################
# AlertManager Configuration
#############################################
variable "alertmanager_storage_size" {
  description = "Persistent storage size for AlertManager (e.g., '10Gi')"
  type        = string
  default     = "10Gi"
}

variable "alertmanager_storage_class" {
  description = "Storage class for AlertManager persistent volumes"
  type        = string
  default     = "gp3"
}

variable "alertmanager_replica_count" {
  description = "Number of AlertManager replicas for high availability (1 for small clusters, 2+ for production)"
  type        = number
  default     = 1
}

variable "alertmanager_resource_requests" {
  description = "Resource requests for AlertManager pods"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "128Mi"
  }
}

variable "alertmanager_resource_limits" {
  description = "Resource limits for AlertManager pods"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

#############################################
# Notification Configuration
#############################################
variable "smtp_config" {
  description = "SMTP configuration for email notifications"
  type = object({
    smarthost     = string
    from          = string
    auth_username = string
    auth_password = string
    require_tls   = bool
  })
  default   = null
  sensitive = true
}

variable "sns_topic_arn" {
  description = "SNS Topic ARN for alert notifications"
  type        = string
  default     = ""
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_routing_config" {
  description = "Alert routing configuration for AlertManager"
  type = object({
    group_by        = list(string)
    group_wait      = string
    group_interval  = string
    repeat_interval = string
    routes = list(object({
      match    = map(string)
      match_re = map(string)
      receiver = string
      group_by = list(string)
      continue = bool
    }))
  })
  default = {
    group_by        = ["alertname", "cluster", "service"]
    group_wait      = "10s"
    group_interval  = "10s"
    repeat_interval = "1h"
    routes          = []
  }
}

#############################################
# Exporters Configuration
#############################################
variable "enable_wordpress_exporter" {
  description = "Enable WordPress metrics exporter"
  type        = bool
  default     = false
}

variable "wordpress_namespace" {
  description = "Namespace where WordPress is deployed"
  type        = string
  default     = "wordpress"
}

variable "wordpress_service_name" {
  description = "WordPress service name for metrics collection"
  type        = string
  default     = "wordpress"
}

variable "enable_mysql_exporter" {
  description = "Enable MySQL/Aurora metrics exporter"
  type        = bool
  default     = false
}

variable "mysql_connection_config" {
  description = "MySQL connection configuration for metrics collection"
  type = object({
    host                = string
    port                = number
    username            = string
    password_secret_ref = string
    database            = string
  })
  default   = null
  sensitive = true
}

variable "enable_redis_exporter" {
  description = "Enable Redis/ElastiCache metrics exporter"
  type        = bool
  default     = false
}

variable "redis_connection_config" {
  description = "Redis connection configuration for metrics collection"
  type = object({
    host                = string
    port                = number
    password_secret_ref = string
    tls_enabled         = bool
  })
  default   = null
  sensitive = true
}

variable "enable_cloudwatch_exporter" {
  description = "Enable CloudWatch metrics exporter for AWS services"
  type        = bool
  default     = false
}

variable "cloudwatch_metrics_config" {
  description = "CloudWatch metrics configuration for AWS services"
  type = object({
    discovery_jobs = list(object({
      type        = string
      regions     = list(string)
      search_tags = map(string)
      custom_tags = map(string)
      metrics     = list(string)
    }))
  })
  default = null
}

variable "enable_cost_monitoring" {
  description = "Enable AWS cost monitoring and optimization tracking"
  type        = bool
  default     = false
}

variable "cost_allocation_tags" {
  description = "Cost allocation tags for cost tracking and optimization"
  type        = list(string)
  default     = ["Environment", "Project", "Owner", "Component"]
}

variable "enable_cloudfront_monitoring" {
  description = "Enable CloudFront CDN monitoring for cache hit rates and content delivery performance"
  type        = bool
  default     = false
}

variable "cloudfront_distribution_ids" {
  description = "List of CloudFront distribution IDs to monitor for CDN metrics"
  type        = list(string)
  default     = []
}

#############################################
# Security Configuration
#############################################
variable "enable_security_features" {
  description = "Enable security and compliance features"
  type        = bool
  default     = true
}

variable "enable_tls_encryption" {
  description = "Enable TLS encryption for all monitoring communications"
  type        = bool
  default     = true
}

variable "tls_cert_manager_issuer" {
  description = "Cert-manager issuer for TLS certificates"
  type        = string
  default     = "letsencrypt-prod"
}

variable "enable_pii_scrubbing" {
  description = "Enable PII scrubbing from collected metrics and logs"
  type        = bool
  default     = true
}

variable "pii_scrubbing_rules" {
  description = "PII scrubbing rules configuration"
  type = list(object({
    pattern     = string
    replacement = string
    description = string
  }))
  default = [
    {
      pattern     = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
      replacement = "[EMAIL_REDACTED]"
      description = "Email addresses"
    },
    {
      pattern     = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
      replacement = "[SSN_REDACTED]"
      description = "Social Security Numbers"
    }
  ]
}

variable "enable_audit_logging" {
  description = "Enable audit logging for monitoring system access"
  type        = bool
  default     = true
}

variable "audit_log_retention_days" {
  description = "Audit log retention period in days"
  type        = number
  default     = 90
}

variable "rbac_policies" {
  description = "RBAC policies for monitoring system access"
  type = map(object({
    subjects = list(object({
      kind      = string
      name      = string
      namespace = string
    }))
    role_ref = object({
      kind      = string
      name      = string
      api_group = string
    })
  }))
  default = {}
}

#############################################
# High Availability and Disaster Recovery Configuration
#############################################
variable "enable_backup_policies" {
  description = "Enable AWS Backup policies for metrics and dashboard data"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backup data"
  type        = number
  default     = 30
}

variable "enable_cloudwatch_fallback" {
  description = "Enable CloudWatch fallback for critical alerting when monitoring stack is unavailable"
  type        = bool
  default     = true
}

variable "fallback_alert_email" {
  description = "Email address for CloudWatch fallback alerts"
  type        = string
  default     = ""
}

variable "database_connection_threshold" {
  description = "Database connection count threshold for CloudWatch fallback alerts"
  type        = number
  default     = 80
}

variable "enable_automatic_recovery" {
  description = "Enable automatic restart and recovery mechanisms for monitoring components"
  type        = bool
  default     = true
}

#############################################
# Network Resilience Configuration
#############################################
variable "enable_network_resilience" {
  description = "Enable network resilience features including local metrics collection during partitions and intelligent retry logic"
  type        = bool
  default     = true
}

variable "network_partition_threshold" {
  description = "Number of consecutive connectivity check failures before declaring a network partition"
  type        = number
  default     = 3
}

variable "metrics_sync_interval" {
  description = "Interval for periodic metrics synchronization checks (in minutes)"
  type        = number
  default     = 15
}

variable "remote_write_queue_capacity" {
  description = "Capacity of the remote write queue for buffering during network issues"
  type        = number
  default     = 10000
}

variable "remote_write_max_backoff" {
  description = "Maximum backoff duration for remote write retries (e.g., '30s', '1m')"
  type        = string
  default     = "30s"
}