# Metrics Exporters

## Overview

Metrics exporters collect application-specific and service-specific metrics and expose them in Prometheus format. The WordPress EKS platform includes exporters for WordPress, MySQL/Aurora, Redis/ElastiCache, CloudWatch, and AWS cost monitoring.

## Available Exporters

### 1. WordPress Exporter

Collects WordPress-specific application metrics.

**Metrics Collected**:
- Request rate by HTTP method and status code
- Response time (p50, p95, p99)
- Active user count
- Cache hit rate
- Database query count
- PHP-FPM metrics
- WordPress plugin performance

**Deployment**: Sidecar container in WordPress pods

### 2. MySQL Exporter

Collects metrics from Aurora MySQL database.

**Metrics Collected**:
- Connection pool usage
- Query performance (slow queries, query rate)
- Table statistics (size, row count)
- Replication lag
- InnoDB metrics (buffer pool, transactions)
- Database uptime

**Deployment**: Dedicated deployment in observability namespace

### 3. Redis Exporter

Collects metrics from ElastiCache Redis.

**Metrics Collected**:
- Cache hit rate
- Memory usage
- Connected clients
- Commands processed per second
- Evicted keys
- Keyspace statistics
- Replication metrics

**Deployment**: Dedicated deployment in observability namespace

### 4. CloudWatch Exporter

Exports CloudWatch metrics to Prometheus.

**Metrics Collected**:
- RDS metrics (CPU, connections, IOPS)
- ElastiCache metrics (CPU, memory, cache hits)
- ALB metrics (request count, target response time)
- EFS metrics (throughput, IOPS)
- CloudFront metrics (requests, data transfer, errors)
- Custom CloudWatch metrics

**Deployment**: Dedicated deployment in observability namespace

### 5. Cost Monitoring

Tracks AWS service costs and usage.

**Metrics Collected**:
- Daily cost by service
- Monthly cost trends
- Cost by resource tags
- Budget utilization
- Cost anomalies

**Deployment**: Scheduled job in observability namespace

## Configuration

### WordPress Exporter

Enable WordPress exporter:

```hcl
# Enable WordPress exporter
enable_wordpress_exporter = true
wordpress_namespace       = "wordpress"
```

The exporter is automatically deployed as a sidecar to WordPress pods.

### MySQL Exporter

#### Step 1: Create Monitoring User

Create a dedicated monitoring user in Aurora:

```sql
CREATE USER 'monitoring'@'%' IDENTIFIED BY 'secure-password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitoring'@'%';
FLUSH PRIVILEGES;
```

#### Step 2: Store Credentials

Store the password in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name mysql-monitoring-password \
  --secret-string "secure-password" \
  --region us-east-1
```

#### Step 3: Enable Exporter

Configure in Terraform Cloud variables:

```hcl
enable_mysql_exporter = true
mysql_connection_config = {
  host                = "aurora-cluster-endpoint.us-east-1.rds.amazonaws.com"
  port                = 3306
  username            = "monitoring"
  password_secret_ref = "arn:aws:secretsmanager:us-east-1:123456789012:secret:mysql-monitoring-password"
  database            = "wordpress"
}
```

### Redis Exporter

#### Step 1: Get Redis Credentials

Retrieve Redis AUTH token from Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id redis-auth-token \
  --query SecretString \
  --output text
```

#### Step 2: Enable Exporter

Configure in Terraform Cloud variables:

```hcl
enable_redis_exporter = true
redis_connection_config = {
  host                = "redis-cluster.cache.amazonaws.com"
  port                = 6379
  password_secret_ref = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis-auth-token"
  tls_enabled         = true
}
```

### CloudWatch Exporter

Enable CloudWatch exporter with service discovery:

```hcl
enable_cloudwatch_exporter = true
cloudwatch_metrics_config = {
  discovery_jobs = [
    {
      type        = "rds"
      regions     = ["us-east-1"]
      search_tags = { Environment = "production" }
      custom_tags = { Component = "database" }
      metrics     = [
        "CPUUtilization",
        "DatabaseConnections",
        "ReadLatency",
        "WriteLatency",
        "ReadIOPS",
        "WriteIOPS"
      ]
    },
    {
      type        = "elasticache"
      regions     = ["us-east-1"]
      search_tags = { Environment = "production" }
      metrics     = [
        "CPUUtilization",
        "CacheHits",
        "CacheMisses",
        "NetworkBytesIn",
        "NetworkBytesOut"
      ]
    },
    {
      type        = "alb"
      regions     = ["us-east-1"]
      search_tags = { Environment = "production" }
      metrics     = [
        "RequestCount",
        "TargetResponseTime",
        "HTTPCode_Target_2XX_Count",
        "HTTPCode_Target_4XX_Count",
        "HTTPCode_Target_5XX_Count"
      ]
    }
  ]
}
```

### Cost Monitoring

Enable AWS cost monitoring:

```hcl
enable_cost_monitoring = true
cost_allocation_tags   = ["Environment", "Project", "Owner", "Component"]
```

The cost exporter requires IAM permissions for Cost Explorer API (automatically configured via IRSA).

## Deployment

### Deploy All Exporters

```bash
cd stacks/app
make plan-app
make apply-app
```

### Verify Deployment

```bash
# Check WordPress exporter (sidecar)
kubectl get pods -n wordpress -o jsonpath='{.items[*].spec.containers[*].name}'

# Check MySQL exporter
kubectl get pods -n observability -l app=mysql-exporter

# Check Redis exporter
kubectl get pods -n observability -l app=redis-exporter

# Check CloudWatch exporter
kubectl get pods -n observability -l app=cloudwatch-exporter

# Check cost monitoring job
kubectl get cronjob -n observability cost-exporter
```

## Accessing Metrics

### Via Prometheus

All exporter metrics are automatically scraped by Prometheus.

Query examples:

```promql
# WordPress request rate
rate(wordpress_http_requests_total[5m])

# MySQL connections
mysql_global_status_threads_connected

# Redis cache hit rate
rate(redis_keyspace_hits_total[5m]) / 
  (rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))

# CloudWatch RDS CPU
aws_rds_cpuutilization_average

# Daily AWS costs
aws_cost_daily_usd
```

### Via Grafana

Metrics are available in Grafana dashboards:
- WordPress Overview dashboard
- AWS Services dashboard
- Cost Tracking dashboard

### Direct Access

Port-forward to exporter for debugging:

```bash
# MySQL exporter
kubectl port-forward -n observability svc/mysql-exporter 9104:9104
curl http://localhost:9104/metrics

# Redis exporter
kubectl port-forward -n observability svc/redis-exporter 9121:9121
curl http://localhost:9121/metrics
```

## WordPress Exporter Metrics

### HTTP Metrics

- `wordpress_http_requests_total`: Total HTTP requests by method and status
- `wordpress_http_request_duration_seconds`: Request duration histogram
- `wordpress_http_request_size_bytes`: Request size histogram
- `wordpress_http_response_size_bytes`: Response size histogram

### Application Metrics

- `wordpress_active_users`: Current active user count
- `wordpress_cache_hits_total`: Cache hits by cache type
- `wordpress_cache_misses_total`: Cache misses by cache type
- `wordpress_database_queries_total`: Database queries executed
- `wordpress_database_query_duration_seconds`: Query duration histogram

### PHP-FPM Metrics

- `wordpress_phpfpm_processes_total`: Total PHP-FPM processes
- `wordpress_phpfpm_active_processes`: Active PHP-FPM processes
- `wordpress_phpfpm_idle_processes`: Idle PHP-FPM processes
- `wordpress_phpfpm_max_children_reached_total`: Max children reached count

## MySQL Exporter Metrics

### Connection Metrics

- `mysql_global_status_threads_connected`: Current connections
- `mysql_global_status_threads_running`: Running threads
- `mysql_global_status_max_used_connections`: Max connections used
- `mysql_global_status_aborted_connects`: Aborted connections

### Query Metrics

- `mysql_global_status_queries`: Total queries
- `mysql_global_status_slow_queries`: Slow queries
- `mysql_global_status_questions`: Questions (client queries)
- `mysql_global_status_com_select`: SELECT queries
- `mysql_global_status_com_insert`: INSERT queries
- `mysql_global_status_com_update`: UPDATE queries
- `mysql_global_status_com_delete`: DELETE queries

### InnoDB Metrics

- `mysql_global_status_innodb_buffer_pool_pages_total`: Total buffer pool pages
- `mysql_global_status_innodb_buffer_pool_pages_free`: Free buffer pool pages
- `mysql_global_status_innodb_buffer_pool_read_requests`: Buffer pool read requests
- `mysql_global_status_innodb_buffer_pool_reads`: Disk reads

### Replication Metrics

- `mysql_slave_status_seconds_behind_master`: Replication lag in seconds
- `mysql_slave_status_slave_io_running`: Slave IO thread running
- `mysql_slave_status_slave_sql_running`: Slave SQL thread running

## Redis Exporter Metrics

### Memory Metrics

- `redis_memory_used_bytes`: Used memory in bytes
- `redis_memory_max_bytes`: Max memory limit
- `redis_memory_fragmentation_ratio`: Memory fragmentation ratio

### Cache Metrics

- `redis_keyspace_hits_total`: Cache hits
- `redis_keyspace_misses_total`: Cache misses
- `redis_evicted_keys_total`: Evicted keys
- `redis_expired_keys_total`: Expired keys

### Connection Metrics

- `redis_connected_clients`: Connected clients
- `redis_blocked_clients`: Blocked clients
- `redis_rejected_connections_total`: Rejected connections

### Performance Metrics

- `redis_commands_processed_total`: Commands processed
- `redis_commands_duration_seconds_total`: Command duration
- `redis_instantaneous_ops_per_sec`: Operations per second

## CloudWatch Exporter Metrics

### RDS Metrics

- `aws_rds_cpuutilization_average`: CPU utilization percentage
- `aws_rds_database_connections_average`: Database connections
- `aws_rds_freeable_memory_average`: Free memory
- `aws_rds_read_latency_average`: Read latency
- `aws_rds_write_latency_average`: Write latency
- `aws_rds_read_iops_average`: Read IOPS
- `aws_rds_write_iops_average`: Write IOPS

### ElastiCache Metrics

- `aws_elasticache_cpuutilization_average`: CPU utilization
- `aws_elasticache_cache_hits_sum`: Cache hits
- `aws_elasticache_cache_misses_sum`: Cache misses
- `aws_elasticache_network_bytes_in_sum`: Network bytes in
- `aws_elasticache_network_bytes_out_sum`: Network bytes out

### ALB Metrics

- `aws_alb_request_count_sum`: Request count
- `aws_alb_target_response_time_average`: Target response time
- `aws_alb_httpcode_target_2xx_count_sum`: 2xx responses
- `aws_alb_httpcode_target_4xx_count_sum`: 4xx responses
- `aws_alb_httpcode_target_5xx_count_sum`: 5xx responses

## Cost Monitoring Metrics

### Cost Metrics

- `aws_cost_daily_usd`: Daily cost by service
- `aws_cost_monthly_usd`: Monthly cost by service
- `aws_cost_forecast_usd`: Forecasted monthly cost
- `aws_cost_by_tag_usd`: Cost by resource tag

### Budget Metrics

- `aws_budget_limit_usd`: Budget limit
- `aws_budget_actual_usd`: Actual spend
- `aws_budget_forecasted_usd`: Forecasted spend
- `aws_budget_utilization_percent`: Budget utilization percentage

## Troubleshooting

### Exporter Not Scraping

Check ServiceMonitor:

```bash
kubectl get servicemonitor -n observability
kubectl describe servicemonitor <name> -n observability
```

Check Prometheus targets:

```bash
kubectl port-forward -n observability svc/prometheus-server 9090:9090
# Visit http://localhost:9090/targets
```

### MySQL Exporter Connection Failed

Check credentials:

```bash
# Test connection from exporter pod
kubectl exec -n observability deployment/mysql-exporter -- \
  mysql -h <host> -u monitoring -p<password> -e "SELECT 1"
```

Verify IAM permissions for Secrets Manager:

```bash
kubectl get sa -n observability mysql-exporter -o yaml
```

### Redis Exporter Authentication Failed

Check AUTH token:

```bash
# Test connection
kubectl exec -n observability deployment/redis-exporter -- \
  redis-cli -h <host> -p 6379 --tls -a <password> PING
```

### CloudWatch Exporter No Metrics

Check IAM permissions:

```bash
# Verify IRSA role
kubectl get sa -n observability cloudwatch-exporter -o yaml

# Check IAM role permissions
aws iam get-role-policy \
  --role-name <cluster-name>-cloudwatch-exporter \
  --policy-name cloudwatch-read
```

### Cost Exporter Job Failed

Check job logs:

```bash
kubectl logs -n observability job/cost-exporter-<timestamp>
```

Verify Cost Explorer API access:

```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## Performance Tuning

### Scrape Intervals

Adjust scrape intervals for different exporters:

```hcl
# In ServiceMonitor configuration
scrape_intervals = {
  wordpress  = "15s"  # High frequency for application metrics
  mysql      = "30s"  # Medium frequency for database
  redis      = "30s"  # Medium frequency for cache
  cloudwatch = "5m"   # Low frequency for AWS metrics (API limits)
  cost       = "1h"   # Very low frequency for cost data
}
```

### Resource Allocation

Adjust resources based on load:

```hcl
# For high-traffic WordPress
wordpress_exporter_resources = {
  requests = {
    cpu    = "100m"
    memory = "128Mi"
  }
  limits = {
    cpu    = "500m"
    memory = "512Mi"
  }
}
```

### Metric Filtering

Reduce metric cardinality:

```hcl
# Filter MySQL metrics
mysql_exporter_config = {
  collect_info_schema_tables = false  # Disable high-cardinality metrics
  collect_perf_schema_events = false
}
```

## Security Considerations

1. **Use Secrets Manager**: Store credentials in AWS Secrets Manager
2. **Use IRSA**: Avoid static AWS credentials
3. **Least Privilege**: Grant minimal database permissions
4. **TLS Connections**: Use TLS for Redis and MySQL connections
5. **Network Policies**: Restrict exporter network access
6. **Rotate Credentials**: Regularly rotate monitoring user passwords

## Best Practices

1. **Monitor Exporter Health**: Alert on exporter scrape failures
2. **Set Appropriate Intervals**: Balance freshness and API limits
3. **Filter Unnecessary Metrics**: Reduce storage and query costs
4. **Use Recording Rules**: Pre-compute expensive queries
5. **Test Credentials**: Verify credentials before deployment
6. **Document Custom Metrics**: Maintain metric documentation

## Related Documentation

- [Enhanced Monitoring Overview](./README.md)
- [Prometheus Configuration](./prometheus.md)
- [Grafana Dashboards](./grafana.md)
- [Variables Reference](../../reference/variables.md)
