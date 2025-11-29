# Alert Rules Reference

This document provides a comprehensive reference for all Prometheus alert rules configured in the WordPress EKS platform.

## Overview

Alert rules are organized into groups by component:
- **WordPress Application** - Application-level alerts
- **Database** - Aurora MySQL performance and health
- **Cache** - Redis/ElastiCache monitoring
- **Infrastructure - Nodes** - Kubernetes node health
- **Infrastructure - Pods** - Pod and deployment health
- **Cost Monitoring** - AWS cost tracking and optimization

## Alert Severity Levels

- **critical**: Immediate action required, service degradation or outage
- **warning**: Attention needed, potential issues or degraded performance
- **info**: Informational, no immediate action required

## Alert Groups

### WordPress Application Alerts

#### WordPressDown
- **Severity**: critical
- **Condition**: `up{job="wordpress"} == 0`
- **Duration**: 1 minute
- **Description**: WordPress application pod is down
- **Remediation**:
  1. Check pod status: `kubectl get pods -n <namespace>`
  2. Check pod logs: `kubectl logs <pod> -n <namespace>`
  3. Check events: `kubectl describe pod <pod> -n <namespace>`

#### WordPressHighResponseTime
- **Severity**: warning
- **Condition**: 95th percentile response time > 2 seconds
- **Duration**: 5 minutes
- **Description**: WordPress response time is high
- **Remediation**:
  1. Check database performance
  2. Review cache hit rates
  3. Check for slow plugins
  4. Review resource utilization

#### WordPressHighErrorRate
- **Severity**: critical
- **Condition**: 5xx error rate > 5%
- **Duration**: 5 minutes
- **Description**: WordPress error rate is high
- **Remediation**:
  1. Check application logs for errors
  2. Verify database connectivity
  3. Check cache service health
  4. Review recent deployments

#### WordPressLowCacheHitRate
- **Severity**: warning
- **Condition**: Cache hit rate < 70%
- **Duration**: 10 minutes
- **Description**: WordPress cache hit rate is low
- **Remediation**:
  1. Check Redis/ElastiCache health
  2. Review cache configuration
  3. Check for cache evictions
  4. Consider increasing cache size

#### WordPressPluginSlowExecution
- **Severity**: warning
- **Condition**: Plugin execution time > 1 second
- **Duration**: 5 minutes
- **Description**: WordPress plugin execution is slow
- **Remediation**:
  1. Review plugin code for optimization
  2. Check for database query issues
  3. Consider disabling or replacing plugin
  4. Profile plugin execution

---

### Database Performance Alerts

#### DatabaseDown
- **Severity**: critical
- **Condition**: `up{job="mysql-exporter"} == 0`
- **Duration**: 1 minute
- **Description**: Database is down or unreachable
- **Remediation**:
  1. Check Aurora cluster status in AWS Console
  2. Verify security group rules
  3. Check database credentials
  4. Review CloudWatch metrics for RDS

#### DatabaseHighConnectionUsage
- **Severity**: warning
- **Condition**: Connection usage > 80%
- **Duration**: 5 minutes
- **Description**: Database connection usage is high
- **Remediation**:
  1. Review application connection pooling
  2. Check for connection leaks
  3. Consider increasing max_connections
  4. Identify long-running queries

#### DatabaseSlowQueries
- **Severity**: warning
- **Condition**: Slow query rate > 10 queries/sec
- **Duration**: 5 minutes
- **Description**: Database has high rate of slow queries
- **Remediation**:
  1. Enable slow query log
  2. Review query execution plans
  3. Check for missing indexes
  4. Optimize problematic queries

#### DatabaseReplicationLag
- **Severity**: warning
- **Condition**: Replication lag > 30 seconds
- **Duration**: 5 minutes
- **Description**: Database replication lag is high
- **Remediation**:
  1. Check replica instance performance
  2. Review network connectivity
  3. Check for long-running transactions
  4. Consider scaling replica instance

#### DatabaseHighCPU
- **Severity**: warning
- **Condition**: Running threads > 20
- **Duration**: 10 minutes
- **Description**: Database CPU usage is high
- **Remediation**:
  1. Identify resource-intensive queries
  2. Review query execution plans
  3. Check for table locks
  4. Consider scaling database instance

---

### Redis/Cache Alerts

#### RedisDown
- **Severity**: critical
- **Condition**: `up{job="redis-exporter"} == 0`
- **Duration**: 1 minute
- **Description**: Redis cache is down or unreachable
- **Remediation**:
  1. Check ElastiCache cluster status
  2. Verify security group rules
  3. Check Redis AUTH configuration
  4. Review CloudWatch metrics

#### RedisHighMemoryUsage
- **Severity**: warning
- **Condition**: Memory usage > 85%
- **Duration**: 5 minutes
- **Description**: Redis memory usage is high
- **Remediation**:
  1. Review cache eviction policy
  2. Check for memory leaks
  3. Consider increasing cache size
  4. Review cache key TTLs

#### RedisHighEvictionRate
- **Severity**: warning
- **Condition**: Eviction rate > 100 keys/sec
- **Duration**: 5 minutes
- **Description**: Redis eviction rate is high
- **Remediation**:
  1. Increase cache memory allocation
  2. Review cache key sizes
  3. Optimize cache usage patterns
  4. Consider cache partitioning

#### RedisHighConnectionUsage
- **Severity**: warning
- **Condition**: Connection usage > 80%
- **Duration**: 5 minutes
- **Description**: Redis connection usage is high
- **Remediation**:
  1. Review application connection pooling
  2. Check for connection leaks
  3. Consider increasing maxclients
  4. Identify clients with many connections

---

### Infrastructure - Node Health Alerts

#### NodeNotReady
- **Severity**: critical
- **Condition**: Node Ready status = false
- **Duration**: 5 minutes
- **Description**: Kubernetes node is not ready
- **Remediation**:
  1. Check node status: `kubectl describe node <node>`
  2. Check kubelet logs
  3. Verify node resources
  4. Check for network issues

#### NodeHighCPU
- **Severity**: warning
- **Condition**: CPU usage > 85%
- **Duration**: 10 minutes
- **Description**: Node CPU usage is high
- **Remediation**:
  1. Identify resource-intensive pods
  2. Check for CPU throttling
  3. Consider scaling cluster
  4. Review pod resource requests/limits

#### NodeHighMemory
- **Severity**: warning
- **Condition**: Memory usage > 85%
- **Duration**: 10 minutes
- **Description**: Node memory usage is high
- **Remediation**:
  1. Identify memory-intensive pods
  2. Check for memory leaks
  3. Consider scaling cluster
  4. Review pod resource requests/limits

#### NodeDiskSpaceLow
- **Severity**: warning
- **Condition**: Disk usage > 85%
- **Duration**: 10 minutes
- **Description**: Node disk space is low
- **Remediation**:
  1. Clean up unused images: `docker system prune`
  2. Check for large log files
  3. Review pod ephemeral storage
  4. Consider increasing disk size

#### NodeDiskIOHigh
- **Severity**: warning
- **Condition**: Disk I/O utilization > 90%
- **Duration**: 10 minutes
- **Description**: Node disk I/O is high
- **Remediation**:
  1. Identify I/O intensive pods
  2. Check for disk performance issues
  3. Consider using faster storage class
  4. Review application I/O patterns

---

### Infrastructure - Pod Health Alerts

#### PodCrashLooping
- **Severity**: warning
- **Condition**: Pod restart rate > 0 over 15 minutes
- **Duration**: 5 minutes
- **Description**: Pod is crash looping
- **Remediation**:
  1. Check pod logs: `kubectl logs <pod> -n <namespace>`
  2. Check events: `kubectl describe pod <pod> -n <namespace>`
  3. Review resource limits
  4. Check for application errors

#### PodNotReady
- **Severity**: warning
- **Condition**: Pod not in Running or Succeeded phase
- **Duration**: 10 minutes
- **Description**: Pod is not ready
- **Remediation**:
  1. Check pod status: `kubectl get pod <pod> -n <namespace>`
  2. Check events: `kubectl describe pod <pod> -n <namespace>`
  3. Check for image pull errors
  4. Verify resource availability

#### PodHighCPUThrottling
- **Severity**: warning
- **Condition**: CPU throttling > 50%
- **Duration**: 10 minutes
- **Description**: Pod is experiencing high CPU throttling
- **Remediation**:
  1. Review CPU limits
  2. Consider increasing CPU limits
  3. Optimize application CPU usage
  4. Check for CPU-intensive operations

#### PodHighMemoryUsage
- **Severity**: warning
- **Condition**: Memory usage > 90% of limit
- **Duration**: 10 minutes
- **Description**: Pod memory usage is high
- **Remediation**:
  1. Check for memory leaks
  2. Review memory limits
  3. Consider increasing memory limits
  4. Optimize application memory usage

#### DeploymentReplicasMismatch
- **Severity**: warning
- **Condition**: Desired replicas ≠ available replicas
- **Duration**: 10 minutes
- **Description**: Deployment replicas mismatch
- **Remediation**:
  1. Check deployment status: `kubectl get deployment <deployment> -n <namespace>`
  2. Check pod status
  3. Review resource availability
  4. Check for scheduling issues

---

### Cost Monitoring Alerts

#### DailyCostThresholdExceeded
- **Severity**: warning
- **Condition**: Daily AWS cost > $500
- **Duration**: 1 hour
- **Description**: Daily AWS cost threshold exceeded
- **Remediation**:
  1. Review AWS Cost Explorer for detailed breakdown
  2. Check for unexpected resource usage
  3. Review Karpenter spot instance usage
  4. Identify cost optimization opportunities

#### MonthlyCostProjectionHigh
- **Severity**: warning
- **Condition**: Projected monthly cost > $15,000
- **Duration**: 6 hours
- **Description**: Monthly cost projection is high
- **Remediation**:
  1. Review cost trends in Cost Explorer
  2. Identify cost spikes and anomalies
  3. Review resource utilization
  4. Implement cost optimization recommendations

#### UnusedResourcesDetected
- **Severity**: info
- **Condition**: Potential savings > $1,000
- **Duration**: 24 hours
- **Description**: Unused resources detected with potential savings
- **Remediation**:
  1. Review AWS Cost Explorer recommendations
  2. Identify idle or underutilized resources
  3. Consider rightsizing or terminating resources
  4. Review EBS volumes and snapshots

#### RDSCostIncreaseSignificant
- **Severity**: warning
- **Condition**: RDS cost increased > 30% week-over-week
- **Duration**: 6 hours
- **Description**: RDS cost increased significantly
- **Remediation**:
  1. Review Aurora Serverless v2 scaling patterns
  2. Check for unexpected query load
  3. Review backup and snapshot costs
  4. Consider optimizing database queries

#### EC2SpotInstanceSavingsLow
- **Severity**: info
- **Condition**: Spot instance usage < 50% of EC2 costs
- **Duration**: 24 hours
- **Description**: EC2 spot instance usage is low
- **Remediation**:
  1. Review Karpenter NodePool configuration
  2. Check spot instance availability
  3. Adjust spot instance preferences
  4. Review workload spot compatibility

#### EFSStorageCostHigh
- **Severity**: warning
- **Condition**: EFS daily cost > $50
- **Duration**: 24 hours
- **Description**: EFS storage cost is high
- **Remediation**:
  1. Review EFS storage usage and growth
  2. Consider EFS Lifecycle Management
  3. Clean up unused files
  4. Review access patterns for optimization

---

## Alert Configuration

### Prometheus Alert Rules File

Alert rules are defined in: `modules/observability/modules/prometheus/files/alert-rules.yaml`

### AlertManager Integration

When AlertManager is enabled, alerts are routed based on:
- **Severity**: Critical alerts to PagerDuty, warnings to Slack
- **Component**: Application alerts to dev team, infrastructure to ops team
- **Team**: Routing based on team label

### Notification Channels

Configure notification channels via application stack variables:
- `smtp_config` - Email notifications
- `sns_topic_arn` - AWS SNS notifications
- `slack_webhook_url` - Slack notifications
- `pagerduty_integration_key` - PagerDuty integration

---

## Customizing Alert Rules

### Adding New Alert Rules

1. Edit `modules/observability/modules/prometheus/files/alert-rules.yaml`
2. Add new rule to appropriate group:
```yaml
- alert: MyCustomAlert
  expr: my_metric > threshold
  for: 5m
  labels:
    severity: warning
    component: my-component
  annotations:
    summary: "Brief description"
    description: "Detailed description with {{ $labels.instance }}"
    remediation: |
      1. Step one
      2. Step two
```
3. Apply Terraform changes
4. Verify rule in Prometheus UI: Status > Rules

### Modifying Thresholds

Edit the `expr` field in the alert rule:
```yaml
# Before
expr: node_cpu_usage > 0.85

# After (more lenient)
expr: node_cpu_usage > 0.90
```

### Adjusting Alert Duration

Modify the `for` field:
```yaml
# Before
for: 5m

# After (less sensitive)
for: 15m
```

---

## Testing Alerts

### Manual Alert Testing

1. **Trigger condition manually**:
```bash
# Example: Increase load to trigger CPU alert
kubectl run stress --image=polinux/stress -- stress --cpu 4
```

2. **Check alert status in Prometheus**:
   - Navigate to Prometheus UI
   - Go to Alerts tab
   - Verify alert is firing

3. **Verify notification delivery**:
   - Check configured notification channels
   - Verify alert appears in Slack/email/PagerDuty

### Alert Silencing

Temporarily silence alerts during maintenance:
```bash
# Via AlertManager UI
# Or via amtool CLI
amtool silence add alertname=NodeHighCPU --duration=1h
```

---

## Troubleshooting

### Alert Not Firing

1. **Check metric availability**:
```promql
# Run query in Prometheus
up{job="wordpress"}
```

2. **Verify alert rule syntax**:
   - Check Prometheus logs for errors
   - Validate PromQL expression

3. **Check alert evaluation**:
   - Prometheus UI > Alerts
   - Look for evaluation errors

### Alert Firing Incorrectly

1. **Review alert condition**:
   - Check if threshold is appropriate
   - Verify metric labels match

2. **Adjust sensitivity**:
   - Increase duration (`for` field)
   - Adjust threshold in `expr`

3. **Add label filters**:
```yaml
# Before
expr: node_cpu_usage > 0.85

# After (exclude specific nodes)
expr: node_cpu_usage{node!~"test-.*"} > 0.85
```

---

## Related Documentation

- [Dashboards Reference](dashboards.md) - Grafana dashboards for visualization
- [Monitoring Guide](../features/monitoring/README.md) - Monitoring stack overview
- [Prometheus Configuration](../features/monitoring/prometheus.md) - Prometheus setup
- [AlertManager Configuration](../features/monitoring/alerting.md) - Alert routing and notifications
- [Operations Runbook](../operations/troubleshooting.md) - Troubleshooting procedures

