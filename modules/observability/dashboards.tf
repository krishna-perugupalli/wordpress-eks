# ==============================================================================
# Dashboard Provisioning Strategy
# ==============================================================================
#
# This file contains placeholder ConfigMap resources for Grafana dashboard
# provisioning. Dashboards are organized by category:
#
# - WordPress: Application-specific metrics (PHP-FPM, WordPress performance)
# - Kubernetes: Cluster and pod metrics (resource usage, health)
# - AWS: Managed service metrics (RDS, ElastiCache, EFS, ALB)
# - Cost: Cost allocation and budget tracking
#
# IMPLEMENTATION PLAN (Phase 3):
# 1. Create dashboard JSON files in respective dashboards/* directories
# 2. Use fileset() to dynamically load all JSON files from each category
# 3. Configure Grafana Helm chart to enable sidecar for automatic dashboard loading
# 4. Label ConfigMaps with "grafana_dashboard" for sidecar discovery
#
# GRAFANA SIDECAR CONFIGURATION:
# The Grafana Helm chart includes a sidecar container that watches for ConfigMaps
# with specific labels and automatically loads them as dashboards. Configuration
# will be added to addons.tf in Phase 2:
#
#   grafana:
#     sidecar:
#       dashboards:
#         enabled: true
#         label: grafana_dashboard
#         labelValue: "1"
#         folder: /tmp/dashboards
#         searchNamespace: ALL
#
# ==============================================================================

# ------------------------------------------------------------------------------
# WordPress Dashboards
# ------------------------------------------------------------------------------
# TODO: Implement in Phase 3
# 
# Purpose: WordPress-specific performance and health dashboards
# Expected dashboards:
# - WordPress overview (requests, response times, cache hit rates)
# - PHP-FPM metrics (pool status, slow requests, memory usage)
# - WordPress database queries (slow queries, connection pool)
# - Content delivery metrics (media uploads, page generation time)
#
# Implementation:
# 1. Create JSON dashboard files in dashboards/wordpress/
# 2. Uncomment the resource block below
# 3. Use fileset() to load all .json files from the directory
#
# resource "kubernetes_config_map" "wordpress_dashboards" {
#   count = local.deploy_wp_dashboards ? 1 : 0
#
#   metadata {
#     name      = "${local.name_prefix}-wordpress-dashboards"
#     namespace = local.grafana_namespace
#     labels = {
#       grafana_dashboard = "1"
#       dashboard_category = "wordpress"
#     }
#   }
#
#   # Future implementation:
#   # data = {
#   #   for filename in fileset("${path.module}/dashboards/wordpress", "*.json") :
#   #   filename => file("${path.module}/dashboards/wordpress/${filename}")
#   # }
# }

# ------------------------------------------------------------------------------
# Kubernetes Dashboards
# ------------------------------------------------------------------------------
# TODO: Implement in Phase 3
#
# Purpose: Kubernetes cluster and workload monitoring dashboards
# Expected dashboards:
# - Cluster overview (node status, resource utilization, pod distribution)
# - Namespace resource usage (CPU, memory, network by namespace)
# - Pod metrics (container restarts, OOMKills, resource requests vs limits)
# - Persistent volume usage (EFS and EBS metrics)
# - Karpenter autoscaling metrics (node provisioning, consolidation)
#
# Implementation:
# 1. Create JSON dashboard files in dashboards/kubernetes/
# 2. Uncomment the resource block below
# 3. Use fileset() to load all .json files from the directory
#
# resource "kubernetes_config_map" "kubernetes_dashboards" {
#   count = local.deploy_aws_dashboards ? 1 : 0
#
#   metadata {
#     name      = "${local.name_prefix}-kubernetes-dashboards"
#     namespace = local.grafana_namespace
#     labels = {
#       grafana_dashboard = "1"
#       dashboard_category = "kubernetes"
#     }
#   }
#
#   # Future implementation:
#   # data = {
#   #   for filename in fileset("${path.module}/dashboards/kubernetes", "*.json") :
#   #   filename => file("${path.module}/dashboards/kubernetes/${filename}")
#   # }
# }

# ------------------------------------------------------------------------------
# AWS Service Dashboards
# ------------------------------------------------------------------------------
# TODO: Implement in Phase 3
#
# Purpose: AWS managed service monitoring dashboards
# Expected dashboards:
# - Aurora MySQL metrics (connections, queries, replication lag, serverless scaling)
# - ElastiCache Redis metrics (cache hit rate, evictions, memory usage, replication)
# - EFS metrics (throughput, IOPS, client connections, burst credits)
# - ALB metrics (request count, target health, response times, error rates)
# - CloudWatch cost metrics (estimated charges by service)
#
# Data Source: YACE (Yet Another CloudWatch Exporter) will be configured in Phase 2
# to scrape CloudWatch metrics and expose them to Prometheus
#
# Implementation:
# 1. Create JSON dashboard files in dashboards/aws/
# 2. Uncomment the resource block below
# 3. Use fileset() to load all .json files from the directory
#
# resource "kubernetes_config_map" "aws_dashboards" {
#   count = local.deploy_aws_dashboards ? 1 : 0
#
#   metadata {
#     name      = "${local.name_prefix}-aws-dashboards"
#     namespace = local.grafana_namespace
#     labels = {
#       grafana_dashboard = "1"
#       dashboard_category = "aws"
#     }
#   }
#
#   # Future implementation:
#   # data = {
#   #   for filename in fileset("${path.module}/dashboards/aws", "*.json") :
#   #   filename => file("${path.module}/dashboards/aws/${filename}")
#   # }
# }

# ------------------------------------------------------------------------------
# Cost Dashboards
# ------------------------------------------------------------------------------
# TODO: Implement in Phase 3
#
# Purpose: Cost allocation and budget tracking dashboards
# Expected dashboards:
# - Cost by service (breakdown of AWS service costs)
# - Cost by tag (Project, Environment, Owner allocation)
# - Budget tracking (actual vs budgeted spend, forecast)
# - Resource efficiency (underutilized resources, savings opportunities)
# - Spot vs On-Demand cost comparison (Karpenter node costs)
#
# Data Source: YACE will be configured to scrape AWS Cost Explorer and Budgets APIs
#
# Implementation:
# 1. Create JSON dashboard files in dashboards/cost/
# 2. Uncomment the resource block below
# 3. Use fileset() to load all .json files from the directory
#
# resource "kubernetes_config_map" "cost_dashboards" {
#   count = local.deploy_cost_dashboards ? 1 : 0
#
#   metadata {
#     name      = "${local.name_prefix}-cost-dashboards"
#     namespace = local.grafana_namespace
#     labels = {
#       grafana_dashboard = "1"
#       dashboard_category = "cost"
#     }
#   }
#
#   # Future implementation:
#   # data = {
#   #   for filename in fileset("${path.module}/dashboards/cost", "*.json") :
#   #   filename => file("${path.module}/dashboards/cost/${filename}")
#   # }
# }

# ==============================================================================
# Notes for Phase 3 Implementation
# ==============================================================================
#
# When implementing dashboard provisioning:
#
# 1. Dashboard JSON Format:
#    - Export dashboards from Grafana UI or use grafana-dashboard-builder
#    - Ensure datasource references use variables: ${DS_PROMETHEUS}
#    - Remove dashboard ID and UID to allow Grafana to generate them
#    - Set "editable": false for production dashboards
#
# 2. Grafana Sidecar Configuration (in addons.tf):
#    - Enable sidecar.dashboards.enabled = true
#    - Set appropriate searchNamespace (ALL or specific namespace)
#    - Configure folder structure for dashboard organization
#
# 3. Dashboard Dependencies:
#    - WordPress dashboards require PHP-FPM, MySQL, Redis exporters
#    - AWS dashboards require YACE exporter with CloudWatch integration
#    - Cost dashboards require YACE with Cost Explorer API access
#
# 4. Testing:
#    - Verify ConfigMaps are created with correct labels
#    - Check Grafana sidecar logs for dashboard loading
#    - Confirm dashboards appear in Grafana UI under correct folders
#    - Validate dashboard queries return data from Prometheus
#
# ==============================================================================
