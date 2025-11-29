#############################################
# AlertManager Sub-module
# Deploys AlertManager with HA configuration and notification integrations
#############################################

data "aws_caller_identity" "current" {}

locals {
  alertmanager_name = "${var.name}-alertmanager"
  oidc_hostpath     = replace(var.cluster_oidc_issuer_url, "https://", "")
  account_id        = data.aws_caller_identity.current.account_id

  # IRSA role name for AlertManager
  alertmanager_role_name = "${var.cluster_name}-alertmanager"

  # Notification receivers configuration
  has_smtp      = var.smtp_config != null
  has_sns       = var.sns_topic_arn != ""
  has_slack     = var.slack_webhook_url != ""
  has_pagerduty = var.pagerduty_integration_key != ""
}

#############################################
# IAM Role for AlertManager (IRSA)
#############################################
data "aws_iam_policy_document" "alertmanager_assume_role" {
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
      values   = ["system:serviceaccount:${var.namespace}:alertmanager-${local.alertmanager_name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "alertmanager" {
  name               = local.alertmanager_role_name
  assume_role_policy = data.aws_iam_policy_document.alertmanager_assume_role.json
  tags = merge(var.tags, {
    Name      = local.alertmanager_role_name
    Component = "alertmanager"
  })
}

# IAM policy for SNS publishing
data "aws_iam_policy_document" "alertmanager_policy" {
  # SNS publish permissions
  dynamic "statement" {
    for_each = local.has_sns ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sns:Publish"
      ]
      resources = [var.sns_topic_arn]
    }
  }

  # KMS permissions for encryption (if KMS key provided)
  dynamic "statement" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ]
      resources = [var.kms_key_arn]
    }
  }
}

resource "aws_iam_role_policy" "alertmanager" {
  name   = "${local.alertmanager_role_name}-policy"
  role   = aws_iam_role.alertmanager.id
  policy = data.aws_iam_policy_document.alertmanager_policy.json
}

#############################################
# Kubernetes Secret for Notification Credentials
#############################################
resource "kubernetes_secret" "alertmanager_notifications" {
  metadata {
    name      = "${local.alertmanager_name}-notifications"
    namespace = var.namespace
  }

  data = {
    # SMTP credentials
    smtp_auth_password = local.has_smtp ? var.smtp_config.auth_password : ""

    # Slack webhook URL
    slack_webhook_url = local.has_slack ? var.slack_webhook_url : ""

    # PagerDuty integration key
    pagerduty_integration_key = local.has_pagerduty ? var.pagerduty_integration_key : ""
  }

  type = "Opaque"
}

#############################################
# AlertManager Configuration
#############################################
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "${local.alertmanager_name}-config"
    namespace = var.namespace
  }

  data = {
    "alertmanager.yml" = yamlencode({
      global = merge(
        {
          resolve_timeout = "5m"
        },
        local.has_smtp ? {
          smtp_smarthost     = var.smtp_config.smarthost
          smtp_from          = var.smtp_config.from
          smtp_auth_username = var.smtp_config.auth_username
          smtp_auth_password = var.smtp_config.auth_password
          smtp_require_tls   = var.smtp_config.require_tls
        } : {}
      )

      route = {
        group_by        = var.alert_routing_config.group_by
        group_wait      = var.alert_routing_config.group_wait
        group_interval  = var.alert_routing_config.group_interval
        repeat_interval = var.alert_routing_config.repeat_interval
        receiver        = "default"

        # Custom routes based on severity and component
        routes = concat(
          [
            # Critical alerts route
            {
              match = {
                severity = "critical"
              }
              receiver        = "critical-alerts"
              group_wait      = "10s"
              group_interval  = "5m"
              repeat_interval = "30m"
              continue        = true
            },
            # Warning alerts route
            {
              match = {
                severity = "warning"
              }
              receiver        = "warning-alerts"
              group_wait      = "30s"
              group_interval  = "10m"
              repeat_interval = "2h"
              continue        = false
            },
            # WordPress component alerts
            {
              match = {
                component = "wordpress"
              }
              receiver        = "wordpress-alerts"
              group_by        = ["alertname", "instance"]
              repeat_interval = "1h"
              continue        = false
            },
            # Database component alerts
            {
              match = {
                component = "database"
              }
              receiver        = "database-alerts"
              group_by        = ["alertname", "instance"]
              repeat_interval = "1h"
              continue        = false
            },
            # Infrastructure alerts
            {
              match = {
                component = "infrastructure"
              }
              receiver        = "infrastructure-alerts"
              group_by        = ["alertname", "node"]
              repeat_interval = "1h"
              continue        = false
            }
          ],
          var.alert_routing_config.routes
        )
      }

      # Inhibition rules to prevent alert storms
      inhibit_rules = [
        {
          source_match = {
            severity = "critical"
          }
          target_match = {
            severity = "warning"
          }
          equal = ["alertname", "cluster", "service"]
        }
      ]

      # Receivers configuration
      receivers = concat(
        [
          # Default receiver
          {
            name = "default"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
                headers = {
                  Subject = "[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }} - {{ .GroupLabels.cluster }}"
                }
                html = <<-EOT
                  <h2>Alert Summary</h2>
                  <p><strong>Status:</strong> {{ .Status }}</p>
                  <p><strong>Cluster:</strong> {{ .GroupLabels.cluster }}</p>
                  <p><strong>Alert:</strong> {{ .GroupLabels.alertname }}</p>
                  
                  <h3>Firing Alerts</h3>
                  {{ range .Alerts.Firing }}
                  <p>
                    <strong>{{ .Labels.alertname }}</strong><br/>
                    {{ .Annotations.summary }}<br/>
                    {{ .Annotations.description }}<br/>
                    <a href="{{ .Annotations.runbook_url }}">Runbook</a>
                  </p>
                  {{ end }}
                  
                  <h3>Resolved Alerts</h3>
                  {{ range .Alerts.Resolved }}
                  <p>
                    <strong>{{ .Labels.alertname }}</strong> - Resolved
                  </p>
                  {{ end }}
                EOT
              }
            ] : []
          },
          # Critical alerts receiver
          {
            name = "critical-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
                headers = {
                  Subject = "[CRITICAL] {{ .GroupLabels.alertname }} - {{ .GroupLabels.cluster }}"
                }
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#alerts-critical"
                send_resolved = true
                title         = "[CRITICAL] {{ .GroupLabels.alertname }}"
                text          = <<-EOT
                  *Cluster:* {{ .GroupLabels.cluster }}
                  *Severity:* {{ .CommonLabels.severity }}
                  
                  {{ range .Alerts }}
                  *Alert:* {{ .Labels.alertname }}
                  *Summary:* {{ .Annotations.summary }}
                  *Description:* {{ .Annotations.description }}
                  *Runbook:* {{ .Annotations.runbook_url }}
                  {{ end }}
                EOT
              }
            ] : []
            pagerduty_configs = local.has_pagerduty ? [
              {
                service_key   = var.pagerduty_integration_key
                send_resolved = true
                description   = "{{ .GroupLabels.alertname }} - {{ .GroupLabels.cluster }}"
                details = {
                  firing    = "{{ .Alerts.Firing | len }}"
                  resolved  = "{{ .Alerts.Resolved | len }}"
                  cluster   = "{{ .GroupLabels.cluster }}"
                  severity  = "{{ .CommonLabels.severity }}"
                  component = "{{ .CommonLabels.component }}"
                }
              }
            ] : []
            sns_configs = local.has_sns ? [
              {
                topic_arn     = var.sns_topic_arn
                send_resolved = true
                subject       = "[CRITICAL] {{ .GroupLabels.alertname }}"
                message       = <<-EOT
                  Alert: {{ .GroupLabels.alertname }}
                  Cluster: {{ .GroupLabels.cluster }}
                  Severity: {{ .CommonLabels.severity }}
                  
                  {{ range .Alerts }}
                  Summary: {{ .Annotations.summary }}
                  Description: {{ .Annotations.description }}
                  Runbook: {{ .Annotations.runbook_url }}
                  {{ end }}
                EOT
              }
            ] : []
          },
          # Warning alerts receiver
          {
            name = "warning-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
                headers = {
                  Subject = "[WARNING] {{ .GroupLabels.alertname }} - {{ .GroupLabels.cluster }}"
                }
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#alerts-warning"
                send_resolved = true
                title         = "[WARNING] {{ .GroupLabels.alertname }}"
                text          = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
              }
            ] : []
          },
          # WordPress alerts receiver
          {
            name = "wordpress-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
                headers = {
                  Subject = "[WordPress] {{ .GroupLabels.alertname }}"
                }
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#wordpress-alerts"
                send_resolved = true
                title         = "[WordPress] {{ .GroupLabels.alertname }}"
              }
            ] : []
          },
          # Database alerts receiver
          {
            name = "database-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
                headers = {
                  Subject = "[Database] {{ .GroupLabels.alertname }}"
                }
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#database-alerts"
                send_resolved = true
                title         = "[Database] {{ .GroupLabels.alertname }}"
              }
            ] : []
          },
          # Infrastructure alerts receiver
          {
            name = "infrastructure-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
                headers = {
                  Subject = "[Infrastructure] {{ .GroupLabels.alertname }}"
                }
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#infrastructure-alerts"
                send_resolved = true
                title         = "[Infrastructure] {{ .GroupLabels.alertname }}"
              }
            ] : []
          }
        ]
      )
    })
  }
}

#############################################
# Storage Class for AlertManager (if needed)
#############################################
resource "kubernetes_storage_class" "alertmanager" {
  count = var.alertmanager_storage_class == "alertmanager-gp3" ? 1 : 0

  metadata {
    name = "alertmanager-gp3"
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
# AlertManager Helm Release
#############################################
resource "helm_release" "alertmanager" {
  name       = local.alertmanager_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "alertmanager"
  version    = "1.12.0" # Latest stable version
  namespace  = var.namespace

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  values = [
    yamlencode({
      # Service account configuration for IRSA
      serviceAccount = {
        create = true
        name   = "alertmanager-${local.alertmanager_name}"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alertmanager.arn
        }
      }

      # Replica configuration for high availability
      replicaCount = var.alertmanager_replica_count

      # Resource configuration
      resources = {
        requests = var.alertmanager_resource_requests
        limits   = var.alertmanager_resource_limits
      }

      # Persistence configuration
      persistence = {
        enabled      = true
        storageClass = var.alertmanager_storage_class
        accessMode   = "ReadWriteOnce"
        size         = var.alertmanager_storage_size
        persistentVolume = {
          enabled = true
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

      # Configuration
      config = {
        global = merge(
          {
            resolve_timeout = "5m"
          },
          local.has_smtp ? {
            smtp_smarthost     = var.smtp_config.smarthost
            smtp_from          = var.smtp_config.from
            smtp_auth_username = var.smtp_config.auth_username
            smtp_auth_password = var.smtp_config.auth_password
            smtp_require_tls   = var.smtp_config.require_tls
          } : {}
        )

        route = {
          group_by        = var.alert_routing_config.group_by
          group_wait      = var.alert_routing_config.group_wait
          group_interval  = var.alert_routing_config.group_interval
          repeat_interval = var.alert_routing_config.repeat_interval
          receiver        = "default"

          routes = concat(
            [
              {
                match = {
                  severity = "critical"
                }
                receiver        = "critical-alerts"
                group_wait      = "10s"
                group_interval  = "5m"
                repeat_interval = "30m"
                continue        = true
              },
              {
                match = {
                  severity = "warning"
                }
                receiver        = "warning-alerts"
                group_wait      = "30s"
                group_interval  = "10m"
                repeat_interval = "2h"
                continue        = false
              },
              {
                match = {
                  component = "wordpress"
                }
                receiver        = "wordpress-alerts"
                group_by        = ["alertname", "instance"]
                repeat_interval = "1h"
                continue        = false
              },
              {
                match = {
                  component = "database"
                }
                receiver        = "database-alerts"
                group_by        = ["alertname", "instance"]
                repeat_interval = "1h"
                continue        = false
              },
              {
                match = {
                  component = "infrastructure"
                }
                receiver        = "infrastructure-alerts"
                group_by        = ["alertname", "node"]
                repeat_interval = "1h"
                continue        = false
              }
            ],
            var.alert_routing_config.routes
          )
        }

        inhibit_rules = [
          {
            source_match = {
              severity = "critical"
            }
            target_match = {
              severity = "warning"
            }
            equal = ["alertname", "cluster", "service"]
          }
        ]

        receivers = [
          {
            name = "default"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
              }
            ] : []
          },
          {
            name = "critical-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#alerts-critical"
                send_resolved = true
              }
            ] : []
            pagerduty_configs = local.has_pagerduty ? [
              {
                service_key   = var.pagerduty_integration_key
                send_resolved = true
              }
            ] : []
            sns_configs = local.has_sns ? [
              {
                topic_arn     = var.sns_topic_arn
                send_resolved = true
              }
            ] : []
          },
          {
            name = "warning-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#alerts-warning"
                send_resolved = true
              }
            ] : []
          },
          {
            name = "wordpress-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#wordpress-alerts"
                send_resolved = true
              }
            ] : []
          },
          {
            name = "database-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#database-alerts"
                send_resolved = true
              }
            ] : []
          },
          {
            name = "infrastructure-alerts"
            email_configs = local.has_smtp ? [
              {
                to            = var.smtp_config.from
                send_resolved = true
              }
            ] : []
            slack_configs = local.has_slack ? [
              {
                api_url       = var.slack_webhook_url
                channel       = "#infrastructure-alerts"
                send_resolved = true
              }
            ] : []
          }
        ]
      }

      # Service configuration
      service = {
        type = "ClusterIP"
        port = 9093
      }

      # Ingress configuration (disabled by default)
      ingress = {
        enabled = false
      }

      # Pod annotations
      podAnnotations = {
        "prometheus.io/scrape" = "true"
        "prometheus.io/port"   = "9093"
      }

      # Pod labels
      podLabels = {
        app       = "alertmanager"
        component = "alerting"
      }

      # Topology spread constraints for multi-AZ deployment
      topologySpreadConstraints = [
        {
          maxSkew           = 1
          topologyKey       = "topology.kubernetes.io/zone"
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              app = "alertmanager"
            }
          }
        },
        {
          maxSkew           = 1
          topologyKey       = "kubernetes.io/hostname"
          whenUnsatisfiable = "ScheduleAnyway"
          labelSelector = {
            matchLabels = {
              app = "alertmanager"
            }
          }
        }
      ]

      # Affinity for HA deployment
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
                      values   = ["alertmanager"]
                    }
                  ]
                }
                topologyKey = "kubernetes.io/hostname"
              }
            }
          ]
        }
      }

      # Liveness and readiness probes for automatic recovery
      livenessProbe = {
        httpGet = {
          path = "/-/healthy"
          port = 9093
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
        timeoutSeconds      = 5
        failureThreshold    = 6
      }

      readinessProbe = {
        httpGet = {
          path = "/-/ready"
          port = 9093
        }
        initialDelaySeconds = 15
        periodSeconds       = 5
        timeoutSeconds      = 3
        failureThreshold    = 3
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy.alertmanager,
    kubernetes_secret.alertmanager_notifications,
    kubernetes_config_map.alertmanager_config,
    kubernetes_storage_class.alertmanager
  ]
}