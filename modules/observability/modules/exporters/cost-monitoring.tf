#############################################
# AWS Cost Monitoring and Optimization
# Integrates with AWS Cost Explorer API
#############################################

# IAM Role for Cost Monitoring
data "aws_iam_policy_document" "cost_monitoring_assume_role" {
  count = var.enable_cost_monitoring ? 1 : 0

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
      values   = ["system:serviceaccount:${var.namespace}:cost-monitoring"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cost_monitoring" {
  count = var.enable_cost_monitoring ? 1 : 0

  name               = "${var.name}-cost-monitoring"
  assume_role_policy = data.aws_iam_policy_document.cost_monitoring_assume_role[0].json

  tags = merge(
    var.tags,
    {
      Name      = "${var.name}-cost-monitoring"
      Component = "monitoring"
      Service   = "cost-monitoring"
    }
  )
}

# IAM Policy for Cost Monitoring
data "aws_iam_policy_document" "cost_monitoring" {
  count = var.enable_cost_monitoring ? 1 : 0

  # Cost Explorer API permissions
  statement {
    sid    = "CostExplorerRead"
    effect = "Allow"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
      "ce:GetDimensionValues",
      "ce:GetTags",
      "ce:GetCostCategories"
    ]
    resources = ["*"]
  }

  # CloudWatch billing metrics
  statement {
    sid    = "CloudWatchBillingRead"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics"
    ]
    resources = ["*"]
  }

  # Resource tagging for cost allocation
  statement {
    sid    = "ResourceTagging"
    effect = "Allow"
    actions = [
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues"
    ]
    resources = ["*"]
  }

  # Service-specific cost tracking
  statement {
    sid    = "ServiceCostTracking"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters",
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeReplicationGroups",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticfilesystem:DescribeFileSystems",
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cost_monitoring" {
  count = var.enable_cost_monitoring ? 1 : 0

  name   = "cost-monitoring-policy"
  role   = aws_iam_role.cost_monitoring[0].id
  policy = data.aws_iam_policy_document.cost_monitoring[0].json
}

# ServiceAccount for Cost Monitoring
resource "kubernetes_service_account" "cost_monitoring" {
  count = var.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "cost-monitoring"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cost_monitoring[0].arn
    }
    labels = {
      app       = "cost-monitoring"
      component = "metrics"
    }
  }
}

# Cost Monitoring ConfigMap
resource "kubernetes_config_map" "cost_monitoring_config" {
  count = var.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "cost-monitoring-config"
    namespace = var.namespace
    labels = {
      app       = "cost-monitoring"
      component = "config"
    }
  }

  data = {
    "config.yaml" = yamlencode({
      aws_region = var.region

      # Cost allocation tags for filtering
      cost_allocation_tags = var.cost_allocation_tags

      # Metrics collection configuration
      collection = {
        interval_seconds = 3600 # Collect every hour
        lookback_days    = 7    # Look back 7 days for trends
      }

      # Service-specific cost tracking
      services = [
        {
          name       = "EC2"
          namespace  = "AWS/EC2"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["InstanceType", "AvailabilityZone"]
        },
        {
          name       = "RDS"
          namespace  = "AWS/RDS"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["DBInstanceClass", "Engine"]
        },
        {
          name       = "ElastiCache"
          namespace  = "AWS/ElastiCache"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["CacheNodeType"]
        },
        {
          name       = "ELB"
          namespace  = "AWS/ELB"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["LoadBalancerName"]
        },
        {
          name       = "EFS"
          namespace  = "AWS/EFS"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["FileSystemId"]
        },
        {
          name       = "EBS"
          namespace  = "AWS/EBS"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["VolumeType"]
        },
        {
          name       = "S3"
          namespace  = "AWS/S3"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["BucketName", "StorageType"]
        },
        {
          name       = "NAT Gateway"
          namespace  = "AWS/NATGateway"
          metrics    = ["UnblendedCost", "UsageQuantity"]
          dimensions = ["NatGatewayId"]
        }
      ]

      # Cost optimization thresholds
      optimization = {
        # Underutilization thresholds
        ec2_cpu_threshold        = 20  # CPU < 20% for 7 days
        rds_connection_threshold = 10  # Connections < 10 for 7 days
        ebs_iops_threshold       = 100 # IOPS < 100 for 7 days

        # Cost increase alerts
        daily_cost_increase_pct   = 20 # Alert if daily cost increases > 20%
        weekly_cost_increase_pct  = 15 # Alert if weekly cost increases > 15%
        monthly_cost_increase_pct = 10 # Alert if monthly cost increases > 10%
      }

      # Karpenter spot instance tracking
      karpenter = {
        track_spot_savings          = true
        spot_vs_ondemand_comparison = true
      }
    })
  }
}

# Cost Exporter Script ConfigMap
resource "kubernetes_config_map" "cost_exporter_script" {
  count = var.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "cost-exporter-script"
    namespace = var.namespace
    labels = {
      app       = "cost-monitoring"
      component = "script"
    }
  }

  data = {
    "exporter.py" = file("${path.module}/files/cost-exporter.py")
  }
}

# Cost Monitoring Deployment
resource "kubectl_manifest" "cost_monitoring_deployment" {
  count = var.enable_cost_monitoring ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "cost-monitoring"
      namespace = var.namespace
      labels = {
        app       = "cost-monitoring"
        component = "metrics"
        version   = "v1.0.0"
      }
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = {
          app = "cost-monitoring"
        }
      }
      template = {
        metadata = {
          labels = {
            app       = "cost-monitoring"
            component = "metrics"
          }
          annotations = {
            "prometheus.io/scrape" = "true"
            "prometheus.io/port"   = "9090"
            "prometheus.io/path"   = "/metrics"
          }
        }
        spec = {
          serviceAccountName = kubernetes_service_account.cost_monitoring[0].metadata[0].name
          containers = [
            {
              name  = "cost-exporter"
              image = "python:3.11-slim"
              command = ["/bin/bash", "-c"]
              args = [
                "pip install --no-cache-dir boto3==1.34.0 prometheus_client==0.19.0 pyyaml==6.0.1 || { echo 'Failed to install Python dependencies'; exit 1; } && python /app/exporter.py"
              ]
              ports = [
                {
                  name          = "metrics"
                  containerPort = 9090
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
                },
                {
                  name  = "CONFIG_FILE"
                  value = "/config/config.yaml"
                },
                {
                  name  = "METRICS_PORT"
                  value = "9090"
                }
              ]
              volumeMounts = [
                {
                  name      = "config"
                  mountPath = "/config"
                  readOnly  = true
                },
                {
                  name      = "app"
                  mountPath = "/app"
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
                  port = 9090
                }
                initialDelaySeconds = 60
                periodSeconds       = 60
                timeoutSeconds      = 10
                failureThreshold    = 3
              }
              readinessProbe = {
                httpGet = {
                  path = "/metrics"
                  port = 9090
                }
                initialDelaySeconds = 60
                periodSeconds       = 30
                timeoutSeconds      = 10
                failureThreshold    = 3
              }
              securityContext = {
                runAsNonRoot             = true
                runAsUser                = 65534
                readOnlyRootFilesystem   = false
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
                name = kubernetes_config_map.cost_monitoring_config[0].metadata[0].name
                items = [
                  {
                    key  = "config.yaml"
                    path = "config.yaml"
                  }
                ]
              }
            },
            {
              name = "app"
              configMap = {
                name = kubernetes_config_map.cost_exporter_script[0].metadata[0].name
                items = [
                  {
                    key  = "exporter.py"
                    path = "exporter.py"
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

# Cost Monitoring Service
resource "kubernetes_service" "cost_monitoring" {
  count = var.enable_cost_monitoring ? 1 : 0

  metadata {
    name      = "cost-monitoring"
    namespace = var.namespace
    labels = {
      app       = "cost-monitoring"
      component = "metrics"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9090"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      app = "cost-monitoring"
    }

    port {
      name        = "metrics"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Cost Monitoring ServiceMonitor
resource "kubectl_manifest" "cost_monitoring_servicemonitor" {
  count = var.enable_cost_monitoring ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "cost-monitoring"
      namespace = var.namespace
      labels = {
        app       = "cost-monitoring"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "cost-monitoring"
        }
      }
      namespaceSelector = {
        matchNames = [var.namespace]
      }
      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "300s" # Collect every 5 minutes
          scrapeTimeout = "60s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "aws_cost_.*|aws_usage_.*|aws_optimization_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}
