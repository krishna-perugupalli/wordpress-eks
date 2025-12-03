variable "region" {
  description = "AWS region (e.g., eu-north-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project/environment short name; used as release/ingress prefix"
  type        = string
  default     = "wdp"
}

variable "env" {
  description = "Environment name for the project"
  type        = string
  default     = "sandbox"
}

variable "owner_email" {
  description = "Owner/Contact email tag"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Extra tags merged into all resources (where supported)"
  type        = map(string)
  default     = {}
}

# ---------------------------
# Optional Tagging (AWS Best Practices)
# ---------------------------
variable "cost_center" {
  description = "Cost center for billing allocation and chargeback (optional)"
  type        = string
  default     = ""
}

variable "application" {
  description = "Application name for resource grouping (optional, defaults to 'wordpress-platform')"
  type        = string
  default     = "wordpress-platform"
}

variable "business_unit" {
  description = "Business unit or department ownership (optional)"
  type        = string
  default     = ""
}

variable "compliance_requirements" {
  description = "Comma-separated compliance requirements (e.g., 'HIPAA,SOC2,PCI-DSS') (optional)"
  type        = string
  default     = ""
}

variable "data_classification" {
  description = "Default data classification level: public, internal, confidential, restricted (optional)"
  type        = string
  default     = ""

  validation {
    condition     = var.data_classification == "" || contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "data_classification must be empty or one of: public, internal, confidential, restricted"
  }
}

variable "technical_contact" {
  description = "Technical contact email (optional, defaults to owner_email)"
  type        = string
  default     = ""
}

variable "product_owner" {
  description = "Product owner email or name (optional)"
  type        = string
  default     = ""
}

# ---------------------------
# DB
# ---------------------------
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "wordpress"
}

variable "db_user" {
  description = "Database username"
  type        = string
  default     = "wpapp"
}

# ---------------------------
# Edge/Ingress
# ---------------------------
variable "enable_cloudfront" {
  description = "Enable CloudFront distribution in front of ALB"
  type        = bool
  default     = false
}

variable "enable_alb_traffic" {
  description = "Create Route53 alias pointing directly to the ALB (disable when using CloudFront)"
  type        = bool
  default     = false
}

variable "alb_domain_name" {
  description = "Hostname for WordPress (ALB Ingress)"
  type        = string
  default     = "wp-sbx.example.com"
}

variable "alb_hosted_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
  default     = "ZXXXXXXXXXXXX"
}

variable "create_regional_certificate" {
  description = "Create ACM certificate in region for ALB"
  type        = bool
  default     = true
}

variable "create_cf_certificate" {
  description = "Create ACM cert in us-east-1 for CloudFront (unused now)"
  type        = bool
  default     = false
}

variable "create_waf_regional" {
  description = "Create WAF v2 Web ACL (REGIONAL) and associate to ALB"
  type        = bool
  default     = true
}

variable "waf_ruleset_level" {
  description = "WAF ruleset level: baseline or strict"
  type        = string
  default     = "baseline"
}

variable "enable_common_ruleset" {
  description = "Enable or disable flag for AWSManagedRulesCommonRuleSet, To unblock some application level issues with WAF"
  type        = string
  default     = false
}

variable "acm_certificate_arn" {
  description = "Pre-created ACM certificate ARN for the ALB (regional). If set, ACM creation/validation is skipped."
  type        = string
  default     = ""
}

variable "cf_acm_certificate_arn" {
  description = "Pre-created ACM certificate ARN for the CloudFront (regional). If set, ACM creation/validation is skipped."
  type        = string
  default     = ""
}

variable "cf_aliases" {
  description = "Additional CNAMEs."
  type        = list(string)
  default     = []
}

# ---------------------------
# Karpenter
# ---------------------------
variable "karpenter_instance_types" {
  description = "Allowed instance types"
  type        = list(string)
  default     = ["t3a.medium", "t3a.large", "t3a.xlarge", "m6a.large", "m6a.xlarge", "c6a.large", "c6a.xlarge"]
}

variable "karpenter_instance_families" {
  description = "Allowed Family types - Optional"
  type        = list(string)
  default     = ["t3a", "m6a", "c6a"]
}

variable "karpenter_cpu_allowed" {
  description = "Allowed CPU types"
  type        = list(string)
  default     = ["2", "4", "8", "16"]
}

variable "karpenter_arch_types" {
  description = "Allowed arch types"
  type        = list(string)
  default     = ["amd64"]
}

variable "karpenter_os_types" {
  description = "Allowed OS types"
  type        = list(string)
  default     = ["linux"]
}

variable "karpenter_capacity_types" {
  description = "Capacity types mix"
  type        = list(string)
  default     = ["spot", "on-demand"]
}

variable "karpenter_ami_family" {
  description = "AMI family (AL2023, Bottlerocket)"
  type        = string
  default     = "AL2023"
}

variable "karpenter_consolidation_policy" {
  description = "Consolidation policy"
  type        = string
  default     = "WhenEmptyOrUnderutilized"
}

variable "karpenter_expire_after" {
  description = "Node expiration (e.g., 720h)"
  type        = string
  default     = "720h"
}

variable "karpenter_cpu_limit" {
  description = "NodePool CPU limit across nodes"
  type        = string
  default     = "64"
}

variable "karpenter_volume_size" {
  description = "Node volume size in GB"
  type        = string
  default     = "50Gi"
}

variable "karpenter_volume_type" {
  description = "Node volume type"
  type        = string
  default     = "gp2"
}

variable "karpenter_taints" {
  description = "Optional taints for provisioned nodes"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = []
}

# ---------------------------
# cert-manager
# ---------------------------
variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificate management"
  type        = bool
  default     = true
}

variable "cert_manager_namespace" {
  description = "Namespace for cert-manager installation"
  type        = string
  default     = "cert-manager"
}

variable "cert_manager_version" {
  description = "cert-manager Helm chart version"
  type        = string
  default     = "v1.16.2"
}

variable "create_letsencrypt_issuer" {
  description = "Create Let's Encrypt ClusterIssuers (prod and staging)"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt account registration"
  type        = string
  default     = ""
}

variable "create_selfsigned_issuer" {
  description = "Create self-signed ClusterIssuer for internal certificates"
  type        = bool
  default     = true
}

variable "cert_manager_resource_requests" {
  description = "Resource requests for cert-manager controller"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "10m"
    memory = "32Mi"
  }
}

variable "cert_manager_resource_limits" {
  description = "Resource limits for cert-manager controller"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "100m"
    memory = "128Mi"
  }
}

# ---------------------------
# Observability
# ---------------------------
variable "observability_namespace" {
  description = "Namespace to install CW Agent/Fluent Bit"
  type        = string
  default     = "observability"
}

variable "cw_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 30
}

variable "install_cloudwatch_agent" {
  description = "Install CW Agent via Helm"
  type        = bool
  default     = true
}

variable "install_fluent_bit" {
  description = "Install Fluent Bit via Helm"
  type        = bool
  default     = true
}

# ---------------------------
# Enhanced Observability Configuration
# ---------------------------

# Stack selection
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

# Prometheus configuration
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

# Service discovery
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

# Grafana configuration
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

# AlertManager configuration
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
  description = "Number of AlertManager replicas for high availability"
  type        = number
  default     = 2
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

# Notification configuration
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

# Exporters configuration
variable "enable_wordpress_exporter" {
  description = "Enable WordPress metrics exporter"
  type        = bool
  default     = false
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

# Security configuration
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
  description = "Cert-manager issuer for TLS certificates (use 'selfsigned-issuer' for internal monitoring)"
  type        = string
  default     = "selfsigned-issuer"
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

# ---------------------------
# WordPress App (Bitnami)
# ---------------------------
variable "wp_namespace" {
  description = "Kubernetes namespace for WordPress"
  type        = string
  default     = "wordpress"
}

variable "wp_storage_class" {
  description = "StorageClass to use (EFS Access Point)"
  type        = string
  default     = "efs-ap"
}

variable "wp_pvc_size" {
  description = "PVC size"
  type        = string
  default     = "10Gi"
}

variable "wp_domain_name" {
  description = "Public hostname (must match alb_domain_name)"
  type        = string
  default     = "wp-sbx.example.com"
}

variable "wp_replicas_min" {
  description = "Min replicas for HPA"
  type        = number
  default     = 2
}

variable "wp_replicas_max" {
  description = "Max replicas for HPA"
  type        = number
  default     = 6
}

variable "wp_image_tag" {
  description = "WordPress image tag"
  type        = string
  default     = "latest"
}

variable "wp_target_cpu_percent" {
  description = "HPA target CPU %"
  type        = number
  default     = 60
}

variable "wp_target_memory_value" {
  description = "HPA target memory %"
  type        = string
  default     = "80"
}

variable "wp_admin_user" {
  description = "Initial admin username (non-sensitive)"
  type        = string
  default     = "wpadmin"
}

variable "wp_admin_email" {
  description = "Initial admin email (non-sensitive)"
  type        = string
  default     = "admin@example.com"
}

variable "wp_admin_bootstrap_enabled" {
  description = "Enable one-time admin bootstrap initContainer"
  type        = bool
  default     = true
}

# ---------------------------
# Redis cache
# ---------------------------
variable "enable_redis_cache" {
  description = "Enable Redis-backed cache configuration in the WordPress release"
  type        = bool
  default     = false
}

variable "redis_port" {
  description = "Redis port exposed by ElastiCache"
  type        = number
  default     = 6379
}

variable "redis_database" {
  description = "Logical Redis database ID used by W3TC"
  type        = number
  default     = 0
}

variable "redis_connection_scheme" {
  description = "Scheme prefix for Redis connections (tcp, tls, rediss)"
  type        = string
  default     = "tls"
}

# --------------------
# EFS Access Point
# --------------------

variable "efs_id" {
  description = "EFS File System ID"
  type        = string
  default     = "efs-ap"
}

# ---------------------------
# Remote state (Terraform Cloud)
# ---------------------------
variable "remote_state_organization" {
  description = "Terraform Cloud organization for remote state"
  type        = string
  default     = "WpOrbit"
}

variable "remote_state_infra_workspace" {
  description = "Terraform Cloud workspace name for infra remote state"
  type        = string
  default     = "wp-infra"
}

variable "cluster_version" {
  description = "EKS cluster minor (e.g., 1.33)"
  type        = string
  default     = "1.33"
}

variable "arch" {
  description = "EC2 architecture for workers"
  type        = string
  default     = "x86_64" # or "arm64"
}
