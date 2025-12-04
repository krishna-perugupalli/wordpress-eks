#############################################
# Security Sub-module
# Implements security and compliance features:
# - TLS encryption for metric communications
# - PII scrubbing for collected metrics
# - Audit logging for monitoring system access
# - RBAC policies for access control
#############################################

locals {
  security_name = "${var.name}-security"

  # TLS certificate names
  prometheus_tls_secret   = "prometheus-tls"
  grafana_tls_secret      = "grafana-tls"
  alertmanager_tls_secret = "alertmanager-tls"
}

#############################################
# TLS Certificates for Monitoring Components
#############################################

# Certificate for Prometheus
resource "kubectl_manifest" "prometheus_certificate" {
  count = var.enable_tls_encryption ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "prometheus-server-tls"
      namespace = var.namespace
    }
    spec = {
      secretName = local.prometheus_tls_secret
      issuerRef = {
        name = var.tls_cert_manager_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        "prometheus-kube-prometheus-prometheus.${var.namespace}.svc",
        "prometheus-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local"
      ]
      usages = [
        "digital signature",
        "key encipherment",
        "server auth",
        "client auth"
      ]
    }
  })
}

# Certificate for Grafana
resource "kubectl_manifest" "grafana_certificate" {
  count = var.enable_tls_encryption ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "grafana-tls"
      namespace = var.namespace
    }
    spec = {
      secretName = local.grafana_tls_secret
      issuerRef = {
        name = var.tls_cert_manager_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        "grafana.${var.namespace}.svc",
        "grafana.${var.namespace}.svc.cluster.local"
      ]
      usages = [
        "digital signature",
        "key encipherment",
        "server auth",
        "client auth"
      ]
    }
  })
}

# Certificate for AlertManager
resource "kubectl_manifest" "alertmanager_certificate" {
  count = var.enable_tls_encryption ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "alertmanager-tls"
      namespace = var.namespace
    }
    spec = {
      secretName = local.alertmanager_tls_secret
      issuerRef = {
        name = var.tls_cert_manager_issuer
        kind = "ClusterIssuer"
      }
      dnsNames = [
        "alertmanager-operated.${var.namespace}.svc",
        "alertmanager-operated.${var.namespace}.svc.cluster.local"
      ]
      usages = [
        "digital signature",
        "key encipherment",
        "server auth",
        "client auth"
      ]
    }
  })
}

#############################################
# PII Scrubbing Configuration
#############################################

# ConfigMap for PII scrubbing rules
resource "kubernetes_config_map" "pii_scrubbing_rules" {
  count = var.enable_pii_scrubbing ? 1 : 0

  metadata {
    name      = "${local.security_name}-pii-rules"
    namespace = var.namespace
    labels = {
      app       = "monitoring"
      component = "security"
    }
  }

  data = {
    "pii-scrubbing-rules.yaml" = yamlencode({
      rules = var.pii_scrubbing_rules
    })
  }
}

# Prometheus relabel configuration for PII scrubbing
resource "kubernetes_config_map" "prometheus_pii_relabel" {
  count = var.enable_pii_scrubbing ? 1 : 0

  metadata {
    name      = "${local.security_name}-prometheus-pii-relabel"
    namespace = var.namespace
    labels = {
      app       = "monitoring"
      component = "security"
    }
  }

  data = {
    "relabel-config.yaml" = yamlencode({
      # Relabel configurations to scrub PII from metric labels
      metric_relabel_configs = [
        # Remove email addresses from labels
        {
          source_labels = ["__name__"]
          regex         = ".*email.*"
          action        = "labeldrop"
        },
        # Remove user identifiable information
        {
          source_labels = ["user", "username", "user_id"]
          regex         = ".*"
          replacement   = "[REDACTED]"
          target_label  = "__tmp_user"
        },
        # Remove IP addresses from labels
        {
          source_labels = ["ip", "client_ip", "remote_addr"]
          regex         = ".*"
          replacement   = "[IP_REDACTED]"
          target_label  = "__tmp_ip"
        }
      ]
    })
  }
}

#############################################
# Audit Logging Configuration
#############################################

# CloudWatch Log Group for audit logs
resource "aws_cloudwatch_log_group" "audit_logs" {
  count = var.enable_audit_logging ? 1 : 0

  name              = "/aws/eks/${var.cluster_name}/monitoring-audit"
  retention_in_days = var.audit_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-monitoring-audit"
    Component = "security"
    Purpose   = "audit-logging"
  })
}

# Fluent Bit configuration for audit log collection
resource "kubernetes_config_map" "audit_log_config" {
  count = var.enable_audit_logging ? 1 : 0

  metadata {
    name      = "${local.security_name}-audit-config"
    namespace = var.namespace
    labels = {
      app       = "monitoring"
      component = "security"
    }
  }

  data = {
    "audit-logging.conf" = <<-EOT
      [INPUT]
          Name              tail
          Tag               audit.grafana
          Path              /var/log/grafana/grafana.log
          Parser            json
          DB                /var/log/flb_grafana_audit.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               audit.prometheus
          Path              /var/log/prometheus/prometheus.log
          Parser            json
          DB                /var/log/flb_prometheus_audit.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [FILTER]
          Name              record_modifier
          Match             audit.*
          Record            cluster_name ${var.cluster_name}
          Record            region ${var.region}
          Record            namespace ${var.namespace}

      [FILTER]
          Name              grep
          Match             audit.*
          Regex             level (info|warn|error)

      [OUTPUT]
          Name              cloudwatch_logs
          Match             audit.*
          region            ${var.region}
          log_group_name    ${var.enable_audit_logging ? aws_cloudwatch_log_group.audit_logs[0].name : ""}
          log_stream_prefix audit-
          auto_create_group false
    EOT
  }
}

# DaemonSet for audit log collection
resource "kubernetes_daemonset" "audit_collector" {
  count = var.enable_audit_logging ? 1 : 0

  metadata {
    name      = "${local.security_name}-audit-collector"
    namespace = var.namespace
    labels = {
      app       = "monitoring"
      component = "audit-collector"
    }
  }

  spec {
    selector {
      match_labels = {
        app       = "monitoring"
        component = "audit-collector"
      }
    }

    template {
      metadata {
        labels = {
          app       = "monitoring"
          component = "audit-collector"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.audit_collector[0].metadata[0].name

        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:2.31.12"

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc/"
            read_only  = true
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }

          security_context {
            # Need root to read host logs
            run_as_user                = 0
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.audit_log_config[0].metadata[0].name
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        security_context {
          # Need root access to read host /var/log
          run_as_user = 0
          fs_group    = 0
        }
      }
    }
  }
}

# Service Account for audit collector
resource "kubernetes_service_account" "audit_collector" {
  count = var.enable_audit_logging ? 1 : 0

  metadata {
    name      = "${local.security_name}-audit-collector"
    namespace = var.namespace
  }
}

# ClusterRole for audit collector
resource "kubernetes_cluster_role" "audit_collector" {
  count = var.enable_audit_logging ? 1 : 0

  metadata {
    name = "${local.security_name}-audit-collector"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for audit collector
resource "kubernetes_cluster_role_binding" "audit_collector" {
  count = var.enable_audit_logging ? 1 : 0

  metadata {
    name = "${local.security_name}-audit-collector"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.audit_collector[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.audit_collector[0].metadata[0].name
    namespace = var.namespace
  }
}

#############################################
# RBAC Policies for Monitoring Access
#############################################

# Create custom RBAC policies for monitoring access
resource "kubernetes_role_binding" "custom_rbac" {
  for_each = var.rbac_policies

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  role_ref {
    api_group = each.value.role_ref.api_group
    kind      = each.value.role_ref.kind
    name      = each.value.role_ref.name
  }

  dynamic "subject" {
    for_each = each.value.subjects
    content {
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = subject.value.namespace
    }
  }
}

# Default monitoring viewer role
resource "kubernetes_role" "monitoring_viewer" {
  metadata {
    name      = "${local.security_name}-viewer"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["monitoring.coreos.com"]
    resources  = ["servicemonitors", "podmonitors", "prometheusrules"]
    verbs      = ["get", "list", "watch"]
  }
}

# Default monitoring admin role
resource "kubernetes_role" "monitoring_admin" {
  metadata {
    name      = "${local.security_name}-admin"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "configmaps", "secrets"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["monitoring.coreos.com"]
    resources  = ["servicemonitors", "podmonitors", "prometheusrules", "alertmanagers", "prometheuses"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }
}

#############################################
# Network Policies for Secure Communication
#############################################

# Network policy to restrict Prometheus access
resource "kubernetes_network_policy" "prometheus_ingress" {
  count = var.enable_tls_encryption ? 1 : 0

  metadata {
    name      = "${local.security_name}-prometheus-ingress"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        app = "kube-prometheus-stack-prometheus"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "grafana"
          }
        }
      }

      from {
        pod_selector {
          match_labels = {
            app = "kube-prometheus-stack-alertmanager"
          }
        }
      }

      from {
        namespace_selector {
          match_labels = {
            name = var.namespace
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "9090"
      }
    }
  }
}

# Network policy to restrict Grafana access
resource "kubernetes_network_policy" "grafana_ingress" {
  count = var.enable_tls_encryption ? 1 : 0

  metadata {
    name      = "${local.security_name}-grafana-ingress"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "grafana"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        namespace_selector {}
      }

      ports {
        protocol = "TCP"
        port     = "3000"
      }
    }
  }
}

#############################################
# Pod Security Standards (PSS)
#############################################
# NOTE: Using "privileged" for observability namespace because:
# - Audit collector DaemonSet requires hostPath volumes to read /var/log
# - Monitoring components need host-level access for metrics collection
# - This is a dedicated monitoring namespace with controlled access

resource "kubernetes_labels" "namespace_pss" {
  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = var.namespace
  }

  labels = {
    # Use privileged for monitoring namespace that needs host access
    # This is required for DaemonSets that need hostPath volumes
    "pod-security.kubernetes.io/enforce" = "privileged"
    "pod-security.kubernetes.io/enforce-version" = "latest"
    
    # Audit mode logs violations without blocking
    "pod-security.kubernetes.io/audit" = "privileged"
    "pod-security.kubernetes.io/audit-version" = "latest"
    
    # Warn mode shows warnings to users
    "pod-security.kubernetes.io/warn" = "privileged"
    "pod-security.kubernetes.io/warn-version" = "latest"
  }
}

# Alternative: Use baseline for less restrictive enforcement
# Uncomment below and comment above if restricted is too strict
#
# resource "kubernetes_labels" "namespace_pss_baseline" {
#   api_version = "v1"
#   kind        = "Namespace"
#   metadata {
#     name = var.namespace
#   }
#
#   labels = {
#     "pod-security.kubernetes.io/enforce" = "baseline"
#     "pod-security.kubernetes.io/enforce-version" = "latest"
#     "pod-security.kubernetes.io/audit" = "baseline"
#     "pod-security.kubernetes.io/audit-version" = "latest"
#     "pod-security.kubernetes.io/warn" = "baseline"
#     "pod-security.kubernetes.io/warn-version" = "latest"
#   }
# }