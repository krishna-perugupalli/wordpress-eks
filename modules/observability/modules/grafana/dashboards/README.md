# Grafana Dashboards

This directory contains pre-configured Grafana dashboards for the WordPress EKS platform monitoring.

## Available Dashboards

### 1. WordPress Application Overview (`wordpress-overview.json`)

**Purpose**: Monitor WordPress application performance and health

**Key Metrics**:
- HTTP request rate by method and status code
- Response time percentiles (p50, p95, p99)
- Active user count
- Cache hit rate
- Database query rate
- WordPress service status
- Plugin execution time
- Database query breakdown by type

**Use Cases**:
- Identify performance bottlenecks in WordPress
- Monitor cache effectiveness
- Track user activity patterns
- Detect slow plugins
- Analyze database query patterns

**Refresh Rate**: 30 seconds

---

### 2. Kubernetes Cluster Overview (`kubernetes-cluster.json`)

**Purpose**: Monitor Kubernetes cluster health and resource utilization

**Key Metrics**:
- Node CPU usage by instance
- Node memory usage by instance
- Total node count
- Running pod count
- Deployment count
- Failed pod count
- Pending pod count
- Namespace count
- Node disk available space
- Network I/O (receive/transmit)
- Pods by namespace
- Top pods by CPU usage

**Use Cases**:
- Monitor cluster capacity and utilization
- Identify resource-constrained nodes
- Track pod health and status
- Plan capacity scaling
- Troubleshoot node issues

**Refresh Rate**: 30 seconds

---

### 3. AWS Services Monitoring (`aws-services.json`)

**Purpose**: Monitor AWS managed services used by the platform

**Key Metrics**:
- RDS CPU utilization
- RDS database connections
- ElastiCache CPU utilization
- ElastiCache memory usage
- ALB request count
- ALB target response time
- EFS I/O bytes (read/write)
- EFS client connections

**Use Cases**:
- Monitor database performance
- Track cache effectiveness
- Analyze load balancer traffic
- Monitor shared storage usage
- Identify AWS service bottlenecks

**Refresh Rate**: 30 seconds

---

### 4. Cost Tracking and Optimization (`cost-tracking.json`)

**Purpose**: Track AWS costs and identify optimization opportunities

**Key Metrics**:
- Total daily cost
- Projected monthly cost
- Cost change (24h)
- Spot instance savings
- Cost by service (time series)
- Cost distribution by service (pie chart)
- Cost by environment
- EC2 cost: Spot vs On-Demand
- EBS volume usage
- EFS metered I/O
- Cost optimization recommendations (table)

**Use Cases**:
- Monitor infrastructure spending
- Track cost trends over time
- Identify cost optimization opportunities
- Compare spot vs on-demand costs
- Analyze cost by service and environment
- Plan budget allocations

**Refresh Rate**: 5 minutes

---

## Dashboard Configuration

### Persistence

All dashboards are configured with:
- **Persistence**: Enabled via Grafana's persistent volume
- **Version Control**: Up to 20 versions retained per dashboard
- **Editability**: Dashboards can be edited through the UI
- **Auto-reload**: Dashboards reload every 30 seconds from ConfigMaps

### Data Sources

Dashboards use the following data sources:
- **Prometheus**: Primary data source for metrics
- **CloudWatch**: Secondary data source for AWS native metrics (optional)

### Folders

Dashboards are organized into folders:
- **Default**: General dashboards
- **WordPress**: Application-specific dashboards
- **Infrastructure**: Kubernetes and infrastructure dashboards
- **Cost Management**: Cost tracking and optimization dashboards

## Customization

### Adding Custom Dashboards

1. Create a new JSON dashboard file in this directory
2. Add the dashboard to the ConfigMap in `main.tf`:
   ```hcl
   data = {
     "my-custom-dashboard.json" = file("${path.module}/dashboards/my-custom-dashboard.json")
   }
   ```
3. Apply the Terraform changes

### Modifying Existing Dashboards

You can modify dashboards in two ways:

1. **Via Grafana UI** (recommended for testing):
   - Edit the dashboard in Grafana
   - Export the JSON
   - Update the corresponding file in this directory
   - Apply Terraform changes

2. **Direct JSON editing**:
   - Edit the JSON file directly
   - Apply Terraform changes
   - Dashboard will auto-reload

### Dashboard Variables

To add template variables for filtering:

```json
"templating": {
  "list": [
    {
      "name": "namespace",
      "type": "query",
      "datasource": "Prometheus",
      "query": "label_values(kube_pod_info, namespace)",
      "refresh": 1
    }
  ]
}
```

## Metrics Reference

### WordPress Metrics

```
wordpress_http_requests_total{method, status, endpoint}
wordpress_http_request_duration_seconds{method, endpoint}
wordpress_active_users_total
wordpress_plugin_execution_time_seconds{plugin}
wordpress_database_queries_total{type}
wordpress_cache_hits_total{type}
wordpress_cache_misses_total{type}
```

### Kubernetes Metrics

```
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

### AWS Service Metrics

```
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

### Cost Metrics

```
aws_cost_daily_usd{service, environment}
aws_cost_spot_savings_usd
aws_ec2_spot_instance_cost_usd{instance_type}
aws_ec2_ondemand_instance_cost_usd{instance_type}
aws_ebs_volume_size_bytes{volume_id}
aws_efs_metered_io_bytes{file_system_id}
aws_cost_optimization_recommendation{resource, recommendation, potential_savings}
```

## Troubleshooting

### Dashboard Not Loading

1. Check ConfigMap exists:
   ```bash
   kubectl get configmap -n observability | grep grafana-dashboards
   ```

2. Check dashboard provider configuration:
   ```bash
   kubectl logs -n observability deployment/grafana | grep dashboard
   ```

3. Verify dashboard JSON is valid:
   ```bash
   kubectl get configmap grafana-dashboards -n observability -o json | jq '.data'
   ```

### Metrics Not Showing

1. Verify Prometheus is scraping targets:
   - Access Prometheus UI
   - Check Status > Targets

2. Test metric query in Prometheus:
   - Run the query directly in Prometheus
   - Verify data exists

3. Check data source configuration in Grafana:
   - Configuration > Data Sources
   - Test the connection

### Dashboard Version Conflicts

If dashboard changes aren't appearing:

1. Force reload from ConfigMap:
   ```bash
   kubectl rollout restart deployment/grafana -n observability
   ```

2. Clear Grafana cache:
   - Delete the Grafana pod to force recreation
   ```bash
   kubectl delete pod -n observability -l app.kubernetes.io/name=grafana
   ```

## Best Practices

1. **Use Variables**: Add template variables for dynamic filtering
2. **Set Appropriate Refresh Rates**: Balance between freshness and load
3. **Add Annotations**: Document important events on dashboards
4. **Use Folders**: Organize dashboards logically
5. **Version Control**: Keep dashboard JSON in Git
6. **Test Queries**: Verify PromQL queries in Prometheus before adding to dashboards
7. **Add Descriptions**: Include panel descriptions for clarity
8. **Set Thresholds**: Configure meaningful thresholds for alerts
9. **Optimize Queries**: Use recording rules for expensive queries
10. **Document Changes**: Add comments when modifying dashboards

## References

- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [Prometheus Query Language](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
