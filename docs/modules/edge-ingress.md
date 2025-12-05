# Edge Ingress Module

## Overview

The `edge-ingress` module deploys the AWS Load Balancer Controller on EKS and manages ACM certificates for HTTPS termination. It enables Kubernetes services to automatically provision and configure ALBs and NLBs using Ingress and Service resources, with support for TargetGroupBinding for direct pod IP registration.

## Key Resources

- **AWS Load Balancer Controller**: Kubernetes controller for ALB/NLB management
- **IRSA Role**: IAM role for service account with least-privilege permissions
- **Service Account**: Kubernetes service account with IRSA annotation
- **Helm Release**: AWS Load Balancer Controller chart
- **ACM Certificates**: Regional certificate for ALB, optional us-east-1 certificate for CloudFront
- **Route53 Records**: DNS validation records for ACM certificates

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    EKS Cluster                               │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │     AWS Load Balancer Controller Pod                   │ │
│  │  ┌──────────────────────────────────────────────────┐ │ │
│  │  │  Service Account (IRSA)                          │ │ │
│  │  │  Role: <name>-alb-controller                     │ │ │
│  │  └──────────────────────────────────────────────────┘ │ │
│  │                      │                                 │ │
│  │                      ↓                                 │ │
│  │         Watches Kubernetes Resources:                 │ │
│  │         - Ingress                                     │ │
│  │         - Service (type: LoadBalancer)                │ │
│  │         - TargetGroupBinding                          │ │
│  └────────────────────────────────────────────────────────┘ │
│                      │                                       │
└──────────────────────┼───────────────────────────────────────┘
                       │
                       ↓
         ┌─────────────────────────────┐
         │    AWS API (via IRSA)       │
         │  - Create/Update ALB/NLB    │
         │  - Manage Target Groups     │
         │  - Configure Security Groups│
         │  - Register/Deregister IPs  │
         └─────────────────────────────┘
                       │
                       ↓
         ┌─────────────────────────────┐
         │  Application Load Balancer  │
         │  - HTTPS Listener (443)     │
         │  - ACM Certificate          │
         │  - Target Group (IP mode)   │
         └─────────────────────────────┘
                       │
                       ↓
         ┌─────────────────────────────┐
         │    WordPress Pods (IPs)     │
         │  - Direct pod registration  │
         │  - Health checks            │
         └─────────────────────────────┘
```

## Configuration

### Basic Setup

```hcl
module "edge_ingress" {
  source = "../../modules/edge-ingress"

  name   = "wordpress-prod"
  region = "us-east-1"

  # EKS cluster details
  cluster_name            = module.eks.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  vpc_id                  = module.foundation.vpc_id

  # Controller namespace
  controller_namespace = "kube-system"

  # Regional ACM certificate for ALB
  create_regional_certificate = true
  alb_domain_name            = "wordpress.example.com"
  alb_hosted_zone_id         = module.foundation.route53_zone_id

  # CloudFront certificate (optional)
  create_cf_certificate = false

  tags = local.common_tags
}
```

### With CloudFront Certificate

```hcl
module "edge_ingress" {
  source = "../../modules/edge-ingress"

  name   = "wordpress-prod"
  region = "us-east-1"

  cluster_name            = module.eks.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  vpc_id                  = module.foundation.vpc_id

  # Regional certificate for ALB
  create_regional_certificate = true
  alb_domain_name            = "wordpress.example.com"
  alb_hosted_zone_id         = module.foundation.route53_zone_id

  # CloudFront certificate (us-east-1)
  create_cf_certificate = true
  cf_domain_name       = "cdn.example.com"
  cf_hosted_zone_id    = module.foundation.route53_zone_id

  tags = local.common_tags
}
```

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | EKS cluster name | Required |
| `oidc_provider_arn` | EKS OIDC provider ARN | Required |
| `cluster_oidc_issuer_url` | OIDC issuer URL | Required |
| `vpc_id` | VPC ID | Required |
| `controller_namespace` | Controller namespace | `"kube-system"` |
| `create_regional_certificate` | Create ACM cert for ALB | `true` |
| `alb_domain_name` | Domain for ALB certificate | `""` |
| `alb_hosted_zone_id` | Route53 zone for validation | `""` |
| `create_cf_certificate` | Create us-east-1 cert | `false` |
| `cf_domain_name` | Domain for CloudFront cert | `""` |
| `cf_hosted_zone_id` | Route53 zone for validation | `""` |

## Outputs

- `alb_controller_role_arn`: IAM role ARN for controller
- `alb_controller_service_account_name`: Service account name
- `regional_certificate_arn`: ACM certificate ARN (regional)
- `cf_certificate_arn`: ACM certificate ARN (us-east-1, if created)

## AWS Load Balancer Controller

### Purpose

The AWS Load Balancer Controller manages AWS Elastic Load Balancers for Kubernetes clusters:

- **Ingress**: Provisions ALBs for Ingress resources
- **Service**: Provisions NLBs for LoadBalancer services
- **TargetGroupBinding**: Registers pod IPs with existing target groups

### IAM Permissions

The module creates a minimal IAM policy focused on TargetGroupBinding management:

**Allowed Actions**:
- `ec2:Describe*`: Discover VPC, subnets, security groups
- `ec2:AuthorizeSecurityGroupIngress`: Allow ALB → pod traffic
- `ec2:CreateSecurityGroup`: Create security groups for ALBs
- `elasticloadbalancing:Describe*`: Discover ALBs and target groups
- `elasticloadbalancing:RegisterTargets`: Register pod IPs
- `elasticloadbalancing:DeregisterTargets`: Remove pod IPs
- `elasticloadbalancing:ModifyTargetGroup*`: Update target group settings

**Note**: This module does NOT grant permissions to create ALBs or listeners, as those are managed by Terraform in the standalone-alb module.

### Helm Chart Configuration

```yaml
serviceAccount:
  create: false
  name: aws-load-balancer-controller

clusterName: <cluster_name>
region: <region>
vpcId: <vpc_id>
```

### Controller Logs

```bash
# View controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Follow logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -f
```

## ACM Certificates

### Regional Certificate (ALB)

**Purpose**: HTTPS termination at the ALB

**Validation**: DNS validation via Route53

**Process**:
1. Create ACM certificate in cluster region
2. Create Route53 validation records
3. Wait for validation to complete
4. Certificate ready for ALB use

**Usage**:
```hcl
# In standalone-alb module
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = module.edge_ingress.regional_certificate_arn
  # ...
}
```

### CloudFront Certificate (us-east-1)

**Purpose**: HTTPS termination at CloudFront edge locations

**Requirement**: CloudFront requires certificates in us-east-1

**Validation**: DNS validation via Route53

**Usage**:
```hcl
# In cloudfront module
resource "aws_cloudfront_distribution" "this" {
  viewer_certificate {
    acm_certificate_arn      = module.edge_ingress.cf_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  # ...
}
```

## TargetGroupBinding

### What is TargetGroupBinding?

TargetGroupBinding is a custom resource that registers Kubernetes pod IPs directly with an ALB target group, bypassing NodePort overhead.

### Benefits

- **Direct Pod Routing**: ALB sends traffic directly to pod IPs
- **Faster Health Checks**: ALB checks pod health, not node health
- **Better Performance**: No NodePort iptables overhead
- **Accurate Metrics**: Per-pod connection and request metrics

### Example

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: wordpress-tgb
  namespace: wordpress
spec:
  serviceRef:
    name: wordpress
    port: 80
  targetGroupARN: arn:aws:elasticloadbalancing:...
  targetType: ip
```

### How It Works

1. Controller watches TargetGroupBinding resources
2. Discovers pods backing the referenced service
3. Registers pod IPs with the target group
4. Continuously syncs as pods scale up/down
5. Deregisters pod IPs when pods terminate

## Integration with Standalone ALB

This module works with the `standalone-alb` module:

**Standalone ALB Module**:
- Creates ALB, listeners, target groups (Terraform-managed)
- Provides target group ARN as output

**Edge Ingress Module**:
- Deploys AWS Load Balancer Controller
- Controller manages TargetGroupBinding resources
- Registers pod IPs with Terraform-created target groups

**Workflow**:
```
Terraform (standalone-alb)
  ↓
Creates ALB + Target Group
  ↓
Outputs target_group_arn
  ↓
WordPress module creates TargetGroupBinding
  ↓
AWS Load Balancer Controller
  ↓
Registers pod IPs with target group
```

## Examples

### Minimal Setup (No Certificates)

```hcl
module "edge_ingress" {
  source = "../../modules/edge-ingress"

  name   = "wordpress-dev"
  region = "us-east-1"

  cluster_name            = module.eks.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  vpc_id                  = module.foundation.vpc_id

  # No certificates (use ALB with HTTP only)
  create_regional_certificate = false
  create_cf_certificate      = false

  tags = local.common_tags
}
```

### Production Setup with CloudFront

```hcl
module "edge_ingress" {
  source = "../../modules/edge-ingress"

  name   = "wordpress-prod"
  region = "us-east-1"

  cluster_name            = module.eks.cluster_name
  oidc_provider_arn       = module.eks.oidc_provider_arn
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  vpc_id                  = module.foundation.vpc_id

  controller_namespace = "kube-system"

  # Regional certificate for ALB
  create_regional_certificate = true
  alb_domain_name            = "origin.example.com"
  alb_hosted_zone_id         = data.aws_route53_zone.main.id

  # CloudFront certificate
  create_cf_certificate = true
  cf_domain_name       = "www.example.com"
  cf_hosted_zone_id    = data.aws_route53_zone.main.id

  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}
```

## Troubleshooting

### Controller Pod Not Starting

**Symptoms**: Controller pod in CrashLoopBackOff or Pending

**Causes**:
- IRSA role not configured correctly
- Service account missing annotation
- Helm chart version incompatible

**Solution**:
```bash
# Check pod status
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check pod logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify service account annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

# Should see: eks.amazonaws.com/role-arn: arn:aws:iam::...
```

### TargetGroupBinding Not Registering Pods

**Symptoms**: Target group shows no healthy targets

**Causes**:
- Security group rules blocking ALB → pod traffic
- Controller doesn't have permissions
- TargetGroupBinding resource misconfigured

**Solution**:
```bash
# Check TargetGroupBinding status
kubectl describe targetgroupbinding <name> -n <namespace>

# Check controller logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep ERROR

# Verify target group in AWS console
aws elbv2 describe-target-health --target-group-arn <arn>
```

### ACM Certificate Validation Stuck

**Symptoms**: Certificate status remains "Pending validation"

**Causes**:
- Route53 validation records not created
- Wrong hosted zone ID
- DNS propagation delay

**Solution**:
```bash
# Check certificate status
aws acm describe-certificate --certificate-arn <arn>

# Verify Route53 records exist
aws route53 list-resource-record-sets --hosted-zone-id <zone_id> \
  | grep -A 5 "_acm-challenge"

# Wait for DNS propagation (can take 5-10 minutes)
```

### IRSA Authentication Failures

**Symptoms**: Controller logs show "AccessDenied" or "not authorized"

**Causes**:
- OIDC provider not configured
- IAM role trust policy incorrect
- Service account annotation missing

**Solution**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check IAM role trust policy
aws iam get-role --role-name <name>-alb-controller

# Verify service account annotation
kubectl get sa aws-load-balancer-controller -n kube-system \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

### Security Group Rules Not Created

**Symptoms**: ALB cannot reach pods, health checks fail

**Causes**:
- Controller missing EC2 permissions
- VPC ID incorrect
- Subnet tags missing

**Solution**:
```bash
# Check controller IAM permissions
aws iam get-role-policy --role-name <name>-alb-controller \
  --policy-name <name>-alb-controller

# Verify VPC ID in controller config
kubectl get deployment aws-load-balancer-controller -n kube-system \
  -o yaml | grep vpc-id

# Check subnet tags
aws ec2 describe-subnets --filters \
  "Name=tag:kubernetes.io/cluster/<cluster_name>,Values=owned"
```

## Related Documentation

- **Module Guide**: [WordPress](wordpress.md) - WordPress TargetGroupBinding configuration
- **Module Guide**: [Networking](networking.md) - VPC and subnet configuration
- **Feature Guide**: [CloudFront](../cloudfront.md) - CloudFront integration
- **Operations**: [Troubleshooting](../operations/troubleshooting.md) - Common ALB issues
- **Reference**: [Variables](../reference/variables.md) - Complete variable reference
- **AWS Documentation**: [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
