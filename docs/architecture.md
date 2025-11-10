# Architecture Deep Dive

This document explains the end-to-end architecture of the WordPress on EKS platform so you can map relationships and produce detailed diagrams. The stack is composed of two Terraform roots—`stacks/infra` and `stacks/app`—that together provision AWS primitives, an EKS cluster, and the Kubernetes workloads required to run WordPress with production guardrails.

## 1. Layered Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ External Client                                                             │
│  └─→ DNS (Route53 / external)                                               │
│       └─→ AWS ALB (Ingress)                                                 │
│            └─→ WordPress Pods (Bitnami Helm)                                │
│                 ├─→ Aurora MySQL (database)                                 │
│                 ├─→ ElastiCache Redis (object cache)                        │
│                 ├─→ EFS via CSI (persistent media)                          │
│                 └─→ Secrets from Secrets Manager via ESO                    │
└─────────────────────────────────────────────────────────────────────────────┘
    ↑                                                           │
    └────── Terraform Cloud coordinates two workspaces ─────────┘
```

The architecture is organised into the following layers:

| Layer | Components | Provisioned By |
|-------|------------|----------------|
| **Foundation** | VPC, subnets, routing, NAT, KMS keys, shared S3 buckets | `modules/foundation` (`stacks/infra`) |
| **Control Plane** | IAM roles for EKS, EKS cluster, managed add-ons, node groups | `modules/iam-eks`, `modules/eks-core` (`stacks/infra`) |
| **Data Services** | Aurora MySQL, EFS, ElastiCache Redis, AWS Backup attachments | `modules/data-aurora`, `modules/data-efs`, `modules/elasticache` (`stacks/infra`) |
| **Security & Governance** | CloudTrail, Config, GuardDuty, Budgets, Secrets Manager | `modules/security-baseline`, `modules/secrets-iam`, `modules/cost-budgets` (`stacks/infra`) |
| **Application Add-ons** | External Secrets Operator, AWS Load Balancer Controller, Karpenter, observability stack | `modules/secrets-operator`, `modules/edge-ingress`, `modules/karpenter`, `modules/observability` (`stacks/app`) |
| **Application** | Bitnami WordPress Helm release | `modules/app-wordpress` (`stacks/app`) |

Terraform Cloud workspaces enforce execution order: `wp-infra` must succeed before `wp-app` can resolve remote state outputs.

## 2. Foundation Layer Details
### Networking
- **VPC**: `/16` CIDR with 3 public and 3 private subnets tagged for Kubernetes (`kubernetes.io/cluster/<name>`) discovery.
- **Routing**: Public subnets route via Internet Gateway; private subnets route via NAT gateways (single or per-AZ mode).
- **Security Groups**: Created by downstream modules; foundation ensures base networking prerequisites.

### Shared Security
- **KMS Keys**: Dedicated CMKs for RDS, EFS, CloudWatch logs, and S3. Downstream modules consume these ARNs.
- **S3 Buckets**: One for logs (CloudTrail, Config) and one for WordPress media offload (optional). Server-side encryption uses the S3 CMK and access logging targets the logs bucket.

### Optional DNS
- Foundation can create a public Route53 hosted zone when `create_public_hosted_zone=true`. Otherwise you point external DNS at the ALB later.

## 3. Control Plane Layer
### IAM & Roles
- `modules/iam-eks` provisions IAM roles for the EKS control plane and managed node group (with AWS managed policies plus project tags).

### EKS Cluster
- Terraform AWS EKS module (`modules/eks-core`) creates:
  - Cluster control plane (API endpoint private by default).
  - Managed node group for system workloads.
  - Managed add-ons (VPC CNI with optional prefix delegation, CoreDNS, kube-proxy, EFS CSI).
  - CloudWatch log groups for control plane logs (optional).
  - IRSA role for the AWS EBS CSI driver.
- Outputs: cluster name/ARN, endpoint, OIDC issuer URL, node security group ID.

### Node Autoscaling
- Base node group handles cluster-critical workloads.
- Karpenter (deployed later) provides adaptive compute for application pods using cluster, VPC, and IRSA data from this layer.

## 4. Data Services Layer
### Aurora MySQL (Serverless v2)
- Deployed inside private subnets with security group allowing ingress from the EKS node security group.
- Encrypted with foundation KMS key; Secrets Manager integration stores administrative credentials.
- AWS Backup (optional) creates vault, plan, selection, and IAM role.
- Outputs writer endpoint, secret ARNs.

### EFS (wp-content)
- File system, security group, mount targets in each private subnet.
- Optional access point (default `/wp-content`) for consistent permissions (UID/GID 33).
- Integrates with AWS Backup using tag-based selection.
- Exposes file system ID and access point ID (used for StorageClass if required).

### ElastiCache Redis
- Replication group with TLS and AUTH token (stored in Secrets Manager).
- Security group allows ingress from node security group.
- Parameter group sets tunables (e.g., `timeout=0`).
- Outputs endpoint address.

## 5. Security & Observability Layer
### Secrets Manager & IAM
- `modules/secrets-iam` provisions:
  - CMK dedicated to Secrets Manager.
  - Secrets for WordPress DB user, WordPress admin bootstrap, Redis auth token.
  - “Secrets read” IAM policy referencing those ARNs.
  - IRSA role for External Secrets Operator (ESO) with trust boundary (namespace/service account).
  - Exposes secret ARNs and policy ARN; consumed downstream.

### Security Baseline
- CloudTrail multi-region trail, AWS Config recorder, GuardDuty detector, CloudWatch/KMS integration.
- Cost budgets module creates SNS-backed Budget alerts (optional).

### Observability
- Later (app layer) the observability module deploys CloudWatch Agent and Fluent Bit with IRSA roles; log groups are created here referencing the security KMS key.

## 6. Application Add-ons (Kubernetes)
### External Secrets Operator
- Terraform module installs ESO using Helm, reuses pre-created namespace/service account with IRSA role from infra.
- Consumes `secrets_read_policy_arn` output to attach proper permissions.
- ESO syncs AWS Secrets Manager entries into Kubernetes secrets used by WordPress.

### AWS Load Balancer Controller
- IRSA role allowing ALB lifecycle management, optional namespace creation.
- Helm release in `kube-system` (or custom namespace) referenced by WordPress ingress.
- Creates/associates ACM certificates, WAF ACLs when enabled.

### Karpenter
- Controller deployed with IRSA role; NodePool definitions use subnet and security group selectors.
- Supports interruption handling via SQS queue and optional consolidation policies.

### Observability Stack
- Deploys CloudWatch Agent and aws-for-fluent-bit, writing to dedicated log groups encrypted with KMS.
- Namespace-level IRSA ensures least privilege.

## 7. WordPress Application Layer
- Bitnami Helm release configured to:
  - Disable bundled MariaDB in favour of external Aurora.
  - Pull DB credentials from `wp-env` secret generated by ESO.
  - Mount EFS via persistent volume (StorageClass optional override).
  - Register ALB ingress with TLS, WAF, and tagging via annotations.
  - Configure HPA parameters (CPU/memory targets).
  - Optionally bootstrap admin credentials via ESO-managed secret (`wp-admin`).
- Relies on remote state outputs: cluster metadata, secrets ARNs, database endpoint, ALB certificate ARN, WAF ARN.

## 8. Request Lifecycle (User Journey)
1. **DNS Resolution**: User queries DNS for `wp-sbx.example.com` (managed by Route53 or external). Record points to ALB.
2. **Edge Controls**:
   - ACM provides TLS termination on ALB listeners (443).
   - Optional AWS WAF inspects traffic with managed rule sets.
3. **Ingress**: AWS Load Balancer Controller maps ALB requests to Kubernetes ingress in the WordPress namespace, routing to `service/<release>-wordpress`.
4. **Kubernetes Service**: Traffic reaches WordPress pods via ClusterIP service. Session stickiness handled by ALB target group, not Kubernetes.
5. **Application Pod**:
   - Retrieves configuration/environment variables from `wp-env` secret (ESO-managed).
   - Reads persistent media from the mounted EFS volume (`/bitnami/wordpress`).
   - Connects to Aurora writer endpoint using credentials from Secrets Manager.
   - Uses Redis endpoint for object caching (optional plugin).
6. **Responses**: Pod returns HTML/PHP response through service → ALB → client. Static assets may be served directly from EFS; optional S3 offload can be enabled in WordPress.

## 9. Secrets & Credential Flow
### Provisioning Time
1. `modules/secrets-iam` creates Secrets Manager entries and random passwords.
2. Infra outputs include secret ARNs and the `secrets_read_policy_arn`.
3. App stack installs ESO with IRSA role referencing that policy.

### Runtime
1. ESO reconciles `ExternalSecret` CRs (`wp-env`, `wp-admin`) and materialises Kubernetes secrets.
2. WordPress pods mount secrets as environment variables, ensuring credentials stay in memory only.
3. Redis module reads the same Redis auth secret to configure replication group authentication.

## 10. Deployment & State Flow
1. **Terraform Cloud**:
   - `wp-infra` workspace executes first; publishes outputs to remote state.
   - `wp-app` declares `data.terraform_remote_state.infra` and fails early if prerequisites are missing.
2. **Makefile**: `make apply-all` sequences `apply-infra` then `apply-app` for local runs.
3. **Run Dependencies**: For CI/CD, a TFC run task or VCS pipeline can enforce sequential applies.

## 11. Scaling & Resilience Patterns
- **Cluster scaling**: Managed node group covers baseline; Karpenter provisions burst capacity across specified instance families and capacity types (Spot/On-Demand).
- **Database scaling**: Aurora Serverless v2 auto-scales ACUs; adjust min/max via Terraform variables.
- **Storage**: EFS provides shared storage across pods; leverage lifecycle policies to manage cost.
- **Cache**: Redis replication group supports automatic failover. Credentials rotate by updating Secrets Manager and reapplying.
- **Backups**: Aurora and EFS tie into AWS Backup with configurable retention; WordPress content stored on EFS plus optional S3 offload.
- **Security monitoring**: GuardDuty, Config, and CloudTrail deliver continuous monitoring; budgets alert on spend anomalies.

## 12. Diagram Suggestions
To build a Lucidchart or similar diagram, consider these views:
1. **Logical Layer Diagram**: Show user → ALB/WAF → Kubernetes → data services → secrets.
2. **Deployment Flow Diagram**: Terraform Cloud runs (infra → app) with remote state arrows and module boundaries.
3. **Network Topology**: VPC with public/private subnets, NAT gateways, EKS worker nodes, Aurora/EFS/Redis endpoints.
4. **Secrets Flow Diagram**: Secrets Manager + ESO + Kubernetes secrets + consuming workloads.
5. **Monitoring & Ops**: GuardDuty/CloudTrail flow into CloudWatch/SNS; budgets to email/SNS recipients.

Include annotations for key dependencies (e.g., `app` workspace consumes `secrets_read_policy_arn`, `writer_endpoint`, `redis_endpoint`, `kms_logs_arn`).

## 13. Key Files & References
- `stacks/infra/main.tf`: Composition of foundation + data + security modules.
- `stacks/app/main.tf`: Composition of add-ons and WordPress.
- `modules/*`: Detailed resource definitions for each building block.
- `docs/runbook.md`: Operational procedures when issues arise.
- `docs/getting-started.md`: Step-by-step deployment guidance.

Use this deep dive as the textual source of truth when designing diagrams or explaining the system to stakeholders.
