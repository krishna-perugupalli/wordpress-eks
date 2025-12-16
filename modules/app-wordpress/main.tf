#############################################
# Namespace (idempotent)
#############################################
resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
  }
}

locals {
  helm_release_name = "${var.name}-wordpress"
}

locals {
  wordpress_service_name = var.fullname_override != "" ? var.fullname_override : (
    var.name_override != "" ? "${local.helm_release_name}-${var.name_override}" : local.helm_release_name
  )
}

##############################################
# Redis cache configuration for WordPress
##############################################
locals {
  redis_cache_enabled    = var.enable_redis_cache && trimspace(var.redis_endpoint) != ""
  redis_scheme_effective = trimspace(var.redis_connection_scheme) != "" ? var.redis_connection_scheme : "tls"
  redis_server_uri       = local.redis_cache_enabled ? format("%s://%s:%d", local.redis_scheme_effective, trimspace(var.redis_endpoint), var.redis_port) : ""
  redis_config_lines = local.redis_cache_enabled ? concat(
    [
      "define('WP_CACHE', true);",
      "define('W3TC_CONFIG_CACHE_ENGINE', 'redis');",
      format("define('W3TC_CONFIG_REDIS_SERVERS', '%s');", local.redis_server_uri),
      format("define('W3TC_CONFIG_REDIS_DBID', '%d');", var.redis_database)
    ],
    trimspace(var.redis_auth_secret_arn) != "" ? [
      format("define('W3TC_CONFIG_REDIS_PASSWORD', getenv('%s'));", var.redis_auth_env_var_name)
    ] : []
  ) : []
  redis_extra_config_content = local.redis_cache_enabled ? join("\n", local.redis_config_lines) : ""
  redis_secret_entries = local.redis_cache_enabled && trimspace(var.redis_auth_secret_arn) != "" ? [
    {
      secretKey = var.redis_auth_env_var_name
      remoteRef = {
        key      = var.redis_auth_secret_arn
        property = var.redis_auth_secret_property
      }
    }
  ] : []
}

##############################################
# CloudFront/Proxy HTTPS detection configuration
##############################################
locals {
  # PHP code to trust X-Forwarded-Proto header from CloudFront/ALB
  cloudfront_proxy_config = var.behind_cloudfront ? [
    "// Trust proxy headers for HTTPS detection when behind CloudFront/ALB",
    "if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {",
    "    $_SERVER['HTTPS'] = 'on';",
    "}",
    "if (isset($_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO']) && $_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO'] === 'https') {",
    "    $_SERVER['HTTPS'] = 'on';",
    "}",
    "define('FORCE_SSL_ADMIN', true);"
  ] : []

  cloudfront_proxy_config_content = length(local.cloudfront_proxy_config) > 0 ? join("\n", local.cloudfront_proxy_config) : ""
}

#############################################
# ESO ExternalSecret: build 'wp-db' with DB creds
# - PASSWORD pulled from SM via ClusterSecretStore 'aws-sm'
# - Non-secret connection metadata templated from variables
#############################################
locals {
  db_secret_template_data = {
    WORDPRESS_DATABASE_HOST = var.db_host
    WORDPRESS_DATABASE_NAME = var.db_name
    WORDPRESS_DATABASE_USER = var.db_user
    WORDPRESS_DATABASE_PORT = tostring(var.db_port)
  }

  db_secret_password_keys = distinct(concat(
    [var.db_secret_key],
    var.db_secret_additional_keys
  ))

  db_secret_data = concat(
    [
      for key in local.db_secret_password_keys : {
        secretKey = key
        remoteRef = {
          key      = var.db_secret_arn
          property = var.db_secret_property
        }
      }
    ],
    local.redis_secret_entries
  )

  admin_secret_arn_effective = trimspace(coalesce(var.db_admin_secret_arn, ""))

  admin_secret_data = local.admin_secret_arn_effective != "" ? concat(
    [
      {
        secretKey = var.db_admin_secret_key
        remoteRef = {
          key      = local.admin_secret_arn_effective
          property = var.db_admin_secret_property
        }
      }
    ],
    trimspace(var.db_admin_username_property) != "" ? [
      {
        secretKey = var.db_admin_username_key
        remoteRef = {
          key      = local.admin_secret_arn_effective
          property = var.db_admin_username_property
        }
      }
    ] : []
  ) : []
}

resource "kubectl_manifest" "wp_db_es" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata   = { name = "wp-db", namespace = var.namespace }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "aws-sm", kind = "ClusterSecretStore" }
      target = {
        name           = "wp-db"
        creationPolicy = "Owner"
        template = {
          type          = "Opaque"
          engineVersion = "v2"
          mergePolicy   = "Merge"
          data          = local.db_secret_template_data
        }
      }
      data = local.db_secret_data
    }
  })
  depends_on = [kubernetes_namespace.ns]
}

resource "kubectl_manifest" "wp_db_admin_es" {
  count = local.admin_secret_arn_effective != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata   = { name = "wp-db-admin", namespace = var.namespace }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "aws-sm", kind = "ClusterSecretStore" }
      target          = { name = "wp-db-admin", creationPolicy = "Owner" }
      data            = local.admin_secret_data
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

  db_grant_job_name      = "${local.effective_fullname}-db-grant"
  admin_secret_available = local.admin_secret_arn_effective != ""
  db_bootstrap_script    = file("${path.module}/files/bootstrap-wpdb.sh")

  db_job_login_envs = local.admin_secret_available ? [
    {
      name        = "MYSQL_LOGIN_USER"
      from_secret = true
      secret_name = "wp-db-admin"
      secret_key  = var.db_admin_username_key
    },
    {
      name        = "MYSQL_LOGIN_PASSWORD"
      from_secret = true
      secret_name = "wp-db-admin"
      secret_key  = var.db_admin_secret_key
    }
    ] : [
    {
      name        = "MYSQL_LOGIN_USER"
      from_secret = false
      value       = local.db_grant_login_user_effective
    },
    {
      name        = "MYSQL_LOGIN_PASSWORD"
      from_secret = true
      secret_name = "wp-db"
      secret_key  = var.db_grant_login_password_key
    }
  ]
}

#############################################
# One-time Job: ensure DB user has privileges
#############################################
resource "kubernetes_job_v1" "wp_db_grant_job" {
  count = var.db_grant_job_enabled ? 1 : 0

  metadata {
    name      = local.db_grant_job_name
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name"      = "wordpress"
      "app.kubernetes.io/instance"  = local.effective_fullname
      "app.kubernetes.io/component" = "db-grant"
    }
  }

  spec {
    backoff_limit              = var.db_grant_job_backoff_limit
    ttl_seconds_after_finished = 3600
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "wordpress"
          "app.kubernetes.io/instance"  = local.effective_fullname
          "app.kubernetes.io/component" = "db-grant"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name              = "mysql-client"
          image             = var.db_grant_job_image
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/bash", "-ceu", local.db_bootstrap_script]

          dynamic "env" {
            for_each = local.db_job_login_envs
            content {
              name  = env.value.name
              value = env.value.from_secret ? null : env.value.value

              dynamic "value_from" {
                for_each = env.value.from_secret ? [1] : []
                content {
                  secret_key_ref {
                    name = env.value.secret_name
                    key  = env.value.secret_key
                  }
                }
              }
            }
          }

          env {
            name = "TARGET_USER_PASSWORD"
            value_from {
              secret_key_ref {
                name = "wp-db"
                key  = var.db_secret_key
              }
            }
          }

          env {
            name = "MYSQL_HOST"
            value_from {
              secret_key_ref {
                name = "wp-db"
                key  = "WORDPRESS_DATABASE_HOST"
              }
            }
          }

          env {
            name = "MYSQL_PORT"
            value_from {
              secret_key_ref {
                name = "wp-db"
                key  = "WORDPRESS_DATABASE_PORT"
              }
            }
          }

          env {
            name = "TARGET_DATABASE"
            value_from {
              secret_key_ref {
                name = "wp-db"
                key  = "WORDPRESS_DATABASE_NAME"
              }
            }
          }

          env {
            name = "TARGET_USER"
            value_from {
              secret_key_ref {
                name = "wp-db"
                key  = "WORDPRESS_DATABASE_USER"
              }
            }
          }
        }
      }
    }
  }

  wait_for_completion = true

  depends_on = [
    kubernetes_namespace.ns,
    kubectl_manifest.wp_db_es
  ]
}

#############################################
# Extra environment variables
#############################################
locals {
  extra_env_vars = concat(
    [
      for k, v in var.env_extra : {
        name  = k
        value = v
      }
    ]
  )
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
  name       = local.helm_release_name
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

  # Service fronted only by ALB ingress, so stick with ClusterIP
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  # Keep this for non-DB envs only (remove DB keys from wp-db to avoid clashes)
  set {
    name  = "extraEnvVarsSecret"
    value = "wp-db"
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
  # Use VALUES (not --set) for HPA and config
  ###########################################
  values = concat(
    [
      # Disable Ingress (using TargetGroupBinding instead)
      yamlencode({
        ingress = {
          enabled = false
        }
      }),

      # HPA + replicaCount with proper numbers (no quotes)
      yamlencode({
        replicaCount = var.replicas_min
        autoscaling  = local.autoscaling_values
      }),

      # Extra env vars if provided
      yamlencode({
        extraEnvVars = local.extra_env_vars
      })
    ],
    # Combine Redis and CloudFront proxy configs into wordpressExtraConfigContent
    (local.redis_cache_enabled || var.behind_cloudfront) ? [
      yamlencode({
        wordpressConfigureCache = local.redis_cache_enabled
        wordpressExtraConfigContent = join("\n", compact([
          local.redis_extra_config_content,
          local.cloudfront_proxy_config_content
        ]))
      })
    ] : [],
    # WordPress metrics exporter sidecar configuration
    var.enable_metrics_exporter ? [
      yamlencode({
        sidecars = [
          {
            name    = "metrics-exporter"
            image   = var.metrics_exporter_image
            command = ["/bin/sh"]
            args    = ["/usr/local/bin/metrics-files/simple-entrypoint.sh"]
            ports = [
              {
                name          = "metrics"
                containerPort = 9090
                protocol      = "TCP"
              }
            ]
            env = [
              {
                name  = "WORDPRESS_PATH"
                value = "/var/www/html"
              }
            ]
            volumeMounts = [
              {
                name      = "wordpress-data"
                mountPath = "/var/www/html"
                readOnly  = true
              },
              {
                name      = "metrics-config"
                mountPath = "/usr/local/bin/metrics-files"
                readOnly  = true
              }
            ]
            resources = {
              requests = {
                cpu    = var.metrics_exporter_resources_requests_cpu
                memory = var.metrics_exporter_resources_requests_memory
              }
              limits = {
                cpu    = var.metrics_exporter_resources_limits_cpu
                memory = var.metrics_exporter_resources_limits_memory
              }
            }
            livenessProbe = {
              httpGet = {
                path = "/metrics"
                port = 9090
              }
              initialDelaySeconds = 30
              periodSeconds       = 30
              timeoutSeconds      = 10
              failureThreshold    = 3
            }
            readinessProbe = {
              httpGet = {
                path = "/metrics"
                port = 9090
              }
              initialDelaySeconds = 5
              periodSeconds       = 10
              timeoutSeconds      = 5
              failureThreshold    = 3
            }
            securityContext = {
              runAsNonRoot             = false
              allowPrivilegeEscalation = false
              readOnlyRootFilesystem   = false
              capabilities = {
                drop = ["ALL"]
              }
            }
          }
        ]
        extraVolumes = [
          {
            name = "metrics-config"
            configMap = {
              name        = "${local.effective_fullname}-metrics-config"
              defaultMode = 0755
            }
          }
        ]
        extraVolumeMounts = [
          {
            name      = "metrics-config"
            mountPath = "/opt/bitnami/wordpress/wp-content/plugins/wordpress-metrics/wordpress-metrics.php"
            subPath   = "wordpress-metrics-plugin.php"
            readOnly  = true
          },
          {
            name      = "metrics-config"
            mountPath = "/opt/bitnami/wordpress/wp-content/mu-plugins/wordpress-metrics-loader.php"
            subPath   = "mu-metrics-loader.php"
            readOnly  = true
          }
        ]
      })
    ] : []
  )

  depends_on = [
    kubernetes_namespace.ns,
    kubectl_manifest.wp_db_es,
    kubectl_manifest.wp_db_admin_es,
    kubectl_manifest.wp_admin_es,
    kubernetes_job_v1.wp_db_grant_job
  ]
}

#############################################
# TargetGroupBinding: Register WordPress pods with ALB target group
#############################################
resource "kubectl_manifest" "wordpress_tgb" {
  yaml_body = yamlencode({
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"
    metadata = {
      name      = "${local.effective_fullname}-tgb"
      namespace = var.namespace
    }
    spec = {
      serviceRef = {
        name = local.wordpress_service_name
        port = 80
      }
      targetGroupARN = var.target_group_arn
      targetType     = "ip"
    }
  })

  depends_on = [helm_release.wordpress]
}

#############################################
# WordPress Metrics ConfigMap (contains exporter and plugin files)
#############################################
resource "kubernetes_config_map" "wordpress_metrics_config" {
  count = var.enable_metrics_exporter ? 1 : 0

  metadata {
    name      = "${local.effective_fullname}-metrics-config"
    namespace = var.namespace
    labels = {
      app                          = "wordpress"
      component                    = "metrics"
      "app.kubernetes.io/name"     = "wordpress"
      "app.kubernetes.io/instance" = local.effective_fullname
    }
  }

  data = {
    "wordpress-exporter.php"         = file("${path.module}/files/wordpress-exporter.php")
    "wordpress-metrics-plugin.php"   = file("${path.module}/files/wordpress-metrics-plugin.php")
    "mu-metrics-loader.php"          = file("${path.module}/files/mu-metrics-loader.php")
    "simple-metrics-exporter.php"    = file("${path.module}/files/simple-metrics-exporter.php")
    "metrics-exporter-entrypoint.sh" = file("${path.module}/files/metrics-exporter-entrypoint.sh")
    "simple-entrypoint.sh"           = file("${path.module}/files/simple-entrypoint.sh")
  }

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# WordPress Metrics Service (for Prometheus scraping)
#############################################
resource "kubernetes_service" "wordpress_metrics" {
  count = var.enable_metrics_exporter ? 1 : 0

  metadata {
    name      = "${local.effective_fullname}-metrics"
    namespace = var.namespace
    labels = {
      app                          = "wordpress"
      component                    = "metrics"
      "app.kubernetes.io/name"     = "wordpress"
      "app.kubernetes.io/instance" = local.effective_fullname
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9090"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "wordpress"
      "app.kubernetes.io/instance" = local.effective_fullname
    }

    port {
      name        = "metrics"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [helm_release.wordpress]
}
