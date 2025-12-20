#############################################
# Data Sources
#############################################

data "aws_region" "current" {}

#############################################
# EKS Blueprints Addons Integration
#############################################
# This module uses the official AWS EKS Blueprints Addons module
# to deploy core observability components: Prometheus, Grafana,
# Alertmanager, and Fluent Bit.
#
# The module handles:
# - Helm chart deployments
# - IRSA role creation and management
# - Namespace management
# - Service account configuration

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  # Cluster configuration
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Component toggles
  enable_kube_prometheus_stack = var.enable_prometheus
  enable_aws_for_fluentbit     = var.enable_fluentbit
  enable_metrics_server        = var.enable_metrics_server

  # Prometheus configuration with custom Helm values
  kube_prometheus_stack = var.enable_prometheus ? {
    # Ensure CRDs are installed and ready before we create ServiceMonitors.
    wait      = true
    skip_crds = false
    values = [yamlencode(merge(
      local.kube_prometheus_stack_values,
      {
        # Grafana is part of kube-prometheus-stack
        grafana = merge(
          local.grafana_values,
          {
            enabled = var.enable_grafana
          }
        )
      }
    ))]
    } : {
    # Preserve object shape when disabled so the conditional type stays consistent.
    wait      = null
    skip_crds = null
    values    = []
  }

  # Fluent Bit configuration with custom Helm values
  aws_for_fluentbit = var.enable_fluentbit ? local.fluentbit_values : local.fluentbit_defaults

  # enable_yace_exporter = var.enable_yace

  # Common tags for AWS resources
  tags = local.common_tags

  depends_on = [
    time_sleep.wait_for_grafana_secret,
    kubectl_manifest.monitoring_namespace
  ]
}

#############################################
# Storage Resources
#############################################

# Loki S3 Bucket
resource "aws_s3_bucket" "loki" {
  count = var.enable_loki ? 1 : 0

  bucket_prefix = "${var.cluster_name}-loki-"
  force_destroy = true # For easier cleanup in dev/demo environments

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "loki" {
  count = var.enable_loki ? 1 : 0

  bucket = aws_s3_bucket.loki[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Tempo S3 Bucket
resource "aws_s3_bucket" "tempo" {
  count = var.enable_tempo ? 1 : 0

  bucket_prefix = "${var.cluster_name}-tempo-"
  force_destroy = true

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  count = var.enable_tempo ? 1 : 0

  bucket = aws_s3_bucket.tempo[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#############################################
# Loki Deployment
#############################################

resource "helm_release" "loki" {
  count = var.enable_loki ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "5.41.6" # Pin to a stable version
  namespace  = local.monitoring_namespace

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.loki_sa_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.loki_irsa[0].iam_role_arn
        }
      }
      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          bucketNames = {
            chunks = aws_s3_bucket.loki[0].id
            ruler  = aws_s3_bucket.loki[0].id
            admin  = aws_s3_bucket.loki[0].id
          }
          type = "s3"
        }
      }
      # Tuning for t3a.medium (2vCPU / 4GB RAM)
      # Default SimpleScalable is too heavy, so we scale down to 1 replica and low resources
      read = {
        replicas = 1
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }
      }
      write = {
        replicas = 1
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }
        persistence = {
          size             = "10Gi"
          storageClassName = "gp2"
        }
      }
      backend = {
        replicas = 1
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "512Mi"
          }
        }
        persistence = {
          size             = "10Gi"
          storageClassName = "gp2"
        }
      }
    })
  ]

  depends_on = [module.eks_blueprints_addons]
}

#############################################
# Tempo Deployment
#############################################

resource "helm_release" "tempo" {
  count = var.enable_tempo ? 1 : 0

  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  version    = "1.7.1"
  namespace  = local.monitoring_namespace

  values = [
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.tempo_sa_name
        annotations = {
          "eks.amazonaws.com/role-arn" = module.tempo_irsa[0].iam_role_arn
        }
      }
      tempo = {
        storage = {
          trace = {
            backend = "s3"
            s3 = {
              bucket   = aws_s3_bucket.tempo[0].id
              endpoint = "s3.${data.aws_region.current.name}.amazonaws.com"
            }
          }
        }
      }
    })
  ]

  depends_on = [module.eks_blueprints_addons]
}

#############################################
# PrometheusRule Resources
#############################################
# These resources deploy alert definitions as PrometheusRule CRDs
# when alerting is enabled. Each alert domain is deployed as a
# separate PrometheusRule resource for better organization.

# WordPress Application Alerts
resource "kubernetes_manifest" "wordpress_alerts" {
  count = var.enable_alerting ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "wordpress-alerts"
      namespace = local.monitoring_namespace
      labels = {
        app        = "wordpress"
        component  = "alerts"
        cluster    = var.cluster_name
        prometheus = "kube-prometheus-stack-prometheus"
        role       = "alert-rules"
      }
    }
    spec = yamldecode(file("${path.module}/alerts/wordpress-alerts.yaml"))
  }

  depends_on = [module.eks_blueprints_addons]
}

# Kubernetes Platform Alerts
resource "kubernetes_manifest" "kubernetes_alerts" {
  count = var.enable_alerting ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "kubernetes-alerts"
      namespace = local.monitoring_namespace
      labels = {
        app        = "kubernetes"
        component  = "alerts"
        cluster    = var.cluster_name
        prometheus = "kube-prometheus-stack-prometheus"
        role       = "alert-rules"
      }
    }
    spec = yamldecode(file("${path.module}/alerts/kubernetes-alerts.yaml"))
  }

  depends_on = [module.eks_blueprints_addons]
}

# AWS Services Alerts
resource "kubernetes_manifest" "aws_alerts" {
  count = var.enable_alerting ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "aws-alerts"
      namespace = local.monitoring_namespace
      labels = {
        app        = "aws-services"
        component  = "alerts"
        cluster    = var.cluster_name
        prometheus = "kube-prometheus-stack-prometheus"
        role       = "alert-rules"
      }
    }
    spec = yamldecode(file("${path.module}/alerts/aws-alerts.yaml"))
  }

  depends_on = [module.eks_blueprints_addons]
}

# Cost Guardrail Alerts
resource "kubernetes_manifest" "cost_alerts" {
  count = var.enable_alerting ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "cost-alerts"
      namespace = local.monitoring_namespace
      labels = {
        app        = "cost-guardrails"
        component  = "alerts"
        cluster    = var.cluster_name
        prometheus = "kube-prometheus-stack-prometheus"
        role       = "alert-rules"
      }
    }
    spec = yamldecode(file("${path.module}/alerts/cost-alerts.yaml"))
  }

  depends_on = [module.eks_blueprints_addons]
}

#############################################
# Alertmanager Configuration (Phase 4)
#############################################
# This resource deploys the Alertmanager configuration as a Secret
# when alerting is enabled. The configuration includes routing rules
# based on severity and notification provider setup.

resource "kubernetes_manifest" "alertmanager_config" {
  count = var.enable_alerting ? 1 : 0

  manifest = {
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "alertmanager-kube-prometheus-stack-alertmanager"
      namespace = local.monitoring_namespace
      labels = {
        app        = "alertmanager"
        component  = "config"
        cluster    = var.cluster_name
        managed-by = "terraform"
      }
    }
    data = {
      "alertmanager.yml" = base64encode(templatefile("${path.module}/alertmanager/alertmanager.yaml", {
        notification_provider = var.notification_provider
        slack_webhook_url     = var.slack_webhook_url
        sns_topic_arn         = var.sns_topic_arn
        cluster_name          = var.cluster_name
      }))
    }
    type = "Opaque"
  }

  depends_on = [module.eks_blueprints_addons]
}
