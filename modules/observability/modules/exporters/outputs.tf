# Service Discovery and Metrics Collection Outputs
output "service_monitors" {
  description = "Created ServiceMonitor resources"
  value = {
    wordpress_servicemonitor       = var.enable_wordpress_exporter ? kubectl_manifest.wordpress_servicemonitor[0].name : null
    mysql_servicemonitor           = var.enable_mysql_exporter ? kubectl_manifest.mysql_servicemonitor[0].name : null
    redis_servicemonitor           = var.enable_redis_exporter ? kubectl_manifest.redis_servicemonitor[0].name : null
    cloudwatch_servicemonitor      = var.enable_cloudwatch_exporter ? kubectl_manifest.cloudwatch_servicemonitor[0].name : null
    cost_monitoring_servicemonitor = var.enable_cost_monitoring ? kubectl_manifest.cost_monitoring_servicemonitor[0].name : null
    service_discovery              = kubectl_manifest.service_discovery_servicemonitor.name
  }
}

output "pod_monitors" {
  description = "Created PodMonitor resources"
  value = {
    kubelet_podmonitor                      = kubectl_manifest.kubelet_podmonitor.name
    coredns_podmonitor                      = kubectl_manifest.coredns_podmonitor.name
    aws_load_balancer_controller_podmonitor = kubectl_manifest.aws_load_balancer_controller_podmonitor.name
    karpenter_podmonitor                    = kubectl_manifest.karpenter_podmonitor.name
    external_secrets_podmonitor             = kubectl_manifest.external_secrets_podmonitor.name
    pod_discovery                           = kubectl_manifest.pod_discovery_podmonitor.name
  }
}

output "additional_scrape_configs" {
  description = "Additional scrape configurations ConfigMap"
  value = {
    name      = kubernetes_config_map.additional_scrape_configs.metadata[0].name
    namespace = kubernetes_config_map.additional_scrape_configs.metadata[0].namespace
  }
}

output "mysql_exporter" {
  description = "MySQL exporter deployment information"
  value = var.enable_mysql_exporter ? {
    deployment_name = kubernetes_deployment.mysql_exporter[0].metadata[0].name
    service_name    = kubernetes_service.mysql_exporter[0].metadata[0].name
    namespace       = var.namespace
    metrics_port    = 9104
    metrics_path    = "/metrics"
    monitoring_user = "monitoring"
  } : null
}

output "redis_exporter" {
  description = "Redis exporter deployment information"
  value = var.enable_redis_exporter ? {
    deployment_name = kubernetes_deployment.redis_exporter[0].metadata[0].name
    service_name    = kubernetes_service.redis_exporter[0].metadata[0].name
    namespace       = var.namespace
    metrics_port    = 9121
    metrics_path    = "/metrics"
  } : null
}

output "monitoring_credentials" {
  description = "Monitoring credentials information"
  value = {
    mysql_secret_name = var.enable_mysql_exporter ? (
      var.mysql_connection_config != null ?
      kubernetes_secret.mysql_monitoring_user_updated[0].metadata[0].name :
      kubernetes_secret.mysql_monitoring_user[0].metadata[0].name
    ) : null
    redis_secret_name = var.enable_redis_exporter ? (
      var.redis_connection_config != null ?
      kubernetes_secret.redis_monitoring_credentials_updated[0].metadata[0].name :
      kubernetes_secret.redis_monitoring_credentials[0].metadata[0].name
    ) : null
  }
  sensitive = true
}

output "cloudwatch_exporter" {
  description = "CloudWatch exporter deployment information"
  value = var.enable_cloudwatch_exporter ? {
    deployment_name          = kubernetes_deployment.cloudwatch_exporter[0].metadata[0].name
    service_name             = kubernetes_service.cloudwatch_exporter[0].metadata[0].name
    namespace                = var.namespace
    metrics_port             = 9106
    metrics_path             = "/metrics"
    iam_role_arn             = aws_iam_role.cloudwatch_exporter[0].arn
    cloudfront_monitoring    = var.enable_cloudfront_monitoring
    cloudfront_distributions = var.cloudfront_distribution_ids
  } : null
}

output "cost_monitoring" {
  description = "Cost monitoring deployment information"
  value = var.enable_cost_monitoring ? {
    deployment_name = kubernetes_deployment.cost_monitoring[0].metadata[0].name
    service_name    = kubernetes_service.cost_monitoring[0].metadata[0].name
    namespace       = var.namespace
    metrics_port    = 9090
    metrics_path    = "/metrics"
    iam_role_arn    = aws_iam_role.cost_monitoring[0].arn
  } : null
}