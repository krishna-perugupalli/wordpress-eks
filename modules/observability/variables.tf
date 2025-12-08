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
  description = "Enable YACE CloudWatch exporter (placeholder for Phase 2)"
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

# ============================================================================
# Common Variables
# ============================================================================

variable "tags" {
  description = "Common tags for AWS resources"
  type        = map(string)
  default     = {}
}
