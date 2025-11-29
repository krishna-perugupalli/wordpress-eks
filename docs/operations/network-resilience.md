# Network Resilience

## Overview

Network resilience features ensure continuous metrics collection and eventual consistency during network partitions, connectivity issues, and infrastructure failures. These capabilities prevent data loss and maintain observability even when network connectivity is degraded or interrupted.

## Key Features

### 1. Local Metrics Collection During Network Partitions

**Implementation**: Prometheus Agent Mode deployed as a lightweight collector on each node.

- **Agent Deployment**: Runs Prometheus in agent mode with local storage
- **Per-Node Collection**: DaemonSet ensures metrics collection continues on each node independently
- **Local Storage**: Uses persistent volumes to buffer metrics during partitions
- **Automatic Discovery**: Continues discovering and scraping local pods and services

**Benefits**:
- Metrics collection continues even when central Prometheus is unreachable
- No data loss during network partitions
- Automatic recovery when connectivity is restored

### 2. Eventual Consistency for Metrics Synchronization

**Implementation**: Remote write with intelligent queuing and retry logic.

**Queue Configuration**:
- **Capacity**: 10,000 samples buffered during network issues
- **Batch Processing**: Sends up to 1,000 samples per batch
- **Parallel Shards**: Up to 10 parallel write streams for throughput
- **Metadata Sync**: Periodic metadata synchronization every minute

**Synchronization Process**:
1. Metrics are collected locally during partition
2. Samples are queued in persistent storage
3. When connectivity restores, queued samples are sent to central Prometheus
4. Periodic sync job (every 15 minutes) checks for gaps and triggers recovery

### 3. Intelligent Retry Logic for Failed Operations

**Implementation**: Exponential backoff with configurable parameters.

**Retry Strategy**:
- **Initial Backoff**: 1 second
- **Maximum Backoff**: 30 seconds (configurable)
- **Rate Limit Handling**: Automatic retry on HTTP 429 responses
- **Failure Detection**: Tracks consecutive failures to detect partitions

**Backoff Algorithm**:
```
retry_delay = min(initial_backoff * 2^attempt, max_backoff)
```

### 4. Network Partition Detection

**Implementation**: Active monitoring with automated detection and response.

**Detection Mechanism**:
- **Health Checks**: Periodic connectivity checks every 30 seconds
- **Threshold-Based**: Declares partition after 3 consecutive failures (configurable)
- **Event Logging**: Records partition events for audit and analysis
- **Automatic Recovery**: Triggers synchronization when connectivity restores

**Partition Response**:
1. Switch to local-only collection mode
2. Log partition event with timestamp and cluster information
3. Continue buffering metrics in local storage
4. Monitor for connectivity restoration
5. Trigger synchronization when connection is re-established

### 5. Monitoring and Alerting

**Prometheus Rules** for network resilience monitoring:

#### HighRemoteWriteRetries
- **Trigger**: Retry rate > 0.1 per second for 10 minutes
- **Severity**: Warning
- **Indicates**: Network issues or downstream problems

#### RemoteWriteQueueFull
- **Trigger**: Queue contains samples older than 1 hour
- **Severity**: Critical
- **Indicates**: Sustained network partition or downstream failure

#### NetworkPartitionDetected
- **Trigger**: More than 100 failed samples in 5 minutes
- **Severity**: Critical
- **Indicates**: Active network partition

#### MetricsSyncLag
- **Trigger**: Metrics more than 5 minutes behind
- **Severity**: Warning
- **Indicates**: Synchronization delays

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     EKS Cluster                              │
│                                                              │
│  ┌──────────────┐         ┌──────────────┐                 │
│  │ Node 1       │         │ Node 2       │                 │
│  │              │         │              │                 │
│  │ ┌──────────┐ │         │ ┌──────────┐ │                 │
│  │ │Prometheus│ │         │ │Prometheus│ │                 │
│  │ │  Agent   │ │         │ │  Agent   │ │                 │
│  │ │          │ │         │ │          │ │                 │
│  │ │ Local    │ │         │ │ Local    │ │                 │
│  │ │ Storage  │ │         │ │ Storage  │ │                 │
│  │ └────┬─────┘ │         │ └────┬─────┘ │                 │
│  └──────┼───────┘         └──────┼───────┘                 │
│         │                        │                          │
│         │  Remote Write          │  Remote Write            │
│         │  (with retry)          │  (with retry)            │
│         │                        │                          │
│         └────────┬───────────────┘                          │
│                  │                                          │
│         ┌────────▼─────────┐                                │
│         │   Central        │                                │
│         │   Prometheus     │                                │
│         │                  │                                │
│         │   Persistent     │                                │
│         │   Storage        │                                │
│         └──────────────────┘                                │
│                                                              │
│  ┌──────────────────────────────────────┐                   │
│  │  Network Partition Detector          │                   │
│  │  - Monitors connectivity              │                   │
│  │  - Detects partitions                │                   │
│  │  - Triggers recovery                 │                   │
│  └──────────────────────────────────────┘                   │
│                                                              │
│  ┌──────────────────────────────────────┐                   │
│  │  Metrics Sync CronJob                │                   │
│  │  - Runs every 15 minutes             │                   │
│  │  - Checks for gaps                   │                   │
│  │  - Triggers synchronization          │                   │
│  └──────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Basic Configuration

Enable network resilience features:

```hcl
module "observability" {
  source = "../../modules/observability"
  
  # Enable Prometheus stack
  enable_prometheus_stack = true
  
  # Enable network resilience
  enable_network_resilience = true
  
  # Other required variables...
}
```

### Advanced Configuration

Fine-tune network resilience parameters:

```hcl
module "observability" {
  source = "../../modules/observability"
  
  # Network resilience configuration
  enable_network_resilience    = true
  network_partition_threshold  = 3      # Failures before partition
  metrics_sync_interval        = 15     # Minutes between syncs
  remote_write_queue_capacity  = 10000  # Sample buffer size
  remote_write_max_backoff     = "30s"  # Maximum retry delay
  
  # Other configuration...
}
```

### Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_network_resilience` | bool | `false` | Enable network resilience features |
| `network_partition_threshold` | number | `3` | Failures before declaring partition |
| `metrics_sync_interval` | number | `15` | Minutes between sync checks |
| `remote_write_queue_capacity` | number | `10000` | Sample buffer size |
| `remote_write_max_backoff` | string | `"30s"` | Maximum retry delay |

## Operational Procedures

### Monitoring Network Resilience

1. **Check Partition Detector Status**:
   ```bash
   kubectl get pods -n observability -l app=network-partition-detector
   kubectl logs -n observability -l app=network-partition-detector
   ```

2. **View Partition Events**:
   ```bash
   kubectl exec -n observability <detector-pod> -- cat /var/log/partition-events.log
   ```

3. **Check Metrics Sync Status**:
   ```bash
   kubectl get cronjobs -n observability
   kubectl logs -n observability -l app=metrics-sync
   ```

4. **Query Prometheus for Retry Metrics**:
   ```promql
   # Remote write retry rate
   rate(prometheus_remote_storage_retries_total[5m])
   
   # Queue depth
   prometheus_remote_storage_queue_length
   
   # Failed samples
   rate(prometheus_remote_storage_failed_samples_total[5m])
   ```

### Troubleshooting Network Partitions

1. **Verify Local Collection**:
   ```bash
   # Check agent pods
   kubectl get pods -n observability -l app=prometheus-agent
   
   # Verify local metrics
   kubectl port-forward -n observability svc/prometheus-agent-server 9090:9090
   # Access http://localhost:9090
   ```

2. **Check Queue Status**:
   ```promql
   # Queue capacity usage
   prometheus_remote_storage_queue_length / prometheus_remote_storage_queue_capacity
   
   # Oldest sample in queue
   time() - prometheus_remote_storage_queue_lowest_sent_timestamp_seconds
   ```

3. **Force Synchronization**:
   ```bash
   # Trigger sync job manually
   kubectl create job -n observability --from=cronjob/<sync-cronjob-name> manual-sync-$(date +%s)
   ```

4. **Check Central Prometheus**:
   ```bash
   # Verify central Prometheus is healthy
   kubectl get pods -n observability -l app=kube-prometheus-stack-prometheus
   
   # Check for remote write errors
   kubectl logs -n observability -l app=kube-prometheus-stack-prometheus | grep "remote_write"
   ```

### Recovery Procedures

**After Network Partition**:

1. Verify connectivity is restored
2. Check partition detector logs for recovery event
3. Monitor sync job execution
4. Query for metric gaps:
   ```promql
   # Check for data continuity
   up{job="kubernetes-nodes"}
   ```
5. Verify queue is draining:
   ```promql
   prometheus_remote_storage_queue_length
   ```

**Manual Recovery**:

If automatic recovery fails:

1. Check agent pod logs for errors
2. Verify network connectivity between agent and central Prometheus
3. Check RBAC permissions for sync jobs
4. Manually trigger synchronization
5. Consider restarting agent pods if queue is corrupted

## Testing

### Simulate Network Partition

1. **Block traffic to central Prometheus**:
   ```bash
   # Create network policy to block traffic
   kubectl apply -f - <<EOF
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: block-prometheus
     namespace: observability
   spec:
     podSelector:
       matchLabels:
         app: kube-prometheus-stack-prometheus
     policyTypes:
     - Ingress
     ingress: []
   EOF
   ```

2. **Verify partition detection**:
   ```bash
   # Watch detector logs
   kubectl logs -f -n observability -l app=network-partition-detector
   ```

3. **Check local collection continues**:
   ```bash
   # Verify agent is collecting metrics
   kubectl port-forward -n observability svc/prometheus-agent-server 9090:9090
   ```

4. **Restore connectivity**:
   ```bash
   # Remove network policy
   kubectl delete networkpolicy -n observability block-prometheus
   ```

5. **Verify recovery**:
   ```bash
   # Check sync job execution
   kubectl get jobs -n observability
   
   # Verify metrics are synchronized
   # Query central Prometheus for recent data
   ```

## Performance Considerations

### Resource Usage

**Prometheus Agent** (per node):
- CPU: 100m request, 500m limit
- Memory: 256Mi request, 1Gi limit
- Storage: 10Gi per node

**Network Partition Detector**:
- CPU: 50m request, 100m limit
- Memory: 64Mi request, 128Mi limit

**Metrics Sync Job**:
- CPU: 50m request, 100m limit
- Memory: 64Mi request, 128Mi limit
- Runs every 15 minutes

### Network Bandwidth

**Normal Operation**:
- Remote write traffic: ~1-5 MB/s per agent (depends on metric volume)
- Batch size: 1,000 samples per request
- Compression: Enabled by default

**During Recovery**:
- Burst traffic: Up to 10x normal during queue drain
- Duration: Depends on partition length and queue size
- Throttling: Automatic via backoff mechanism

## Security Considerations

### RBAC Permissions

Network resilience components require:
- Read access to pods, services, configmaps
- Update access to configmaps (for configuration updates)
- Get/list/watch access to statefulsets and deployments

### Network Policies

Ensure network policies allow:
- Agent → Central Prometheus (port 9090)
- Partition Detector → Prometheus (port 9090)
- Sync Job → Prometheus (port 9090)

### Data Security

- All metrics in transit use cluster-internal networking
- Persistent volumes encrypted with KMS (if configured)
- No sensitive data in partition event logs

## Metrics and Monitoring

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `prometheus_remote_storage_retries_total` | Total retry attempts | > 0.1/s for 10m |
| `prometheus_remote_storage_queue_length` | Current queue size | > 8000 samples |
| `prometheus_remote_storage_failed_samples_total` | Failed samples | > 100 in 5m |
| `prometheus_remote_storage_queue_highest_sent_timestamp_seconds` | Newest sample timestamp | - |
| `prometheus_remote_storage_queue_lowest_sent_timestamp_seconds` | Oldest sample timestamp | > 1h old |

### Dashboards

Create Grafana dashboard with panels for:
- Remote write retry rate
- Queue depth over time
- Failed samples rate
- Sync lag duration
- Partition events timeline

## Limitations

1. **Storage Capacity**: Local storage limited to 10Gi per node
2. **Retention During Partition**: Limited by local storage size
3. **Recovery Time**: Depends on partition duration and queue size
4. **Network Overhead**: Increased during recovery phase
5. **Eventual Consistency**: Metrics may be delayed during partitions

## Best Practices

1. **Monitor Queue Depth**: Set alerts for queue approaching capacity
2. **Regular Testing**: Periodically test partition scenarios
3. **Capacity Planning**: Size local storage based on metric volume
4. **Network Monitoring**: Monitor network health proactively
5. **Documentation**: Keep runbooks updated with recovery procedures
6. **Backup Strategy**: Ensure AWS Backup policies cover persistent volumes
7. **Alert Tuning**: Adjust thresholds based on environment characteristics

## Cost Considerations

### Storage Costs

- **Local Storage**: 10Gi per node × number of nodes
- **EBS gp3**: ~$0.08/GB-month
- **Typical Cost**: $10-50/month for 10-node cluster

### Network Costs

- **Cross-AZ Transfer**: $0.01/GB for multi-AZ deployments
- **Typical Cost**: $5-20/month for normal operations

### Compute Costs

- **Agent Pods**: Minimal CPU/memory overhead
- **Sync Jobs**: Runs every 15 minutes, negligible cost

## Troubleshooting

### Agent Pods Not Starting

```bash
# Check pod status
kubectl get pods -n observability -l app=prometheus-agent

# View pod events
kubectl describe pod -n observability <agent-pod>

# Check logs
kubectl logs -n observability <agent-pod>
```

### Queue Not Draining

```bash
# Check queue metrics
kubectl port-forward -n observability <agent-pod> 9090:9090
# Query: prometheus_remote_storage_queue_length

# Check for errors
kubectl logs -n observability <agent-pod> | grep "remote_write"

# Verify network connectivity
kubectl exec -n observability <agent-pod> -- wget -O- http://prometheus-kube-prometheus-prometheus:9090/-/healthy
```

### Sync Job Failing

```bash
# Check job status
kubectl get jobs -n observability -l app=metrics-sync

# View job logs
kubectl logs -n observability -l app=metrics-sync

# Check RBAC permissions
kubectl auth can-i get pods --as=system:serviceaccount:observability:metrics-sync -n observability
```

## Related Documentation

- [Observability Module Guide](../modules/observability.md)
- [High Availability and Disaster Recovery](./ha-dr.md)
- [Monitoring Overview](../features/monitoring/README.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Prometheus Remote Write Specification](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#remote_write)
- [Prometheus Agent Mode](https://prometheus.io/docs/prometheus/latest/feature_flags/#prometheus-agent)
