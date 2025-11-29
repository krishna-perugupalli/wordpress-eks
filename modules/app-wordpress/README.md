# WordPress Application Module

Deploys Bitnami WordPress Helm chart with external Aurora database, EFS storage, and optional Redis cache.

## Resources Created

- WordPress Helm release with HPA
- TargetGroupBinding for ALB integration
- ExternalSecrets for database and admin credentials
- Optional database grant job for user privileges
- Optional Redis cache configuration
- Optional metrics exporter sidecar

## Key Inputs

- `domain_name` - Public hostname for the WordPress site
- `target_group_arn` - ALB target group ARN for pod registration
- `db_host` - Aurora writer endpoint
- `db_secret_arn` - Secrets Manager ARN for database password
- `storage_class_name` - StorageClass for wp-content (default: "efs-ap")
- `enable_redis_cache` - Enable Redis-backed cache (default: false)
- `enable_metrics_exporter` - Enable Prometheus metrics (default: false)

## Key Outputs

- `release_name` - Helm release name
- `namespace` - Kubernetes namespace
- `service_name` - WordPress service name
- `metrics_service_name` - Metrics service name (if enabled)

## Documentation

For detailed configuration, examples, and troubleshooting, see:
- **Module Guide**: [docs/modules/wordpress.md](../../docs/modules/wordpress.md)
- **Getting Started**: [docs/getting-started.md](../../docs/getting-started.md)
- **Operations**: [docs/operations/](../../docs/operations/)
