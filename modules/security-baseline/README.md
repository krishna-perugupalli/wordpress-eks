<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudtrail.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_cloudwatch_log_group.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_config_configuration_recorder.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder) | resource |
| [aws_config_configuration_recorder_status.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_configuration_recorder_status) | resource |
| [aws_config_delivery_channel.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/config_delivery_channel) | resource |
| [aws_guardduty_detector.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_detector) | resource |
| [aws_iam_role.cloudtrail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudtrail_to_cwl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.config_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.security_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.security_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.security_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.security_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.security_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.security_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_guardduty_detector.existing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/guardduty_detector) | data source |
| [aws_iam_policy_document.cloudtrail_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudtrail_to_cwl](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.config_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.config_inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.security_logs_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Logical prefix, e.g., project-env | `string` | n/a | yes |
| <a name="input_cloudtrail_cwl_retention_days"></a> [cloudtrail\_cwl\_retention\_days](#input\_cloudtrail\_cwl\_retention\_days) | CloudWatch Logs retention (days) for CloudTrail log group. | `number` | `90` | no |
| <a name="input_create_cloudtrail"></a> [create\_cloudtrail](#input\_create\_cloudtrail) | Create a multi-region account-level CloudTrail. | `bool` | `true` | no |
| <a name="input_create_config"></a> [create\_config](#input\_create\_config) | Enable AWS Config recorder + delivery channel. | `bool` | `true` | no |
| <a name="input_create_guardduty"></a> [create\_guardduty](#input\_create\_guardduty) | Enable GuardDuty detector in this account/region. | `bool` | `false` | no |
| <a name="input_create_trail_bucket"></a> [create\_trail\_bucket](#input\_create\_trail\_bucket) | If true, create the security logs S3 bucket in this module; otherwise, use trail\_bucket\_name (can be a module output). | `bool` | `false` | no |
| <a name="input_guardduty_use_existing"></a> [guardduty\_use\_existing](#input\_guardduty\_use\_existing) | Set to true if a GuardDuty detector already exists in this account/region and should be reused instead of creating a new one. | `bool` | `true` | no |
| <a name="input_logs_expire_after_days"></a> [logs\_expire\_after\_days](#input\_logs\_expire\_after\_days) | S3 lifecycle expiration in days for security logs. | `number` | `365` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags. | `map(string)` | `{}` | no |
| <a name="input_trail_bucket_name"></a> [trail\_bucket\_name](#input\_trail\_bucket\_name) | Existing S3 bucket name for security logs (CloudTrail/ALB/Config). Required when create\_trail\_bucket=false. Leave empty when create\_trail\_bucket=true to auto-generate. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_guardduty_detector_id"></a> [guardduty\_detector\_id](#output\_guardduty\_detector\_id) | GuardDuty detector ID (null if disabled) |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS CMK ARN for security logs |
| <a name="output_security_logs_bucket"></a> [security\_logs\_bucket](#output\_security\_logs\_bucket) | S3 bucket for security logs |
| <a name="output_trail_arn"></a> [trail\_arn](#output\_trail\_arn) | CloudTrail ARN (null if trail disabled) |
<!-- END_TF_DOCS -->