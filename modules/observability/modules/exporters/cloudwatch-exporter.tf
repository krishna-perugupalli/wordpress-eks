#############################################
# CloudWatch Exporter for AWS Service Metrics
# Collects metrics from ALB, RDS, ElastiCache, EFS
#############################################

# IAM Role for CloudWatch Exporter
data "aws_iam_policy_document" "cloudwatch_exporter_assume_role" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:cloudwatch-exporter"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_exporter" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  name               = "${var.name}-cloudwatch-exporter"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_exporter_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name      = "${var.name}-cloudwatch-exporter"
      Component = "monitoring"
      Service   = "cloudwatch-exporter"
    }
  )
}

# IAM Policy for CloudWatch Exporter
data "aws_iam_policy_document" "cloudwatch_exporter" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  # CloudWatch metrics read permissions
  statement {
    sid    = "CloudWatchMetricsRead"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics"
    ]
    resources = ["*"]
  }

  # Resource discovery permissions
  statement {
    sid    = "ResourceDiscovery"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeTags",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTags",
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "rds:ListTagsForResource",
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeReplicationGroups",
      "elasticache:ListTagsForResource",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeTags",
      "cloudfront:ListDistributions",
      "cloudfront:ListTagsForResource",
      "cloudfront:GetDistribution",
      "tag:GetResources"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_exporter" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  name   = "cloudwatch-exporter-policy"
  role   = aws_iam_role.cloudwatch_exporter[0].id
  policy = data.aws_iam_policy_document.cloudwatch_exporter[0].json
}

# ServiceAccount for CloudWatch Exporter
resource "kubernetes_service_account" "cloudwatch_exporter" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  metadata {
    name      = "cloudwatch-exporter"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cloudwatch_exporter[0].arn
    }
    labels = {
      app       = "cloudwatch-exporter"
      component = "metrics"
    }
  }
}

# CloudWatch Exporter ConfigMap
resource "kubernetes_config_map" "cloudwatch_exporter_config" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  metadata {
    name      = "cloudwatch-exporter-config"
    namespace = var.namespace
    labels = {
      app       = "cloudwatch-exporter"
      component = "config"
    }
  }

  data = {
    "config.yml" = yamlencode({
      region = var.region
      metrics = concat(
        # ALB metrics
        [
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "RequestCount"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "TargetResponseTime"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "HTTPCode_Target_2XX_Count"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "HTTPCode_Target_4XX_Count"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "HTTPCode_Target_5XX_Count"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "TargetConnectionErrorCount"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ApplicationELB"
            aws_metric_name = "ActiveConnectionCount"
            aws_dimensions  = ["LoadBalancer"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
        ],
        # RDS/Aurora metrics
        [
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "CPUUtilization"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "DatabaseConnections"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "FreeableMemory"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "ReadLatency"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "WriteLatency"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "ReadIOPS"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/RDS"
            aws_metric_name = "WriteIOPS"
            aws_dimensions  = ["DBClusterIdentifier"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
        ],
        # ElastiCache metrics
        [
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "CPUUtilization"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "DatabaseMemoryUsagePercentage"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "CurrConnections"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "CacheHits"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "CacheMisses"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "NetworkBytesIn"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/ElastiCache"
            aws_metric_name = "NetworkBytesOut"
            aws_dimensions  = ["ReplicationGroupId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
        ],
        # EFS metrics
        [
          {
            aws_namespace   = "AWS/EFS"
            aws_metric_name = "ClientConnections"
            aws_dimensions  = ["FileSystemId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/EFS"
            aws_metric_name = "DataReadIOBytes"
            aws_dimensions  = ["FileSystemId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/EFS"
            aws_metric_name = "DataWriteIOBytes"
            aws_dimensions  = ["FileSystemId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/EFS"
            aws_metric_name = "MetadataIOBytes"
            aws_dimensions  = ["FileSystemId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/EFS"
            aws_metric_name = "PercentIOLimit"
            aws_dimensions  = ["FileSystemId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/EFS"
            aws_metric_name = "BurstCreditBalance"
            aws_dimensions  = ["FileSystemId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
        ],
        # CloudFront metrics
        [
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "Requests"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "BytesDownloaded"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "BytesUploaded"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Sum"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "4xxErrorRate"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "5xxErrorRate"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "TotalErrorRate"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "CacheHitRate"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
          {
            aws_namespace   = "AWS/CloudFront"
            aws_metric_name = "OriginLatency"
            aws_dimensions  = ["DistributionId"]
            aws_statistics  = ["Average"]
            period_seconds  = 300
            range_seconds   = 600
            set_timestamp   = true
          },
        ],
        # Custom metrics from config if provided
        var.cloudwatch_metrics_config != null ? [
          for job in var.cloudwatch_metrics_config.discovery_jobs : {
            aws_namespace  = job.type
            aws_dimensions = keys(job.search_tags)
            aws_statistics = ["Average", "Sum"]
            period_seconds = 300
            range_seconds  = 600
            set_timestamp  = true
          }
        ] : []
      )

      # Discovery configuration
      discovery = {
        jobs = var.cloudwatch_metrics_config != null ? [
          for job in var.cloudwatch_metrics_config.discovery_jobs : {
            type        = job.type
            regions     = job.regions
            search_tags = job.search_tags
            custom_tags = job.custom_tags
            metrics     = job.metrics
          }
        ] : []
      }
    })
  }
}

# CloudWatch Exporter Deployment
resource "kubectl_manifest" "cloudwatch_exporter_deployment" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "cloudwatch-exporter"
      namespace = var.namespace
      labels = {
        app       = "cloudwatch-exporter"
        component = "metrics"
        version   = "v0.15.5"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "cloudwatch-exporter"
        }
      }
      template = {
        metadata = {
          labels = {
            app       = "cloudwatch-exporter"
            component = "metrics"
          }
          annotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = "9106"
            "prometheus.io/path"   = "/metrics"
          }
        }
        spec = {
          serviceAccountName = kubernetes_service_account.cloudwatch_exporter[0].metadata[0].name
          containers = [
            {
              name  = "cloudwatch-exporter"
              image = "prom/cloudwatch-exporter:v0.15.5"
              args = [
                "--config.file=/config/config.yml"
              ]
              ports = [
                {
                  name          = "metrics"
                  containerPort = 9106
                  protocol      = "TCP"
                }
              ]
              env = [
                {
                  name  = "AWS_REGION"
                  value = var.region
                },
                {
                  name  = "AWS_SDK_LOAD_CONFIG"
                  value = "true"
                }
              ]
              volumeMounts = [
                {
                  name      = "config"
                  mountPath = "/config"
                  readOnly  = true
                }
              ]
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
              livenessProbe = {
                httpGet = {
                  path = "/metrics"
                  port = 9106
                }
                initialDelaySeconds = 30
                periodSeconds       = 30
                timeoutSeconds      = 10
                failureThreshold    = 3
              }
              readinessProbe = {
                httpGet = {
                  path = "/metrics"
                  port = 9106
                }
                initialDelaySeconds = 5
                periodSeconds       = 10
                timeoutSeconds      = 5
                failureThreshold    = 3
              }
              securityContext = {
                runAsNonRoot             = true
                runAsUser                = 65534
                readOnlyRootFilesystem   = true
                allowPrivilegeEscalation = false
                capabilities = {
                  drop = ["ALL"]
                }
              }
            }
          ]
          volumes = [
            {
              name = "config"
              configMap = {
                name = kubernetes_config_map.cloudwatch_exporter_config[0].metadata[0].name
                items = [
                  {
                    key  = "config.yml"
                    path = "config.yml"
                  }
                ]
              }
            }
          ]
          securityContext = {
            fsGroup = 65534
          }
          restartPolicy = "Always"
        }
      }
    }
  })
}

# CloudWatch Exporter Service
resource "kubernetes_service" "cloudwatch_exporter" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  metadata {
    name      = "cloudwatch-exporter"
    namespace = var.namespace
    labels = {
      app       = "cloudwatch-exporter"
      component = "metrics"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9106"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      app = "cloudwatch-exporter"
    }

    port {
      name        = "metrics"
      port        = 9106
      target_port = 9106
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}
