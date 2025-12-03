#############################################
# High Availability and Disaster Recovery Configuration
# Implements multi-AZ deployment, automatic recovery, backups, and CloudWatch fallback
#############################################

#############################################
# Multi-AZ Deployment Configuration
#############################################

# Pod Disruption Budget for Prometheus
resource "kubernetes_pod_disruption_budget_v1" "prometheus" {
  count = local.prometheus_enabled ? 1 : 0

  metadata {
    name      = "${var.name}-prometheus-pdb"
    namespace = local.ns
  }

  spec {
    min_available = var.prometheus_replica_count > 1 ? 1 : 0

    selector {
      match_labels = {
        app                          = "kube-prometheus-stack-prometheus"
        "app.kubernetes.io/instance" = "prometheus"
      }
    }
  }

  depends_on = [module.prometheus]
}

# Pod Disruption Budget for Grafana
resource "kubernetes_pod_disruption_budget_v1" "grafana" {
  count = local.grafana_enabled ? 1 : 0

  metadata {
    name      = "${var.name}-grafana-pdb"
    namespace = local.ns
  }

  spec {
    min_available = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "grafana"
        "app.kubernetes.io/instance" = "grafana"
      }
    }
  }

  depends_on = [module.grafana]
}

# Pod Disruption Budget for AlertManager
resource "kubernetes_pod_disruption_budget_v1" "alertmanager" {
  count = local.alertmanager_enabled ? 1 : 0

  metadata {
    name      = "${var.name}-alertmanager-pdb"
    namespace = local.ns
  }

  spec {
    min_available = var.alertmanager_replica_count > 1 ? 1 : 0

    selector {
      match_labels = {
        app       = "alertmanager"
        component = "alerting"
      }
    }
  }

  depends_on = [module.alertmanager]
}

#############################################
# Backup Configuration for Metrics and Dashboards
#############################################

# AWS Backup Vault for monitoring data
resource "aws_backup_vault" "monitoring" {
  count = var.enable_backup_policies ? 1 : 0

  name        = "${var.name}-monitoring-backup-vault"
  kms_key_arn = var.kms_key_arn

  tags = merge(var.tags, {
    Name      = "${var.name}-monitoring-backup-vault"
    Component = "monitoring-backup"
  })
}

# AWS Backup Plan for EBS volumes (Prometheus and Grafana storage)
resource "aws_backup_plan" "monitoring" {
  count = var.enable_backup_policies ? 1 : 0

  name = "${var.name}-monitoring-backup-plan"

  # Daily backup with 30-day retention
  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.monitoring[0].name
    schedule          = "cron(0 2 * * ? *)" # 2 AM UTC daily

    lifecycle {
      delete_after = var.backup_retention_days
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "daily"
      Component  = "monitoring"
    })
  }

  # Weekly backup with 90-day retention
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.monitoring[0].name
    schedule          = "cron(0 3 ? * SUN *)" # 3 AM UTC on Sundays

    lifecycle {
      delete_after = 90
    }

    recovery_point_tags = merge(var.tags, {
      BackupType = "weekly"
      Component  = "monitoring"
    })
  }

  tags = merge(var.tags, {
    Name      = "${var.name}-monitoring-backup-plan"
    Component = "monitoring-backup"
  })
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  count = var.enable_backup_policies ? 1 : 0

  name = "${var.name}-monitoring-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.name}-monitoring-backup-role"
    Component = "monitoring-backup"
  })
}

# Attach AWS managed backup policy
resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_backup_policies ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Attach AWS managed restore policy
resource "aws_iam_role_policy_attachment" "restore" {
  count = var.enable_backup_policies ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Backup selection for monitoring EBS volumes
resource "aws_backup_selection" "monitoring" {
  count = var.enable_backup_policies ? 1 : 0

  name         = "${var.name}-monitoring-backup-selection"
  plan_id      = aws_backup_plan.monitoring[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Component"
    value = "monitoring"
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = lookup(var.tags, "Project", var.name)
  }
}

#############################################
# CloudWatch Fallback for Critical Alerting
#############################################

# SNS Topic for CloudWatch fallback alerts
resource "aws_sns_topic" "cloudwatch_fallback" {
  count = var.enable_cloudwatch_fallback ? 1 : 0

  name              = "${var.name}-monitoring-fallback-alerts"
  display_name      = "Monitoring Stack Fallback Alerts"
  kms_master_key_id = var.kms_key_arn

  tags = merge(var.tags, {
    Name      = "${var.name}-monitoring-fallback-alerts"
    Component = "monitoring-fallback"
  })
}

# SNS Topic Subscription for email notifications
resource "aws_sns_topic_subscription" "cloudwatch_fallback_email" {
  count = var.enable_cloudwatch_fallback && var.fallback_alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.cloudwatch_fallback[0].arn
  protocol  = "email"
  endpoint  = var.fallback_alert_email
}

# CloudWatch Alarm for Prometheus availability
resource "aws_cloudwatch_metric_alarm" "prometheus_unavailable" {
  count = var.enable_cloudwatch_fallback && local.prometheus_enabled ? 1 : 0

  alarm_name          = "${var.name}-prometheus-unavailable"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "prometheus_up"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Prometheus server is unavailable - fallback alerting active"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.cloudwatch_fallback[0].arn]
  ok_actions    = [aws_sns_topic.cloudwatch_fallback[0].arn]

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = local.ns
    Service     = "prometheus"
  }

  tags = merge(var.tags, {
    Name      = "${var.name}-prometheus-unavailable"
    Component = "monitoring-fallback"
  })
}

# CloudWatch Alarm for Grafana availability
resource "aws_cloudwatch_metric_alarm" "grafana_unavailable" {
  count = var.enable_cloudwatch_fallback && local.grafana_enabled ? 1 : 0

  alarm_name          = "${var.name}-grafana-unavailable"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "SampleCount"
  threshold           = 1
  alarm_description   = "Grafana is unavailable - check monitoring stack health"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.cloudwatch_fallback[0].arn]
  ok_actions    = [aws_sns_topic.cloudwatch_fallback[0].arn]

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = local.ns
    Service     = "grafana"
  }

  tags = merge(var.tags, {
    Name      = "${var.name}-grafana-unavailable"
    Component = "monitoring-fallback"
  })
}

# CloudWatch Alarm for AlertManager availability
resource "aws_cloudwatch_metric_alarm" "alertmanager_unavailable" {
  count = var.enable_cloudwatch_fallback && local.alertmanager_enabled ? 1 : 0

  alarm_name          = "${var.name}-alertmanager-unavailable"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "SampleCount"
  threshold           = 1
  alarm_description   = "AlertManager is unavailable - critical alerts may not be delivered"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.cloudwatch_fallback[0].arn]
  ok_actions    = [aws_sns_topic.cloudwatch_fallback[0].arn]

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = local.ns
    Service     = "alertmanager"
  }

  tags = merge(var.tags, {
    Name      = "${var.name}-alertmanager-unavailable"
    Component = "monitoring-fallback"
  })
}

# CloudWatch Alarm for critical WordPress availability (fallback)
resource "aws_cloudwatch_metric_alarm" "wordpress_critical_fallback" {
  count = var.enable_cloudwatch_fallback && var.enable_wordpress_exporter ? 1 : 0

  alarm_name          = "${var.name}-critical-fallback"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "SampleCount"
  threshold           = 1
  alarm_description   = "WordPress pods are unavailable - CRITICAL"
  treat_missing_data  = "breaching"

  alarm_actions = [aws_sns_topic.cloudwatch_fallback[0].arn]

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = var.wordpress_namespace
    Service     = var.wordpress_service_name
  }

  tags = merge(var.tags, {
    Name      = "${var.name}-critical-fallback"
    Component = "monitoring-fallback"
    Severity  = "critical"
  })
}

# CloudWatch Alarm for database connection issues (fallback)
resource "aws_cloudwatch_metric_alarm" "database_connections_critical_fallback" {
  count = var.enable_cloudwatch_fallback && var.enable_mysql_exporter ? 1 : 0

  alarm_name          = "${var.name}-database-connections-critical-fallback"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.database_connection_threshold
  alarm_description   = "Database connections are critically high - CRITICAL"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.cloudwatch_fallback[0].arn]

  dimensions = {
    DBClusterIdentifier = var.mysql_connection_config != null ? split(".", var.mysql_connection_config.host)[0] : ""
  }

  tags = merge(var.tags, {
    Name      = "${var.name}-database-connections-critical-fallback"
    Component = "monitoring-fallback"
    Severity  = "critical"
  })
}

#############################################
# Automatic Recovery Configuration
#############################################

# Kubernetes CronJob for periodic health checks and recovery
resource "kubernetes_cron_job_v1" "monitoring_health_check" {
  count = var.enable_automatic_recovery ? 1 : 0

  metadata {
    name      = "${var.name}-monitoring-health-check"
    namespace = local.ns
  }

  spec {
    schedule                      = "*/5 * * * *" # Every 5 minutes
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = {
          app       = "monitoring-health-check"
          component = "recovery"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              app       = "monitoring-health-check"
              component = "recovery"
            }
          }

          spec {
            service_account_name = "monitoring-health-check"
            restart_policy       = "OnFailure"

            container {
              name  = "health-check"
              image = "bitnami/kubectl:latest"

              command = ["/bin/bash", "-c"]
              args = [
                <<-EOT
                  #!/bin/bash
                  set -e
                  
                  echo "Checking monitoring stack health..."
                  
                  # Check Prometheus
                  if kubectl get pods -n ${local.ns} -l app=kube-prometheus-stack-prometheus -o jsonpath='{.items[*].status.phase}' | grep -q Running; then
                    echo "Prometheus is healthy"
                  else
                    echo "Prometheus is unhealthy, attempting recovery..."
                    kubectl rollout restart statefulset -n ${local.ns} prometheus-kube-prometheus-prometheus || true
                  fi
                  
                  # Check Grafana
                  if kubectl get pods -n ${local.ns} -l app.kubernetes.io/name=grafana -o jsonpath='{.items[*].status.phase}' | grep -q Running; then
                    echo "Grafana is healthy"
                  else
                    echo "Grafana is unhealthy, attempting recovery..."
                    kubectl rollout restart deployment -n ${local.ns} grafana || true
                  fi
                  
                  # Check AlertManager
                  if kubectl get pods -n ${local.ns} -l app=alertmanager -o jsonpath='{.items[*].status.phase}' | grep -q Running; then
                    echo "AlertManager is healthy"
                  else
                    echo "AlertManager is unhealthy, attempting recovery..."
                    kubectl rollout restart statefulset -n ${local.ns} alertmanager-${var.name}-alertmanager || true
                  fi
                  
                  echo "Health check complete"
                EOT
              ]

              resources {
                requests = {
                  cpu    = "100m"
                  memory = "128Mi"
                }
                limits = {
                  cpu    = "200m"
                  memory = "256Mi"
                }
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.ns]
}

# Service Account for health check job
resource "kubernetes_service_account" "monitoring_health_check" {
  count = var.enable_automatic_recovery ? 1 : 0

  metadata {
    name      = "monitoring-health-check"
    namespace = local.ns
  }
}

# Role for health check operations
resource "kubernetes_role" "monitoring_health_check" {
  count = var.enable_automatic_recovery ? 1 : 0

  metadata {
    name      = "monitoring-health-check"
    namespace = local.ns
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets"]
    verbs      = ["get", "list", "patch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments/rollout", "statefulsets/rollout"]
    verbs      = ["create"]
  }
}

# Role binding for health check
resource "kubernetes_role_binding" "monitoring_health_check" {
  count = var.enable_automatic_recovery ? 1 : 0

  metadata {
    name      = "monitoring-health-check"
    namespace = local.ns
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.monitoring_health_check[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.monitoring_health_check[0].metadata[0].name
    namespace = local.ns
  }
}