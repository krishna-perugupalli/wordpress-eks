# Feature Documentation

This directory contains user-facing guides for platform features and capabilities.

## Available Features

### Monitoring & Observability
- [Monitoring Overview](monitoring/) - Complete monitoring stack documentation
  - Prometheus setup and configuration
  - Grafana dashboards and usage
  - AlertManager and alert rules
  - Metrics exporters
  - CloudFront monitoring
  - Migration guides

### Content Delivery & Performance
- [CloudFront CDN](cloudfront.md) - CloudFront integration for global content delivery

### Autoscaling & Compute
- [Karpenter](../karpenter.md) - Karpenter autoscaling configuration
- [Karpenter Integration](../karpenter-integration.md) - Karpenter with AWS Load Balancer Controller
- [TargetGroupBinding](../targetgroupbinding.md) - Direct pod-to-ALB integration

Note: These files remain in the docs root directory as they were not moved during the restructuring.

## Feature Documentation Structure

Each feature guide includes:
- **Overview**: What the feature provides
- **Prerequisites**: Requirements before enabling the feature
- **Setup**: Step-by-step configuration instructions
- **Usage**: How to use the feature effectively
- **Best Practices**: Recommended patterns and configurations
- **Troubleshooting**: Common issues and solutions

## Related Documentation

- [Modules](../modules/) - Module-specific technical documentation
- [Operations](../operations/) - Operational procedures
- [Getting Started](../getting-started.md) - Initial platform deployment
