# Edge Ingress Module

AWS Load Balancer Controller with ACM certificates for ALB and optional CloudFront integration.

## Resources Created

- AWS Load Balancer Controller Helm release
- IRSA role with ALB management permissions
- Regional ACM certificate for ALB (with DNS validation)
- Optional ACM certificate in us-east-1 for CloudFront
- Security policies for ingress traffic

## Key Inputs

- `cluster_name` - EKS cluster name
- `oidc_provider_arn` - EKS OIDC provider ARN for IRSA
- `vpc_id` - VPC ID for ALB controller
- `create_regional_certificate` - Create ACM cert for ALB (default: true)
- `alb_domain_name` - FQDN for ALB certificate
- `create_cf_certificate` - Create ACM cert for CloudFront (default: false)

## Key Outputs

- `alb_controller_role_arn` - IRSA role ARN for ALB controller
- `alb_certificate_arn` - Regional ACM certificate ARN
- `cloudfront_certificate_arn` - CloudFront ACM certificate ARN (if created)

## Documentation

For detailed configuration, examples, and troubleshooting, see:
- **Module Guide**: [docs/modules/edge-ingress.md](../../docs/modules/edge-ingress.md)
- **CloudFront Integration**: [docs/features/cloudfront.md](../../docs/features/cloudfront.md)
- **Operations**: [docs/operations/](../../docs/operations/)
