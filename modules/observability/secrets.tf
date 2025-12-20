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
            key      = element(split(":", var.grafana_secret_arn), length(split(":", var.grafana_secret_arn)) - 1)
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = element(split(":", var.grafana_secret_arn), length(split(":", var.grafana_secret_arn)) - 1)
            property = "password"
          }
        }
      ]
    }
  })

  depends_on = [module.eks_blueprints_addons]
}
