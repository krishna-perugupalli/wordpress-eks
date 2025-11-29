# Reference Documentation

This directory contains technical reference documentation for the WordPress EKS platform.

## Available References

### [Variables Reference](variables.md)
Comprehensive reference for all Terraform variables used across infrastructure and application stacks.

**Contents**:
- Infrastructure stack variables (networking, EKS, database, storage, security, load balancer, CloudFront)
- Application stack variables (Karpenter, observability, WordPress, Redis cache)
- Variable types, defaults, and validation rules
- Usage examples and best practices

**Use this when**: Configuring Terraform deployments, understanding available configuration options, or customizing the platform.

---

### [Outputs Reference](outputs.md)
Complete reference for all Terraform outputs from both stacks.

**Contents**:
- Infrastructure outputs (EKS cluster, networking, data services, secrets, IAM roles, load balancer, CloudFront, DNS)
- Application outputs (WordPress, monitoring)
- Output types and descriptions
- Usage examples for CLI and scripts

**Use this when**: Accessing deployment information, configuring kubectl, connecting to services, or integrating with other systems.

---

### [Alert Rules Reference](alert-rules.md)
Detailed reference for all Prometheus alert rules configured in the monitoring stack.

**Contents**:
- WordPress application alerts
- Database performance alerts
- Redis/cache alerts
- Infrastructure node health alerts
- Pod health alerts
- Cost monitoring alerts
- Alert severity levels and remediation steps

**Use this when**: Understanding alert conditions, troubleshooting alerts, customizing alert thresholds, or adding new alert rules.

---

### [Dashboards Reference](dashboards.md)
Complete reference for all Grafana dashboards and their metrics.

**Contents**:
- WordPress application overview dashboard
- Kubernetes cluster overview dashboard
- AWS services monitoring dashboard
- Cost tracking and optimization dashboard
- Dashboard customization guide
- Metrics reference and query examples

**Use this when**: Accessing monitoring dashboards, understanding available metrics, customizing dashboards, or creating new visualizations.

---

### [Terraform Cloud Variables](terraform-cloud-variables.md)
Reference for Terraform Cloud-specific configuration and workspace variables.

**Contents**:
- Workspace configuration
- Environment variables
- Sensitive variables handling
- Remote state configuration

**Use this when**: Setting up Terraform Cloud workspaces or managing sensitive configuration.

---

## Quick Links

### Configuration
- [All Variables](variables.md) - Complete variable reference
- [Terraform Cloud Setup](terraform-cloud-variables.md) - Workspace configuration

### Deployment Information
- [All Outputs](outputs.md) - Stack outputs reference
- [Getting Started](../getting-started.md) - Deployment guide

### Monitoring
- [Alert Rules](alert-rules.md) - Alert conditions and remediation
- [Dashboards](dashboards.md) - Dashboard metrics and customization
- [Monitoring Guide](../features/monitoring/README.md) - Monitoring stack overview

### Operations
- [Troubleshooting](../operations/troubleshooting.md) - Common issues and solutions
- [Operations Runbook](../runbook.md) - Operational procedures

---

## Using Reference Documentation

### Finding Configuration Options

1. **Start with [Variables Reference](variables.md)** to see all available configuration options
2. **Check variable defaults** to understand baseline configuration
3. **Review validation rules** to ensure values are valid
4. **Refer to examples** in the Getting Started guide

### Accessing Deployment Information

1. **Use [Outputs Reference](outputs.md)** to find available outputs
2. **Run `terraform output`** in the appropriate stack directory
3. **Use outputs in scripts** with `terraform output -raw <output_name>`

### Understanding Monitoring

1. **Review [Alert Rules](alert-rules.md)** to understand alert conditions
2. **Check [Dashboards Reference](dashboards.md)** for available visualizations
3. **Access Grafana** to view real-time metrics
4. **Customize alerts and dashboards** as needed

---

## Related Documentation

- [Module Documentation](../modules/) - Module-specific configuration and usage
- [Feature Guides](../features/) - Feature-specific documentation
- [Operations Guides](../operations/) - Operational procedures and troubleshooting
- [Architecture Overview](../architecture.md) - System design and component relationships

