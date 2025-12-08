#############################################
# EKS Blueprints Addons Integration
#############################################
# This module uses the official AWS EKS Blueprints Addons module
# to deploy core observability components: Prometheus, Grafana,
# Alertmanager, and Fluent Bit.
#
# The module handles:
# - Helm chart deployments
# - IRSA role creation and management
# - Namespace management
# - Service account configuration

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  # Cluster configuration
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Component toggles
  enable_kube_prometheus_stack = var.enable_prometheus
  enable_aws_for_fluentbit     = var.enable_fluentbit

  # Note: Grafana and Alertmanager are typically included as part of
  # kube-prometheus-stack. Separate enable flags may not be available
  # in the Blueprints Addons module. These will be configured via
  # Helm values in addons.tf (Phase 2).

  # Placeholder for YACE - to be implemented in Phase 2
  # enable_yace_exporter = var.enable_yace

  # Common tags for AWS resources
  tags = local.common_tags
}
