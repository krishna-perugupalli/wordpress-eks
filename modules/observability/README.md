# Observability Module

Comprehensive monitoring stack for WordPress EKS platform with Prometheus, Grafana, and AlertManager.

## Resources Created

- Prometheus server with persistent storage and IRSA
- Grafana dashboards for WordPress, Kubernetes, and AWS services
- AlertManager for notification routing
- CloudWatch exporters for AWS metrics
- Service discovery for automatic metrics collection
- Network resilience with local collection and eventual consistency

## Key Inputs

- `enable_prometheus_stack` - Enable Prometheus monitoring (default: false)
- `prometheus_storage_size` - Storage size for metrics (default: "50Gi")
- `prometheus_retention_days` - Metrics retention period (default: 30)
- `enable_grafana` - Enable Grafana dashboards (default: true)
- `enable_alertmanager` - Enable AlertManager (default: true)
- `enable_cloudfront_monitoring` - Enable CloudFront metrics (default: false)

## Key Outputs

- `prometheus_url` - Internal Prometheus service URL
- `prometheus_role_arn` - IAM role ARN for Prometheus IRSA
- `monitoring_stack_summary` - Configuration summary

## Documentation

For detailed configuration, examples, and troubleshooting, see:
- **Module Guide**: [docs/modules/observability.md](../../docs/modules/observability.md)
- **Monitoring Features**: [docs/features/monitoring/](../../docs/features/monitoring/)
- **Operations**: [docs/operations/](../../docs/operations/)
