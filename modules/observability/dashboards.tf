# ==============================================================================
# Grafana Dashboards
# ==============================================================================
# This file manages the creation of ConfigMaps containing Grafana dashboards.
# The Grafana sidecar (configured in addons.tf) watches for these ConfigMaps
# and automatically provisions them in Grafana.

# ------------------------------------------------------------------------------
# WordPress Dashboards
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "wordpress_dashboards" {
  for_each = var.enable_wp_dashboards ? fileset("${path.module}/dashboards/wordpress", "*.json") : []

  metadata {
    name      = "grafana-dashboard-wp-${trimsuffix(each.value, ".json")}"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "WordPress"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/wordpress/${each.value}")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# AWS Service Dashboards
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "aws_dashboards" {
  for_each = var.enable_aws_dashboards ? fileset("${path.module}/dashboards/aws", "*.json") : []

  metadata {
    name      = "grafana-dashboard-aws-${trimsuffix(each.value, ".json")}"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "AWS"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/aws/${each.value}")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# Cost Dashboards
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "cost_dashboards" {
  for_each = var.enable_cost_dashboards ? fileset("${path.module}/dashboards/cost", "*.json") : []

  metadata {
    name      = "grafana-dashboard-cost-${trimsuffix(each.value, ".json")}"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Cost"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/cost/${each.value}")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# Kubernetes Cluster Dashboards
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "kubernetes_dashboards" {
  for_each = var.enable_prometheus ? fileset("${path.module}/dashboards/kubernetes", "*.json") : []

  metadata {
    name      = "grafana-dashboard-k8s-${trimsuffix(each.value, ".json")}"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Kubernetes"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/kubernetes/${each.value}")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# Loki Dashboards
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "loki_dashboards" {
  for_each = var.enable_loki ? fileset("${path.module}/dashboards/loki", "*.json") : []

  metadata {
    name      = "grafana-dashboard-loki-${trimsuffix(each.value, ".json")}"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Loki"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/loki/${each.value}")
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# Tempo Dashboards
# ------------------------------------------------------------------------------
resource "kubernetes_config_map" "tempo_dashboards" {
  for_each = var.enable_tempo ? fileset("${path.module}/dashboards/tempo", "*.json") : []

  metadata {
    name      = "grafana-dashboard-tempo-${trimsuffix(each.value, ".json")}"
    namespace = local.monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Tempo"
    }
  }

  data = {
    "${each.value}" = file("${path.module}/dashboards/tempo/${each.value}")
  }

  depends_on = [module.eks_blueprints_addons]
}