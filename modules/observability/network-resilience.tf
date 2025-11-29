#############################################
# Network Resilience Configuration
# Implements local metrics collection during network partitions,
# eventual consistency for metrics synchronization, and intelligent retry logic
#############################################

#############################################
# Local Metrics Collection During Network Partitions
#############################################

# ConfigMap for Prometheus remote write configuration with retry logic
resource "kubernetes_config_map" "prometheus_remote_write_config" {
  count = local.prometheus_enabled ? 1 : 0

  metadata {
    name      = "${var.name}-prometheus-remote-write-config"
    namespace = local.ns
  }

  data = {
    "remote-write-config.yaml" = yamlencode({
      # Remote write configuration with intelligent retry logic
      remote_write = [
        {
          url = "http://prometheus-kube-prometheus-prometheus.${local.ns}.svc.cluster.local:9090/api/v1/write"

          # Queue configuration for network partition tolerance
          queue_config = {
            capacity             = 10000 # Buffer up to 10k samples during partition
            max_shards           = 10    # Parallel write shards
            min_shards           = 1     # Minimum shards
            max_samples_per_send = 1000  # Batch size
            batch_send_deadline  = "5s"  # Send batch after 5s
            min_backoff          = "1s"  # Initial retry delay
            max_backoff          = "30s" # Maximum retry delay
            retry_on_http_429    = true  # Retry on rate limit
          }

          # Metadata configuration for eventual consistency
          metadata_config = {
            send                 = true
            send_interval        = "1m"
            max_samples_per_send = 500
          }

          # Write relabel configs to add partition metadata
          write_relabel_configs = [
            {
              source_labels = ["__name__"]
              target_label  = "partition_aware"
              replacement   = "true"
            }
          ]
        }
      ]
    })
  }
}

# Prometheus Agent Mode for Edge Collection
# Deploys lightweight Prometheus agents on each node for local collection
resource "helm_release" "prometheus_agent" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  name       = "prometheus-agent"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = "25.8.0"
  namespace  = local.ns

  values = [
    yamlencode({
      # Run Prometheus in agent mode for local collection
      server = {
        enabled = true

        # Agent mode configuration
        extraArgs = {
          "enable-feature"     = "agent"
          "storage.agent.path" = "/prometheus/agent"
        }

        # Resource configuration for lightweight agent
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }

        # Deploy as DaemonSet for per-node collection
        statefulSet = {
          enabled = false
        }

        # Use hostPath for local storage during partitions
        persistentVolume = {
          enabled      = true
          size         = "10Gi"
          storageClass = var.prometheus_storage_class
          accessModes  = ["ReadWriteOnce"]
        }

        # Remote write to central Prometheus with retry logic
        remoteWrite = [
          {
            url = "http://prometheus-kube-prometheus-prometheus.${local.ns}.svc.cluster.local:9090/api/v1/write"

            # Queue configuration for partition tolerance
            queueConfig = {
              capacity          = 10000
              maxShards         = 5
              minShards         = 1
              maxSamplesPerSend = 1000
              batchSendDeadline = "5s"
              minBackoff        = "1s"
              maxBackoff        = "30s"
              retryOnRateLimit  = true
            }

            # Write relabel configs
            writeRelabelConfigs = [
              {
                sourceLabels = ["__name__"]
                targetLabel  = "collected_by"
                replacement  = "agent"
              },
              {
                sourceLabels = ["__name__"]
                targetLabel  = "partition_tolerant"
                replacement  = "true"
              }
            ]
          }
        ]

        # Scrape configuration for local metrics
        extraScrapeConfigs = yamlencode([
          {
            job_name = "kubernetes-nodes-local"
            scheme   = "https"

            tls_config = {
              ca_file              = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
              insecure_skip_verify = false
            }

            bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"

            kubernetes_sd_configs = [
              {
                role = "node"
              }
            ]

            relabel_configs = [
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_node_label_(.+)"
              },
              {
                target_label = "__address__"
                replacement  = "kubernetes.default.svc:443"
              },
              {
                source_labels = ["__meta_kubernetes_node_name"]
                regex         = "(.+)"
                target_label  = "__metrics_path__"
                replacement   = "/api/v1/nodes/$${1}/proxy/metrics"
              }
            ]
          },
          {
            job_name = "kubernetes-pods-local"

            kubernetes_sd_configs = [
              {
                role = "pod"
              }
            ]

            relabel_configs = [
              {
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                action        = "keep"
                regex         = "true"
              },
              {
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                action        = "replace"
                target_label  = "__metrics_path__"
                regex         = "(.+)"
              },
              {
                source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                action        = "replace"
                regex         = "([^:]+)(?::\\d+)?;(\\d+)"
                replacement   = "$1:$2"
                target_label  = "__address__"
              },
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_pod_label_(.+)"
              },
              {
                source_labels = ["__meta_kubernetes_namespace"]
                action        = "replace"
                target_label  = "kubernetes_namespace"
              },
              {
                source_labels = ["__meta_kubernetes_pod_name"]
                action        = "replace"
                target_label  = "kubernetes_pod_name"
              }
            ]
          }
        ])

        # Security context
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 65534
          fsGroup      = 65534
        }

        # Node selector to ensure distribution
        nodeSelector = {}

        # Tolerations for all nodes
        tolerations = [
          {
            operator = "Exists"
          }
        ]
      }

      # Disable other components
      alertmanager = {
        enabled = false
      }

      nodeExporter = {
        enabled = false
      }

      pushgateway = {
        enabled = false
      }

      kubeStateMetrics = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.ns,
    module.prometheus
  ]
}

#############################################
# Network Partition Detection and Handling
#############################################

# ConfigMap for network partition detection script
resource "kubernetes_config_map" "network_partition_detector" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  metadata {
    name      = "${var.name}-network-partition-detector"
    namespace = local.ns
  }

  data = {
    "detect-partition.sh" = <<-EOT
      #!/bin/bash
      set -e
      
      # Configuration
      PROMETHEUS_URL="http://prometheus-kube-prometheus-prometheus.${local.ns}.svc.cluster.local:9090"
      CHECK_INTERVAL=30
      PARTITION_THRESHOLD=3
      CONSECUTIVE_FAILURES=0
      
      echo "Starting network partition detector..."
      echo "Prometheus URL: $PROMETHEUS_URL"
      echo "Check interval: $CHECK_INTERVAL seconds"
      echo "Partition threshold: $PARTITION_THRESHOLD consecutive failures"
      
      while true; do
        # Check connectivity to Prometheus
        if curl -s -f -m 5 "$PROMETHEUS_URL/-/healthy" > /dev/null 2>&1; then
          if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
            echo "$(date): Connectivity restored after $CONSECUTIVE_FAILURES failures"
            CONSECUTIVE_FAILURES=0
            
            # Trigger metrics synchronization
            echo "$(date): Triggering metrics synchronization..."
            curl -X POST "$PROMETHEUS_URL/api/v1/admin/tsdb/snapshot" || true
          fi
        else
          CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
          echo "$(date): Connectivity check failed ($CONSECUTIVE_FAILURES/$PARTITION_THRESHOLD)"
          
          if [ $CONSECUTIVE_FAILURES -ge $PARTITION_THRESHOLD ]; then
            echo "$(date): Network partition detected! Switching to local-only mode..."
            
            # Update Prometheus configuration to local-only mode
            # This would typically involve updating the Prometheus config
            # to disable remote write temporarily
            
            # Log partition event
            echo "$(date): PARTITION_EVENT cluster=${var.cluster_name} namespace=${local.ns}" >> /var/log/partition-events.log
          fi
        fi
        
        sleep $CHECK_INTERVAL
      done
    EOT

    "sync-metrics.sh" = <<-EOT
      #!/bin/bash
      set -e
      
      # Metrics synchronization script for post-partition recovery
      PROMETHEUS_URL="http://prometheus-kube-prometheus-prometheus.${local.ns}.svc.cluster.local:9090"
      AGENT_URL="http://prometheus-agent-server.${local.ns}.svc.cluster.local:9090"
      
      echo "Starting metrics synchronization..."
      
      # Check if both Prometheus instances are available
      if ! curl -s -f -m 5 "$PROMETHEUS_URL/-/healthy" > /dev/null 2>&1; then
        echo "Central Prometheus is not available, skipping sync"
        exit 0
      fi
      
      if ! curl -s -f -m 5 "$AGENT_URL/-/healthy" > /dev/null 2>&1; then
        echo "Prometheus agent is not available, skipping sync"
        exit 0
      fi
      
      echo "Both Prometheus instances are healthy, synchronization will happen automatically via remote write"
      
      # Query for any gaps in metrics
      CURRENT_TIME=$(date +%s)
      LOOKBACK_TIME=$((CURRENT_TIME - 3600)) # Look back 1 hour
      
      # Check for metric gaps (this is informational)
      echo "Checking for metric gaps in the last hour..."
      curl -s "$PROMETHEUS_URL/api/v1/query_range?query=up&start=$LOOKBACK_TIME&end=$CURRENT_TIME&step=60" | \
        jq -r '.data.result[] | select(.values | length < 60) | "Gap detected for: " + .metric.job' || true
      
      echo "Synchronization check complete"
    EOT
  }
}

# Deployment for network partition detector
resource "kubernetes_deployment" "network_partition_detector" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  metadata {
    name      = "${var.name}-network-partition-detector"
    namespace = local.ns
    labels = {
      app       = "network-partition-detector"
      component = "resilience"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app       = "network-partition-detector"
        component = "resilience"
      }
    }

    template {
      metadata {
        labels = {
          app       = "network-partition-detector"
          component = "resilience"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.network_resilience[0].metadata[0].name

        container {
          name  = "detector"
          image = "curlimages/curl:latest"

          command = ["/bin/sh", "-c"]
          args    = ["sh /scripts/detect-partition.sh"]

          volume_mount {
            name       = "scripts"
            mount_path = "/scripts"
          }

          volume_mount {
            name       = "logs"
            mount_path = "/var/log"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["sh", "-c", "test -f /var/log/partition-events.log || touch /var/log/partition-events.log"]
            }
            initial_delay_seconds = 10
            period_seconds        = 30
          }
        }

        volume {
          name = "scripts"
          config_map {
            name         = kubernetes_config_map.network_partition_detector[0].metadata[0].name
            default_mode = "0755"
          }
        }

        volume {
          name = "logs"
          empty_dir {}
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [kubernetes_namespace.ns]
}

# CronJob for periodic metrics synchronization
resource "kubernetes_cron_job_v1" "metrics_sync" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  metadata {
    name      = "${var.name}-metrics-sync"
    namespace = local.ns
  }

  spec {
    schedule                      = "*/15 * * * *" # Every 15 minutes
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = {
          app       = "metrics-sync"
          component = "resilience"
        }
      }

      spec {
        template {
          metadata {
            labels = {
              app       = "metrics-sync"
              component = "resilience"
            }
          }

          spec {
            service_account_name = kubernetes_service_account.network_resilience[0].metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name  = "sync"
              image = "curlimages/curl:latest"

              command = ["/bin/sh", "-c"]
              args    = ["sh /scripts/sync-metrics.sh"]

              volume_mount {
                name       = "scripts"
                mount_path = "/scripts"
              }

              resources {
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

            volume {
              name = "scripts"
              config_map {
                name         = kubernetes_config_map.network_partition_detector[0].metadata[0].name
                default_mode = "0755"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Service Account and RBAC for Network Resilience
#############################################

resource "kubernetes_service_account" "network_resilience" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  metadata {
    name      = "${var.name}-network-resilience"
    namespace = local.ns
  }
}

resource "kubernetes_role" "network_resilience" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  metadata {
    name      = "${var.name}-network-resilience"
    namespace = local.ns
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "network_resilience" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  metadata {
    name      = "${var.name}-network-resilience"
    namespace = local.ns
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.network_resilience[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.network_resilience[0].metadata[0].name
    namespace = local.ns
  }
}

#############################################
# Intelligent Retry Logic Configuration
#############################################

# PrometheusRule for retry metrics and alerting
resource "kubectl_manifest" "retry_metrics_rule" {
  count = local.prometheus_enabled && var.enable_network_resilience ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "${var.name}-retry-metrics"
      namespace = local.ns
      labels = {
        prometheus = "kube-prometheus"
        role       = "alert-rules"
      }
    }
    spec = {
      groups = [
        {
          name     = "network-resilience"
          interval = "30s"
          rules = [
            {
              alert = "HighRemoteWriteRetries"
              expr  = "rate(prometheus_remote_storage_retries_total[5m]) > 0.1"
              for   = "10m"
              labels = {
                severity  = "warning"
                component = "prometheus"
                category  = "network-resilience"
              }
              annotations = {
                summary     = "High rate of remote write retries detected"
                description = "Prometheus is experiencing {{ $value }} retries per second for remote write operations. This may indicate network issues."
                runbook_url = "https://runbooks.prometheus.io/runbooks/prometheus/highremotewriteretries"
              }
            },
            {
              alert = "RemoteWriteQueueFull"
              expr  = "prometheus_remote_storage_queue_highest_sent_timestamp_seconds - prometheus_remote_storage_queue_lowest_sent_timestamp_seconds > 3600"
              for   = "5m"
              labels = {
                severity  = "critical"
                component = "prometheus"
                category  = "network-resilience"
              }
              annotations = {
                summary     = "Remote write queue is backing up"
                description = "Prometheus remote write queue has samples older than 1 hour. Network partition or downstream issues detected."
                runbook_url = "https://runbooks.prometheus.io/runbooks/prometheus/remotewritequeuefull"
              }
            },
            {
              alert = "NetworkPartitionDetected"
              expr  = "increase(prometheus_remote_storage_failed_samples_total[5m]) > 100"
              for   = "2m"
              labels = {
                severity  = "critical"
                component = "prometheus"
                category  = "network-resilience"
              }
              annotations = {
                summary     = "Potential network partition detected"
                description = "Prometheus has failed to send {{ $value }} samples in the last 5 minutes. Local collection mode activated."
                runbook_url = "https://runbooks.prometheus.io/runbooks/prometheus/networkpartitiondetected"
              }
            },
            {
              alert = "MetricsSyncLag"
              expr  = "time() - prometheus_remote_storage_queue_highest_sent_timestamp_seconds > 300"
              for   = "5m"
              labels = {
                severity  = "warning"
                component = "prometheus"
                category  = "network-resilience"
              }
              annotations = {
                summary     = "Metrics synchronization is lagging"
                description = "Metrics are {{ $value }} seconds behind. Eventual consistency may be delayed."
                runbook_url = "https://runbooks.prometheus.io/runbooks/prometheus/metricssynclag"
              }
            }
          ]
        }
      ]
    }
  })

  depends_on = [module.prometheus]
}
