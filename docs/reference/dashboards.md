# Grafana Dashboards Reference

This document provides a comprehensive reference for all Grafana dashboards configured in the WordPress EKS platform.

## Overview

Pre-configured dashboards are organized by category:
- **WordPress Application** - Application performance and health
- **Kubernetes Cluster** - Cluster resources and pod health
- **AWS Services** - Managed AWS services monitoring
- **Cost Management** - Cost tracking and optimization

All dashboards are stored in: `modules/observability/modules/grafana/dashboards/`

## Dashboard Configuration

### Persistence
- **Storage**: Persistent volume for dashboard state
- **Version Control**: Up to 20 versions retained per dashboard
- **Editability**: Dashboards can be edited through Grafana UI
- **Auto-reload**: Dashboards reload every 30 seconds from ConfigMaps

### Data Sources
- **Prometheus**: Primary data source for metrics
- **CloudWatch**: Secondary data source for AWS native metrics (optional)

### Refresh Rates
- **Application/Infrastructure**: 30 seconds
- **Cost Tracking**: 5 minutes

---

## Available Dashboards

### 1. WordPress Application Overview

**File**: `wordpress-overview.json`

**Purpose**: Monitor WordPress application performance and health

**Key Panels**:

#### HTTP Request Metrics
- **HTTP Request Rate by Method**: Tracks GET, POST, PUT, DELETE requests per second
- **HTTP Request Rate by Status Code**: Monitors 2xx, 3xx, 4xx, 5xx responses
- **Response Time Percentiles**: Shows p50, p95, p99 response times
- **Active User Count**: Current active users on the site

#### Cache Performance
- **Cache Hit Rate**: Percentage of requests served from cache
- **Cache Hits vs Misses**: Time series comparison
- **Cache Operations**: Hit/miss breakdown by cache type

#### Database Metrics
- **Database Query Rate**: Queries per second
- **Database Query Breakdown**: Queries by type (SELECT, INSERT, UPDATE, DELETE)
- **Database Connection Count**: Active database connections

#### WordPress Specific
- **WordPress Service Status**: Up/down status indicator
- **Plugin Execution Time**: Slowest plugins by execution time
- **WordPress Version**: Current WordPress version

**Use Cases**:
- Identify performance bottlenecks
- Monitor cache effectiveness
- Track user activity patterns
- Detect slow plugins
- Analyze database query patterns

**Metrics Used**:
```promql
wordpress_http_requests_total{method, status, endpoint}
wordpress_http_request_duration_seconds{method, endpoint}
wordpress_active_users_total
wordpress_plugin_execution_time_seconds{plugin}
wordpress_database_queries_total{type}
wordpress_cache_hits_total{type}
wordpress_cache_misses_total{type}
```

---

### 2. Kubernetes Cluster Overview

**File**: `kubernetes-cluster.json`

**Purpose**: Monitor Kubernetes cluster health and resource utilization

**Key Panels**:

#### Cluster Summary
- **Total Node Count**: Number of nodes in cluster
- **Running Pod Count**: Total running pods
- **Deployment Count**: Number of deployments
- **Failed Pod Count**: Pods in failed state
- **Pending Pod Count**: Pods waiting to be scheduled
- **Namespace Count**: Total namespaces

#### Node Resources
- **Node CPU Usage by Instance**: CPU utilization per node
- **Node Memory Usage by Instance**: Memory utilization per node
- **Node Disk Available Space**: Free disk space per node
- **Network I/O**: Network receive/transmit bytes per node

#### Pod Distribution
- **Pods by Namespace**: Pod count grouped by namespace
- **Top Pods by CPU Usage**: Most CPU-intensive pods
- **Top Pods by Memory Usage**: Most memory-intensive pods

#### Health Status
- **Node Status**: Ready/NotReady status per node
- **Pod Phase Distribution**: Pods by phase (Running, Pending, Failed)
- **Container Restart Count**: Containers with restarts

**Use Cases**:
- Monitor cluster capacity and utilization
- Identify resource-constrained nodes
- Track pod health and status
- Plan capacity scaling
- Troubleshoot node issues

**Metrics Used**:
```promql
node_cpu_seconds_total{mode, instance}
node_memory_MemTotal_bytes{instance}
node_memory_MemAvailable_bytes{instance}
node_filesystem_avail_bytes{mountpoint, instance}
node_network_receive_bytes_total{device, instance}
node_network_transmit_bytes_total{device, instance}
kube_pod_status_phase{namespace, pod, phase}
kube_deployment_status_replicas{namespace, deployment}
kube_node_info
kube_namespace_created
container_cpu_usage_seconds_total{container, namespace, pod}
```

---

### 3. AWS Services Monitoring

**File**: `aws-services.json`

**Purpose**: Monitor AWS managed services used by the platform

**Key Panels**:

#### RDS/Aurora
- **RDS CPU Utilization**: Database CPU usage percentage
- **RDS Database Connections**: Active database connections
- **RDS Read/Write IOPS**: Database I/O operations per second
- **RDS Freeable Memory**: Available memory on database instance

#### ElastiCache Redis
- **ElastiCache CPU Utilization**: Cache CPU usage percentage
- **ElastiCache Memory Usage**: Cache memory utilization
- **ElastiCache Network Bytes In/Out**: Cache network traffic
- **ElastiCache Current Connections**: Active cache connections

#### Application Load Balancer
- **ALB Request Count**: Total requests per second
- **ALB Target Response Time**: Average response time from targets
- **ALB HTTP Status Codes**: Response codes (2xx, 3xx, 4xx, 5xx)
- **ALB Active Connection Count**: Current active connections

#### EFS Storage
- **EFS I/O Bytes Read**: Data read from EFS
- **EFS I/O Bytes Write**: Data written to EFS
- **EFS Client Connections**: Active EFS client connections
- **EFS Throughput**: Read/write throughput

**Use Cases**:
- Monitor database performance
- Track cache effectiveness
- Analyze load balancer traffic
- Monitor shared storage usage
- Identify AWS service bottlenecks

**Metrics Used**:
```promql
aws_rds_cpu_utilization{db_instance}
aws_rds_database_connections{db_instance}
aws_elasticache_cpu_utilization{cache_cluster}
aws_elasticache_bytes_used_for_cache{cache_cluster}
aws_alb_request_count_sum{load_balancer}
aws_alb_target_response_time_average{load_balancer}
aws_efs_data_read_io_bytes{file_system_id}
aws_efs_data_write_io_bytes{file_system_id}
aws_efs_client_connections{file_system_id}
```

---

### 4. Cost Tracking and Optimization

**File**: `cost-tracking.json`

**Purpose**: Track AWS costs and identify optimization opportunities

**Key Panels**:

#### Cost Summary
- **Total Daily Cost**: Current daily AWS spending
- **Projected Monthly Cost**: Estimated monthly cost based on current usage
- **Cost Change (24h)**: Cost increase/decrease over last 24 hours
- **Spot Instance Savings**: Savings from using spot instances

#### Cost Breakdown
- **Cost by Service (Time Series)**: Cost trends by AWS service
- **Cost Distribution by Service (Pie Chart)**: Percentage breakdown by service
- **Cost by Environment**: Spending per environment (dev, staging, prod)

#### Compute Costs
- **EC2 Cost: Spot vs On-Demand**: Comparison of spot and on-demand costs
- **EC2 Instance Type Distribution**: Cost by instance type
- **Karpenter Node Cost**: Cost of Karpenter-provisioned nodes

#### Storage Costs
- **EBS Volume Usage**: EBS volume costs and utilization
- **EFS Metered I/O**: EFS I/O costs
- **S3 Storage Costs**: S3 bucket storage costs

#### Optimization
- **Cost Optimization Recommendations (Table)**: Actionable recommendations
  - Resource type
  - Current cost
  - Potential savings
  - Recommendation
- **Unused Resources**: Idle resources with associated costs
- **Rightsizing Opportunities**: Over-provisioned resources

**Use Cases**:
- Monitor infrastructure spending
- Track cost trends over time
- Identify cost optimization opportunities
- Compare spot vs on-demand costs
- Analyze cost by service and environment
- Plan budget allocations

**Metrics Used**:
```promql
aws_cost_daily_usd{service, environment}
aws_cost_spot_savings_usd
aws_ec2_spot_instance_cost_usd{instance_type}
aws_ec2_ondemand_instance_cost_usd{instance_type}
aws_ebs_volume_size_bytes{volume_id}
aws_efs_metered_io_bytes{file_system_id}
aws_cost_optimization_recommendation{resource, recommendation, potential_savings}
```

---

## Dashboard Organization

### Folders

Dashboards are organized into Grafana folders:
- **Default**: General dashboards
- **WordPress**: Application-specific dashboards
- **Infrastructure**: Kubernetes and infrastructure dashboards
- **Cost Management**: Cost tracking and optimization dashboards

### Tags

Dashboards are tagged for easy discovery:
- `wordpress`, `application`, `performance`
- `kubernetes`, `infrastructure`, `cluster`
- `aws`, `rds`, `elasticache`, `alb`, `efs`
- `cost`, `optimization`, `billing`

---

## Customization

### Adding Custom Dashboards

1. **Create dashboard JSON file**:
```bash
# Create new dashboard file
touch modules/observability/modules/grafana/dashboards/my-custom-dashboard.json
```

2. **Add to ConfigMap in Terraform**:
```hcl
data = {
  "my-custom-dashboard.json" = file("${path.module}/dashboards/my-custom-dashboard.json")
}
```

3. **Apply Terraform changes**:
```bash
cd stacks/app
terraform apply
```

### Modifying Existing Dashboards

**Via Grafana UI** (recommended for testing):
1. Edit dashboard in Grafana
2. Save changes
3. Export JSON: Dashboard Settings > JSON Model
4. Update corresponding file in `dashboards/` directory
5. Apply Terraform changes

**Direct JSON editing**:
1. Edit JSON file directly
2. Apply Terraform changes
3. Dashboard will auto-reload

### Adding Template Variables

Template variables enable dynamic filtering:

```json
"templating": {
  "list": [
    {
      "name": "namespace",
      "type": "query",
      "datasource": "Prometheus",
      "query": "label_values(kube_pod_info, namespace)",
      "refresh": 1,
      "multi": true,
      "includeAll": true
    },
    {
      "name": "pod",
      "type": "query",
      "datasource": "Prometheus",
      "query": "label_values(kube_pod_info{namespace=\"$namespace\"}, pod)",
      "refresh": 2
    }
  ]
}
```

### Adding Annotations

Annotations mark important events on dashboards:

```json
"annotations": {
  "list": [
    {
      "datasource": "Prometheus",
      "enable": true,
      "expr": "ALERTS{alertstate=\"firing\"}",
      "name": "Alerts",
      "step": "60s",
      "tagKeys": "alertname,severity",
      "titleFormat": "{{ alertname }}",
      "textFormat": "{{ annotations.description }}"
    }
  ]
}
```

---

## Dashboard Best Practices

### Design Principles

1. **Use Variables**: Add template variables for dynamic filtering
2. **Set Appropriate Refresh Rates**: Balance between freshness and load
3. **Add Descriptions**: Include panel descriptions for clarity
4. **Set Thresholds**: Configure meaningful thresholds for visual indicators
5. **Optimize Queries**: Use recording rules for expensive queries
6. **Group Related Panels**: Organize panels logically by rows
7. **Use Consistent Units**: Standardize units across similar metrics
8. **Add Links**: Link to related dashboards and documentation

### Query Optimization

**Use recording rules for expensive queries**:
```yaml
# In Prometheus rules
groups:
  - name: dashboard_rules
    interval: 30s
    rules:
      - record: node:cpu:usage
        expr: 1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m]))
```

**Then use in dashboard**:
```promql
# Instead of complex query
node:cpu:usage
```

### Visual Design

1. **Color Coding**:
   - Green: Healthy/normal
   - Yellow: Warning
   - Red: Critical
   - Blue: Informational

2. **Panel Types**:
   - **Graph**: Time series data
   - **Stat**: Single value metrics
   - **Gauge**: Percentage/ratio metrics
   - **Table**: Detailed breakdowns
   - **Heatmap**: Distribution analysis

3. **Thresholds**:
```json
"thresholds": [
  { "value": 0, "color": "green" },
  { "value": 70, "color": "yellow" },
  { "value": 85, "color": "red" }
]
```

---

## Troubleshooting

### Dashboard Not Loading

1. **Check ConfigMap exists**:
```bash
kubectl get configmap -n observability | grep grafana-dashboards
```

2. **Check dashboard provider configuration**:
```bash
kubectl logs -n observability deployment/grafana | grep dashboard
```

3. **Verify dashboard JSON is valid**:
```bash
kubectl get configmap grafana-dashboards -n observability -o json | jq '.data'
```

### Metrics Not Showing

1. **Verify Prometheus is scraping targets**:
   - Access Prometheus UI
   - Check Status > Targets
   - Ensure targets are "UP"

2. **Test metric query in Prometheus**:
   - Run the query directly in Prometheus
   - Verify data exists

3. **Check data source configuration**:
   - Grafana > Configuration > Data Sources
   - Test the connection
   - Verify URL and authentication

### Dashboard Version Conflicts

If dashboard changes aren't appearing:

1. **Force reload from ConfigMap**:
```bash
kubectl rollout restart deployment/grafana -n observability
```

2. **Clear Grafana cache**:
```bash
kubectl delete pod -n observability -l app.kubernetes.io/name=grafana
```

3. **Check dashboard provisioning logs**:
```bash
kubectl logs -n observability deployment/grafana | grep provisioning
```

### Query Performance Issues

1. **Check query execution time** in Prometheus
2. **Reduce time range** for expensive queries
3. **Use recording rules** for complex calculations
4. **Increase scrape interval** if appropriate
5. **Add label filters** to reduce cardinality

---

## Accessing Dashboards

### Internal Access (within cluster)

```bash
# Port-forward to Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Access at http://localhost:3000
```

### External Access (if configured)

```bash
# Get Grafana external URL
terraform output -raw grafana_external_url
```

### Default Credentials

- **Username**: `admin`
- **Password**: Retrieved from Secrets Manager or set via `grafana_admin_password` variable

---

## Related Documentation

- [Alert Rules Reference](alert-rules.md) - Prometheus alert rules
- [Monitoring Guide](../features/monitoring/README.md) - Monitoring stack overview
- [Grafana Configuration](../features/monitoring/grafana.md) - Grafana setup and configuration
- [Prometheus Configuration](../features/monitoring/prometheus.md) - Prometheus setup
- [Variables Reference](variables.md) - Configuration variables for monitoring

