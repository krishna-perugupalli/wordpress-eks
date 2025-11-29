# Terraform Cloud Variables for Enhanced Monitoring

This document provides a quick reference for configuring the enhanced monitoring stack in your Terraform Cloud `wp-app` workspace.

## Quick Start - Minimal Prometheus

Set these variables in your Terraform Cloud `wp-app` workspace:

```hcl
enable_prometheus_stack = true
```

That's it! This will deploy Prometheus with default settings:
- 50Gi storage
- 30 days retention  
- 2 replicas for HA
- Service discovery enabled

## Production Configuration

For production environments, add these variables:

```hcl
# Core Prometheus
enable_prometheus_stack = true
prometheus_storage_size = "200Gi"
prometheus_retention_days = 90
prometheus_replica_count = 3

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
enable_service_discovery = true
service_discovery_namespaces = ["default", "wordpress", "kube-system", "observability"]
```

## Complete Monitoring Stack

When all tasks are completed, you can enable the full stack:

```hcl
# Enable all components
enable_prometheus_stack = true
enable_grafana = true
enable_alertmanager = true

# Exporters
enable_wordpress_exporter = true
enable_mysql_exporter = true
enable_redis_exporter = true
enable_cloudwatch_exporter = true
enable_cost_monitoring = true

# Security features
enable_security_features = true
enable_tls_encryption = true
enable_pii_scrubbing = true
enable_audit_logging = true
```

## Variable Reference

### Core Prometheus Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_prometheus_stack` | `bool` | `false` | Enable Prometheus monitoring |
| `prometheus_storage_size` | `string` | `"50Gi"` | Persistent storage size |
| `prometheus_retention_days` | `number` | `30` | Metrics retention period |
| `prometheus_replica_count` | `number` | `2` | Number of Prometheus replicas |
| `prometheus_storage_class` | `string` | `"gp3"` | Storage class for PVs |

### Resource Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `prometheus_resource_requests` | `object` | `{cpu="500m", memory="2Gi"}` | Resource requests |
| `prometheus_resource_limits` | `object` | `{cpu="2", memory="8Gi"}` | Resource limits |

### Service Discovery

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_service_discovery` | `bool` | `true` | Enable automatic service discovery |
| `service_discovery_namespaces` | `list(string)` | `["default", "wordpress", "kube-system"]` | Namespaces to monitor |

### Grafana Variables (Task 6)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_grafana` | `bool` | `false` | Enable Grafana dashboards |
| `grafana_storage_size` | `string` | `"10Gi"` | Grafana storage size |
| `enable_default_dashboards` | `bool` | `true` | Enable pre-built dashboards |
| `enable_aws_iam_auth` | `bool` | `true` | Enable AWS IAM authentication |

### AlertManager Variables (Task 8)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_alertmanager` | `bool` | `false` | Enable AlertManager |
| `alertmanager_storage_size` | `string` | `"10Gi"` | AlertManager storage size |
| `alertmanager_replica_count` | `number` | `2` | Number of AlertManager replicas |
| `sns_topic_arn` | `string` | `""` | SNS topic for notifications |

### Exporter Variables (Tasks 4-5, 10)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_wordpress_exporter` | `bool` | `false` | Enable WordPress metrics |
| `enable_mysql_exporter` | `bool` | `false` | Enable MySQL/Aurora metrics |
| `enable_redis_exporter` | `bool` | `false` | Enable Redis/ElastiCache metrics |
| `enable_cloudwatch_exporter` | `bool` | `false` | Enable CloudWatch metrics export |
| `enable_cost_monitoring` | `bool` | `false` | Enable AWS cost monitoring |

### Security Variables (Task 12)

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_security_features` | `bool` | `true` | Enable security features |
| `enable_tls_encryption` | `bool` | `true` | Enable TLS for communications |
| `enable_pii_scrubbing` | `bool` | `true` | Enable PII scrubbing |
| `enable_audit_logging` | `bool` | `true` | Enable audit logging |

## How to Set Variables in Terraform Cloud

1. **Navigate to Workspace**
   - Go to your `wp-app` workspace in Terraform Cloud
   - Click on the **Variables** tab

2. **Add Terraform Variables**
   - Click **"+ Add variable"**
   - Select **"Terraform variable"** (not Environment variable)
   - Enter the variable name (e.g., `enable_prometheus_stack`)
   - Enter the value (e.g., `true`)
   - For complex objects, use HCL format:
     ```hcl
     {
       cpu    = "1"
       memory = "4Gi"
     }
     ```

3. **Save and Apply**
   - Click **"Save variable"**
   - Repeat for all desired variables
   - Queue a plan to see the changes
   - Apply when ready

## Environment-Specific Configurations

### Development Environment

```hcl
enable_prometheus_stack = true
prometheus_storage_size = "20Gi"
prometheus_retention_days = 15
prometheus_replica_count = 1
prometheus_resource_requests = {
  cpu    = "200m"
  memory = "1Gi"
}
```

### Staging Environment

```hcl
enable_prometheus_stack = true
prometheus_storage_size = "50Gi"
prometheus_retention_days = 30
prometheus_replica_count = 2
```

### Production Environment

```hcl
enable_prometheus_stack = true
prometheus_storage_size = "200Gi"
prometheus_retention_days = 90
prometheus_replica_count = 3
prometheus_resource_requests = {
  cpu    = "1"
  memory = "4Gi"
}
prometheus_resource_limits = {
  cpu    = "4"
  memory = "16Gi"
}
```

## Storage Sizing Guidelines

| Environment | Metrics Series | Recommended Storage | Retention |
|-------------|----------------|-------------------|-----------|
| Development | < 10k | 20Gi | 15 days |
| Staging | 10k - 50k | 50Gi | 30 days |
| Production | 50k - 200k | 100-200Gi | 90 days |
| Large Production | > 200k | 500Gi+ | 90+ days |

**Rule of thumb**: ~1GB per day per 10k active time series

## Verification Commands

After setting variables and applying:

```bash
# Check if variables took effect
kubectl get pods -n observability -l app.kubernetes.io/name=prometheus

# Verify storage size
kubectl get pvc -n observability

# Check Prometheus configuration
kubectl get prometheus -n observability -o yaml
```

## Troubleshooting Variables

### Variable Not Taking Effect
- Ensure variable is set as **Terraform variable**, not Environment variable
- Check variable name matches exactly (case-sensitive)
- Queue a new plan to see if changes are detected

### Invalid Variable Format
- For objects, use HCL format: `{ key = "value" }`
- For lists, use HCL format: `["item1", "item2"]`
- For booleans, use `true` or `false` (not quoted)

### Storage Issues
- Ensure storage size is valid Kubernetes format: `"50Gi"`, `"100Gi"`
- Check if storage class exists in your cluster
- Verify EBS CSI driver is installed