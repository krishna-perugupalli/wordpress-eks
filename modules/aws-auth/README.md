<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.33 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_aws_auth"></a> [aws\_auth](#module\_aws\_auth) | terraform-aws-modules/eks/aws//modules/aws-auth | ~> 20.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_node_role_arn"></a> [node\_role\_arn](#input\_node\_role\_arn) | IAM role ARN for the EKS managed node group(s) | `string` | n/a | yes |
| <a name="input_additional_role_mappings"></a> [additional\_role\_mappings](#input\_additional\_role\_mappings) | Additional aws-auth role mappings (advanced) | <pre>list(object({<br>    rolearn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_additional_user_mappings"></a> [additional\_user\_mappings](#input\_additional\_user\_mappings) | Additional aws-auth user mappings (optional) | <pre>list(object({<br>    userarn  = string<br>    username = string<br>    groups   = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_admin_role_arns"></a> [admin\_role\_arns](#input\_admin\_role\_arns) | IAM role ARNs to grant cluster-admin (system:masters) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_configured"></a> [configured](#output\_configured) | True when aws-auth has been applied |
<!-- END_TF_DOCS -->