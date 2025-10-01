#############################################
# Namespace (idempotent)
#############################################
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

#############################################
# ESO ExternalSecret: build 'wp-env' with DB creds
# - PASSWORD pulled from SM via ClusterSecretStore 'aws-sm'
# - Non-secret connection metadata templated from variables
#############################################
locals {
  wp_env_template_data = {
    WORDPRESS_DB_HOST = var.db_host
    WORDPRESS_DB_NAME = var.db_name
    WORDPRESS_DB_USER = var.db_user
    WORDPRESS_DB_PORT = "3306"
  }

  wp_env_data = [
    {
      secretKey = "WORDPRESS_DB_PASSWORD"
      remoteRef = { key = var.db_secret_arn, property = "password" }
    }
  ]
}

resource "kubectl_manifest" "wp_env_es" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "wp-env"
      namespace = var.namespace
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "aws-sm", kind = "ClusterSecretStore" }
      target          = { name = "wp-env", creationPolicy = "Owner" }
      data            = local.wp_env_data
      template        = { type = "Opaque", data = local.wp_env_template_data }
    }
  })

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Optional: ESO ExternalSecret 'wp-admin' for admin bootstrap
# - Only the password is required by the Bitnami chart when using 'existingSecret'
# - Username/email are provided via Helm values (below)
#############################################
resource "kubectl_manifest" "wp_admin_es" {
  count = var.admin_bootstrap_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "wp-admin"
      namespace = var.namespace
    }
    spec = {
      refreshInterval = "24h"
      secretStoreRef  = { name = "aws-sm", kind = "ClusterSecretStore" }
      target          = { name = "wp-admin", creationPolicy = "Owner" }
      data = [
        { secretKey = "wordpress-password", remoteRef = { key = var.admin_secret_arn, property = "password" } }
      ]
    }
  })

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Ingress annotations (ALB / TLS / WAFv2 / tags)
#############################################
locals {
  alb_tags_csv = length(var.alb_tags) > 0 ? join(",", [for k, v in var.alb_tags : "${k}=${v}"]) : ""

  ingress_annotations = merge(
    {
      "kubernetes.io/ingress.class"                = "alb"
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
    },
    var.alb_certificate_arn != "" ? {
      "alb.ingress.kubernetes.io/certificate-arn" = var.alb_certificate_arn
    } : {},
    var.waf_acl_arn != "" ? {
      # ALB + WAFv2 association
      "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.waf_acl_arn
    } : {},
    local.alb_tags_csv != "" ? {
      "alb.ingress.kubernetes.io/tags" = local.alb_tags_csv
    } : {}
  )
}

#############################################
# Helm: Bitnami/wordpress (external DB, ESO env, EFS PVC, ALB ingress, HPA)
#############################################
resource "helm_release" "wordpress" {
  name       = "${var.name}-wordpress"
  namespace  = var.namespace
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "wordpress"
  # If you want to pin: add -> version = "x.y.z"

  # Use external DB (disable bundled MariaDB)
  set {
    name  = "mariadb.enabled"
    value = "false"
  }

  # Image tag
  set {
    name  = "image.tag"
    value = var.image_tag
  }

  # Inject envs from ESO-built secret
  set {
    name  = "extraEnvVarsSecret"
    value = "wp-env"
  }

  # Admin bootstrap via chart (safe one-time init)
  set {
    name  = "wordpressUsername"
    value = var.admin_user
  }
  set {
    name  = "wordpressEmail"
    value = var.admin_email
  }
  dynamic "set" {
    for_each = var.admin_bootstrap_enabled ? [1] : []
    content {
      name  = "existingSecret"
      value = "wp-admin"
    }
  }

  # Persistence (PVC / EFS-backed StorageClass)
  set {
    name  = "persistence.enabled"
    value = "true"
  }
  set {
    name  = "persistence.size"
    value = var.pvc_size
  }
  dynamic "set" {
    for_each = var.storage_class_name == null ? [] : [var.storage_class_name]
    content {
      name  = "persistence.storageClass"
      value = set.value
    }
  }

  # Ingress (ALB via AWS LBC)
  set {
    name  = "ingress.enabled"
    value = "true"
  }
  set {
    name  = "ingress.hostname"
    value = var.domain_name
  }
  dynamic "set" {
    for_each = local.ingress_annotations
    content {
      name  = "ingress.annotations.${set.key}"
      value = set.value
    }
  }

  # HPA
  set {
    name  = "replicaCount"
    value = tostring(var.replicas_min)
  }
  set {
    name  = "autoscaling.enabled"
    value = "true"
  }
  set {
    name  = "autoscaling.minReplicas"
    value = tostring(var.replicas_min)
  }
  set {
    name  = "autoscaling.maxReplicas"
    value = tostring(var.replicas_max)
  }
  set {
    name  = "autoscaling.targetCPU"
    value = tostring(var.target_cpu_percent)
  }
  set {
    name  = "autoscaling.targetMemory"
    value = var.target_memory_value
  }

  depends_on = [
    kubernetes_namespace.ns,
    kubectl_manifest.wp_env_es,
    kubectl_manifest.wp_admin_es
  ]
}
