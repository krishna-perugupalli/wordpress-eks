#############################################
# Exporters Sub-module
# Service Discovery and Metrics Collection
#############################################

locals {
  exporters_name = "${var.name}-exporters"
}

#############################################
# ServiceMonitor CRDs for Application Services
#############################################

# WordPress ServiceMonitor
resource "kubectl_manifest" "wordpress_servicemonitor" {
  count = var.enable_wordpress_exporter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "wordpress-metrics"
      namespace = var.namespace
      labels = {
        app       = "wordpress"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "wordpress"
        }
      }
      namespaceSelector = {
        matchNames = [var.wordpress_namespace]
      }
      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "wordpress_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# MySQL/Aurora ServiceMonitor
resource "kubectl_manifest" "mysql_servicemonitor" {
  count = var.enable_mysql_exporter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "mysql-metrics"
      namespace = var.namespace
      labels = {
        app       = "mysql-exporter"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "mysql-exporter"
        }
      }
      namespaceSelector = {
        matchNames = [var.namespace]
      }
      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "mysql_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# Redis/ElastiCache ServiceMonitor
resource "kubectl_manifest" "redis_servicemonitor" {
  count = var.enable_redis_exporter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "redis-metrics"
      namespace = var.namespace
      labels = {
        app       = "redis-exporter"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "redis-exporter"
        }
      }
      namespaceSelector = {
        matchNames = [var.namespace]
      }
      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "redis_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# CloudWatch Exporter ServiceMonitor
resource "kubectl_manifest" "cloudwatch_servicemonitor" {
  count = var.enable_cloudwatch_exporter ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "cloudwatch-metrics"
      namespace = var.namespace
      labels = {
        app       = "cloudwatch-exporter"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "cloudwatch-exporter"
        }
      }
      namespaceSelector = {
        matchNames = [var.namespace]
      }
      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "60s"
          scrapeTimeout = "30s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "aws_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

#############################################
# PodMonitor CRDs for Kubernetes Components
#############################################

# Kubelet PodMonitor (for cAdvisor metrics)
resource "kubectl_manifest" "kubelet_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "kubelet-cadvisor"
      namespace = var.namespace
      labels = {
        app       = "kubelet"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "kubelet"
        }
      }
      namespaceSelector = {
        matchNames = ["kube-system"]
      }
      podMetricsEndpoints = [
        {
          port          = "https-metrics"
          path          = "/metrics/cadvisor"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          scheme        = "https"
          tlsConfig = {
            insecureSkipVerify = true
          }
          bearerTokenFile = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "container_.*|kubelet_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# CoreDNS PodMonitor
resource "kubectl_manifest" "coredns_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "coredns"
      namespace = var.namespace
      labels = {
        app       = "coredns"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "k8s-app" = "kube-dns"
        }
      }
      namespaceSelector = {
        matchNames = ["kube-system"]
      }
      podMetricsEndpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "coredns_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# AWS Load Balancer Controller PodMonitor
resource "kubectl_manifest" "aws_load_balancer_controller_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "aws-load-balancer-controller"
      namespace = var.namespace
      labels = {
        app       = "aws-load-balancer-controller"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "aws-load-balancer-controller"
        }
      }
      namespaceSelector = {
        matchNames = ["kube-system"]
      }
      podMetricsEndpoints = [
        {
          port          = "webhook-server"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "controller_.*|workqueue_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# Karpenter PodMonitor
resource "kubectl_manifest" "karpenter_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "karpenter"
      namespace = var.namespace
      labels = {
        app       = "karpenter"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "karpenter"
        }
      }
      namespaceSelector = {
        matchNames = ["karpenter"]
      }
      podMetricsEndpoints = [
        {
          port          = "http-metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "karpenter_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

# External Secrets Operator PodMonitor
resource "kubectl_manifest" "external_secrets_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "external-secrets-operator"
      namespace = var.namespace
      labels = {
        app       = "external-secrets-operator"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "external-secrets"
        }
      }
      namespaceSelector = {
        matchNames = ["external-secrets"]
      }
      podMetricsEndpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          metricRelabelings = [
            {
              sourceLabels = ["__name__"]
              regex        = "externalsecrets_.*|controller_.*"
              action       = "keep"
            }
          ]
        }
      ]
    }
  })
}

#############################################
# Additional Scrape Configurations
#############################################

# ConfigMap for additional scrape configurations
resource "kubernetes_config_map" "additional_scrape_configs" {
  metadata {
    name      = "additional-scrape-configs"
    namespace = var.namespace
    labels = {
      app       = "prometheus"
      component = "config"
    }
  }

  data = {
    "additional-scrape-configs.yaml" = yamlencode([
      # Kubernetes API Server metrics
      {
        job_name = "kubernetes-apiservers"
        kubernetes_sd_configs = [
          {
            role = "endpoints"
          }
        ]
        scheme = "https"
        tls_config = {
          ca_file              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          insecure_skip_verify = true
        }
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        relabel_configs = [
          {
            source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
            action        = "keep"
            regex         = "default;kubernetes;https"
          },
          {
            action       = "replace"
            target_label = "job"
            replacement  = "kubernetes-apiservers"
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "apiserver_.*|etcd_.*|rest_client_.*|workqueue_.*"
            action        = "keep"
          }
        ]
      },
      # Kubernetes nodes (kubelet) metrics
      {
        job_name = "kubernetes-nodes"
        kubernetes_sd_configs = [
          {
            role = "node"
          }
        ]
        scheme = "https"
        tls_config = {
          ca_file              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          insecure_skip_verify = true
        }
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        relabel_configs = [
          {
            action = "labelmap"
            regex  = "__meta_kubernetes_node_label_(.+)"
          },
          {
            action       = "replace"
            target_label = "__address__"
            regex        = "([^:]+)(?::\\d+)?"
            replacement  = "$1:10250"
          },
          {
            action       = "replace"
            target_label = "__metrics_path__"
            replacement  = "/metrics"
          },
          {
            action       = "replace"
            target_label = "job"
            replacement  = "kubernetes-nodes"
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "kubelet_.*|node_.*|container_.*"
            action        = "keep"
          }
        ]
      },
      # Kubelet cAdvisor metrics
      {
        job_name = "kubernetes-nodes-cadvisor"
        kubernetes_sd_configs = [
          {
            role = "node"
          }
        ]
        scheme = "https"
        tls_config = {
          ca_file              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          insecure_skip_verify = true
        }
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        relabel_configs = [
          {
            action = "labelmap"
            regex  = "__meta_kubernetes_node_label_(.+)"
          },
          {
            action       = "replace"
            target_label = "__address__"
            regex        = "([^:]+)(?::\\d+)?"
            replacement  = "$1:10250"
          },
          {
            action       = "replace"
            target_label = "__metrics_path__"
            replacement  = "/metrics/cadvisor"
          },
          {
            action       = "replace"
            target_label = "job"
            replacement  = "kubernetes-nodes-cadvisor"
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "container_.*|machine_.*"
            action        = "keep"
          }
        ]
      },
      # Kubernetes Controller Manager metrics (EKS managed - may not be accessible)
      {
        job_name = "kubernetes-controller-manager"
        kubernetes_sd_configs = [
          {
            role = "endpoints"
          }
        ]
        scheme = "https"
        tls_config = {
          ca_file              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          insecure_skip_verify = true
        }
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        relabel_configs = [
          {
            source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
            action        = "keep"
            regex         = "kube-system;kube-controller-manager;https"
          },
          {
            action       = "replace"
            target_label = "job"
            replacement  = "kubernetes-controller-manager"
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "controller_.*|workqueue_.*|rest_client_.*"
            action        = "keep"
          }
        ]
      },
      # Kubernetes Scheduler metrics (EKS managed - may not be accessible)
      {
        job_name = "kubernetes-scheduler"
        kubernetes_sd_configs = [
          {
            role = "endpoints"
          }
        ]
        scheme = "https"
        tls_config = {
          ca_file              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          insecure_skip_verify = true
        }
        bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
        relabel_configs = [
          {
            source_labels = ["__meta_kubernetes_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
            action        = "keep"
            regex         = "kube-system;kube-scheduler;https"
          },
          {
            action       = "replace"
            target_label = "job"
            replacement  = "kubernetes-scheduler"
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "scheduler_.*|workqueue_.*|rest_client_.*"
            action        = "keep"
          }
        ]
      }
    ])
  }
}

#############################################
# MySQL Exporter Deployment
#############################################

# MySQL monitoring user secret
resource "kubernetes_secret" "mysql_monitoring_user" {
  count = var.enable_mysql_exporter ? 1 : 0

  metadata {
    name      = "mysql-monitoring-credentials"
    namespace = var.namespace
    labels = {
      app       = "mysql-exporter"
      component = "credentials"
    }
  }

  data = {
    username = base64encode("monitoring")
    password = base64encode("monitoring_password_placeholder")
  }

  type = "Opaque"
}

# MySQL Exporter Deployment
resource "kubernetes_deployment" "mysql_exporter" {
  count = var.enable_mysql_exporter ? 1 : 0

  metadata {
    name      = "mysql-exporter"
    namespace = var.namespace
    labels = {
      app       = "mysql-exporter"
      component = "metrics"
      version   = "v0.15.1"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mysql-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app       = "mysql-exporter"
          component = "metrics"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9104"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          name  = "mysql-exporter"
          image = "prom/mysqld-exporter:v0.15.1"

          port {
            name           = "metrics"
            container_port = 9104
            protocol       = "TCP"
          }

          env {
            name = "DATA_SOURCE_NAME"
            value_from {
              secret_key_ref {
                name = var.mysql_connection_config != null ? "mysql-connection-credentials" : kubernetes_secret.mysql_monitoring_user[0].metadata[0].name
                key  = "dsn"
              }
            }
          }

          # Connection pooling and timeout settings
          env {
            name  = "MYSQLD_EXPORTER_LOCK_WAIT_TIMEOUT"
            value = "2"
          }

          env {
            name  = "MYSQLD_EXPORTER_LOG_SLOW_FILTER"
            value = "false"
          }

          env {
            name  = "MYSQLD_EXPORTER_MAX_CONNECTIONS"
            value = "3"
          }

          env {
            name  = "MYSQLD_EXPORTER_MAX_IDLE_CONNECTIONS"
            value = "3"
          }

          env {
            name  = "MYSQLD_EXPORTER_WEB_LISTEN_ADDRESS"
            value = ":9104"
          }

          env {
            name  = "MYSQLD_EXPORTER_WEB_TELEMETRY_PATH"
            value = "/metrics"
          }

          # Collect additional MySQL metrics
          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_INNODB_METRICS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_PROCESSLIST"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_QUERY_RESPONSE_TIME"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_REPLICA_HOST"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_INFO_SCHEMA_TABLES"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_TABLELOCKS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_FILE_EVENTS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_EVENTSWAITS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_INDEXIOWAITS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_PERF_SCHEMA_TABLEIOWAITS"
            value = "true"
          }

          env {
            name  = "MYSQLD_EXPORTER_COLLECT_SLAVE_STATUS"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/metrics"
              port = 9104
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/metrics"
              port = 9104
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          security_context {
            run_as_non_root            = true
            run_as_user                = 65534
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        security_context {
          fs_group = 65534
        }

        restart_policy = "Always"
      }
    }
  }
}

# MySQL Exporter Service
resource "kubernetes_service" "mysql_exporter" {
  count = var.enable_mysql_exporter ? 1 : 0

  metadata {
    name      = "mysql-exporter"
    namespace = var.namespace
    labels = {
      app       = "mysql-exporter"
      component = "metrics"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9104"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      app = "mysql-exporter"
    }

    port {
      name        = "metrics"
      port        = 9104
      target_port = 9104
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

#############################################
# Redis Exporter Deployment
#############################################

# Redis monitoring credentials secret (placeholder - only used when redis_connection_config is null)
resource "kubernetes_secret" "redis_monitoring_credentials" {
  count = var.enable_redis_exporter && var.redis_connection_config == null ? 1 : 0

  metadata {
    name      = "redis-monitoring-credentials"
    namespace = var.namespace
    labels = {
      app       = "redis-exporter"
      component = "credentials"
    }
  }

  data = {
    password = base64encode("redis_auth_token_placeholder")
  }

  type = "Opaque"
}

# Redis Exporter Deployment
resource "kubernetes_deployment" "redis_exporter" {
  count = var.enable_redis_exporter ? 1 : 0

  metadata {
    name      = "redis-exporter"
    namespace = var.namespace
    labels = {
      app       = "redis-exporter"
      component = "metrics"
      version   = "v1.58.0"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis-exporter"
      }
    }

    template {
      metadata {
        labels = {
          app       = "redis-exporter"
          component = "metrics"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9121"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        container {
          name  = "redis-exporter"
          image = "oliver006/redis_exporter:v1.58.0"

          port {
            name           = "metrics"
            container_port = 9121
            protocol       = "TCP"
          }

          env {
            name  = "REDIS_ADDR"
            value = var.redis_connection_config != null ? "${var.redis_connection_config.host}:${var.redis_connection_config.port}" : "localhost:6379"
          }

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.redis_connection_config != null ? "redis-connection-credentials" : kubernetes_secret.redis_monitoring_credentials[0].metadata[0].name
                key  = "password"
              }
            }
          }

          # Enable TLS if configured
          env {
            name  = "REDIS_EXPORTER_SKIP_TLS_VERIFICATION"
            value = var.redis_connection_config != null && var.redis_connection_config.tls_enabled ? "false" : "true"
          }

          # Connection pooling and timeout settings
          env {
            name  = "REDIS_EXPORTER_CONNECTION_TIMEOUT"
            value = "15s"
          }

          env {
            name  = "REDIS_EXPORTER_REDIS_ONLY_METRICS"
            value = "false"
          }

          env {
            name  = "REDIS_EXPORTER_PING_ON_CONNECT"
            value = "true"
          }

          env {
            name  = "REDIS_EXPORTER_INCL_CONFIG_METRICS"
            value = "true"
          }

          env {
            name  = "REDIS_EXPORTER_WEB_LISTEN_ADDRESS"
            value = ":9121"
          }

          env {
            name  = "REDIS_EXPORTER_WEB_TELEMETRY_PATH"
            value = "/metrics"
          }



          # Collect additional Redis metrics
          env {
            name  = "REDIS_EXPORTER_CHECK_KEYS"
            value = "*"
          }

          env {
            name  = "REDIS_EXPORTER_CHECK_KEY_GROUPS"
            value = "*"
          }

          env {
            name  = "REDIS_EXPORTER_INCLUDE_SYSTEM_METRICS"
            value = "true"
          }

          env {
            name  = "REDIS_EXPORTER_EXPORT_CLIENT_LIST"
            value = "true"
          }

          env {
            name  = "REDIS_EXPORTER_EXPORT_CLIENT_PORT"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/metrics"
              port = 9121
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/metrics"
              port = 9121
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          security_context {
            run_as_non_root            = true
            run_as_user                = 65534
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        security_context {
          fs_group = 65534
        }

        restart_policy = "Always"
      }
    }
  }
}

# Redis Exporter Service
resource "kubernetes_service" "redis_exporter" {
  count = var.enable_redis_exporter ? 1 : 0

  metadata {
    name      = "redis-exporter"
    namespace = var.namespace
    labels = {
      app       = "redis-exporter"
      component = "metrics"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9121"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      app = "redis-exporter"
    }

    port {
      name        = "metrics"
      port        = 9121
      target_port = 9121
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

#############################################
# Database Connection Pooling and Authentication
#############################################

# MySQL connection credentials ExternalSecret
# This syncs the MySQL password from AWS Secrets Manager to a Kubernetes secret
# and constructs the proper DSN format with connection parameters
resource "kubectl_manifest" "mysql_connection_credentials" {
  count = var.enable_mysql_exporter && var.mysql_connection_config != null ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "mysql-connection-credentials"
      namespace = var.namespace
      labels = {
        app       = "mysql-exporter"
        component = "credentials"
      }
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-sm"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "mysql-connection-credentials"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          data = {
            # Construct DSN with proper format: username:password@tcp(host:port)/database?params
            # Connection parameters:
            # - timeout: Connection timeout
            # - readTimeout: I/O read timeout
            # - writeTimeout: I/O write timeout
            # - parseTime: Parse DATE and DATETIME to time.Time
            # - loc: Location for time.Time values
            # - tls: TLS configuration (skip-verify for Aurora with TLS)
            # - maxAllowedPacket: Max packet size
            # - interpolateParams: Interpolate placeholders into query string
            dsn      = "{{ .username }}:{{ .password }}@tcp(${var.mysql_connection_config.host}:${var.mysql_connection_config.port})/${var.mysql_connection_config.database}?timeout=5s&readTimeout=10s&writeTimeout=10s&parseTime=true&loc=UTC&tls=skip-verify&maxAllowedPacket=67108864&interpolateParams=true"
            username = "{{ .username }}"
            password = "{{ .password }}"
            host     = "${var.mysql_connection_config.host}"
            port     = "${var.mysql_connection_config.port}"
            database = "${var.mysql_connection_config.database}"
          }
        }
      }
      data = [
        {
          secretKey = "username"
          remoteRef = {
            key      = var.mysql_connection_config.password_secret_ref
            property = "username"
          }
        },
        {
          secretKey = "password"
          remoteRef = {
            key      = var.mysql_connection_config.password_secret_ref
            property = "password"
          }
        }
      ]
    }
  })
}

# Redis connection credentials ExternalSecret
# This syncs the Redis auth token from AWS Secrets Manager to a Kubernetes secret
resource "kubectl_manifest" "redis_connection_credentials" {
  count = var.enable_redis_exporter && var.redis_connection_config != null ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "redis-connection-credentials"
      namespace = var.namespace
      labels = {
        app       = "redis-exporter"
        component = "credentials"
      }
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-sm"
        kind = "ClusterSecretStore"
      }
      target = {
        name           = "redis-connection-credentials"
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          data = {
            password = "{{ .token | toString }}"
          }
        }
      }
      data = [
        {
          secretKey = "token"
          remoteRef = {
            key = var.redis_connection_config.password_secret_ref
          }
        }
      ]
    }
  })
}

#############################################
# Service Discovery Configuration
#############################################

# ServiceMonitor for automatic service discovery
resource "kubectl_manifest" "service_discovery_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "service-discovery"
      namespace = var.namespace
      labels = {
        app       = "service-discovery"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
      }
      namespaceSelector = {
        any = true
      }
      endpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          relabelings = [
            {
              sourceLabels = ["__meta_kubernetes_service_annotation_prometheus_io_path"]
              targetLabel  = "__metrics_path__"
              regex        = "(.+)"
            },
            {
              sourceLabels = ["__address__", "__meta_kubernetes_service_annotation_prometheus_io_port"]
              targetLabel  = "__address__"
              regex        = "([^:]+)(?::\\d+)?;(\\d+)"
              replacement  = "$1:$2"
            }
          ]
        }
      ]
    }
  })
}

# PodMonitor for automatic pod discovery
resource "kubectl_manifest" "pod_discovery_podmonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      name      = "pod-discovery"
      namespace = var.namespace
      labels = {
        app       = "pod-discovery"
        component = "metrics"
        release   = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "prometheus.io/scrape" = "true"
        }
      }
      namespaceSelector = {
        any = true
      }
      podMetricsEndpoints = [
        {
          port          = "metrics"
          path          = "/metrics"
          interval      = "30s"
          scrapeTimeout = "10s"
          honorLabels   = true
          relabelings = [
            {
              sourceLabels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
              targetLabel  = "__metrics_path__"
              regex        = "(.+)"
            },
            {
              sourceLabels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
              targetLabel  = "__address__"
              regex        = "([^:]+)(?::\\d+)?;(\\d+)"
              replacement  = "$1:$2"
            }
          ]
        }
      ]
    }
  })
}