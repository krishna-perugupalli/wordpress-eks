# ==============================================================================
# Dashboard Provisioning via ConfigMaps
# ==============================================================================
#
# This file implements Grafana dashboard provisioning using Kubernetes ConfigMaps.
# Dashboards are organized by category and automatically loaded by Grafana sidecar:
#
# - WordPress: Application-specific metrics (WordPress exporter, Redis, MySQL)
# - Kubernetes: Cluster and pod metrics (kube-prometheus-stack)
# - AWS: Managed service metrics (YACE CloudWatch exporter)
# - Cost: Cost allocation and budget tracking (YACE billing metrics)
#
# The Grafana sidecar watches for ConfigMaps with label "grafana_dashboard: 1"
# and automatically provisions them as dashboards in appropriate folders.
#
# ==============================================================================

# ------------------------------------------------------------------------------
# WordPress Dashboard ConfigMap
# ------------------------------------------------------------------------------
# Deploys WordPress application overview dashboard
# Conditional: requires var.enable_prometheus = true
# Validates: Requirements 5.2, 8.1

resource "kubernetes_config_map" "wordpress_dashboard" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name      = "wordpress-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "WordPress"
    }
  }

  data = {
    "wordpress-overview.json" = file("${path.module}/dashboards/wordpress/wordpress-overview.json")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# Kubernetes Dashboard ConfigMap
# ------------------------------------------------------------------------------
# Deploys Kubernetes cluster overview dashboard
# Conditional: requires var.enable_prometheus = true
# Validates: Requirements 5.2, 8.2

resource "kubernetes_config_map" "kubernetes_dashboard" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name      = "kubernetes-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Kubernetes"
    }
  }

  data = {
    "kubernetes-cluster.json" = file("${path.module}/dashboards/kubernetes/kubernetes-cluster.json")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# AWS Services Dashboard ConfigMap
# ------------------------------------------------------------------------------
# Deploys AWS services monitoring dashboard
# Conditional: requires var.enable_prometheus = true AND var.enable_yace = true
# Validates: Requirements 5.2, 8.3

resource "kubernetes_config_map" "aws_services_dashboard" {
  count = var.enable_prometheus && var.enable_yace ? 1 : 0

  metadata {
    name      = "aws-services-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "AWS Services"
    }
  }

  data = {
    "aws-services.json" = file("${path.module}/dashboards/aws/aws-services.json")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# Cost Tracking Dashboard ConfigMap
# ------------------------------------------------------------------------------
# Deploys cost tracking and optimization dashboard
# Conditional: requires var.enable_prometheus = true AND var.enable_yace = true
# Validates: Requirements 5.2, 8.4

resource "kubernetes_config_map" "cost_dashboard" {
  count = var.enable_prometheus && var.enable_yace ? 1 : 0

  metadata {
    name      = "cost-dashboard"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Cost Tracking"
    }
  }

  data = {
    "cost-tracking.json" = file("${path.module}/dashboards/cost/cost-tracking.json")
  }

  depends_on = [module.eks_blueprints_addons]
}