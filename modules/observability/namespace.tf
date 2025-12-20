
#############################################
# Namespace Management
#############################################
# Create the monitoring namespace explicitly to ensure it exists
# before ExternalSecrets and Helm charts attempt to use it.
resource "kubectl_manifest" "monitoring_namespace" {
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = local.monitoring_namespace
      labels = {
        for k, v in local.common_tags : k => replace(v, "/[^A-Za-z0-9_.-]/", "_")
      }
    }
  })
}
