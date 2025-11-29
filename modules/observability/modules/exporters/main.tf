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
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "apiserver_.*|etcd_.*|rest_client_.*"
            action        = "keep"
          }
        ]
      },
      # Kubernetes nodes metrics
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
          }
        ]
        metric_relabel_configs = [
          {
            source_labels = ["__name__"]
            regex         = "kubelet_.*|node_.*"
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
                name = var.mysql_connection_config != null ? kubernetes_secret.mysql_monitoring_user_updated[0].metadata[0].name : kubernetes_secret.mysql_monitoring_user[0].metadata[0].name
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

# Redis monitoring credentials secret
resource "kubernetes_secret" "redis_monitoring_credentials" {
  count = var.enable_redis_exporter ? 1 : 0

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
                name = var.redis_connection_config != null ? kubernetes_secret.redis_monitoring_credentials_updated[0].metadata[0].name : kubernetes_secret.redis_monitoring_credentials[0].metadata[0].name
                key  = "password"
              }
            }
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

          # Enable TLS if configured
          dynamic "env" {
            for_each = var.redis_connection_config != null && var.redis_connection_config.tls_enabled ? [1] : []
            content {
              name  = "REDIS_EXPORTER_TLS_CLIENT_CERT_FILE"
              value = "/etc/ssl/certs/redis-client.crt"
            }
          }

          dynamic "env" {
            for_each = var.redis_connection_config != null && var.redis_connection_config.tls_enabled ? [1] : []
            content {
              name  = "REDIS_EXPORTER_TLS_CLIENT_KEY_FILE"
              value = "/etc/ssl/private/redis-client.key"
            }
          }

          dynamic "env" {
            for_each = var.redis_connection_config != null && var.redis_connection_config.tls_enabled ? [1] : []
            content {
              name  = "REDIS_EXPORTER_SKIP_TLS_VERIFICATION"
              value = "false"
            }
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

# MySQL connection configuration secret
resource "kubernetes_secret" "mysql_connection_config" {
  count = var.enable_mysql_exporter && var.mysql_connection_config != null ? 1 : 0

  metadata {
    name      = "mysql-connection-config"
    namespace = var.namespace
    labels = {
      app       = "mysql-exporter"
      component = "config"
    }
  }

  data = {
    dsn = base64encode(
      "monitoring:${var.mysql_connection_config.password_secret_ref}@tcp(${var.mysql_connection_config.host}:${var.mysql_connection_config.port})/${var.mysql_connection_config.database}?timeout=5s&readTimeout=5s&writeTimeout=5s"
    )
    host     = base64encode(var.mysql_connection_config.host)
    port     = base64encode(tostring(var.mysql_connection_config.port))
    username = base64encode(var.mysql_connection_config.username)
    database = base64encode(var.mysql_connection_config.database)
  }

  type = "Opaque"
}

# MySQL monitoring setup ConfigMap
resource "kubernetes_config_map" "mysql_monitoring_setup" {
  count = var.enable_mysql_exporter ? 1 : 0

  metadata {
    name      = "mysql-monitoring-setup"
    namespace = var.namespace
    labels = {
      app       = "mysql-exporter"
      component = "setup"
    }
  }

  data = {
    "setup.sql" = file("${path.module}/files/mysql-monitoring-setup.sql")
  }
}

# MySQL monitoring user setup Job
resource "kubernetes_job" "mysql_monitoring_setup" {
  count = var.enable_mysql_exporter && var.mysql_connection_config != null ? 1 : 0

  metadata {
    name      = "mysql-monitoring-setup"
    namespace = var.namespace
    labels = {
      app       = "mysql-exporter"
      component = "setup"
    }
  }

  spec {
    template {
      metadata {
        labels = {
          app       = "mysql-monitoring-setup"
          component = "setup"
        }
      }

      spec {
        container {
          name  = "mysql-setup"
          image = "mysql:8.0"

          command = [
            "/bin/bash",
            "-c",
            <<-EOT
              # Replace placeholder with actual password
              sed "s/MONITORING_PASSWORD_PLACEHOLDER/$MONITORING_PASSWORD/g" /scripts/setup.sql > /tmp/setup.sql
              
              # Execute the setup script
              mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_ROOT_USER -p$MYSQL_ROOT_PASSWORD < /tmp/setup.sql
              
              echo "MySQL monitoring user setup completed successfully"
            EOT
          ]

          env {
            name  = "MYSQL_HOST"
            value = var.mysql_connection_config.host
          }

          env {
            name  = "MYSQL_PORT"
            value = tostring(var.mysql_connection_config.port)
          }

          env {
            name  = "MYSQL_ROOT_USER"
            value = "root"
          }

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.mysql_connection_config.password_secret_ref
                key  = "password"
              }
            }
          }

          env {
            name  = "MONITORING_PASSWORD"
            value = "monitoring_secure_password_${random_password.mysql_monitoring_password[0].result}"
          }

          volume_mount {
            name       = "setup-scripts"
            mount_path = "/scripts"
            read_only  = true
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
        }

        volume {
          name = "setup-scripts"
          config_map {
            name = kubernetes_config_map.mysql_monitoring_setup[0].metadata[0].name
          }
        }

        restart_policy = "OnFailure"
      }
    }

    backoff_limit = 3
  }

  wait_for_completion = true
  timeouts {
    create = "5m"
    update = "5m"
  }
}

# Generate secure password for MySQL monitoring user
resource "random_password" "mysql_monitoring_password" {
  count   = var.enable_mysql_exporter ? 1 : 0
  length  = 32
  special = true
}

# Update MySQL exporter secret to use actual connection config
resource "kubernetes_secret" "mysql_monitoring_user_updated" {
  count = var.enable_mysql_exporter && var.mysql_connection_config != null ? 1 : 0

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
    password = base64encode("monitoring_secure_password_${random_password.mysql_monitoring_password[0].result}")
    dsn = base64encode(
      "monitoring:monitoring_secure_password_${random_password.mysql_monitoring_password[0].result}@tcp(${var.mysql_connection_config.host}:${var.mysql_connection_config.port})/${var.mysql_connection_config.database}?timeout=5s&readTimeout=5s&writeTimeout=5s"
    )
  }

  type = "Opaque"

  depends_on = [kubernetes_job.mysql_monitoring_setup]

  lifecycle {
    replace_triggered_by = [kubernetes_secret.mysql_monitoring_user]
  }
}

# Redis connection configuration secret
resource "kubernetes_secret" "redis_connection_config" {
  count = var.enable_redis_exporter && var.redis_connection_config != null ? 1 : 0

  metadata {
    name      = "redis-connection-config"
    namespace = var.namespace
    labels = {
      app       = "redis-exporter"
      component = "config"
    }
  }

  data = {
    host        = base64encode(var.redis_connection_config.host)
    port        = base64encode(tostring(var.redis_connection_config.port))
    password    = base64encode(var.redis_connection_config.password_secret_ref)
    tls_enabled = base64encode(tostring(var.redis_connection_config.tls_enabled))
  }

  type = "Opaque"
}

# Update Redis exporter secret to use actual connection config
resource "kubernetes_secret" "redis_monitoring_credentials_updated" {
  count = var.enable_redis_exporter && var.redis_connection_config != null ? 1 : 0

  metadata {
    name      = "redis-monitoring-credentials"
    namespace = var.namespace
    labels = {
      app       = "redis-exporter"
      component = "credentials"
    }
  }

  data = {
    password = base64encode(var.redis_connection_config.password_secret_ref)
  }

  type = "Opaque"

  lifecycle {
    replace_triggered_by = [kubernetes_secret.redis_monitoring_credentials]
  }
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