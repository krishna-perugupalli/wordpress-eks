#############################################
# Comprehensive Alert Rules Configuration
# Deploys PrometheusRule CRDs for monitoring alerts
#############################################

# Load alert rules from YAML file
locals {
  alert_rules_yaml = file("${path.module}/files/alert-rules.yaml")
}

# Deploy PrometheusRule CRD with all alert rules
resource "kubectl_manifest" "prometheus_alert_rules" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "${var.name}-comprehensive-alerts"
      namespace = var.namespace
      labels = {
        app        = "kube-prometheus-stack"
        release    = "prometheus"
        prometheus = "kube-prometheus"
      }
    }
    spec = yamldecode(local.alert_rules_yaml)
  })

  depends_on = [helm_release.kube_prometheus_stack]
}
