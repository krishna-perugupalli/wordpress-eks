<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_wafv2_web_acl.regional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Base name for WAF resources | `string` | n/a | yes |
| <a name="input_enable_managed_rules"></a> [enable\_managed\_rules](#input\_enable\_managed\_rules) | Enable AWS Managed Rules (Common Rule Set) for OWASP Top 10 protection | `bool` | `true` | no |
| <a name="input_rate_limit"></a> [rate\_limit](#input\_rate\_limit) | Rate limit for wp-login.php requests per 5 minutes from a single IP | `number` | `100` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to WAF resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_waf_arn"></a> [waf\_arn](#output\_waf\_arn) | ARN of the WAF WebACL |
| <a name="output_waf_id"></a> [waf\_id](#output\_waf\_id) | ID of the WAF WebACL |
| <a name="output_waf_name"></a> [waf\_name](#output\_waf\_name) | Name of the WAF WebACL |
<!-- END_TF_DOCS -->