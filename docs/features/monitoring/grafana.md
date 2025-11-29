# Grafana Dashboard and Visualization

## Overview

Grafana provides powerful visualization and dashboarding capabilities for the WordPress EKS platform. It integrates with Prometheus and CloudWatch data sources to provide comprehensive insights into application performance, infrastructure health, and AWS service metrics.

## Features

- **Multiple Data Sources**: Prometheus (primary) and CloudWatch (optional)
- **AWS IAM Authentication**: Secure access via IRSA without managing passwords
- **Persistent Dashboards**: Dashboard configurations stored in persistent volumes
- **Pre-configured Dashboards**: Ready-to-use dashboards for WordPress, Kubernetes, and AWS services
- **RBAC Integration**: Role-based access control for different user types
- **Custom Dashboards**: Support for custom dashboard configurations

## Prerequisites

- Prometheus stack deployed and collecting metrics
- EKS cluster with OIDC provider configured
- Appropriate IAM permissions for IRSA roles
- (Optional) CloudWatch data source enabled for AWS metrics

## Configuration

### Basic Configuration

Enable Grafana in your Terraform Cloud workspace variables:

```hcl
# Enable Grafana
enable_grafana = true

# Storage configuration
grafana_storage_size  = "10Gi"
grafana_storage_class = "gp3"

# Enable default dashboards
enable_default_dashboards = true
```

### Production Configuration

For production environments with high availability:

```hcl
# Enable Grafana
enable_grafana = true

# Storage configuration
grafana_storage_size  = "20Gi"
grafana_storage_class = "gp3"

# Resource allocation
grafana_resource_requests = {
  cpu    = "200m"
  memory = "512Mi"
}

grafana_resource_limits = {
  cpu    = "1"
  memory = "2Gi"
}

# Authentication
enable_aws_iam_auth = true
grafana_iam_role_arns = [
  "arn:aws:iam::123456789012:role/DevOpsTeam",
  "arn:aws:iam::123456789012:role/PlatformEngineers"
]

# Data sources
enable_default_dashboards    = true
enable_cloudwatch_datasource = true
```

### Development Configuration

For development/testing environments:

```hcl
# Enable Grafana
enable_grafana = true

# Minimal storage
grafana_storage_size = "5Gi"

# Reduced resources
grafana_resource_requests = {
  cpu    = "100m"
  memory = "256Mi"
}

grafana_resource_limits = {
  cpu    = "500m"
  memory = "1Gi"
}

# Basic authentication (no IAM)
enable_aws_iam_auth = false
```

## Deployment

### Step 1: Configure Variables

Set the required variables in your Terraform Cloud workspace (see Configuration section above).

### Step 2: Deploy

```bash
cd stacks/app
make plan-app
make apply-app
```

### Step 3: Verify Deployment

```bash
# Check Grafana pod
kubectl get pods -n observability -l app=grafana

# Check Grafana service
kubectl get svc -n observability grafana

# Check persistent volume
kubectl get pvc -n observability -l app=grafana
```

## Accessing Grafana

### Port Forward (Development)

```bash
kubectl port-forward -n observability svc/grafana 3000:80
```

Then access at: http://localhost:3000

### Default Credentials

If AWS IAM authentication is disabled, use:
- **Username**: `admin`
- **Password**: Retrieved from Kubernetes secret or auto-generated

Get the password:

```bash
kubectl get secret -n observability grafana-admin-credentials -o jsonpath='{.data.password}' | base64 -d
```

### AWS IAM Authentication

When `enable_aws_iam_auth = true`:

1. Ensure your IAM role is in the `grafana_iam_role_arns` list
2. Assume the IAM role
3. Access Grafana URL
4. You'll be automatically authenticated via AWS IAM

## Pre-configured Dashboards

When `enable_default_dashboards = true`, the following dashboards are automatically created:

### 1. WordPress Overview

**Purpose**: Monitor WordPress application performance

**Panels**:
- Request rate by HTTP method and status code
- Response time (95th percentile)
- Active users count
- Cache hit rate gauge
- Error rate over time
- Top requested pages

**Use Cases**:
- Identify performance bottlenecks
- Monitor user traffic patterns
- Track cache effectiveness
- Detect error spikes

### 2. Kubernetes Cluster Overview

**Purpose**: Monitor EKS cluster health and resource utilization

**Panels**:
- Node CPU usage by instance
- Node memory usage by instance
- Running pod count
- Node count
- Pod restarts
- Container resource usage
- Persistent volume usage

**Use Cases**:
- Capacity planning
- Resource optimization
- Identify node issues
- Monitor pod health

### 3. AWS Services Monitoring

**Purpose**: Monitor AWS managed services

**Panels**:
- RDS CPU utilization
- RDS database connections
- ElastiCache CPU utilization
- ElastiCache cache hit rate
- ALB request count
- ALB target response time
- EFS throughput
- CloudFront metrics (if enabled)

**Use Cases**:
- Database performance monitoring
- Cache effectiveness tracking
- Load balancer health
- Storage performance

## Data Sources

### Prometheus Data Source

**Configuration**:
- **Type**: Prometheus
- **URL**: `http://prometheus-server:9090`
- **Access**: Proxy (via Grafana backend)
- **Default**: Yes

**Metrics Available**:
- Kubernetes metrics (nodes, pods, containers)
- Application metrics (WordPress, custom exporters)
- Infrastructure metrics (CPU, memory, disk, network)

### CloudWatch Data Source

**Configuration** (when `enable_cloudwatch_datasource = true`):
- **Type**: CloudWatch
- **Authentication**: AWS IAM (via IRSA)
- **Default Region**: Configurable
- **Access**: All CloudWatch metrics and logs

**Metrics Available**:
- RDS metrics
- ElastiCache metrics
- ALB metrics
- EFS metrics
- CloudFront metrics
- Lambda metrics
- Custom CloudWatch metrics

## Creating Custom Dashboards

### Via Grafana UI

1. Access Grafana
2. Click **+** → **Dashboard**
3. Add panels with queries
4. Configure visualizations
5. Save dashboard

### Via Terraform Configuration

Add custom dashboard configurations:

```hcl
custom_dashboard_configs = {
  "custom-app-dashboard" = jsonencode({
    title = "Custom Application Dashboard"
    panels = [
      {
        title = "Custom Metric"
        targets = [
          {
            expr = "custom_metric_name"
          }
        ]
      }
    ]
  })
}
```

### Dashboard Persistence

Dashboards are automatically persisted to the EBS-backed persistent volume. They will survive:
- Pod restarts
- Node failures
- Cluster upgrades

## RBAC and Access Control

### Kubernetes RBAC

Grafana service account has permissions to:
- Read ConfigMaps (for dashboard configs)
- Read Secrets (for data source credentials)
- List namespaces (for service discovery)

### Grafana RBAC

Built-in roles:
- **Admin**: Full access to all features
- **Editor**: Can create and edit dashboards
- **Viewer**: Read-only access to dashboards

### IAM Role Mapping

When using AWS IAM authentication:

```hcl
grafana_iam_role_arns = [
  "arn:aws:iam::123456789012:role/GrafanaAdmins",   # Admin role
  "arn:aws:iam::123456789012:role/GrafanaViewers"   # Viewer role
]
```

Users assuming these roles get appropriate Grafana permissions.

## Dashboard Best Practices

### Performance

1. **Limit Time Range**: Use shorter time ranges for better performance
2. **Reduce Query Frequency**: Set appropriate refresh intervals
3. **Use Variables**: Create reusable dashboard variables
4. **Optimize Queries**: Use efficient PromQL queries

### Organization

1. **Use Folders**: Organize dashboards into logical folders
2. **Naming Convention**: Use clear, descriptive names
3. **Tags**: Add tags for easy discovery
4. **Documentation**: Add panel descriptions

### Visualization

1. **Choose Appropriate Visualizations**: Match visualization to data type
2. **Use Thresholds**: Set meaningful thresholds for alerts
3. **Color Coding**: Use consistent color schemes
4. **Units**: Always specify units for metrics

## Troubleshooting

### Grafana Pod Not Starting

Check pod status:

```bash
kubectl describe pod -n observability -l app=grafana
```

Common issues:
- Persistent volume not available
- Insufficient resources
- Image pull errors

### Cannot Access Grafana

Check service:

```bash
kubectl get svc -n observability grafana
kubectl describe svc grafana -n observability
```

Verify port-forward:

```bash
kubectl port-forward -n observability svc/grafana 3000:80
```

### Dashboards Not Loading

Check Grafana logs:

```bash
kubectl logs -n observability deployment/grafana
```

Verify data source configuration:

```bash
kubectl get configmap -n observability grafana-datasources -o yaml
```

### Prometheus Data Source Not Working

Test Prometheus connectivity:

```bash
kubectl exec -n observability deployment/grafana -- \
  curl -s http://prometheus-server:9090/api/v1/query?query=up
```

### CloudWatch Data Source Authentication Failed

Verify IRSA configuration:

```bash
# Check service account annotation
kubectl get sa -n observability grafana -o yaml

# Check IAM role
aws iam get-role --role-name <cluster-name>-grafana
```

### Dashboard Changes Not Persisting

Check persistent volume:

```bash
kubectl get pvc -n observability -l app=grafana
kubectl describe pvc <pvc-name> -n observability
```

Verify storage class:

```bash
kubectl get storageclass
```

## Monitoring Grafana

### Key Metrics

Monitor these Grafana metrics:
- `grafana_api_response_status_total`: API response status codes
- `grafana_api_request_duration_seconds`: API request duration
- `grafana_database_queries_total`: Database query count
- `grafana_alerting_active_alerts`: Active alert count

### Health Check

Check Grafana health:

```bash
kubectl exec -n observability deployment/grafana -- \
  curl -s http://localhost:3000/api/health
```

### Resource Usage

Monitor resource consumption:

```bash
kubectl top pod -n observability -l app=grafana
```

## Backup and Recovery

### Automated Backups

When `enable_backup_policies = true`:
- Grafana persistent volume backed up daily
- Dashboard configurations included
- Retention: 30 days (configurable)

### Manual Backup

Export dashboards:

```bash
# List all dashboards
kubectl exec -n observability deployment/grafana -- \
  grafana-cli admin data-migration list

# Export specific dashboard
kubectl exec -n observability deployment/grafana -- \
  grafana-cli admin export-dashboard <dashboard-uid>
```

### Recovery

Restore from AWS Backup:

```bash
aws backup start-restore-job \
  --recovery-point-arn <arn> \
  --metadata file://restore-metadata.json
```

## Integration with Other Tools

### AlertManager Integration

Configure AlertManager as a data source to display alerts in Grafana:

```hcl
# AlertManager will be automatically configured as a data source
enable_alertmanager = true
```

### Prometheus Integration

Grafana automatically discovers Prometheus when both are enabled:

```hcl
enable_prometheus_stack = true
enable_grafana = true
```

### CloudWatch Integration

Enable CloudWatch data source for AWS metrics:

```hcl
enable_cloudwatch_datasource = true
```

## Advanced Configuration

### Custom Grafana Configuration

Override Grafana settings via `grafana.ini`:

```hcl
grafana_custom_config = {
  "server" = {
    "root_url" = "https://grafana.example.com"
  }
  "security" = {
    "admin_user" = "admin"
  }
}
```

### Plugin Installation

Install additional Grafana plugins:

```hcl
grafana_plugins = [
  "grafana-piechart-panel",
  "grafana-worldmap-panel"
]
```

### SMTP Configuration

Configure email notifications:

```hcl
smtp_config = {
  host          = "smtp.example.com:587"
  user          = "grafana@example.com"
  password      = "password"
  from_address  = "grafana@example.com"
  from_name     = "Grafana"
}
```

## Security Considerations

1. **Use AWS IAM Authentication**: Avoid managing passwords
2. **Enable TLS**: Encrypt traffic to Grafana
3. **Restrict IAM Roles**: Limit who can access Grafana
4. **Regular Updates**: Keep Grafana version up to date
5. **Audit Logging**: Enable audit logs for compliance
6. **Network Policies**: Restrict network access to Grafana

## Performance Tuning

### For Large Deployments

```hcl
grafana_resource_limits = {
  cpu    = "2"
  memory = "4Gi"
}

# Increase storage for more dashboards
grafana_storage_size = "50Gi"
```

### Query Optimization

1. Use recording rules in Prometheus for complex queries
2. Set appropriate time ranges
3. Use dashboard variables for filtering
4. Cache query results when possible

## Related Documentation

- [Enhanced Monitoring Overview](./README.md)
- [Prometheus Configuration](./prometheus.md)
- [AlertManager Configuration](./alerting.md)
- [Migration Guide](./migration-guide.md)
- [Variables Reference](../../reference/variables.md)
