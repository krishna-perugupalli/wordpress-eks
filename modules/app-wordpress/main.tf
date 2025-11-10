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

locals {
  media_offload_enabled = var.enable_media_offload && trimspace(var.media_bucket_name) != ""
  media_service_account = trimspace(var.media_service_account) != "" ? var.media_service_account : "${var.name}-media"
  media_env_vars = local.media_offload_enabled ? [
    { name = "MEDIA_BUCKET_NAME", value = var.media_bucket_name },
    { name = "MEDIA_BUCKET_REGION", value = var.media_bucket_region }
  ] : []
  media_extra_config_template = <<-EOT
define('AS3CF_AWS_USE_IAM_ROLE', true);
define('AS3CF_AWS_USE_EC2_IAM_ROLE', true);
define('AS3CF_SETTINGS', serialize(array(
  'provider'         => 'aws',
  'bucket'           => getenv('MEDIA_BUCKET_NAME'),
  'region'           => getenv('MEDIA_BUCKET_REGION'),
  'use-server-roles' => true,
  'copy-to-s3'       => true,
  'serve-from-s3'    => true,
  'force-https'      => true,
  'domain'           => 's3',
  'object-prefix'    => '',
  'enable-object-prefix' => false,
  'remove-local-file'    => false
)));
EOT
  media_extra_config_content = local.media_offload_enabled ? trimspace(local.media_extra_config_template) : ""
  media_post_init_scripts = local.media_offload_enabled ? {
    "10-media-offload.sh" = <<-EOT
      #!/bin/bash
      set -euo pipefail

      PLUGIN="amazon-s3-and-cloudfront"
      LOCK_DIR="/bitnami/wordpress/.media-offload.lock"
      DONE_FILE="/bitnami/wordpress/.media-offload.done"
      export WP_CLI_CACHE_DIR="/tmp/wp-cli-cache"
      mkdir -p "$WP_CLI_CACHE_DIR"

      if [ -f "$DONE_FILE" ]; then
        echo "Media offload already configured; skipping."
        exit 0
      fi

      if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "Another pod is configuring media offload; waiting..."
        for i in {1..60}; do
          if [ -f "$DONE_FILE" ]; then
            echo "Configuration completed by another pod; exiting."
            exit 0
          fi
          if [ ! -d "$LOCK_DIR" ]; then
            break
          fi
          echo "Waiting for lock... ($i/60)"
          sleep 5
        done
        if [ -f "$DONE_FILE" ]; then
          exit 0
        fi
        if [ -d "$LOCK_DIR" ]; then
          echo "Timed out waiting for media offload lock; aborting."
          exit 1
        fi
      fi
      trap 'rm -rf "$LOCK_DIR"' EXIT

      if ! wp plugin is-installed "$${PLUGIN}" --allow-root; then
        wp plugin install "$${PLUGIN}" --activate --allow-root || {
          echo "Failed to install plugin $${PLUGIN}"
          exit 1
        }
      else
        wp plugin activate "$${PLUGIN}" --allow-root || {
          echo "Failed to activate plugin $${PLUGIN}"
          exit 1
        }
      fi

      SETTINGS=$(php -r '
        $bucket = getenv("MEDIA_BUCKET_NAME");
        $region = getenv("MEDIA_BUCKET_REGION");
        if (!$bucket || !$region) { exit(1); }
        $settings = serialize([
          "provider" => "aws",
          "bucket" => $bucket,
          "region" => $region,
          "use-server-roles" => true,
          "copy-to-s3" => true,
          "serve-from-s3" => true,
          "force-https" => true,
          "domain" => "s3",
          "object-prefix" => "",
          "enable-object-prefix" => false,
          "remove-local-file" => false,
        ]);
        echo $settings;
      ')

      wp config set AS3CF_SETTINGS "$SETTINGS" --type=constant --allow-root
      wp config set AS3CF_AWS_USE_IAM_ROLE true --type=constant --raw --allow-root
      wp config set AS3CF_AWS_USE_EC2_IAM_ROLE true --type=constant --raw --allow-root
      wp option update as3cf_settings "$SETTINGS" --allow-root
      touch "$DONE_FILE"
    EOT
  } : {}
}

resource "null_resource" "media_requirements" {
  count = local.media_offload_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = trimspace(var.media_bucket_region) != "" && trimspace(var.media_irsa_role_arn) != ""
      error_message = "Media offload requires media_bucket_region and media_irsa_role_arn to be set."
    }
  }
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

  db_grant_job_name = "${local.effective_fullname}-db-grant"
}

#############################################
# One-time Job: ensure DB user has privileges
#############################################
/* resource "kubectl_manifest" "wp_db_grant_job" {
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
  --host="$MYSQL_HOST" \
  --port="$MYSQL_PORT" \
  --user="$MYSQL_LOGIN_USER" \
  --password="$MYSQL_LOGIN_PASSWORD" <<SQL
GRANT ALL ON `$TARGET_DATABASE`.* TO '$TARGET_USER'@'%';
FLUSH PRIVILEGES;
SQL
EOT
              ]
              env = [
                {
                  name = "MYSQL_HOST"
                  valueFrom = {
                    secretKeyRef = {
                  name = "wp-db"
                      key  = "WORDPRESS_DATABASE_HOST"
                    }
                  }
                },
                {
                  name = "MYSQL_PORT"
                  valueFrom = {
                    secretKeyRef = {
                  name = "wp-db"
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
} */

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
    } : {},
    var.ingress_forward_default ? {
      "alb.ingress.kubernetes.io/actions.forward-default" = jsonencode({
        Type = "forward"
        ForwardConfig = {
          TargetGroups = [
            {
              ServiceName = local.wordpress_service_name
              ServicePort = "http"
            }
          ]
        }
      })
    } : {}
  )

  ingress_extra_rules = var.ingress_forward_default ? [
    {
      host = ""
      http = {
        paths = [
          {
            path     = "/*"
            pathType = "ImplementationSpecific"
            backend = {
              service = {
                name = "forward-default"
                port = {
                  name = "use-annotation"
                }
              }
            }
          }
        ]
      }
    }
  ] : []

  extra_env_vars = concat(
    [
      for k, v in var.env_extra : {
        name  = k
        value = v
      }
    ],
    local.media_env_vars
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

locals {
  wordpress_extra_config_blocks = concat(
    local.redis_cache_enabled ? [local.redis_extra_config_content] : [],
    local.media_offload_enabled ? [local.media_extra_config_content] : []
  )
  wordpress_extra_config_content = length(local.wordpress_extra_config_blocks) > 0 ? join("\n\n", local.wordpress_extra_config_blocks) : ""
  media_service_account_values = local.media_offload_enabled ? {
    serviceAccount = {
      create                      = true
      name                        = local.media_service_account
      automountServiceAccountToken = true
      annotations = {
        "eks.amazonaws.com/role-arn" = var.media_irsa_role_arn
      }
    }
  } : {}
  media_post_init_values = local.media_offload_enabled ? {
    customPostInitScripts = local.media_post_init_scripts
  } : {}
  wordpress_runtime_values = merge(
    { extraEnvVars = local.extra_env_vars },
    local.media_service_account_values,
    local.media_post_init_values,
    local.wordpress_extra_config_content != "" ? {
      wordpressExtraConfigContent = "${local.wordpress_extra_config_content}\n"
    } : {},
    local.redis_cache_enabled ? { wordpressConfigureCache = true } : {}
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
        extraRules  = local.ingress_extra_rules
      }
    }),

    # HPA + replicaCount with proper numbers (no quotes)
    yamlencode({
      replicaCount = var.replicas_min
      autoscaling  = local.autoscaling_values
    }),

    # Runtime extras (env vars, wp-config additions, service account, init scripts)
    yamlencode(local.wordpress_runtime_values)
  ]

  depends_on = [
    kubernetes_namespace.ns,
    kubectl_manifest.wp_db_es,
    kubectl_manifest.wp_db_admin_es,
    kubectl_manifest.wp_admin_es
  ]
}
