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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.33 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |
| <a name="provider_aws.use1"></a> [aws.use1](#provider\_aws.use1) | ~> 5.55 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.13 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.33 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.cf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_acm_certificate_validation.cf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_iam_policy.alb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.alb_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.alb_controller_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_route53_record.alb_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cf_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [helm_release.alb_controller](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.controller_ns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.alb_controller](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.alb_controller_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.alb_controller_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name | `string` | n/a | yes |
| <a name="input_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#input\_cluster\_oidc\_issuer\_url) | Cluster OIDC issuer URL (https://oidc.eks.<region>.amazonaws.com/id/xxxx) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Base/cluster name (used in role names and tags) | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKS OIDC provider ARN for IRSA | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region for the EKS cluster (and regional ACM/WAF) | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for ALB controller (required by chart) | `string` | n/a | yes |
| <a name="input_alb_domain_name"></a> [alb\_domain\_name](#input\_alb\_domain\_name) | FQDN served by the ALB (used when creating regional ACM cert) | `string` | `""` | no |
| <a name="input_alb_hosted_zone_id"></a> [alb\_hosted\_zone\_id](#input\_alb\_hosted\_zone\_id) | Route53 Hosted Zone ID for alb\_domain\_name (for DNS validation) | `string` | `""` | no |
| <a name="input_cf_domain_name"></a> [cf\_domain\_name](#input\_cf\_domain\_name) | FQDN for CloudFront (used if create\_cf\_certificate = true) | `string` | `""` | no |
| <a name="input_cf_hosted_zone_id"></a> [cf\_hosted\_zone\_id](#input\_cf\_hosted\_zone\_id) | Route53 Hosted Zone ID for cf\_domain\_name (for DNS validation) | `string` | `""` | no |
| <a name="input_controller_namespace"></a> [controller\_namespace](#input\_controller\_namespace) | Namespace to install AWS Load Balancer Controller | `string` | `"kube-system"` | no |
| <a name="input_create_cf_certificate"></a> [create\_cf\_certificate](#input\_create\_cf\_certificate) | Create an ACM certificate in us-east-1 for future CloudFront | `bool` | `false` | no |
| <a name="input_create_regional_certificate"></a> [create\_regional\_certificate](#input\_create\_regional\_certificate) | Create a regional ACM certificate for ALB | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags for created resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_certificate_arn"></a> [alb\_certificate\_arn](#output\_alb\_certificate\_arn) | Regional ACM certificate ARN for ALB (if created) |
| <a name="output_alb_controller_role_arn"></a> [alb\_controller\_role\_arn](#output\_alb\_controller\_role\_arn) | IRSA role ARN used by the AWS Load Balancer Controller (for TargetGroupBinding) |
| <a name="output_cloudfront_certificate_arn"></a> [cloudfront\_certificate\_arn](#output\_cloudfront\_certificate\_arn) | ACM certificate ARN in us-east-1 for CloudFront (if created) |
<!-- END_TF_DOCS -->