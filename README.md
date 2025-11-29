# WordPress on EKS – Project Overview

## High level architecture
![High level architecture](./docs/wp_hla.png)

## Network architecture
![Network architecture](./docs/wp_network.png)

## What This Stack Delivers
- A production-grade AWS foundation (networking, KMS, shared buckets) sized for an EKS-hosted WordPress deployment.
- Managed data services: Aurora MySQL Serverless v2 for the application database, ElastiCache Redis for object caching, and EFS for persistent media.
- An EKS control plane with managed node groups, core add-ons (CNI, CoreDNS, kube-proxy, EFS CSI), and supporting IAM roles.
- A standalone Application Load Balancer (ALB) managed directly by Terraform with TargetGroupBinding for pod registration.
- A Kubernetes application layer that installs the External Secrets Operator (ESO), AWS Load Balancer Controller (for TargetGroupBinding), Karpenter, observability agents, and WordPress via Helm.
- Guardrails such as GuardDuty, AWS Config, CloudTrail, and monthly cost budgets.

## Repository Layout
```
stacks/
  infra/     # Terraform root for AWS infrastructure
  app/       # Terraform root for cluster add-ons + WordPress release
modules/     # Reusable building blocks consumed by the stacks
Makefile     # Helper targets for fmt/lint/plan/apply per stack
wordpress-eks.tfvars # Example variable overrides for Terraform runs
```

### Stack Boundaries
| Stack | Key Responsibilities | Terraform Cloud Workspace |
|-------|----------------------|---------------------------|
| `stacks/infra` | Foundation (VPC, NAT, subnets), EKS cluster/IAM, Aurora, EFS, Redis, standalone ALB, WAF, Route53, security baseline, shared secrets | `wp-infra` |
| `stacks/app`   | ESO, AWS Load Balancer Controller (for TargetGroupBinding), Karpenter, observability add-ons, WordPress Helm release with TargetGroupBinding | `wp-app` |

The `stacks/app` configuration consumes outputs published by `stacks/infra` through Terraform Cloud remote state.

## Deployment Flow (High Level)
1. **Terraform Cloud workspaces**: create/run `wp-infra`, then `wp-app`. The app stack refuses to plan until infra has produced required outputs (cluster name, OIDC, secrets policy ARN, ALB target group ARN, etc.).
2. **Infrastructure apply**:
   - Builds networking/KMS, then EKS IAM, then the cluster and node group.
   - Provisions Aurora, EFS (with access point and optional backups), Redis (auth token in Secrets Manager), and security services.
   - Creates standalone ALB with target group, listeners, security groups, WAF association, and Route53 records.
   - Publishes outputs (cluster metadata, secret ARNs, policy ARNs, ALB details, target group ARN) for downstream stacks.
3. **Application apply**:
   - Installs ESO using the pre-created read policy so it can sync secrets from Secrets Manager.
   - Deploys AWS Load Balancer Controller (for TargetGroupBinding functionality only).
   - Configures Karpenter for flexible compute, observability agents, and finally installs WordPress via Bitnami Helm chart with TargetGroupBinding pointing to the pre-created target group.

Refer to the [Getting Started Guide](./docs/getting-started.md) for the exact Terraform Cloud configuration steps.

## Key AWS/Kubernetes Components
- **Networking**: VPC with three public + three private subnets, NAT gateways (single or per-AZ), internet gateway, and routing tables tagged for Kubernetes discovery.
- **Security & Audit**: Dedicated KMS keys for RDS/EFS/logs/S3, CloudTrail + Config + GuardDuty, cost budget alarms, private secrets in Secrets Manager encrypted by a custom CMK.
- **Data Stores**:
  - Aurora MySQL with Serverless v2 scaling, AWS Backup integration, and secure ingress limited to the EKS node security group.
  - EFS shared filesystem with access point and AWS Backup support for `wp-content`.
  - Redis replication group with TLS/auth, fed from Secrets Manager.
- **EKS Add-ons**: IRSA-enabled AWS controllers (LBC, ESO, CloudWatch Agent, Fluent Bit, EFS CSI), Karpenter node provisioning, namespace-specific service accounts.
- **App Layer**: Bitnami WordPress chart configured for external database, ESO-managed secrets, TargetGroupBinding for ALB integration, horizontal autoscaling, and EFS-backed storage.

## Tooling & Automation
- **Terraform Cloud** for remote state, execution, and cross-workspace dependencies.
- **Make targets** for local validation (`make fmt`, `make lint`, `make validate-infra`, `make validate-app`) and full plan/apply (`make plan-all`, `make apply-all`).
- **Observability** via CloudWatch Agent and Fluent Bit shipping logs/metrics for both cluster and application workloads. Enhanced monitoring with Prometheus, Grafana, and AlertManager is available for comprehensive metrics collection, visualization, and alerting (see [Monitoring Guide](./docs/features/monitoring/README.md)).

## Secrets & IAM Relationships
1. `modules/secrets-iam` provisions Secrets Manager entries for WordPress DB credentials, admin bootstrap password, and Redis auth tokens.
2. It also publishes a “secrets-read” IAM policy ARN exposed to the app stack.
3. The app stack feeds that ARN into the ESO module, which creates an IRSA role scoped to the ESO controller service account.
4. ESO fetches secrets from Secrets Manager and materialises Kubernetes secrets consumed by the WordPress Helm release.

## Documentation

Complete documentation is organized by category for easy navigation:

### Quick Links
- **[Getting Started](./docs/getting-started.md)** - Deploy the platform from scratch
- **[Architecture Overview](./docs/architecture.md)** - System design and component relationships
- **[Operations Runbook](./docs/runbook.md)** - Day-2 operations and troubleshooting
- **[Monitoring Setup](./docs/features/monitoring/README.md)** - Prometheus, Grafana, and AlertManager

### Documentation Categories

#### [Modules](./docs/modules/README.md)
Detailed guides for each Terraform module:
- [Observability](./docs/modules/observability.md) - Monitoring and logging infrastructure
- [WordPress](./docs/modules/wordpress.md) - WordPress application deployment
- [Data Services](./docs/modules/data-services.md) - Aurora, Redis, and EFS configuration
- [Edge Ingress](./docs/modules/edge-ingress.md) - ALB and ingress controllers
- [Security](./docs/modules/security.md) - Security baseline and compliance
- [Networking](./docs/modules/networking.md) - VPC and network foundation

#### [Features](./docs/features/README.md)
User-facing feature documentation:
- [Monitoring](./docs/features/monitoring/README.md) - Complete monitoring stack guide
  - [Prometheus](./docs/features/monitoring/prometheus.md) - Metrics collection
  - [Grafana](./docs/features/monitoring/grafana.md) - Dashboards and visualization
  - [Alerting](./docs/features/monitoring/alerting.md) - AlertManager configuration
  - [CloudFront Monitoring](./docs/features/monitoring/cloudfront.md) - CDN metrics
  - [Migration Guide](./docs/features/monitoring/migration-guide.md) - CloudWatch to Prometheus
- [CloudFront Integration](./docs/cloudfront.md) - Optional CDN configuration
- [Karpenter Autoscaling](./docs/karpenter.md) - Node autoscaling with Karpenter
- [TargetGroupBinding](./docs/targetgroupbinding.md) - ALB pod registration

#### [Operations](./docs/operations/README.md)
Day-2 operations and maintenance:
- [High Availability & DR](./docs/operations/ha-dr.md) - Resilience and disaster recovery
- [Security & Compliance](./docs/operations/security-compliance.md) - Security validation
- [Network Resilience](./docs/operations/network-resilience.md) - Network partition handling
- [Backup & Restore](./docs/operations/backup-restore.md) - Data protection procedures
- [Cost Optimization](./docs/operations/cost-optimization.md) - Cost monitoring and budgets
- [Troubleshooting](./docs/operations/troubleshooting.md) - Common issues and solutions

#### [Reference](./docs/reference/README.md)
Technical reference documentation:
- [Variables](./docs/reference/variables.md) - All Terraform input variables
- [Outputs](./docs/reference/outputs.md) - All Terraform outputs
- [Alert Rules](./docs/reference/alert-rules.md) - Prometheus alert definitions
- [Dashboards](./docs/reference/dashboards.md) - Grafana dashboard catalog

### Suggested Reading Order

**For New Users:**
1. [Getting Started](./docs/getting-started.md) - Initial deployment walkthrough
2. [Architecture](./docs/architecture.md) - Understand the system design
3. [Modules Overview](./docs/modules/README.md) - Learn about available modules

**For Operators:**
1. [Operations Runbook](./docs/runbook.md) - Day-2 operations guide
2. [Monitoring Setup](./docs/features/monitoring/README.md) - Set up observability
3. [Troubleshooting](./docs/operations/troubleshooting.md) - Common issues
4. [HA & DR](./docs/operations/ha-dr.md) - Resilience procedures

**For Developers:**
1. [Architecture](./docs/architecture.md) - System design deep dive
2. [Module Documentation](./docs/modules/README.md) - Module implementation details
3. [Reference Documentation](./docs/reference/README.md) - Variables and outputs

## In Progress
- You can find the progress in the "issues"

## CloudFront Integration (Optional)
The standalone ALB architecture supports optional CloudFront integration:
- **ALB Security Group Restriction**: Restrict ALB ingress to CloudFront IP ranges only
- **Conditional Route53 Records**: Route53 can point to either ALB directly or CloudFront distribution  
- **WordPress Proxy Header Trust**: WordPress trusts X-Forwarded-Proto headers from CloudFront/ALB

See [CloudFront Integration](./docs/cloudfront.md) and `examples/cloudfront-integration.tfvars` for configuration details.

## Known Issues
- DNS management outside Route53 (e.g., external providers).
- Domain validation for ACM certificates should be created manually beforehand; automated DNS validation is not yet implemented.
- TargetGroupBinding requires AWS Load Balancer Controller to be running for pod IP registration.

## Not Supported At This Time
- Multi-region deployments.
- Automated CI/CD pipelines.
- Advanced WordPress configurations (multisite, custom plugins/themes).
- Automated scaling policies for Aurora Serverless v2 beyond default behavior.

Feel free to expand this directory with more runbooks, troubleshooting guides, and diagrams as the platform evolves.
