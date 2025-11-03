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
    WORDPRESS_DATABASE_HOST = var.db_host
    WORDPRESS_DATABASE_NAME = var.db_name
    WORDPRESS_DATABASE_USER = var.db_user
    WORDPRESS_DATABASE_PORT = "3306"
  }

  wp_env_data = [
    {
      secretKey = "WORDPRESS_DATABASE_PASSWORD"
      remoteRef = {
        key      = var.db_secret_arn
        property = "password"
      }
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
      target = {
        name           = "wp-env"
        creationPolicy = "Owner"
        template = {
          type = "Opaque"
          data = local.wp_env_template_data
        }
      }
      data = local.wp_env_data
    }
  })

  depends_on = [kubernetes_namespace.ns]
}

resource "kubectl_manifest" "wp_db_es" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata   = { name = "wp-db", namespace = var.namespace }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "aws-sm", kind = "ClusterSecretStore" }
      target          = { name = "wp-db", creationPolicy = "Owner" }
      data = [
        {
          secretKey = "password"
          remoteRef = { key = var.db_secret_arn, property = "password" }
        }
      ]
    }
  })
  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Optional: ESO ExternalSecret 'wp-admin' for admin bootstrap
# - Only password is pulled; username/email via Helm values
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
        {
          secretKey = "wordpress-password"
          remoteRef = {
            key      = var.admin_secret_arn
            property = "password"
          }
        }
      ]
    }
  })

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Deterministic naming for Service/Ingress
#############################################
locals {
  effective_fullname = var.fullname_override != "" ? var.fullname_override : (
    var.name_override != "" ? var.name_override : var.name
  )
}

locals {
  db_grant_login_user_effective = (
    var.db_grant_login_user != null && trimspace(var.db_grant_login_user) != ""
  ) ? var.db_grant_login_user : var.db_user

  # db_grant_job_name = "${local.effective_fullname}-db-grant"
  db_grant_job_name = tostring(replace(lower(local.effective_fullname), "_", "-")) + "-db-grant"
}

#############################################
# One-time Job: ensure DB user has privileges
#############################################
resource "kubectl_manifest" "wp_db_grant_job" {
  count = var.db_grant_job_enabled ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = local.db_grant_job_name
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/name"      = "wordpress"
        "app.kubernetes.io/instance"  = local.effective_fullname
        "app.kubernetes.io/component" = "db-grant"
      }
    }
    spec = {
      backoffLimit            = var.db_grant_job_backoff_limit
      ttlSecondsAfterFinished = 3600
      template = {
        metadata = {
          labels = {
            "app.kubernetes.io/name"      = "wordpress"
            "app.kubernetes.io/instance"  = local.effective_fullname
            "app.kubernetes.io/component" = "db-grant"
          }
        }
        spec = {
          restartPolicy = "OnFailure"
          containers = [
            {
              name            = "mysql-grant"
              image           = var.db_grant_job_image
              imagePullPolicy = "IfNotPresent"
              command         = ["/bin/sh", "-c"]
              args = [<<-EOT
set -euo pipefail
mysql --protocol=TCP \
  --host="${MYSQL_HOST}" \
  --port="${MYSQL_PORT}" \
  --user="${MYSQL_LOGIN_USER}" \
  --password="${MYSQL_LOGIN_PASSWORD}" <<'SQL'
GRANT ALL ON `${TARGET_DATABASE}`.* TO '${TARGET_USER}'@'%';
FLUSH PRIVILEGES;
SQL
EOT
              ]
              env = [
                {
                  name = "MYSQL_HOST"
                  valueFrom = {
                    secretKeyRef = {
                      name = "wp-env"
                      key  = "WORDPRESS_DATABASE_HOST"
                    }
                  }
                },
                {
                  name = "MYSQL_PORT"
                  valueFrom = {
                    secretKeyRef = {
                      name = "wp-env"
                      key  = "WORDPRESS_DATABASE_PORT"
                    }
                  }
                },
                {
                  name  = "MYSQL_LOGIN_USER"
                  value = local.db_grant_login_user_effective
                },
                {
                  name = "MYSQL_LOGIN_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = "wp-db"
                      key  = var.db_grant_login_password_key
                    }
                  }
                },
                {
                  name  = "TARGET_DATABASE"
                  value = var.db_name
                },
                {
                  name  = "TARGET_USER"
                  value = var.db_user
                }
              ]
            }
          ]
        }
      }
    }
  })

  depends_on = [
    kubernetes_namespace.ns,
    kubectl_manifest.wp_env_es,
    kubectl_manifest.wp_db_es
  ]
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
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/ssl-policy"       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    },
    var.alb_certificate_arn != "" ? {
      "alb.ingress.kubernetes.io/certificate-arn" = var.alb_certificate_arn
    } : {},
    var.waf_acl_arn != "" ? {
      "alb.ingress.kubernetes.io/wafv2-acl-arn" = var.waf_acl_arn
    } : {},
    local.alb_tags_csv != "" ? {
      "alb.ingress.kubernetes.io/tags" = local.alb_tags_csv
    } : {}
  )

  extra_env_vars = [
    for k, v in var.env_extra : {
      name  = k
      value = v
    }
  ]
}

#############################################
# HPA values (ensure ints, not strings)
#############################################
locals {
  autoscaling_values = merge(
    {
      enabled     = true
      minReplicas = var.replicas_min
      maxReplicas = var.replicas_max
    },
    var.target_cpu_percent != null ? { targetCPU = tonumber(var.target_cpu_percent) } : {},
    var.target_memory_percent != null ? { targetMemory = tonumber(var.target_memory_percent) } : {}
  )
}


#############################################
# Helm: Bitnami/wordpress (external DB, ESO env, EFS PVC, ALB ingress, HPA)
#############################################
resource "helm_release" "wordpress" {
  name       = "${var.name}-wordpress"
  namespace  = var.namespace
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "wordpress"
  version    = var.wordpress_chart_version
  timeout    = 600
  wait       = true

  # Deterministic names (Service/Ingress)
  dynamic "set" {
    for_each = var.fullname_override != "" ? [1] : []
    content {
      name  = "fullnameOverride"
      value = var.fullname_override
    }
  }
  dynamic "set" {
    for_each = var.fullname_override == "" && var.name_override != "" ? [1] : []
    content {
      name  = "nameOverride"
      value = var.name_override
    }
  }

  # External DB (disable bundled MariaDB)
  # Disable the bundled MariaDB
  set {
    name  = "mariadb.enabled"
    value = "false"
  }

  # Tell the chart about your Aurora DB (host/user/name/port)
  set {
    name  = "externalDatabase.host"
    value = var.db_host
  }
  set {
    name  = "externalDatabase.port"
    value = tostring(var.db_port)
  }
  set {
    name  = "externalDatabase.user"
    value = var.db_user
  }
  set {
    name  = "externalDatabase.database"
    value = var.db_name
  }

  # Point the chart to the ESO-created password Secret (key must be "password")
  set {
    name  = "externalDatabase.existingSecret"
    value = "wp-db"
  }
  # (Optional, if your chart version supports it)
  # set { name = "externalDatabase.existingSecretPasswordKey", value = "password" }

  # Do NOT let it fall back to empty passwords
  set {
    name  = "allowEmptyPassword"
    value = "false"
  }

  set {
    name  = "wordpressScheme"
    value = "https"
  }

  # Keep this for non-DB envs only (remove DB keys from wp-env to avoid clashes)
  set {
    name  = "extraEnvVarsSecret"
    value = "wp-env"
  }

  # Admin bootstrap (safe one-time init)
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

  # Resources (requests only — keep as strings, that’s fine)
  set {
    name  = "resources.requests.cpu"
    value = var.resources_requests_cpu
  }
  set {
    name  = "resources.requests.memory"
    value = var.resources_requests_memory
  }

  ###########################################
  # Use VALUES (not --set) for ingress + HPA
  ###########################################
  values = [
    # Ingress (annotations include listen-ports JSON as a string)
    yamlencode({
      ingress = {
        enabled     = true
        hostname    = var.domain_name
        annotations = local.ingress_annotations
        tls         = true
      }
    }),

    # HPA + replicaCount with proper numbers (no quotes)
    yamlencode({
      replicaCount = var.replicas_min
      autoscaling  = local.autoscaling_values
    })
  ]

  depends_on = [
    kubernetes_namespace.ns,
    kubectl_manifest.wp_env_es,
    kubectl_manifest.wp_db_es,
    kubectl_manifest.wp_admin_es
  ]
}
