# Networking Module (Foundation)

## Overview

The `foundation` module creates the core networking infrastructure for the WordPress platform. It provisions a VPC with public and private subnets across multiple availability zones, NAT gateways for outbound connectivity, KMS keys for encryption, and S3 buckets for logs and media storage.

## Key Resources

- **VPC**: Isolated network with DNS support
- **Subnets**: Public and private subnets across 2-3 AZs
- **Internet Gateway**: Outbound internet access for public subnets
- **NAT Gateways**: Outbound internet access for private subnets (single or per-AZ)
- **Route Tables**: Routing configuration for public and private subnets
- **KMS Keys**: Customer-managed keys for RDS, EFS, logs, and S3
- **S3 Buckets**: Security logs and media storage
- **ECR Repository**: Container image storage for WordPress
- **Route53 Zone**: Optional public hosted zone for domain

## Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                  Public Subnets                         │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │  10.0.1.0/24 │  │  10.0.2.0/24 │  │  10.0.3.0/24 │ │ │
│  │  │  AZ-1        │  │  AZ-2        │  │  AZ-3        │ │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │ │
│  │         │                 │                 │          │ │
│  │         └─────────────────┼─────────────────┘          │ │
│  │                           ↓                             │ │
│  │                  Internet Gateway                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                 Private Subnets                         │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │ 10.0.11.0/24 │  │ 10.0.12.0/24 │  │ 10.0.13.0/24 │ │ │
│  │  │  AZ-1        │  │  AZ-2        │  │  AZ-3        │ │ │
│  │  │  EKS Nodes   │  │  EKS Nodes   │  │  EKS Nodes   │ │ │
│  │  │  RDS         │  │  RDS         │  │  RDS         │ │ │
│  │  │  ElastiCache │  │  ElastiCache │  │  ElastiCache │ │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │ │
│  │         │                 │                 │          │ │
│  │         ↓                 ↓                 ↓          │ │
│  │    ┌─────────┐      ┌─────────┐      ┌─────────┐     │ │
│  │    │ NAT GW  │      │ NAT GW  │      │ NAT GW  │     │ │
│  │    │ (opt)   │      │ (opt)   │      │ (opt)   │     │ │
│  │    └─────────┘      └─────────┘      └─────────┘     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### NAT Gateway Modes

#### Single NAT Gateway (Cost-Optimized)

```
Private Subnets (All AZs)
         │
         ↓
    NAT Gateway (AZ-1)
         │
         ↓
   Internet Gateway
```

**Pros**: Lower cost (1 NAT Gateway + 1 EIP)
**Cons**: Single point of failure, cross-AZ data transfer charges

#### Per-AZ NAT Gateway (High Availability)

```
Private Subnet AZ-1  →  NAT Gateway AZ-1  ┐
Private Subnet AZ-2  →  NAT Gateway AZ-2  ├→ Internet Gateway
Private Subnet AZ-3  →  NAT Gateway AZ-3  ┘
```

**Pros**: No single point of failure, no cross-AZ charges
**Cons**: Higher cost (3 NAT Gateways + 3 EIPs)

## Configuration

### Basic Setup (2 AZs, Single NAT)

```hcl
module "foundation" {
  source = "../../modules/foundation"

  name    = "wordpress-prod"
  vpc_cidr = "10.0.0.0/16"

  # 2 AZs
  public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  # Single NAT Gateway (cost-optimized)
  nat_gateway_mode = "single"

  # Optional Route53 zone
  create_public_hosted_zone = false

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
```

### High Availability Setup (3 AZs, Per-AZ NAT)

```hcl
module "foundation" {
  source = "../../modules/foundation"

  name    = "wordpress-prod"
  vpc_cidr = "10.0.0.0/16"

  # 3 AZs
  public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  # Per-AZ NAT Gateways (high availability)
  nat_gateway_mode = "per_az"

  # Route53 public zone
  create_public_hosted_zone = true
  domain                    = "example.com"

  # Custom media bucket name
  media_bucket_name = "wordpress-prod-media"

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
```

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_cidr` | VPC CIDR block | Required |
| `public_cidrs` | Public subnet CIDRs (2-3) | Required |
| `private_cidrs` | Private subnet CIDRs (2-3) | Required |
| `nat_gateway_mode` | NAT strategy: `single` or `per_az` | `"single"` |
| `create_public_hosted_zone` | Create Route53 zone | `false` |
| `domain` | Root domain for Route53 | `""` |
| `media_bucket_name` | S3 bucket name for media | Auto-generated |

## Outputs

### Networking

- `vpc_id`: VPC identifier
- `vpc_cidr`: VPC CIDR block
- `public_subnet_ids`: List of public subnet IDs
- `private_subnet_ids`: List of private subnet IDs
- `nat_gateway_ids`: List of NAT Gateway IDs
- `internet_gateway_id`: Internet Gateway ID

### KMS Keys

- `kms_rds_arn`: KMS key ARN for RDS encryption
- `kms_efs_arn`: KMS key ARN for EFS encryption
- `kms_logs_arn`: KMS key ARN for log encryption
- `kms_s3_arn`: KMS key ARN for S3 encryption

### Storage

- `logs_bucket_name`: S3 bucket for security logs
- `logs_bucket_arn`: S3 bucket ARN
- `media_bucket_name`: S3 bucket for WordPress media
- `media_bucket_arn`: S3 bucket ARN
- `ecr_repository_url`: ECR repository URL for WordPress images

### DNS

- `route53_zone_id`: Route53 hosted zone ID (if created)
- `route53_zone_name_servers`: Name servers for domain delegation

## Subnet Tagging

The module automatically tags subnets for EKS and Karpenter discovery:

### Public Subnets

```hcl
tags = {
  "kubernetes.io/role/elb"            = "1"
  "kubernetes.io/cluster/${var.name}" = "owned"
}
```

- `kubernetes.io/role/elb`: Enables AWS Load Balancer Controller to create public ALBs
- `kubernetes.io/cluster/<name>`: Indicates cluster ownership

### Private Subnets

```hcl
tags = {
  "kubernetes.io/role/internal-elb"   = "1"
  "kubernetes.io/cluster/${var.name}" = "owned"
  "karpenter.sh/discovery"            = var.name
}
```

- `kubernetes.io/role/internal-elb`: Enables internal ALBs
- `karpenter.sh/discovery`: Enables Karpenter node provisioning

## KMS Key Management

The module creates four customer-managed KMS keys:

### RDS Key

**Purpose**: Encrypt Aurora database storage and automated backups

**Key Policy**:
- Account root has full access
- RDS service can use for encryption/decryption
- Automatic key rotation enabled

### EFS Key

**Purpose**: Encrypt EFS file system data at rest

**Key Policy**:
- Account root has full access
- EFS service can use for encryption/decryption
- Automatic key rotation enabled

### Logs Key

**Purpose**: Encrypt CloudWatch Logs and CloudTrail logs

**Key Policy**:
- Account root has full access
- CloudWatch Logs service can use
- CloudTrail service can use
- Automatic key rotation enabled

### S3 Key

**Purpose**: Encrypt S3 buckets (media, backups)

**Key Policy**:
- Account root has full access
- S3 service can use for encryption/decryption
- Automatic key rotation enabled

**Key Rotation**: All keys have automatic rotation enabled (365 days)

## S3 Buckets

### Security Logs Bucket

**Purpose**: Store CloudTrail, AWS Config, and ALB access logs

**Features**:
- Versioning enabled
- SSE-S3 encryption (for CloudFront compatibility)
- Log delivery ACL permissions
- Public access blocked
- Lifecycle policy (auto-delete after configured days)

**Bucket Naming**: `<name>-sec-logs-<account_id>-<region>-<random>`

### Media Bucket

**Purpose**: Store WordPress media files (optional S3 offload)

**Features**:
- Versioning enabled
- KMS encryption (SSE-KMS)
- Access logging to security logs bucket
- Public access blocked
- Bucket owner enforced (no ACLs)

**Bucket Naming**: `<name>-media-<account_id>-<region>-<random>` or custom via `media_bucket_name`

## ECR Repository

The module creates an ECR repository for custom WordPress images:

**Features**:
- Image scanning on push
- KMS encryption
- Immutable tags (optional)

**Repository Name**: `<name>/wdp`

**Use Cases**:
- Custom WordPress images with pre-installed plugins
- Metrics exporter sidecar images
- WordPress with custom PHP configuration

## Route53 Integration

### Public Hosted Zone

When `create_public_hosted_zone = true`:

```hcl
resource "aws_route53_zone" "public" {
  name = var.domain
  tags = var.tags
}
```

**Outputs**:
- `route53_zone_id`: Use for ACM certificate validation
- `route53_zone_name_servers`: Delegate domain to these name servers

**Domain Delegation**:
```bash
# Update domain registrar with these name servers
terraform output route53_zone_name_servers
```

## Network Design Considerations

### CIDR Planning

**Recommended Allocation**:
- VPC: `/16` (65,536 IPs)
- Public subnets: `/24` each (256 IPs per AZ)
- Private subnets: `/20` or `/19` each (4,096 or 8,192 IPs per AZ)

**Why Larger Private Subnets?**
- EKS nodes consume IPs
- Each pod gets an IP (VPC CNI)
- Karpenter may scale to hundreds of nodes
- RDS, ElastiCache, EFS mount targets

**Example for 3 AZs**:
```hcl
vpc_cidr      = "10.0.0.0/16"
public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_cidrs = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
```

### NAT Gateway Selection

**Use Single NAT When**:
- Cost is primary concern
- Development/staging environments
- Acceptable downtime during NAT Gateway failure
- Low cross-AZ data transfer

**Use Per-AZ NAT When**:
- Production workloads
- High availability required
- Minimize cross-AZ data transfer costs
- Compliance requires no single point of failure

**Cost Comparison** (us-east-1):
- Single NAT: ~$32/month + $0.045/GB processed
- Per-AZ NAT (3 AZs): ~$96/month + $0.045/GB processed

## Examples

### Development Environment

```hcl
module "foundation" {
  source = "../../modules/foundation"

  name    = "wordpress-dev"
  vpc_cidr = "10.1.0.0/16"

  # 2 AZs, smaller subnets
  public_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

  # Single NAT for cost savings
  nat_gateway_mode = "single"

  # No Route53 zone
  create_public_hosted_zone = false

  tags = {
    Environment = "dev"
    CostCenter  = "engineering"
  }
}
```

### Production Environment

```hcl
module "foundation" {
  source = "../../modules/foundation"

  name    = "wordpress-prod"
  vpc_cidr = "10.0.0.0/16"

  # 3 AZs, large private subnets for pod IPs
  public_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_cidrs = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]

  # Per-AZ NAT for high availability
  nat_gateway_mode = "per_az"

  # Route53 zone for domain
  create_public_hosted_zone = true
  domain                    = "example.com"

  # Custom media bucket name
  media_bucket_name = "example-com-media"

  tags = {
    Environment = "prod"
    Compliance  = "PCI-DSS"
    Backup      = "daily"
  }
}
```

## Troubleshooting

### Private Subnet Instances Cannot Reach Internet

**Symptoms**: Pods cannot pull images, cannot reach external APIs

**Causes**:
- NAT Gateway not created
- Route table not associated with private subnets
- NAT Gateway in wrong subnet

**Solution**:
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc_id>"

# Check route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc_id>"

# Verify default route points to NAT Gateway
# Should see: 0.0.0.0/0 → nat-xxxxx
```

### EKS Cannot Create Load Balancers

**Symptoms**: ALB/NLB creation fails, AWS Load Balancer Controller errors

**Causes**:
- Missing subnet tags
- Insufficient IP addresses in subnets

**Solution**:
```bash
# Verify subnet tags
aws ec2 describe-subnets --subnet-ids <subnet_id> --query 'Subnets[0].Tags'

# Check available IPs
aws ec2 describe-subnets --subnet-ids <subnet_id> \
  --query 'Subnets[0].AvailableIpAddressCount'
```

### Karpenter Cannot Provision Nodes

**Symptoms**: Karpenter logs show "no subnets found"

**Causes**:
- Missing `karpenter.sh/discovery` tag on private subnets

**Solution**:
```bash
# Verify Karpenter discovery tag
aws ec2 describe-subnets --filters \
  "Name=tag:karpenter.sh/discovery,Values=<cluster_name>"
```

### S3 Bucket Access Denied

**Symptoms**: Cannot write to logs or media bucket

**Causes**:
- Bucket policy too restrictive
- KMS key policy doesn't allow service
- Public access block preventing legitimate access

**Solution**:
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket <bucket_name>

# Check public access block
aws s3api get-public-access-block --bucket <bucket_name>

# Test access with AWS CLI
aws s3 ls s3://<bucket_name>/
```

## Related Documentation

- **Module Guide**: [Data Services](data-services.md) - Aurora, Redis, EFS configuration
- **Module Guide**: [Edge Ingress](edge-ingress.md) - ALB and ingress configuration
- **Operations**: [Network Resilience](../operations/network-resilience.md) - Network failure handling
- **Reference**: [Variables](../reference/variables.md) - Complete variable reference
- **AWS Documentation**: [VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
