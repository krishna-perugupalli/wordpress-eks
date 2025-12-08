# ==============================================================================
# Addon-Specific Helm Values and Configurations
# ==============================================================================
# This file contains addon-specific Helm values and custom configurations for
# observability components deployed via EKS Blueprints Addons.
#
# Phase 1: Placeholder structures for future implementation
# Phase 2: Full Helm values, IRSA roles, and YACE exporter deployment
# Phase 3: ServiceMonitor and PrometheusRule definitions
# ==============================================================================

# ------------------------------------------------------------------------------
# Prometheus (kube-prometheus-stack) Custom Values
# ------------------------------------------------------------------------------
# TODO: Phase 2 - Implement custom Helm values for kube-prometheus-stack
#
# Planned configurations:
# - Resource requests/limits for Prometheus server
# - Retention period and storage configuration
# - ServiceMonitor definitions for WordPress components:
#   * WordPress pods (PHP-FPM metrics)
#   * MySQL exporter
#   * Redis exporter
# - PrometheusRule definitions for alerting:
#   * High pod CPU/memory usage
#   * Database connection pool exhaustion
#   * Redis cache hit rate degradation
#   * WordPress response time SLOs
# - Persistent volume claims for metrics storage
# - Node affinity and tolerations for scheduling
#
# Example structure (to be implemented):
# locals {
#   prometheus_values = {
#     prometheus = {
#       prometheusSpec = {
#         retention = "15d"
#         resources = {
#           requests = { memory = "2Gi", cpu = "1000m" }
#           limits   = { memory = "4Gi", cpu = "2000m" }
#         }
#         storageSpec = {
#           volumeClaimTemplate = {
#             spec = {
#               accessModes = ["ReadWriteOnce"]
#               resources   = { requests = { storage = "50Gi" } }
#             }
#           }
#         }
#       }
#     }
#   }
# }

# ------------------------------------------------------------------------------
# Grafana Custom Values
# ------------------------------------------------------------------------------
# TODO: Phase 2 - Implement custom Helm values for Grafana
#
# Planned configurations:
# - Admin credentials management (via Kubernetes secrets)
# - Dashboard sidecar configuration for automatic loading
# - Data source definitions:
#   * Prometheus (primary metrics source)
#   * CloudWatch (via YACE exporter)
# - Ingress configuration for external access
# - Resource requests/limits
# - Persistence for Grafana database
#
# TODO: Phase 3 - Dashboard provisioning
# - Configure sidecar to watch ConfigMaps with label "grafana_dashboard=1"
# - Load dashboards from dashboards/ directory structure
# - Enable dashboard versioning and change tracking
#
# Example structure (to be implemented):
# locals {
#   grafana_values = {
#     adminUser     = "admin"
#     adminPassword = "changeme"  # Should be managed via External Secrets
#     sidecar = {
#       dashboards = {
#         enabled = true
#         label   = "grafana_dashboard"
#       }
#     }
#     datasources = {
#       "datasources.yaml" = {
#         apiVersion = 1
#         datasources = [
#           {
#             name   = "Prometheus"
#             type   = "prometheus"
#             url    = "http://prometheus-server:9090"
#             access = "proxy"
#           }
#         ]
#       }
#     }
#   }
# }

# ------------------------------------------------------------------------------
# Alertmanager Custom Values
# ------------------------------------------------------------------------------
# TODO: Phase 2 - Implement custom Helm values for Alertmanager
#
# Planned configurations:
# - Alert routing rules by severity and component
# - SNS integration for critical alerts
# - Grouping and throttling policies
# - Silence management
# - Resource requests/limits
#
# TODO: Phase 4 - Advanced alerting integrations
# - PagerDuty integration for on-call rotations
# - Slack webhook notifications
# - Email notifications via SES
# - Runbook URL annotations in alerts
#
# Example structure (to be implemented):
# locals {
#   alertmanager_values = {
#     config = {
#       route = {
#         group_by        = ["alertname", "cluster", "service"]
#         group_wait      = "10s"
#         group_interval  = "10s"
#         repeat_interval = "12h"
#         receiver        = "default"
#       }
#       receivers = [
#         {
#           name = "default"
#           # SNS configuration to be added
#         }
#       ]
#     }
#   }
# }

# ------------------------------------------------------------------------------
# Fluent Bit Custom Values
# ------------------------------------------------------------------------------
# TODO: Phase 2 - Implement custom Helm values for Fluent Bit
#
# Planned configurations:
# - CloudWatch Logs integration with log group per namespace
# - Log parsing rules for WordPress, MySQL, Redis
# - Resource requests/limits for DaemonSet pods
# - Buffer configuration for burst handling
# - KMS encryption for CloudWatch Logs
# - Log retention policies
#
# Example structure (to be implemented):
# locals {
#   fluentbit_values = {
#     cloudWatch = {
#       enabled       = true
#       region        = data.aws_region.current.name
#       logGroupName  = "/aws/eks/${var.cluster_name}/application"
#       logRetention  = 7
#     }
#     resources = {
#       requests = { memory = "100Mi", cpu = "100m" }
#       limits   = { memory = "200Mi", cpu = "200m" }
#     }
#   }
# }

# ------------------------------------------------------------------------------
# YACE (Yet Another CloudWatch Exporter) Configuration
# ------------------------------------------------------------------------------
# TODO: Phase 2 - Implement YACE exporter deployment
#
# YACE exports CloudWatch metrics to Prometheus for unified observability.
# This enables Grafana dashboards to display AWS service metrics alongside
# application metrics without switching data sources.
#
# Planned configurations:
# - IRSA role with CloudWatch read permissions
# - Helm chart deployment with values from exporters/yace-values.yaml
# - ServiceMonitor for Prometheus scraping
# - Metrics discovery for:
#   * RDS (Aurora MySQL): connections, CPU, storage, replication lag
#   * ElastiCache (Redis): cache hits/misses, CPU, memory, connections
#   * EFS: throughput, IOPS, client connections
#   * ALB: request count, target response time, HTTP errors
#   * EKS: node count, pod count
#   * NAT Gateway: bytes in/out, connection count
#
# Example structure (to be implemented):
# resource "helm_release" "yace" {
#   count = var.enable_yace ? 1 : 0
#
#   name       = "yace-exporter"
#   repository = "https://nerdswords.github.io/helm-charts"
#   chart      = "yet-another-cloudwatch-exporter"
#   namespace  = local.prometheus_namespace
#   version    = "0.37.0"
#
#   values = [
#     file("${path.module}/exporters/yace-values.yaml")
#   ]
#
#   depends_on = [module.eks_blueprints_addons]
# }
#
# resource "kubernetes_service_monitor" "yace" {
#   count = var.enable_yace ? 1 : 0
#
#   metadata {
#     name      = "yace-exporter"
#     namespace = local.prometheus_namespace
#   }
#
#   spec {
#     selector {
#       match_labels = {
#         app = "yace-exporter"
#       }
#     }
#     endpoints {
#       port     = "metrics"
#       interval = "60s"
#     }
#   }
# }

# ------------------------------------------------------------------------------
# ServiceMonitor Definitions
# ------------------------------------------------------------------------------
# TODO: Phase 2 - Implement ServiceMonitor resources for application exporters
#
# ServiceMonitors tell Prometheus which services to scrape for metrics.
# These will be created for:
# - WordPress PHP-FPM exporter (custom metrics from wordpress-metrics-plugin.php)
# - MySQL exporter (database performance metrics)
# - Redis exporter (cache performance metrics)
# - YACE exporter (CloudWatch metrics)
#
# Example structure (to be implemented):
# resource "kubernetes_manifest" "wordpress_service_monitor" {
#   count = var.enable_prometheus ? 1 : 0
#
#   manifest = {
#     apiVersion = "monitoring.coreos.com/v1"
#     kind       = "ServiceMonitor"
#     metadata = {
#       name      = "wordpress-metrics"
#       namespace = local.prometheus_namespace
#     }
#     spec = {
#       selector = {
#         matchLabels = {
#           app = "wordpress"
#         }
#       }
#       endpoints = [
#         {
#           port     = "metrics"
#           interval = "30s"
#           path     = "/metrics"
#         }
#       ]
#     }
#   }
# }

# ------------------------------------------------------------------------------
# PrometheusRule Definitions
# ------------------------------------------------------------------------------
# TODO: Phase 4 - Implement PrometheusRule resources for alerting
#
# PrometheusRules define alerting rules that trigger when conditions are met.
# These will include:
# - High pod CPU/memory usage (>80% for 5 minutes)
# - Database connection pool exhaustion (>90% connections used)
# - Redis cache hit rate degradation (<80% hit rate)
# - WordPress response time SLO violations (p95 > 2s)
# - Disk space warnings (>85% used)
# - Certificate expiration warnings (<30 days)
#
# Example structure (to be implemented):
# resource "kubernetes_manifest" "wordpress_alerts" {
#   count = var.enable_prometheus && var.enable_alertmanager ? 1 : 0
#
#   manifest = {
#     apiVersion = "monitoring.coreos.com/v1"
#     kind       = "PrometheusRule"
#     metadata = {
#       name      = "wordpress-alerts"
#       namespace = local.prometheus_namespace
#     }
#     spec = {
#       groups = [
#         {
#           name = "wordpress"
#           rules = [
#             {
#               alert = "WordPressHighResponseTime"
#               expr  = "histogram_quantile(0.95, rate(wordpress_request_duration_seconds_bucket[5m])) > 2"
#               for   = "5m"
#               labels = {
#                 severity = "warning"
#               }
#               annotations = {
#                 summary     = "WordPress response time is high"
#                 description = "95th percentile response time is {{ $value }}s"
#                 runbook_url = "https://runbooks.example.com/wordpress-slow-response"
#               }
#             }
#           ]
#         }
#       ]
#     }
#   }
# }
