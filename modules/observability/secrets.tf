resource "kubectl_manifest" "grafana_secret" {
  count = var.enable_grafana && var.grafana_secret_arn != null && var.grafana_secret_arn != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "grafana-admin"
      namespace = local.monitoring_namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-sm"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "grafana-admin-credentials" # Provide explicit name
        template = {
          engineVersion = "v2"
          data = {
            "admin-user"     = "{{ .username }}"
            "admin-password" = "{{ .password }}"
          }
        }
      }
      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = var.grafana_secret_arn
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = var.grafana_secret_arn
            property = "password"
          }
        }
      ]
    }
  })

  depends_on = [
    kubectl_manifest.monitoring_namespace
  ]
}

# Wait for ESO to reconcile and create the actual Secret
resource "time_sleep" "wait_for_grafana_secret" {
  count = var.enable_grafana && var.grafana_secret_arn != null && var.grafana_secret_arn != "" ? 1 : 0

  create_duration = "30s"

  depends_on = [kubectl_manifest.grafana_secret]
}
