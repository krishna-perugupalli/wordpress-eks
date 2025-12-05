#############################################
# Grafana Sub-module
# Deploys Grafana with persistent storage, AWS IAM auth, and data sources
#############################################

data "aws_caller_identity" "current" {}

locals {
  grafana_name  = "${var.name}-grafana"
  oidc_hostpath = replace(var.cluster_oidc_issuer_url, "https://", "")
  account_id    = data.aws_caller_identity.current.account_id

  # IRSA role name for Grafana
  grafana_role_name = "${var.cluster_name}-grafana"

  # Service account name
  grafana_sa_name = "grafana"

  # Admin password handling
  grafana_admin_password_final = var.grafana_admin_password != null ? var.grafana_admin_password : random_password.grafana_admin[0].result
}

#############################################
# Random password for Grafana admin (if not provided)
#############################################
resource "random_password" "grafana_admin" {
  count   = var.grafana_admin_password == null ? 1 : 0
  length  = 32
  special = true
}

#############################################
# Kubernetes Secret for Grafana Admin Password
#############################################
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "${local.grafana_name}-admin"
    namespace = var.namespace
  }

  data = {
    admin-user     = "admin"
    admin-password = local.grafana_admin_password_final
  }

  type = "Opaque"
}

#############################################
# IAM Role for Grafana (IRSA)
#############################################
data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${local.grafana_sa_name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "grafana" {
  name               = local.grafana_role_name
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json
  tags = merge(var.tags, {
    Name      = local.grafana_role_name
    Component = "grafana"
  })
}

# IAM policy for CloudWatch data source and AWS IAM authentication
data "aws_iam_policy_document" "grafana_policy" {
  # CloudWatch data source permissions
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetInsightRuleReport"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs Insights permissions
  statement {
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents"
    ]
    resources = ["*"]
  }

  # EC2 describe permissions for CloudWatch data source
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions"
    ]
    resources = ["*"]
  }

  # Resource Groups Tagging API for CloudWatch data source
  statement {
    effect = "Allow"
    actions = [
      "tag:GetResources"
    ]
    resources = ["*"]
  }

  # KMS permissions for encryption (if KMS key provided)
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "grafana" {
  name   = "${local.grafana_role_name}-policy"
  role   = aws_iam_role.grafana.id
  policy = data.aws_iam_policy_document.grafana_policy.json
}

#############################################
# Storage Class for Grafana
# Note: Using cluster-wide gp3 StorageClass created in parent module
# No custom StorageClass needed - removed to use cluster default
#############################################

#############################################
# ConfigMap for Grafana Data Sources
#############################################
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "${local.grafana_name}-datasources"
    namespace = var.namespace
  }

  data = {
    "datasources.yaml" = yamlencode({
      apiVersion = 1
      datasources = concat(
        # Prometheus data source (if enabled)
        var.prometheus_url != null ? [{
          name      = "Prometheus"
          type      = "prometheus"
          access    = "proxy" # Grafana backend makes requests
          url       = var.prometheus_url
          isDefault = true
          editable  = false
          jsonData = {
            timeInterval = "30s"
            httpMethod   = "POST" # Better performance
          }
        }] : [],
        # CloudWatch data source (if enabled)
        var.enable_cloudwatch_datasource ? [{
          name     = "CloudWatch"
          type     = "cloudwatch"
          access   = "proxy"
          editable = false
          jsonData = {
            authType      = "default" # Uses IRSA
            defaultRegion = var.region
          }
        }] : []
      )
    })
  }
}

#############################################
# ConfigMap for Default Dashboards
#############################################
resource "kubernetes_config_map" "grafana_dashboards" {
  count = var.enable_default_dashboards ? 1 : 0

  metadata {
    name      = "${local.grafana_name}-dashboards"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    # WordPress Application Overview Dashboard
    "wordpress-overview.json" = file("${path.module}/dashboards/wordpress-overview.json")

    # Kubernetes Cluster Overview Dashboard
    "kubernetes-cluster.json" = file("${path.module}/dashboards/kubernetes-cluster.json")

    # AWS Services Monitoring Dashboard
    "aws-services.json" = file("${path.module}/dashboards/aws-services.json")

    # Cost Tracking and Optimization Dashboard
    "cost-tracking.json" = file("${path.module}/dashboards/cost-tracking.json")
  }
}

#############################################
# RBAC for Grafana
#############################################
resource "kubernetes_cluster_role" "grafana_viewer" {
  metadata {
    name = "${local.grafana_name}-viewer"
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "grafana_viewer" {
  metadata {
    name = "${local.grafana_name}-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.grafana_viewer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = local.grafana_sa_name
    namespace = var.namespace
  }
}

#############################################
# Grafana Helm Release
#############################################
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = "8.5.2" # Latest stable version
  namespace  = var.namespace

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      # Service account configuration for IRSA
      serviceAccount = {
        create = true
        name   = local.grafana_sa_name
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.grafana.arn
        }
      }

      # Admin credentials from secret
      admin = {
        existingSecret = kubernetes_secret.grafana_admin.metadata[0].name
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }

      # Persistence configuration
      persistence = {
        enabled          = true
        storageClassName = var.grafana_storage_class
        size             = var.grafana_storage_size
        accessModes      = ["ReadWriteOnce"]
      }

      # Resource configuration
      resources = {
        requests = var.grafana_resource_requests
        limits   = var.grafana_resource_limits
      }

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 472
        fsGroup      = 472
      }

      # Data sources configuration
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = concat(
            var.prometheus_url != null ? [{
              name      = "Prometheus"
              type      = "prometheus"
              access    = "proxy" # Grafana backend makes requests
              url       = var.prometheus_url
              isDefault = true
              editable  = false
              jsonData = {
                timeInterval = "30s"
                httpMethod   = "POST" # Better performance
              }
            }] : [],
            var.enable_cloudwatch_datasource ? [{
              name     = "CloudWatch"
              type     = "cloudwatch"
              access   = "proxy"
              editable = false
              jsonData = {
                authType      = "default"
                defaultRegion = var.region
              }
            }] : []
          )
        }
      }

      # Dashboard providers configuration
      dashboardProviders = var.enable_default_dashboards ? {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name                  = "default"
              orgId                 = 1
              folder                = ""
              type                  = "file"
              disableDeletion       = false
              editable              = true
              updateIntervalSeconds = 30
              allowUiUpdates        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            },
            {
              name                  = "wordpress"
              orgId                 = 1
              folder                = "WordPress"
              type                  = "file"
              disableDeletion       = false
              editable              = true
              updateIntervalSeconds = 30
              allowUiUpdates        = true
              options = {
                path = "/var/lib/grafana/dashboards/wordpress"
              }
            },
            {
              name                  = "infrastructure"
              orgId                 = 1
              folder                = "Infrastructure"
              type                  = "file"
              disableDeletion       = false
              editable              = true
              updateIntervalSeconds = 30
              allowUiUpdates        = true
              options = {
                path = "/var/lib/grafana/dashboards/infrastructure"
              }
            },
            {
              name                  = "cost"
              orgId                 = 1
              folder                = "Cost Management"
              type                  = "file"
              disableDeletion       = false
              editable              = true
              updateIntervalSeconds = 30
              allowUiUpdates        = true
              options = {
                path = "/var/lib/grafana/dashboards/cost"
              }
            }
          ]
        }
      } : {}

      # Dashboard configuration maps
      dashboardsConfigMaps = var.enable_default_dashboards ? {
        default = kubernetes_config_map.grafana_dashboards[0].metadata[0].name
      } : {}

      # Grafana configuration
      "grafana.ini" = {
        server = {
          root_url = "%(protocol)s://%(domain)s:%(http_port)s/"
        }

        # Dashboard configuration for persistence and version control
        dashboards = {
          default_home_dashboard_path = "/var/lib/grafana/dashboards/default/wordpress-overview.json"
          versions_to_keep            = 20
        }

        # Database configuration for dashboard persistence
        database = {
          type = "sqlite3"
          path = "/var/lib/grafana/grafana.db"
        }

        # AWS IAM authentication (if enabled)
        "auth.generic_oauth" = var.enable_aws_iam_auth ? {
          enabled             = true
          name                = "AWS IAM"
          allow_sign_up       = true
          client_id           = "grafana"
          scopes              = "openid profile email"
          auth_url            = "https://signin.aws.amazon.com/oauth"
          token_url           = "https://signin.aws.amazon.com/oauth/token"
          api_url             = "https://signin.aws.amazon.com/oauth/userinfo"
          role_attribute_path = "contains(groups[*], 'admin') && 'Admin' || 'Viewer'"
        } : {}

        analytics = {
          reporting_enabled = false
          check_for_updates = false
        }

        security = {
          disable_initial_admin_creation = false
          admin_user                     = "admin"
        }

        users = {
          allow_sign_up    = false
          auto_assign_org  = true
          auto_assign_role = "Viewer"
        }

        "auth.anonymous" = {
          enabled = false
        }

        log = {
          mode  = "console"
          level = "info"
        }

        # Snapshot configuration
        snapshots = {
          external_enabled = false
        }
      }

      # Service configuration
      service = {
        type = "ClusterIP"
        port = 80
      }

      # Ingress configuration (disabled by default, can be enabled via ALB controller)
      ingress = {
        enabled = false
      }

      # Plugins to install
      plugins = [
        "grafana-piechart-panel",
        "grafana-clock-panel"
      ]

      # Environment variables
      env = {
        GF_INSTALL_PLUGINS = "grafana-piechart-panel,grafana-clock-panel"
      }

      # Sidecar configuration for dashboard auto-discovery
      sidecar = {
        dashboards = {
          enabled = var.enable_default_dashboards
          label   = "grafana_dashboard"
        }
        datasources = {
          enabled = false # We configure datasources directly
        }
      }

      # Replica count for HA
      replicas = var.grafana_replica_count

      # Topology spread constraints for multi-AZ deployment
      # Relaxed for small clusters to allow scheduling
      topologySpreadConstraints = [
        {
          maxSkew           = 2 # Increased from 1 for small clusters
          topologyKey       = "topology.kubernetes.io/zone"
          whenUnsatisfiable = "ScheduleAnyway" # Changed from DoNotSchedule to allow scheduling
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name" = "grafana"
            }
          }
        },
        {
          maxSkew           = 1
          topologyKey       = "kubernetes.io/hostname"
          whenUnsatisfiable = "ScheduleAnyway"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name" = "grafana"
            }
          }
        }
      ]

      # Pod anti-affinity for HA - node affinity relaxed to allow scheduling on any worker node
      affinity = {
        nodeAffinity = {
          # Changed to preferred (not required) to allow scheduling on any worker node
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              preference = {
                matchExpressions = [
                  {
                    key      = "karpenter.sh/capacity-type"
                    operator = "In"
                    values   = ["on-demand", "spot"]
                  }
                ]
              }
            }
          ]
        }
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              podAffinityTerm = {
                labelSelector = {
                  matchExpressions = [
                    {
                      key      = "app.kubernetes.io/name"
                      operator = "In"
                      values   = ["grafana"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }

      # Tolerations to avoid scheduling on control plane nodes
      tolerations = [
        {
          key      = "node-role.kubernetes.io/control-plane"
          operator = "Exists"
          effect   = "NoSchedule"
        }
      ]

      # Liveness and readiness probes for automatic recovery
      livenessProbe = {
        httpGet = {
          path = "/api/health"
          port = 3000
        }
        initialDelaySeconds = 60
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 6
      }

      readinessProbe = {
        httpGet = {
          path = "/api/health"
          port = 3000
        }
        initialDelaySeconds = 30
        periodSeconds       = 5
        timeoutSeconds      = 3
        failureThreshold    = 3
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy.grafana,
    kubernetes_secret.grafana_admin,
    kubernetes_config_map.grafana_datasources
  ]
}