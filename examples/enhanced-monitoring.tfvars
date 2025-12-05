############################################
# Enhanced Monitoring Configuration Example
# This file demonstrates how to enable and configure
# the enhanced observability stack with Prometheus,
# Grafana, and AlertManager alongside CloudWatch
############################################

############################################
# Stack Selection
############################################
# Enable CloudWatch for backward compatibility
enable_cloudwatch        = true
install_cloudwatch_agent = true
install_fluent_bit       = true
cw_retention_days        = 30

# Enable Prometheus stack components
enable_prometheus_stack = true
enable_grafana          = true
enable_alertmanager     = true

############################################
# Prometheus Configuration
############################################
prometheus_storage_size   = "100Gi" # Adjust based on metrics volume
prometheus_retention_days = 30
prometheus_storage_class  = "gp3"
prometheus_replica_count  = 2 # High availability

prometheus_resource_requests = {
  cpu    = "1"
  memory = "4Gi"
}

prometheus_resource_limits = {
  cpu    = "4"
  memory = "16Gi"
}

# Service discovery
enable_service_discovery     = true
service_discovery_namespaces = ["default", "wordpress", "kube-system", "observability"]

############################################
# Grafana Configuration
############################################
grafana_storage_size  = "20Gi"
grafana_storage_class = "gp3"

# Set admin password via AWS Secrets Manager reference
# grafana_admin_password = "arn:aws:secretsmanager:region:account:secret:grafana-admin-password"

grafana_resource_requests = {
  cpu    = "200m"
  memory = "512Mi"
}

grafana_resource_limits = {
  cpu    = "1"
  memory = "2Gi"
}

# Authentication
enable_aws_iam_auth = true
grafana_iam_role_arns = [
  # Add IAM role ARNs that should have access to Grafana
  # "arn:aws:iam::123456789012:role/DevOpsTeam"
]

# Dashboards
enable_default_dashboards    = true
enable_cloudwatch_datasource = true

############################################
# AlertManager Configuration
############################################
alertmanager_storage_size  = "10Gi"
alertmanager_storage_class = "gp3"
alertmanager_replica_count = 2 # High availability

alertmanager_resource_requests = {
  cpu    = "100m"
  memory = "128Mi"
}

alertmanager_resource_limits = {
  cpu    = "500m"
  memory = "512Mi"
}

# Notification channels
# sns_topic_arn = "arn:aws:sns:region:account:monitoring-alerts"
# slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# pagerduty_integration_key = "your-pagerduty-integration-key"

# Alert routing configuration
alert_routing_config = {
  group_by        = ["alertname", "cluster", "service"]
  group_wait      = "10s"
  group_interval  = "10s"
  repeat_interval = "1h"
  routes = [
    {
      match = {
        severity = "critical"
      }
      match_re = {}
      receiver = "pagerduty"
      group_by = ["alertname"]
      continue = true
    },
    {
      match = {
        severity = "warning"
      }
      match_re = {}
      receiver = "slack"
      group_by = ["alertname", "service"]
      continue = false
    }
  ]
}

############################################
# Exporters Configuration
############################################
# WordPress metrics
enable_wordpress_exporter = true

# MySQL/Aurora metrics
enable_mysql_exporter = true
mysql_connection_config = {
  host                = "aurora-cluster-endpoint.region.rds.amazonaws.com"
  port                = 3306
  username            = "monitoring_user"
  password_secret_ref = "arn:aws:secretsmanager:region:account:secret:mysql-monitoring-password"
  database            = "wordpress"
}

# Redis/ElastiCache metrics
enable_redis_exporter = true
redis_connection_config = {
  host                = "redis-cluster.cache.amazonaws.com"
  port                = 6379
  password_secret_ref = "arn:aws:secretsmanager:region:account:secret:redis-auth-token"
  tls_enabled         = true
}

# CloudWatch exporter for AWS services
enable_cloudwatch_exporter = true
cloudwatch_metrics_config = {
  discovery_jobs = [
    {
      type    = "rds"
      regions = ["us-east-1"]
      search_tags = {
        Environment = "production"
      }
      custom_tags = {
        Component = "database"
      }
      metrics = [
        "CPUUtilization",
        "DatabaseConnections",
        "FreeableMemory",
        "ReadLatency",
        "WriteLatency"
      ]
    },
    {
      type    = "elasticache"
      regions = ["us-east-1"]
      search_tags = {
        Environment = "production"
      }
      custom_tags = {
        Component = "cache"
      }
      metrics = [
        "CPUUtilization",
        "CurrConnections",
        "CacheHits",
        "CacheMisses",
        "BytesUsedForCache"
      ]
    },
    {
      type    = "alb"
      regions = ["us-east-1"]
      search_tags = {
        Environment = "production"
      }
      custom_tags = {
        Component = "loadbalancer"
      }
      metrics = [
        "RequestCount",
        "TargetResponseTime",
        "HTTPCode_Target_2XX_Count",
        "HTTPCode_Target_4XX_Count",
        "HTTPCode_Target_5XX_Count"
      ]
    }
  ]
}

# Cost monitoring
enable_cost_monitoring = true
cost_allocation_tags   = ["Environment", "Project", "Owner", "Component", "Service"]

############################################
# Security Configuration
############################################
enable_security_features = true
enable_tls_encryption    = true
tls_cert_manager_issuer  = "letsencrypt-prod"

# PII scrubbing
enable_pii_scrubbing = true
pii_scrubbing_rules = [
  {
    pattern     = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
    replacement = "[EMAIL_REDACTED]"
    description = "Email addresses"
  },
  {
    pattern     = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
    replacement = "[SSN_REDACTED]"
    description = "Social Security Numbers"
  },
  {
    pattern     = "\\b(?:\\d{4}[-\\s]?){3}\\d{4}\\b"
    replacement = "[CARD_REDACTED]"
    description = "Credit card numbers"
  }
]

# Audit logging
enable_audit_logging     = true
audit_log_retention_days = 90

# RBAC policies
rbac_policies = {
  monitoring_viewers = {
    subjects = [
      {
        kind      = "Group"
        name      = "monitoring-viewers"
        namespace = "observability"
      }
    ]
    role_ref = {
      kind      = "ClusterRole"
      name      = "monitoring-viewer"
      api_group = "rbac.authorization.k8s.io"
    }
  }
  monitoring_admins = {
    subjects = [
      {
        kind      = "Group"
        name      = "monitoring-admins"
        namespace = "observability"
      }
    ]
    role_ref = {
      kind      = "ClusterRole"
      name      = "monitoring-admin"
      api_group = "rbac.authorization.k8s.io"
    }
  }
}

############################################
# High Availability and Disaster Recovery
############################################
enable_backup_policies     = true
backup_retention_days      = 30
enable_cloudwatch_fallback = true
fallback_alert_email       = "ops-team@example.com"
enable_automatic_recovery  = true

############################################
# Network Resilience
############################################
enable_network_resilience   = true
remote_write_queue_capacity = 10000
remote_write_max_backoff    = "30s"

############################################
# CDN Monitoring (if CloudFront is enabled)
############################################
enable_cloudfront_monitoring = false
# cloudfront_distribution_ids = ["E1234567890ABC"]
