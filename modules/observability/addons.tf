# ==============================================================================
# Addon-Specific Helm Values and Configurations
# ==============================================================================
# This file contains addon-specific Helm values and custom configurations for
# observability components deployed via EKS Blueprints Addons.
# ==============================================================================

# ------------------------------------------------------------------------------
# Prometheus (kube-prometheus-stack) Custom Values
# ------------------------------------------------------------------------------

locals {
  kube_prometheus_stack_values = {
    prometheus = {
      prometheusSpec = {
        retention = "15d"
        resources = {
          requests = {
            cpu    = "1"
            memory = "2Gi"
          }
          limits = {
            cpu    = "2"
            memory = "4Gi"
          }
        }
        # Enable ServiceMonitor and PodMonitor CRDs
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Grafana Custom Values
# ------------------------------------------------------------------------------

locals {
  grafana_values = {
    service = {
      type = "ClusterIP"
    }
    grafana_ini = {
      auth_anonymous = {
        enabled = false
      }
    }

    # Enables automatic dashboard provisioning from ConfigMaps
    sidecar = {
      dashboards = {
        enabled          = true
        label            = "grafana_dashboard"
        labelValue       = "1"
        folder           = "/tmp/dashboards"
        searchNamespace  = "monitoring"
        resource         = "configmap"
        folderAnnotation = "grafana_folder"
        provider = {
          foldersFromFilesStructure = true
        }
      }
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    }
  }
}

# ------------------------------------------------------------------------------
# Fluent Bit Custom Values
# ------------------------------------------------------------------------------
# The aws_for_fluentbit parameter accepts a map of configuration options
# that the EKS Blueprints Addons module will convert to Helm values.
# Do NOT use the 'values' array format here - the module handles that internally.

locals {
  fluentbit_values = {
    set = [
      {
        name  = "cloudWatchLogs.enabled"
        value = "true"
      },
      {
        name  = "cloudWatchLogs.region"
        value = data.aws_region.current.name
      },
      {
        name  = "cloudWatchLogs.logGroupName"
        value = "/aws/eks/${var.cluster_name}/application"
      }
    ]
  }
}

# ------------------------------------------------------------------------------
# YACE (Yet Another CloudWatch Exporter) Configuration
# ------------------------------------------------------------------------------
# YACE exports CloudWatch metrics to Prometheus for unified observability.
# This enables Grafana dashboards to display AWS service metrics alongside
# application metrics without switching data sources.
#
# Metrics discovery for:
# - RDS (Aurora MySQL): connections, CPU, storage, replication lag
# - ElastiCache (Redis): cache hits/misses, CPU, memory, connections
# - EFS: throughput, IOPS, client connections
# - ALB: request count, target response time, HTTP errors

resource "helm_release" "yace" {
  count = var.enable_yace ? 1 : 0

  name       = "yace"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-yet-another-cloudwatch-exporter"
  namespace  = local.monitoring_namespace

  values = [
    templatefile("${path.module}/exporters/yace-values.yaml", {
      aws_region      = data.aws_region.current.name
      project_tag     = var.project_name
      environment_tag = var.environment
    })
  ]

  # Configure service account with IRSA annotation
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.yace[0].arn
  }

  # Configure AWS region from data source
  set {
    name  = "aws.region"
    value = data.aws_region.current.name
  }

  depends_on = [
    module.eks_blueprints_addons,
    aws_iam_role.yace
  ]
}

# ------------------------------------------------------------------------------
# YACE IRSA Configuration
# ------------------------------------------------------------------------------
# IAM Role for Service Accounts (IRSA) configuration for YACE exporter.
# Grants YACE permissions to read CloudWatch metrics and describe AWS resources.

# Trust policy for YACE service account
data "aws_iam_policy_document" "yace_trust" {
  count = var.enable_yace ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub"
      values = [
        "system:serviceaccount:${local.monitoring_namespace}:yace-yet-another-cloudwatch-exporter"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM role for YACE
resource "aws_iam_role" "yace" {
  count = var.enable_yace ? 1 : 0

  name               = "${var.cluster_name}-yace"
  assume_role_policy = data.aws_iam_policy_document.yace_trust[0].json
  tags               = local.common_tags
}

# IAM policy document with CloudWatch and resource describe permissions
data "aws_iam_policy_document" "yace" {
  count = var.enable_yace ? 1 : 0

  statement {
    sid    = "CloudWatchReadMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DescribeResources"
    effect = "Allow"
    actions = [
      "ec2:DescribeRegions",
      "ec2:DescribeInstances",
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeReplicationGroups",
      "elasticfilesystem:DescribeFileSystems",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "tag:GetResources"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "BillingReadAccess"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetUsageRecords",
      "ce:ListCostCategoryDefinitions",
      "ce:GetRightsizingRecommendation"
    ]
    resources = ["*"]
  }
}

# IAM policy resource
resource "aws_iam_policy" "yace" {
  count = var.enable_yace ? 1 : 0

  name        = "${var.cluster_name}-yace-cloudwatch"
  description = "CloudWatch metrics read permissions for YACE exporter"
  policy      = data.aws_iam_policy_document.yace[0].json
  tags        = local.common_tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "yace" {
  count = var.enable_yace ? 1 : 0

  role       = aws_iam_role.yace[0].name
  policy_arn = aws_iam_policy.yace[0].arn
}

# ------------------------------------------------------------------------------
# Redis Exporter Deployment
# ------------------------------------------------------------------------------
# Redis exporter exposes ElastiCache Redis metrics to Prometheus.
# Provides cache performance metrics including hit/miss rates, memory usage,
# connections, and command statistics.

resource "helm_release" "redis_exporter" {
  count = var.enable_prometheus && var.redis_endpoint != "" ? 1 : 0

  name       = "redis-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-redis-exporter"
  namespace  = local.monitoring_namespace
  version    = "6.4.0"

  values = [
    templatefile("${path.module}/exporters/redis-values.yaml", {
      redis_endpoint = var.redis_endpoint
    })
  ]

  # Override the placeholder with actual Redis endpoint
  set {
    name  = "redisAddress"
    value = "rediss://${var.redis_endpoint}:6379"
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# MySQL Exporter Deployment
# ------------------------------------------------------------------------------
# MySQL exporter exposes Aurora MySQL database metrics to Prometheus.
# Provides database performance metrics including connections, queries per second,
# slow queries, replication lag, and resource utilization.

resource "helm_release" "mysql_exporter" {
  count = var.enable_prometheus && var.mysql_endpoint != "" ? 1 : 0

  name       = "mysql-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-mysql-exporter"
  namespace  = local.monitoring_namespace
  version    = "2.6.1"

  values = [
    templatefile("${path.module}/exporters/mysql-values.yaml", {
      mysql_host = var.mysql_endpoint
    })
  ]

  # Override the placeholder with actual MySQL endpoint
  set {
    name  = "mysql.host"
    value = var.mysql_endpoint
  }

  # Use the existing wpapp database user for metrics collection
  set {
    name  = "mysql.user"
    value = "wpapp"
  }

  # Reference the existing wpapp database secret
  set {
    name  = "mysql.existingSecret.name"
    value = "wp-db"
  }

  set {
    name  = "mysql.existingSecret.key"
    value = "password"
  }

  depends_on = [module.eks_blueprints_addons]
}

# ------------------------------------------------------------------------------
# ServiceMonitor Definitions
# ------------------------------------------------------------------------------
# ServiceMonitors tell Prometheus which services to scrape for metrics.
# These are created for application exporters to enable automatic discovery.

# ServiceMonitor for WordPress Exporter
resource "kubernetes_manifest" "servicemonitor_wordpress" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "wordpress-metrics"
      namespace = var.wordpress_namespace
      labels = {
        app       = "wordpress"
        component = "metrics"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app       = "wordpress"
          component = "metrics"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [module.eks_blueprints_addons]
}

# ServiceMonitor for Redis Exporter
resource "kubernetes_manifest" "servicemonitor_redis" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "redis-exporter"
      namespace = local.monitoring_namespace
      labels = {
        app = "redis-exporter"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "redis-exporter"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.redis_exporter]
}

# ServiceMonitor for MySQL Exporter
resource "kubernetes_manifest" "servicemonitor_mysql" {
  count = var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "mysql-exporter"
      namespace = local.monitoring_namespace
      labels = {
        app = "mysql-exporter"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "mysql-exporter"
        }
      }
      endpoints = [
        {
          port     = "metrics"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.mysql_exporter]
}

# ServiceMonitor for YACE Exporter
resource "kubernetes_manifest" "servicemonitor_yace" {
  count = var.enable_yace ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "yace"
      namespace = local.monitoring_namespace
      labels = {
        app = "yace"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "yace"
        }
      }
      endpoints = [
        {
          port     = "http"
          interval = "30s"
          path     = "/metrics"
        }
      ]
    }
  }

  depends_on = [helm_release.yace]
}
