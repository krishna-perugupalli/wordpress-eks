#############################################
# cert-manager Module
# Installs cert-manager for automated TLS certificate management
# Supports Let's Encrypt and other ACME providers
#############################################

locals {
  cert_manager_name      = "${var.name}-cert-manager"
  cert_manager_namespace = var.namespace
  cert_manager_version   = var.cert_manager_version
}

#############################################
# cert-manager Helm Release
#############################################

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = local.cert_manager_version
  namespace  = local.cert_manager_namespace

  create_namespace = true

  # Install CRDs as part of the Helm release
  set {
    name  = "installCRDs"
    value = "true"
  }

  # Enable Prometheus metrics
  set {
    name  = "prometheus.enabled"
    value = var.enable_prometheus_metrics
  }

  # Resource requests and limits
  set {
    name  = "resources.requests.cpu"
    value = var.resource_requests.cpu
  }

  set {
    name  = "resources.requests.memory"
    value = var.resource_requests.memory
  }

  set {
    name  = "resources.limits.cpu"
    value = var.resource_limits.cpu
  }

  set {
    name  = "resources.limits.memory"
    value = var.resource_limits.memory
  }

  # Webhook resource configuration
  set {
    name  = "webhook.resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "webhook.resources.requests.memory"
    value = "32Mi"
  }

  # CA injector resource configuration
  set {
    name  = "cainjector.resources.requests.cpu"
    value = "10m"
  }

  set {
    name  = "cainjector.resources.requests.memory"
    value = "32Mi"
  }

  # Security context
  set {
    name  = "securityContext.fsGroup"
    value = "1001"
  }

  # Enable leader election for HA
  set {
    name  = "global.leaderElection.namespace"
    value = local.cert_manager_namespace
  }

  # Startup API check configuration - increase timeout
  set {
    name  = "startupapicheck.timeout"
    value = "5m"
  }

  set {
    name  = "startupapicheck.backoffLimit"
    value = "10"
  }

  # Webhook configuration - ensure it's ready before checks
  set {
    name  = "webhook.timeoutSeconds"
    value = "30"
  }

  values = var.additional_helm_values != null ? [var.additional_helm_values] : []

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_namespace.cert_manager
  ]
}

#############################################
# Namespace
#############################################

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = local.cert_manager_namespace
    labels = {
      "name"                               = local.cert_manager_namespace
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

#############################################
# ClusterIssuer for Let's Encrypt (Optional)
#############################################

resource "kubectl_manifest" "letsencrypt_prod" {
  count = var.create_letsencrypt_issuer ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "alb"
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}

resource "kubectl_manifest" "letsencrypt_staging" {
  count = var.create_letsencrypt_issuer ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-staging-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "alb"
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [helm_release.cert_manager]
}

#############################################
# Self-Signed ClusterIssuer (for internal certs)
#############################################

resource "kubectl_manifest" "selfsigned_issuer" {
  count = var.create_selfsigned_issuer ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-issuer"
    }
    spec = {
      selfSigned = {}
    }
  })

  depends_on = [helm_release.cert_manager]
}
