#############################################
# Storage Class for Observability Components
# Creates gp3 StorageClass for Prometheus, Grafana, and AlertManager
#############################################

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/component"  = "storage"
      "app.kubernetes.io/part-of"    = "observability"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type       = "gp3"
    encrypted  = "true"
    fsType     = "ext4"
    iops       = "3000"
    throughput = "125"
  }

  depends_on = [kubernetes_namespace.ns]
}
