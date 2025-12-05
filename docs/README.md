# Documentation Hub

Welcome to the WordPress on EKS platform documentation. This guide helps you find the information you need quickly, whether you're deploying for the first time, operating the platform, or developing new features.

## Quick Start

**New to the platform?** Start here:
1. [Getting Started Guide](getting-started.md) - Deploy the platform step-by-step
2. [Architecture Overview](architecture.md) - Understand the system design
3. [Operations Runbook](runbook.md) - Day-2 operations and maintenance

## Documentation Categories

### 📦 [Modules](modules/)
Detailed technical documentation for each Terraform module in the platform.

**Quick Links:**
- [Observability Module](modules/observability.md) - Monitoring, logging, and alerting
- [WordPress Module](modules/wordpress.md) - WordPress application configuration
- [Data Services](modules/data-services.md) - Aurora, Redis, and EFS storage

[View all modules →](modules/)

### ✨ [Features](features/)
User-facing guides for platform features and capabilities.

**Quick Links:**
- [Monitoring & Observability](features/monitoring/) - Complete monitoring stack
- [CloudFront CDN](cloudfront.md) - Global content delivery
- [Karpenter Autoscaling](karpenter.md) - Dynamic compute scaling

[View all features →](features/)

### 🔧 [Operations](operations/)
Day-2 operations guides, runbooks, and procedures for maintaining the platform.

**Quick Links:**
- [HA/DR Procedures](operations/ha-dr.md) - High availability and disaster recovery
- [Troubleshooting Guide](operations/troubleshooting.md) - Common issues and solutions
- [Security Compliance](operations/security-compliance.md) - Security validation

[View all operations guides →](operations/)

### 📚 [Reference](reference/)
Technical reference materials for quick lookup of configuration options.

**Quick Links:**
- [Terraform Variables](reference/variables.md) - Complete variable reference
- [Alert Rules](reference/alert-rules.md) - Prometheus alert reference
- [Dashboards](reference/dashboards.md) - Grafana dashboard reference

[View all references →](reference/)

### 📋 [Tasks](tasks/)
Historical record of implementation tasks and decisions made during platform development.

[View task summaries →](tasks/)

## Common Tasks

### Deployment & Setup
- [Initial Platform Deployment](getting-started.md)
- [Terraform Cloud Configuration](terraform-cloud-variables.md)
- [ACM Certificate Setup](getting-started.md#prerequisites)

### Monitoring & Observability
- [Enable Enhanced Monitoring](features/monitoring/README.md)
- [Migrate to Prometheus](features/monitoring/migration-guide.md)
- [Configure Grafana Dashboards](features/monitoring/grafana.md)
- [Set Up Alerts](features/monitoring/alerting.md)

### Operations & Maintenance
- [Backup & Restore Procedures](operations/backup-restore.md)
- [Incident Response](runbook.md)
- [Cost Optimization](operations/cost-optimization.md)
- [Security Validation](operations/security-compliance.md)

### Troubleshooting
- [General Troubleshooting](operations/troubleshooting.md)
- [TargetGroupBinding Issues](features/targetgroupbinding.md#troubleshooting)
- [Karpenter Issues](features/karpenter-integration.md#troubleshooting)
- [Network Issues](operations/network-resilience.md)

## Architecture & Design

### System Architecture
- [Architecture Deep Dive](architecture.md) - Network layout, data flows, security controls
- [High-Level Architecture Diagram](wp_hla.png)
- [Network Architecture Diagram](wp_network.png)

### Key Components
- **Compute**: EKS 1.30 with managed node groups and Karpenter autoscaling
- **Database**: Aurora MySQL Serverless v2 with automated backups
- **Storage**: EFS for shared wp-content, EBS via CSI driver
- **Cache**: ElastiCache Redis with TLS and authentication
- **Ingress**: Standalone ALB with TargetGroupBinding for pod registration
- **Security**: KMS encryption, Secrets Manager, WAF, GuardDuty, CloudTrail

## Documentation Structure

This documentation follows a clear organizational pattern:

- **Modules** - Technical implementation details for Terraform modules
- **Features** - User-facing guides for platform capabilities
- **Operations** - Procedures for maintaining and troubleshooting the platform
- **Reference** - Quick lookup for configuration options and specifications
- **Tasks** - Historical implementation records and decisions

## Finding What You Need

### By Role

**Platform Operators**
- Start with [Operations](operations/) for runbooks and procedures
- Check [Troubleshooting](operations/troubleshooting.md) for common issues
- Review [HA/DR](operations/ha-dr.md) for resilience procedures

**Developers**
- Start with [Getting Started](getting-started.md) for deployment
- Review [Modules](modules/) for technical implementation details
- Check [Features](features/) for capability guides

**Architects**
- Start with [Architecture](architecture.md) for system design
- Review [Security Compliance](operations/security-compliance.md)
- Check [Reference](reference/) for configuration options

### By Topic

**Monitoring & Observability**
- [Enhanced Monitoring Guide](features/monitoring/README.md)
- [Prometheus Setup](features/monitoring/prometheus.md)
- [Monitoring Migration](features/monitoring/migration-guide.md)
- [CloudFront Monitoring](features/monitoring/cloudfront.md)

**Autoscaling & Compute**
- [Karpenter Configuration](features/karpenter.md)
- [Karpenter Integration](features/karpenter-integration.md)
- [TargetGroupBinding](features/targetgroupbinding.md)

**Content Delivery**
- [CloudFront Integration](cloudfront.md)

**Security & Compliance**
- [Security Baseline](operations/security-compliance.md)
- [Secrets Management](getting-started.md#secrets-management)

## Contributing to Documentation

When adding or updating documentation:

1. **Choose the right location**:
   - Module implementation details → `modules/`
   - User-facing feature guides → `features/`
   - Operational procedures → `operations/`
   - Configuration references → `reference/`

2. **Follow the standard structure**:
   - Overview/Purpose
   - Prerequisites
   - Main content sections
   - Examples
   - Troubleshooting
   - Related documentation links

3. **Update index files**:
   - Add links to category README files
   - Update this central documentation hub
   - Update root README.md if needed

4. **Use relative links**:
   - Link to other docs using relative paths
   - Keep links working when files move

## Getting Help

- **Documentation Issues**: Check [Troubleshooting](operations/troubleshooting.md)
- **Operational Issues**: Follow [Operations Runbook](runbook.md)
- **Architecture Questions**: Review [Architecture Guide](architecture.md)
- **Configuration Questions**: Check [Reference Documentation](reference/)

## Additional Resources

- [Root README](../README.md) - Project overview and repository layout
- [Makefile](../Makefile) - Build automation and helper commands
- [Example Configurations](../examples/) - Sample tfvars files
