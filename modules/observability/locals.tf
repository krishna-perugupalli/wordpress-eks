# Local values for shared naming and labels

locals {
  # Common naming prefix
  name_prefix = var.cluster_name

  # Common tags
  common_tags = merge(
    var.tags,
    {
      Module    = "observability"
      ManagedBy = "Terraform"
    }
  )

  # Namespace names (use Blueprints defaults or overrides)
  prometheus_namespace = coalesce(
    var.prometheus_namespace,
    "monitoring"
  )

  grafana_namespace = coalesce(
    var.grafana_namespace,
    "monitoring"
  )

  # Dashboard toggles
  deploy_wp_dashboards   = var.enable_grafana && var.enable_wp_dashboards
  deploy_aws_dashboards  = var.enable_grafana && var.enable_aws_dashboards
  deploy_cost_dashboards = var.enable_grafana && var.enable_cost_dashboards
}
