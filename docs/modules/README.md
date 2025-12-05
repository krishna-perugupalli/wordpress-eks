# Module Documentation

This directory contains detailed documentation for each Terraform module in the platform.

## Available Modules

### Core Infrastructure
- [Observability](observability.md) - Monitoring, logging, and alerting infrastructure
- [WordPress](wordpress.md) - WordPress application deployment and configuration
- [Networking](networking.md) - VPC, subnets, and network foundation

### Data Services
- [Data Services](data-services.md) - Aurora MySQL, ElastiCache Redis, and EFS storage

### Security & Edge
- [Security](security.md) - Security baseline, CloudTrail, Config, GuardDuty
- [Edge Ingress](edge-ingress.md) - AWS Load Balancer Controller and ingress configuration

## Module Documentation Structure

Each module guide includes:
- **Purpose**: What the module does and why it exists
- **Resources Created**: Key AWS resources provisioned
- **Configuration**: Important variables and their usage
- **Examples**: Common configuration patterns
- **Integration**: How the module integrates with other components
- **Troubleshooting**: Common issues and solutions

## Related Documentation

- [Features](../features/) - Feature-specific guides and tutorials
- [Operations](../operations/) - Operational procedures and runbooks
- [Reference](../reference/) - Variable and output references
