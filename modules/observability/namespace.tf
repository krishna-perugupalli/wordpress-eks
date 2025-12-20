
#############################################
# Namespace Management
#############################################
# Create the monitoring namespace explicitly to ensure it exists
# before ExternalSecrets and Helm charts attempt to use it.
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = local.monitoring_namespace
    labels = local.common_tags
  }
}
