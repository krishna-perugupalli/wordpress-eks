#############################################
# Prometheus Server Sub-module
# Deploys kube-prometheus-stack with persistent storage
#############################################

data "aws_caller_identity" "current" {}

locals {
  prometheus_name = "${var.name}-prometheus"
  oidc_hostpath   = replace(var.cluster_oidc_issuer_url, "https://", "")
  account_id      = data.aws_caller_identity.current.account_id

  # Prometheus configuration
  prometheus_retention = "${var.prometheus_retention_days}d"

  # IRSA role name for Prometheus
  prometheus_role_name = "${var.cluster_name}-prometheus-server"
}

#############################################
# IAM Role for Prometheus Server (IRSA)
#############################################
data "aws_iam_policy_document" "prometheus_assume_role" {
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
      values   = ["system:serviceaccount:${var.namespace}:prometheus-kube-prometheus-prometheus"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "prometheus" {
  name               = local.prometheus_role_name
  assume_role_policy = data.aws_iam_policy_document.prometheus_assume_role.json
  tags = merge(var.tags, {
    Name      = local.prometheus_role_name
    Component = "prometheus"
  })
}

# IAM policy for AWS service discovery and cost metrics
data "aws_iam_policy_document" "prometheus_policy" {
  # CloudWatch metrics access for cost monitoring
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData",
      "cloudwatch:ListMetrics"
    ]
    resources = ["*"]
  }

  # Cost Explorer API access
  statement {
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetUsageReport",
      "ce:GetRightsizingRecommendation",
      "ce:GetReservationCoverage",
      "ce:GetReservationPurchaseRecommendation",
      "ce:GetReservationUtilization"
    ]
    resources = ["*"]
  }

  # EC2 describe permissions for service discovery
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeAvailabilityZones"
    ]
    resources = ["*"]
  }

  # EKS describe permissions
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters"
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

resource "aws_iam_role_policy" "prometheus" {
  name   = "${local.prometheus_role_name}-policy"
  role   = aws_iam_role.prometheus.id
  policy = data.aws_iam_policy_document.prometheus_policy.json
}

#############################################
# Storage Class for Prometheus (if needed)
#############################################
resource "kubernetes_storage_class" "prometheus" {
  count = var.prometheus_storage_class == "prometheus-gp3" ? 1 : 0

  metadata {
    name = "prometheus-gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    kmsKeyId  = var.kms_key_arn != null ? var.kms_key_arn : ""
    fsType    = "ext4"
  }
}

#############################################
# kube-prometheus-stack Helm Release
#############################################
resource "helm_release" "kube_prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "61.3.2" # Latest stable version
  namespace  = var.namespace

  # Wait for CRDs to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # Prometheus server configuration
  values = [
    yamlencode({
      # Global configuration
      global = {
        imageRegistry = ""
      }

      # Prometheus server configuration
      prometheus = {
        enabled = true

        # Service account configuration for IRSA
        serviceAccount = {
          create = true
          name   = "prometheus-kube-prometheus-prometheus"
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.prometheus.arn
          }
        }

        prometheusSpec = {
          # Retention configuration
          retention     = local.prometheus_retention
          retentionSize = "45GB" # Leave some buffer from storage size

          # Resource configuration
          resources = {
            requests = var.prometheus_resource_requests
            limits   = var.prometheus_resource_limits
          }

          # Replica configuration for HA
          replicas = var.prometheus_replica_count

          # Topology spread constraints for multi-AZ deployment
          topologySpreadConstraints = [
            {
              maxSkew           = 1
              topologyKey       = "topology.kubernetes.io/zone"
              whenUnsatisfiable = "DoNotSchedule"
              labelSelector = {
                matchLabels = {
                  app = "prometheus"
                }
              }
            },
            {
              maxSkew           = 1
              topologyKey       = "kubernetes.io/hostname"
              whenUnsatisfiable = "ScheduleAnyway"
              labelSelector = {
                matchLabels = {
                  app = "prometheus"
                }
              }
            }
          ]

          # Pod anti-affinity for HA
          affinity = {
            podAntiAffinity = {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  podAffinityTerm = {
                    labelSelector = {
                      matchExpressions = [
                        {
                          key      = "app"
                          operator = "In"
                          values   = ["prometheus"]
                        }
                      ]
                    }
                    topologyKey = "kubernetes.io/hostname"
                  }
                }
              ]
            }
          }

          # Storage configuration
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.prometheus_storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }

          # Security context
          securityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }

          # Pod security context
          podSecurityContext = {
            runAsNonRoot = true
            runAsUser    = 65534
            fsGroup      = 65534
          }

          # Service discovery configuration
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false

          # Enable service discovery for specified namespaces
          serviceMonitorNamespaceSelector = var.enable_service_discovery ? {
            matchNames = var.service_discovery_namespaces
          } : {}

          podMonitorNamespaceSelector = var.enable_service_discovery ? {
            matchNames = var.service_discovery_namespaces
          } : {}

          # Additional scrape configs for AWS services and Kubernetes components
          additionalScrapeConfigs = {
            name = "additional-scrape-configs"
            key  = "additional-scrape-configs.yaml"
          }

          # Remote write configuration for network resilience
          remoteWrite = var.enable_network_resilience ? [
            {
              url = "http://prometheus-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090/api/v1/write"
              queueConfig = {
                capacity          = var.remote_write_queue_capacity
                maxShards         = 10
                minShards         = 1
                maxSamplesPerSend = 1000
                batchSendDeadline = "5s"
                minBackoff        = "1s"
                maxBackoff        = var.remote_write_max_backoff
                retryOnRateLimit  = true
              }
              writeRelabelConfigs = [
                {
                  sourceLabels = ["__name__"]
                  targetLabel  = "partition_aware"
                  replacement  = "true"
                }
              ]
            }
          ] : []

          # External labels
          externalLabels = {
            cluster     = var.cluster_name
            region      = var.region
            environment = lookup(var.tags, "Environment", "unknown")
          }

          # Storage alerts configuration
          additionalPrometheusRulesMap = {
            "prometheus-storage-alerts" = {
              groups = [
                {
                  name = "prometheus.storage"
                  rules = [
                    {
                      alert = "PrometheusStorageSpaceRunningOut"
                      expr  = "prometheus_tsdb_wal_fsync_duration_seconds{quantile=\"0.5\"} > 0.1"
                      for   = "5m"
                      labels = {
                        severity  = "warning"
                        component = "prometheus"
                      }
                      annotations = {
                        summary     = "Prometheus storage space is running out"
                        description = "Prometheus storage usage is above 80% on {{ $labels.instance }}"
                        runbook_url = "https://runbooks.prometheus.io/runbooks/prometheus/prometheusstoragespacerunningout"
                      }
                    },
                    {
                      alert = "PrometheusStorageSpaceCritical"
                      expr  = "prometheus_tsdb_wal_fsync_duration_seconds{quantile=\"0.9\"} > 0.2"
                      for   = "2m"
                      labels = {
                        severity  = "critical"
                        component = "prometheus"
                      }
                      annotations = {
                        summary     = "Prometheus storage space is critically low"
                        description = "Prometheus storage usage is above 90% on {{ $labels.instance }}"
                        runbook_url = "https://runbooks.prometheus.io/runbooks/prometheus/prometheusstoragespacecritical"
                      }
                    }
                  ]
                }
              ]
            }
          }
        }

        # Service configuration
        service = {
          type = "ClusterIP"
          port = 9090
        }
      }

      # Grafana configuration (disabled in this module, handled separately)
      grafana = {
        enabled = false
      }

      # AlertManager configuration (disabled in this module, handled separately)
      alertmanager = {
        enabled = false
      }

      # Node exporter configuration
      nodeExporter = {
        enabled = true
      }

      # Kube-state-metrics configuration
      kubeStateMetrics = {
        enabled = true
      }

      # Prometheus operator configuration
      prometheusOperator = {
        enabled = true

        # Resource configuration for operator
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }

        # Security context
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 65534
        }
      }

      # Default rules configuration
      defaultRules = {
        create = true
        rules = {
          alertmanager                = false # Handled separately
          etcd                        = true
          configReloaders             = true
          general                     = true
          k8s                         = true
          kubeApiserverAvailability   = true
          kubeApiserverBurnrate       = true
          kubeApiserverHistogram      = true
          kubeApiserverSlos           = true
          kubelet                     = true
          kubeProxy                   = true
          kubePrometheusGeneral       = true
          kubePrometheusNodeRecording = true
          kubernetesApps              = true
          kubernetesResources         = true
          kubernetesStorage           = true
          kubernetesSystem            = true
          kubeScheduler               = true
          kubeStateMetrics            = true
          network                     = true
          node                        = true
          nodeExporterAlerting        = true
          nodeExporterRecording       = true
          prometheus                  = true
          prometheusOperator          = true
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy.prometheus,
    kubernetes_storage_class.prometheus
  ]
}