# WordPress Metrics Exporter

This directory contains the WordPress metrics exporter implementation that provides Prometheus-compatible metrics for WordPress applications running on EKS.

## Overview

The WordPress metrics exporter is designed to fulfill requirements 4.4, 8.1, and 8.2 by providing:

- **Page views and response times**: HTTP request metrics with method, status, and endpoint labels
- **Active user tracking**: Real-time count of active users based on session activity
- **Plugin performance monitoring**: Execution time tracking for WordPress plugins
- **Database query metrics**: Query count and performance tracking
- **Cache effectiveness**: Hit/miss ratios for object and page caching
- **System resource usage**: Memory usage and PHP performance metrics

## Architecture

The exporter is deployed as a sidecar container alongside WordPress pods, providing:

1. **Lightweight metrics collection**: Minimal overhead PHP-based exporter
2. **Secure access**: Read-only access to WordPress data and configuration
3. **Prometheus integration**: Standard `/metrics` endpoint with proper labels
4. **High availability**: Deployed with each WordPress replica for resilience

## Files

### Core Components

- **`simple-metrics-exporter.php`**: Lightweight PHP script that collects and exposes WordPress metrics
- **`wordpress-exporter.php`**: Full-featured exporter with advanced metrics collection
- **`wordpress-metrics-plugin.php`**: WordPress plugin for real-time metrics tracking

### Deployment Files

- **`simple-entrypoint.sh`**: Entrypoint script for the sidecar container
- **`metrics-exporter-entrypoint.sh`**: Advanced entrypoint with nginx configuration
- **`Dockerfile.metrics-exporter`**: Container image definition (optional)

## Metrics Exposed

### Application Metrics

| Metric Name | Type | Description | Labels |
|-------------|------|-------------|---------|
| `wordpress_http_requests_total` | counter | Total HTTP requests | method, status, endpoint |
| `wordpress_http_request_duration_seconds` | histogram | Request duration | method, endpoint |
| `wordpress_active_users_total` | gauge | Currently active users | - |
| `wordpress_plugin_execution_time_seconds` | histogram | Plugin execution time | plugin |
| `wordpress_database_queries_total` | counter | Database queries | type |
| `wordpress_cache_hits_total` | counter | Cache hits | type |
| `wordpress_cache_misses_total` | counter | Cache misses | type |

### System Metrics

| Metric Name | Type | Description | Labels |
|-------------|------|-------------|---------|
| `wordpress_posts_total` | gauge | Published posts | post_type |
| `wordpress_users_total` | gauge | Registered users | role |
| `wordpress_comments_total` | gauge | Comments | status |
| `wordpress_memory_usage_bytes` | gauge | Memory usage | - |
| `wordpress_plugins_total` | gauge | Installed plugins | - |
| `wordpress_themes_total` | gauge | Installed themes | - |

### Meta Metrics

| Metric Name | Type | Description | Labels |
|-------------|------|-------------|---------|
| `wordpress_version_info` | gauge | WordPress version | version |
| `wordpress_php_version_info` | gauge | PHP version | version |
| `wordpress_exporter_duration_seconds` | gauge | Collection time | - |
| `wordpress_exporter_last_scrape_timestamp_seconds` | gauge | Last scrape time | - |

## Configuration

### Deployment Options

The metrics exporter can be deployed in two ways:

**Option 1: Standard PHP Image with ConfigMap (Default)**

This is the current default approach. It uses a standard PHP image and mounts the exporter scripts via Kubernetes ConfigMap.

Advantages:
- No custom image to build or maintain
- Easy to update scripts without rebuilding images
- Simpler CI/CD pipeline
- Faster deployment iterations

Configuration:
```hcl
enable_metrics_exporter = true
metrics_exporter_image  = "php:8.2-cli-alpine"  # Default
```

**Option 2: Custom Container Image (Optional)**

You can build a custom container image using the provided `Dockerfile.metrics-exporter`. This pre-packages all exporter files and dependencies.

Advantages:
- Faster pod startup (no ConfigMap mounting)
- Can include additional dependencies (nginx, PHP extensions)
- Versioned and immutable deployments
- Better for air-gapped environments

Steps to use custom image:

1. Build and push the image:
```bash
cd modules/app-wordpress/files
docker build -f Dockerfile.metrics-exporter -t your-registry/wordpress-metrics-exporter:1.0.0 .
docker push your-registry/wordpress-metrics-exporter:1.0.0
```

2. Update Terraform configuration:
```hcl
enable_metrics_exporter = true
metrics_exporter_image  = "your-registry/wordpress-metrics-exporter:1.0.0"
```

3. If using custom image, you may want to disable ConfigMap mounting by modifying the module (advanced).

### Terraform Variables

```hcl
# Enable the metrics exporter
enable_metrics_exporter = true

# Configure resources
metrics_exporter_resources_requests_cpu    = "50m"
metrics_exporter_resources_requests_memory = "64Mi"
metrics_exporter_resources_limits_cpu      = "200m"
metrics_exporter_resources_limits_memory   = "256Mi"

# Container image - use standard PHP image (default) or custom built image
metrics_exporter_image = "php:8.2-cli-alpine"
# OR for custom image:
# metrics_exporter_image = "your-registry/wordpress-metrics-exporter:1.0.0"
```

### Kubernetes Labels

The metrics service is automatically labeled for Prometheus discovery:

```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9090"
  prometheus.io/path: "/metrics"
```

## Security Considerations

1. **Read-only access**: The sidecar has read-only access to WordPress files
2. **Minimal privileges**: Runs with minimal container privileges
3. **Network isolation**: Only exposes metrics port (9090)
4. **PII protection**: Metrics are designed to avoid exposing sensitive user data

## Monitoring Integration

### Prometheus Configuration

The exporter integrates with Prometheus through ServiceMonitor CRDs:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: wordpress-metrics
spec:
  selector:
    matchLabels:
      app: wordpress
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### Grafana Dashboards

Metrics are designed to work with pre-configured Grafana dashboards for:

- WordPress application performance
- User activity and engagement
- Plugin and theme management
- Database and cache performance
- System resource utilization

## Troubleshooting

### Common Issues

1. **Metrics endpoint not accessible**
   - Check if sidecar container is running
   - Verify port 9090 is exposed
   - Check WordPress configuration is accessible

2. **Missing metrics**
   - Verify WordPress database connection
   - Check file permissions on WordPress directory
   - Review container logs for PHP errors

3. **High resource usage**
   - Adjust collection frequency
   - Optimize database queries
   - Consider using simple exporter variant

### Debugging

```bash
# Check sidecar container status
kubectl get pods -l app=wordpress -o wide

# View exporter logs
kubectl logs <pod-name> -c metrics-exporter

# Test metrics endpoint
kubectl port-forward <pod-name> 9090:9090
curl http://localhost:9090/metrics
```

## Performance Impact

The metrics exporter is designed for minimal performance impact:

- **CPU usage**: ~50m CPU request, 200m limit
- **Memory usage**: ~64Mi request, 256Mi limit
- **Collection frequency**: 30-second intervals (configurable)
- **Database impact**: Read-only queries with minimal overhead

## Development

### Testing Locally

```bash
# Start PHP development server
cd modules/app-wordpress/files
php -S localhost:9090 simple-metrics-exporter.php

# Test metrics collection
curl http://localhost:9090/metrics
```

### Building Custom Image

If you choose to build a custom container image:

1. Review and customize the Dockerfile:
```bash
# The Dockerfile includes:
# - PHP 8.2 FPM Alpine base
# - Required PHP extensions (mysqli, pdo_mysql)
# - Non-root user setup
# - Health checks
# - All exporter files pre-installed
```

2. Build for your target architecture:
```bash
# For single architecture
docker build -f Dockerfile.metrics-exporter -t wordpress-metrics-exporter:1.0.0 .

# For multi-architecture (ARM64 + AMD64)
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.metrics-exporter \
  -t your-registry/wordpress-metrics-exporter:1.0.0 \
  --push .
```

3. Test the image locally:
```bash
docker run -p 9090:9090 \
  -v /path/to/wordpress:/var/www/html:ro \
  wordpress-metrics-exporter:1.0.0
```

4. Update the Terraform variable to use your custom image.

### Extending Metrics

To add new metrics:

1. Update the metrics collection logic in the PHP files
2. Add appropriate labels and help text
3. Test with Prometheus to ensure proper formatting
4. Update documentation and dashboards
5. If using custom image, rebuild and push the new version

## Requirements Compliance

This implementation satisfies the following requirements:

- **4.4**: Custom WordPress metrics through prometheus-php integration
- **8.1**: Page load times, database query performance, and cache effectiveness tracking
- **8.2**: Plugin-specific performance impact monitoring

The exporter provides comprehensive visibility into WordPress application performance while maintaining security and operational best practices.