# Complete example of Grafana module usage
# This example shows all configuration options

terraform {
  required_version = ">= 1.6.0"
}

# Example: Deploy Grafana with all features enabled
module "grafana_complete" {
  source = "../"

  # Core configuration
  name                    = "production"
  region                  = "us-east-1"
  cluster_name            = "prod-eks-cluster"
  cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
  oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
  namespace               = "observability"

  # Storage configuration with KMS encryption
  grafana_storage_size  = "20Gi"
  grafana_storage_class = "gp3"

  # Admin password - use AWS Secrets Manager reference in production
  grafana_admin_password = null # Will generate secure random password

  # Resource configuration for production workload
  grafana_resource_requests = {
    cpu    = "200m"
    memory = "512Mi"
  }
  grafana_resource_limits = {
    cpu    = "1000m"
    memory = "2Gi"
  }

  # AWS IAM authentication for secure access
  enable_aws_iam_auth = true
  grafana_iam_role_arns = [
    "arn:aws:iam::123456789012:role/DevOpsTeam",
    "arn:aws:iam::123456789012:role/SRETeam"
  ]

  # Enable pre-configured dashboards
  enable_default_dashboards = true

  # Custom dashboard configurations (optional)
  custom_dashboard_configs = {
    "custom-app-metrics" = jsonencode({
      dashboard = {
        title = "Custom Application Metrics"
        tags  = ["custom", "application"]
        panels = [
          {
            title = "Custom Metric"
            type  = "graph"
            targets = [
              {
                expr = "custom_metric_total"
              }
            ]
          }
        ]
      }
    })
  }

  # Data source configuration
  prometheus_url               = "http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090"
  enable_cloudwatch_datasource = true

  # KMS encryption for persistent storage
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Resource tags
  tags = {
    Environment = "production"
    Project     = "wordpress-eks"
    ManagedBy   = "terraform"
    Owner       = "platform-team@example.com"
    CostCenter  = "engineering"
  }
}

# Example: Minimal Grafana deployment for development
module "grafana_minimal" {
  source = "../"

  # Core configuration
  name                    = "dev"
  region                  = "us-east-1"
  cluster_name            = "dev-eks-cluster"
  cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
  oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E"
  namespace               = "observability"

  # Minimal storage for development
  grafana_storage_size  = "5Gi"
  grafana_storage_class = "gp3"

  # Auto-generated admin password
  grafana_admin_password = null

  # Minimal resources for development
  grafana_resource_requests = {
    cpu    = "100m"
    memory = "256Mi"
  }
  grafana_resource_limits = {
    cpu    = "500m"
    memory = "1Gi"
  }

  # Disable AWS IAM auth for simpler development setup
  enable_aws_iam_auth   = false
  grafana_iam_role_arns = []

  # Enable default dashboards
  enable_default_dashboards = true
  custom_dashboard_configs  = {}

  # Only Prometheus data source
  prometheus_url               = "http://prometheus.observability.svc.cluster.local:9090"
  enable_cloudwatch_datasource = false

  # No KMS encryption for development
  kms_key_arn = null

  tags = {
    Environment = "development"
    ManagedBy   = "terraform"
  }
}

# Outputs for complete example
output "complete_grafana_url" {
  description = "Grafana URL for complete example"
  value       = module.grafana_complete.grafana_url
}

output "complete_grafana_role_arn" {
  description = "Grafana IAM role ARN for complete example"
  value       = module.grafana_complete.grafana_role_arn
}

output "complete_admin_secret" {
  description = "Admin secret name for complete example"
  value       = module.grafana_complete.grafana_admin_secret_name
}

# Outputs for minimal example
output "minimal_grafana_url" {
  description = "Grafana URL for minimal example"
  value       = module.grafana_minimal.grafana_url
}

output "minimal_admin_secret" {
  description = "Admin secret name for minimal example"
  value       = module.grafana_minimal.grafana_admin_secret_name
}
