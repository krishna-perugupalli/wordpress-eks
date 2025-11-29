# Complete AlertManager Configuration Example
# This example demonstrates all available configuration options

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.55"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

# Example: Complete AlertManager deployment with all notification channels
module "alertmanager_complete" {
  source = "../"

  # Core configuration
  name                    = "wordpress-prod"
  region                  = "us-east-1"
  cluster_name            = "wordpress-eks-prod"
  cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  namespace               = "observability"

  # Storage configuration
  alertmanager_storage_size  = "10Gi"
  alertmanager_storage_class = "gp3"
  alertmanager_replica_count = 3 # 3 replicas for production

  # Resource configuration
  alertmanager_resource_requests = {
    cpu    = "200m"
    memory = "256Mi"
  }
  alertmanager_resource_limits = {
    cpu    = "1000m"
    memory = "1Gi"
  }

  # SMTP configuration for email notifications
  smtp_config = {
    smarthost     = "smtp.gmail.com:587"
    from          = "wordpress-alerts@example.com"
    auth_username = "wordpress-alerts@example.com"
    auth_password = var.smtp_password # Store in Terraform Cloud variables
    require_tls   = true
  }

  # SNS configuration for AWS notifications
  sns_topic_arn = "arn:aws:sns:us-east-1:123456789012:wordpress-alerts"

  # Slack configuration for team notifications
  slack_webhook_url = var.slack_webhook_url # Store in Terraform Cloud variables

  # PagerDuty configuration for on-call alerts
  pagerduty_integration_key = var.pagerduty_integration_key # Store in Terraform Cloud variables

  # Alert routing configuration
  alert_routing_config = {
    group_by        = ["alertname", "cluster", "service", "severity"]
    group_wait      = "10s"
    group_interval  = "5m"
    repeat_interval = "1h"

    # Custom routes for specific teams or services
    routes = [
      # Database team route
      {
        match = {
          team = "database"
        }
        match_re = {}
        receiver = "database-team"
        group_by = ["alertname", "instance"]
        continue = false
      },
      # Security team route
      {
        match = {
          category = "security"
        }
        match_re = {}
        receiver = "security-team"
        group_by = ["alertname"]
        continue = true # Continue to other routes
      },
      # Business hours vs after hours
      {
        match = {}
        match_re = {
          time = "^(09|10|11|12|13|14|15|16|17):.*" # Business hours
        }
        receiver = "business-hours"
        group_by = ["alertname"]
        continue = false
      }
    ]
  }

  # KMS encryption for persistent storage
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  # Tags
  tags = {
    Environment = "production"
    Project     = "wordpress"
    ManagedBy   = "Terraform"
    Owner       = "platform-team@example.com"
    CostCenter  = "engineering"
  }
}

# Example: Minimal AlertManager deployment with only email notifications
module "alertmanager_minimal" {
  source = "../"

  # Core configuration
  name                    = "wordpress-dev"
  region                  = "us-east-1"
  cluster_name            = "wordpress-eks-dev"
  cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  namespace               = "observability"

  # Minimal storage configuration
  alertmanager_storage_size  = "5Gi"
  alertmanager_storage_class = "gp3"
  alertmanager_replica_count = 1 # Single replica for dev

  # Minimal resource configuration
  alertmanager_resource_requests = {
    cpu    = "100m"
    memory = "128Mi"
  }
  alertmanager_resource_limits = {
    cpu    = "500m"
    memory = "512Mi"
  }

  # Only email notifications
  smtp_config = {
    smarthost     = "smtp.example.com:587"
    from          = "dev-alerts@example.com"
    auth_username = "dev-alerts@example.com"
    auth_password = var.smtp_password
    require_tls   = true
  }

  # No SNS, Slack, or PagerDuty
  sns_topic_arn             = ""
  slack_webhook_url         = ""
  pagerduty_integration_key = ""

  # Default alert routing
  alert_routing_config = {
    group_by        = ["alertname", "cluster"]
    group_wait      = "30s"
    group_interval  = "10m"
    repeat_interval = "2h"
    routes          = []
  }

  tags = {
    Environment = "development"
    Project     = "wordpress"
    ManagedBy   = "Terraform"
  }
}

# Example: SNS-only AlertManager for AWS-native notifications
module "alertmanager_sns_only" {
  source = "../"

  # Core configuration
  name                    = "wordpress-staging"
  region                  = "us-east-1"
  cluster_name            = "wordpress-eks-staging"
  cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  oidc_provider_arn       = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  namespace               = "observability"

  # Storage configuration
  alertmanager_storage_size  = "10Gi"
  alertmanager_storage_class = "gp3"
  alertmanager_replica_count = 2

  # Resource configuration
  alertmanager_resource_requests = {
    cpu    = "100m"
    memory = "128Mi"
  }
  alertmanager_resource_limits = {
    cpu    = "500m"
    memory = "512Mi"
  }

  # Only SNS notifications
  smtp_config               = null
  sns_topic_arn             = "arn:aws:sns:us-east-1:123456789012:staging-alerts"
  slack_webhook_url         = ""
  pagerduty_integration_key = ""

  # Alert routing configuration
  alert_routing_config = {
    group_by        = ["alertname", "cluster", "severity"]
    group_wait      = "10s"
    group_interval  = "10s"
    repeat_interval = "1h"
    routes          = []
  }

  # KMS encryption
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  tags = {
    Environment = "staging"
    Project     = "wordpress"
    ManagedBy   = "Terraform"
  }
}

# Variables for sensitive data
variable "smtp_password" {
  description = "SMTP password for email notifications"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pagerduty_integration_key" {
  description = "PagerDuty integration key for on-call alerts"
  type        = string
  sensitive   = true
  default     = ""
}

# Outputs
output "complete_alertmanager_url" {
  description = "Complete AlertManager URL"
  value       = module.alertmanager_complete.alertmanager_url
}

output "complete_alertmanager_role_arn" {
  description = "Complete AlertManager IAM role ARN"
  value       = module.alertmanager_complete.alertmanager_role_arn
}

output "minimal_alertmanager_url" {
  description = "Minimal AlertManager URL"
  value       = module.alertmanager_minimal.alertmanager_url
}

output "sns_only_alertmanager_url" {
  description = "SNS-only AlertManager URL"
  value       = module.alertmanager_sns_only.alertmanager_url
}
