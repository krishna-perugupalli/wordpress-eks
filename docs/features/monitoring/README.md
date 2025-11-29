# Enhanced Monitoring Integration Guide

## Overview

The enhanced observability module provides comprehensive monitoring, alerting, and visualization capabilities for the WordPress EKS platform. It supports both CloudWatch (legacy) and Prometheus stack (modern) monitoring approaches, allowing for a gradual migration or hybrid deployment.

## Architecture

The enhanced monitoring stack consists of:

- **CloudWatch Integration**: Legacy monitoring with Container Insights, CloudWatch Agent, and Fluent Bit
- **Prometheus Stack**: Modern metrics collection with persistent storage and service discovery
- **Grafana**: Visualization and dashboards with AWS IAM authentication
- **AlertManager**: Intelligent alert routing and notification management
- **Exporters**: Application-specific metrics collection (WordPress, MySQL, Redis, AWS services)
- **Security Features**: TLS encryption, PII scrubbing, audit logging, and RBAC

## Deployment Modes

### Mode 1: CloudWatch Only (Default/Legacy)

Maintains backward compatibility with existing deployments:

```hcl
enable_cloudwatch        = true
enable_prometheus_stack  = false
enable_grafana          = false
enable_alertmanager     = false
```

### Mode 2: Hybrid (Recommended for Migration)

Run both CloudWatch and Prometheus stack side-by-side:

```hcl
enable_cloudwatch        = true
enable_prometheus_stack  = true
enable_grafana          = true
enable_alertmanager     = true
```

### Mode 3: Prometheus Only (Future State)

Full migration to Prometheus stack:

```hcl
enable_cloudwatch        = false
enable_prometheus_stack  = true
enable_grafana          = true
enable_alertmanager     = true
```

## Quick Start

### 1. Enable Enhanced Monitoring

Add to your `terraform.tfvars`:

```hcl
# Enable Prometheus stack
enable_prometheus_stack = true
enable_grafana          = true
enable_alertmanager     = true

# Configure storage
prometheus_storage_size = "100Gi"
grafana_storage_size    = "20Gi"

# Enable service discovery
enable_service_discovery = true
service_discovery_namespaces = ["wordpress", "kube-system"]
```

### 2. Deploy the Stack

```bash
cd stacks/app
terraform plan
terraform apply
```

### 3. Access Grafana

Get the Grafana URL:

```bash
terraform output grafana_url
```

Port-forward to access locally:

```bash
kubectl port-forward -n observability svc/grafana 3000:80
```

Access at: http://localhost:3000

## Configuration Reference

### Prometheus Configuration

```hcl
# Storage configuration
prometheus_storage_size      = "100Gi"  # Adjust based on metrics volume
prometheus_retention_days    = 30       # Metrics retention period
prometheus_storage_class     = "gp3"    # EBS storage class
prometheus_replica_count     = 2        # High availability

# Resource allocation
prometheus_resource_requests = {
  cpu    = "1"
  memory = "4Gi"
}

prometheus_resource_limits = {
  cpu    = "4"
  memory = "16Gi"
}

# Service discovery
enable_service_discovery     = true
service_discovery_namespaces = ["default", "wordpress", "kube-system"]
```

### Grafana Configuration

```hcl
# Storage configuration
grafana_storage_size  = "20Gi"
grafana_storage_class = "gp3"

# Authentication
enable_aws_iam_auth = true
grafana_iam_role_arns = [
  "arn:aws:iam::123456789012:role/DevOpsTeam"
]

# Dashboards
enable_default_dashboards    = true
enable_cloudwatch_datasource = true

# Resource allocation
grafana_resource_requests = {
  cpu    = "200m"
  memory = "512Mi"
}
```

### AlertManager Configuration

```hcl
# Storage configuration
alertmanager_storage_size  = "10Gi"
alertmanager_replica_count = 2

# Notification channels
sns_topic_arn             = "arn:aws:sns:region:account:alerts"
slack_webhook_url         = "https://hooks.slack.com/services/..."
pagerduty_integration_key = "your-key"

# Alert routing
alert_routing_config = {
  group_by        = ["alertname", "cluster", "service"]
  group_wait      = "10s"
  group_interval  = "10s"
  repeat_interval = "1h"
  routes = [
    {
      match = { severity = "critical" }
      receiver = "pagerduty"
      continue = true
    }
  ]
}
```

### Exporters Configuration

#### WordPress Exporter

```hcl
enable_wordpress_exporter = true
wordpress_namespace       = "wordpress"
```

Automatically deploys as sidecar to WordPress pods.

#### MySQL Exporter

```hcl
enable_mysql_exporter = true
mysql_connection_config = {
  host                = "aurora-endpoint.rds.amazonaws.com"
  port                = 3306
  username            = "monitoring_user"
  password_secret_ref = "arn:aws:secretsmanager:..."
  database            = "wordpress"
}
```

#### Redis Exporter

```hcl
enable_redis_exporter = true
redis_connection_config = {
  host                = "redis.cache.amazonaws.com"
  port                = 6379
  password_secret_ref = "arn:aws:secretsmanager:..."
  tls_enabled         = true
}
```

#### CloudWatch Exporter

```hcl
enable_cloudwatch_exporter = true
cloudwatch_metrics_config = {
  discovery_jobs = [
    {
      type    = "rds"
      regions = ["us-east-1"]
      search_tags = { Environment = "production" }
      metrics = ["CPUUtilization", "DatabaseConnections"]
    }
  ]
}
```

#### Cost Monitoring

```hcl
enable_cost_monitoring = true
cost_allocation_tags   = ["Environment", "Project", "Component"]
```

### Security Configuration

```hcl
enable_security_features = true
enable_tls_encryption    = true
enable_pii_scrubbing     = true
enable_audit_logging     = true
audit_log_retention_days = 90

pii_scrubbing_rules = [
  {
    pattern     = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
    replacement = "[EMAIL_REDACTED]"
    description = "Email addresses"
  }
]
```

### High Availability Configuration

```hcl
# Backup policies
enable_backup_policies = true
backup_retention_days  = 30

# CloudWatch fallback
enable_cloudwatch_fallback = true
fallback_alert_email       = "ops-team@example.com"

# Automatic recovery
enable_automatic_recovery = true

# Network resilience
enable_network_resilience   = true
remote_write_queue_capacity = 10000
```

## Accessing Monitoring Components

### Prometheus

```bash
# Get Prometheus URL
terraform output prometheus_url

# Port-forward
kubectl port-forward -n observability svc/prometheus-server 9090:9090

# Access at http://localhost:9090
```

### Grafana

```bash
# Get Grafana URL
terraform output grafana_url

# Port-forward
kubectl port-forward -n observability svc/grafana 3000:80

# Access at http://localhost:3000
```

### AlertManager

```bash
# Get AlertManager URL
terraform output alertmanager_url

# Port-forward
kubectl port-forward -n observability svc/alertmanager 9093:9093

# Access at http://localhost:9093
```

## Pre-configured Dashboards

When `enable_default_dashboards = true`, the following dashboards are automatically created:

1. **WordPress Overview**: Application metrics, request rates, response times
2. **Kubernetes Cluster**: Node health, pod status, resource utilization
3. **AWS Services**: RDS, ElastiCache, ALB, EFS metrics
4. **Cost Tracking**: AWS service costs, optimization opportunities

## Alert Rules

The following alert rules are automatically configured:

### Critical Alerts
- WordPress service down
- Database connection pool exhausted
- High error rate (>5%)
- Disk space critical (<10%)
- Pod crash looping

### Warning Alerts
- High CPU utilization (>80%)
- High memory usage (>85%)
- Slow database queries (>1s)
- Cache hit rate low (<70%)
- Cost threshold exceeded

## Troubleshooting

### Prometheus Not Scraping Metrics

Check ServiceMonitor resources:

```bash
kubectl get servicemonitors -n observability
kubectl describe servicemonitor <name> -n observability
```

Check Prometheus targets:

```bash
kubectl port-forward -n observability svc/prometheus-server 9090:9090
# Visit http://localhost:9090/targets
```

### Grafana Dashboard Not Loading

Check Grafana logs:

```bash
kubectl logs -n observability deployment/grafana
```

Verify data source configuration:

```bash
kubectl get configmap -n observability grafana-datasources -o yaml
```

### Alerts Not Firing

Check AlertManager configuration:

```bash
kubectl get configmap -n observability alertmanager-config -o yaml
```

Check AlertManager logs:

```bash
kubectl logs -n observability deployment/alertmanager
```

### Storage Issues

Check PVC status:

```bash
kubectl get pvc -n observability
kubectl describe pvc <name> -n observability
```

Check storage capacity:

```bash
kubectl exec -n observability deployment/prometheus-server -- df -h /prometheus
```

## Migration Guide

### From CloudWatch to Prometheus

1. **Phase 1: Enable Hybrid Mode**
   ```hcl
   enable_cloudwatch       = true
   enable_prometheus_stack = true
   ```

2. **Phase 2: Validate Prometheus**
   - Verify metrics collection
   - Test dashboards
   - Validate alerts

3. **Phase 3: Disable CloudWatch**
   ```hcl
   enable_cloudwatch       = false
   enable_prometheus_stack = true
   ```

## Performance Tuning

### Prometheus Storage

Adjust retention and storage based on metrics volume:

```hcl
prometheus_storage_size   = "200Gi"  # For high-volume environments
prometheus_retention_days = 60       # Extended retention
```

### Resource Allocation

For large clusters, increase resource limits:

```hcl
prometheus_resource_limits = {
  cpu    = "8"
  memory = "32Gi"
}
```

### Service Discovery

Limit namespaces to reduce overhead:

```hcl
service_discovery_namespaces = ["wordpress"]  # Only monitor WordPress
```

## Cost Optimization

### Storage Costs

- Use `gp3` storage class for better price/performance
- Adjust retention periods based on requirements
- Enable lifecycle policies for old metrics

### Compute Costs

- Right-size resource requests/limits
- Use spot instances for non-critical monitoring components
- Disable unused exporters

## Security Best Practices

1. **Enable TLS encryption** for all monitoring communications
2. **Use AWS IAM authentication** for Grafana access
3. **Enable PII scrubbing** to prevent sensitive data collection
4. **Configure RBAC policies** for least-privilege access
5. **Enable audit logging** for compliance requirements
6. **Rotate credentials** stored in Secrets Manager regularly

## Backup and Recovery

### Automated Backups

When `enable_backup_policies = true`:
- Prometheus data backed up daily
- Grafana dashboards backed up daily
- Retention: 30 days (configurable)

### Manual Backup

Export Grafana dashboards:

```bash
kubectl exec -n observability deployment/grafana -- \
  grafana-cli admin export-dashboard <dashboard-id>
```

### Recovery

Restore from AWS Backup:

```bash
aws backup start-restore-job \
  --recovery-point-arn <arn> \
  --metadata file://restore-metadata.json
```

## Outputs Reference

After deployment, the following outputs are available:

```bash
terraform output monitoring_stack_summary
terraform output prometheus_url
terraform output grafana_url
terraform output alertmanager_url
terraform output wordpress_exporter_enabled
terraform output mysql_exporter_enabled
terraform output cost_monitoring_enabled
```

## Support and Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Project Runbook](../../runbook.md)
- [Architecture Documentation](../../architecture.md)
