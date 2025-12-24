# Secrets IAM Module

This module creates IAM roles and policies for External Secrets Operator to access AWS Secrets Manager.

## Overview

The secrets-iam module provisions the necessary IAM resources for Kubernetes pods to securely access secrets stored in AWS Secrets Manager using IRSA (IAM Roles for Service Accounts).

## Features

- IAM role for External Secrets Operator service account
- Least-privilege IAM policy for Secrets Manager access
- IRSA integration with EKS OIDC provider
- Support for specific secret ARN restrictions
- KMS key permissions for encrypted secrets

## Usage

```hcl
module "secrets_iam" {
  source = "../../modules/secrets-iam"

  name                = "wordpress-eks"
  oidc_provider_arn   = module.eks.oidc_provider_arn
  namespace           = "external-secrets"
  service_account     = "external-secrets"
  
  secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:wordpress/*"
  ]
  
  kms_key_arns = [
    module.kms.key_arn
  ]
  
  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

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
| [aws_iam_policy.secrets_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secrets_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secrets_versions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ssm_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.eso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.eso_attach_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eso_attach_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eso_attach_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.eso_attach_versions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_alias.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_secretsmanager_secret.grafana_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.redis_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.wpadmin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.wpapp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.grafana_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.redis_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.wpadmin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.wpapp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [random_password.grafana_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.redis_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.wpadmin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.wpapp](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |
| [aws_iam_policy_document.eso_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets_kms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.secrets_versions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ssm_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_secret.external](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_oidc_provider_arn"></a> [cluster\_oidc\_provider\_arn](#input\_cluster\_oidc\_provider\_arn) | ARN of the EKS cluster's IAM OIDC provider (for IRSA). | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Logical prefix (e.g., project-env) | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region | `string` | n/a | yes |
| <a name="input_create_grafana_admin_secret"></a> [create\_grafana\_admin\_secret](#input\_create\_grafana\_admin\_secret) | Create Secrets Manager secret for Grafana admin creds | `bool` | `false` | no |
| <a name="input_create_redis_auth_secret"></a> [create\_redis\_auth\_secret](#input\_create\_redis\_auth\_secret) | If true, create a Secrets Manager secret with a random Redis AUTH token. | `bool` | `false` | no |
| <a name="input_create_ssm_kms_key"></a> [create\_ssm\_kms\_key](#input\_create\_ssm\_kms\_key) | Also create a CMK for SSM Parameter Store | `bool` | `false` | no |
| <a name="input_create_wp_admin_secret"></a> [create\_wp\_admin\_secret](#input\_create\_wp\_admin\_secret) | Create Secrets Manager secret for WP admin creds | `bool` | `false` | no |
| <a name="input_create_wpapp_db_secret"></a> [create\_wpapp\_db\_secret](#input\_create\_wpapp\_db\_secret) | Create Secrets Manager secret for the app DB user | `bool` | `false` | no |
| <a name="input_eso_namespace"></a> [eso\_namespace](#input\_eso\_namespace) | Namespace where External Secrets Operator runs. | `string` | `"external-secrets"` | no |
| <a name="input_eso_service_account_name"></a> [eso\_service\_account\_name](#input\_eso\_service\_account\_name) | ServiceAccount name used by the ESO controller. | `string` | `"external-secrets"` | no |
| <a name="input_eso_validate_audience"></a> [eso\_validate\_audience](#input\_eso\_validate\_audience) | If true, require OIDC token audience to be sts.amazonaws.com. | `bool` | `true` | no |
| <a name="input_existing_redis_auth_secret_arn"></a> [existing\_redis\_auth\_secret\_arn](#input\_existing\_redis\_auth\_secret\_arn) | If provided, use this existing secret instead of creating one. | `string` | `""` | no |
| <a name="input_grafana_admin_password"></a> [grafana\_admin\_password](#input\_grafana\_admin\_password) | If empty, a strong random password is generated | `string` | `""` | no |
| <a name="input_grafana_admin_secret_name"></a> [grafana\_admin\_secret\_name](#input\_grafana\_admin\_secret\_name) | Name for the Grafana admin secret | `string` | `"grafana-admin"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key ARN to encrypt Secrets Manager secrets (null = AWS managed). | `string` | `null` | no |
| <a name="input_readable_secret_arn_map"></a> [readable\_secret\_arn\_map](#input\_readable\_secret\_arn\_map) | Optional map of external readable secrets (stable key => ARN). Use when ARNs may be unknown until apply to keep for\_each keys deterministic. | `map(string)` | `{}` | no |
| <a name="input_readable_secret_arns"></a> [readable\_secret\_arns](#input\_readable\_secret\_arns) | Secrets Manager ARNs that a 'secrets-read' policy should allow | `list(string)` | `[]` | no |
| <a name="input_readable_ssm_parameter_arns"></a> [readable\_ssm\_parameter\_arns](#input\_readable\_ssm\_parameter\_arns) | SSM Parameter ARNs that a 'ssm-read' policy should allow (if using SSM) | `list(string)` | `[]` | no |
| <a name="input_redis_auth_secret_name"></a> [redis\_auth\_secret\_name](#input\_redis\_auth\_secret\_name) | Name/path for the Redis auth secret (e.g., app/redis/auth). Required if create\_redis\_auth\_secret=true. | `string` | `null` | no |
| <a name="input_redis_auth_token_length"></a> [redis\_auth\_token\_length](#input\_redis\_auth\_token\_length) | Length of the generated Redis token. | `number` | `64` | no |
| <a name="input_required_secret_tag_key"></a> [required\_secret\_tag\_key](#input\_required\_secret\_tag\_key) | Optional: require this tag key on secrets ESO may read (for SCP/ABAC-like control). Empty = disabled. | `string` | `""` | no |
| <a name="input_required_secret_tag_value"></a> [required\_secret\_tag\_value](#input\_required\_secret\_tag\_value) | Optional: required tag value when required\_secret\_tag\_key is set. | `string` | `""` | no |
| <a name="input_restrict_to_version_stage"></a> [restrict\_to\_version\_stage](#input\_restrict\_to\_version\_stage) | Limit ESO reads to a specific Secrets Manager version stage (e.g., AWSCURRENT). Empty = no restriction. | `string` | `"AWSCURRENT"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |
| <a name="input_wp_admin_email"></a> [wp\_admin\_email](#input\_wp\_admin\_email) | Admin email | `string` | `"admin@example.com"` | no |
| <a name="input_wp_admin_password"></a> [wp\_admin\_password](#input\_wp\_admin\_password) | If empty, a strong random password is generated | `string` | `""` | no |
| <a name="input_wp_admin_secret_name"></a> [wp\_admin\_secret\_name](#input\_wp\_admin\_secret\_name) | Name for the admin secret | `string` | `"wp-admin"` | no |
| <a name="input_wp_admin_username"></a> [wp\_admin\_username](#input\_wp\_admin\_username) | WP admin username | `string` | `"wpadmin"` | no |
| <a name="input_wpapp_db_database"></a> [wpapp\_db\_database](#input\_wpapp\_db\_database) | Database name | `string` | `"wordpress"` | no |
| <a name="input_wpapp_db_host"></a> [wpapp\_db\_host](#input\_wpapp\_db\_host) | DB hostname (e.g., module.data\_aurora.writer\_endpoint). Can be blank initially; update later. | `string` | `""` | no |
| <a name="input_wpapp_db_password"></a> [wpapp\_db\_password](#input\_wpapp\_db\_password) | If empty, a strong random password is generated | `string` | `""` | no |
| <a name="input_wpapp_db_port"></a> [wpapp\_db\_port](#input\_wpapp\_db\_port) | DB port | `number` | `3306` | no |
| <a name="input_wpapp_db_secret_name"></a> [wpapp\_db\_secret\_name](#input\_wpapp\_db\_secret\_name) | Name for the app DB secret (without arn); must be unique per account | `string` | `"wpapp-db"` | no |
| <a name="input_wpapp_db_username"></a> [wpapp\_db\_username](#input\_wpapp\_db\_username) | DB username for the app (ignored if create\_wpapp\_db\_secret=false) | `string` | `"wpapp"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eso_role_arn"></a> [eso\_role\_arn](#output\_eso\_role\_arn) | IAM Role ARN for the External Secrets Operator (IRSA). |
| <a name="output_grafana_admin_secret_arn"></a> [grafana\_admin\_secret\_arn](#output\_grafana\_admin\_secret\_arn) | ARN of created Grafana admin secret (if created) |
| <a name="output_kms_secrets_arn"></a> [kms\_secrets\_arn](#output\_kms\_secrets\_arn) | KMS CMK ARN for Secrets Manager |
| <a name="output_kms_ssm_arn"></a> [kms\_ssm\_arn](#output\_kms\_ssm\_arn) | KMS CMK ARN for SSM (if created) |
| <a name="output_redis_auth_secret_arn"></a> [redis\_auth\_secret\_arn](#output\_redis\_auth\_secret\_arn) | ARN of the Redis AUTH token secret in Secrets Manager. |
| <a name="output_redis_auth_token"></a> [redis\_auth\_token](#output\_redis\_auth\_token) | Redis AUTH token value generated by this module (empty when using an externally provided secret). |
| <a name="output_secrets_read_policy_arn"></a> [secrets\_read\_policy\_arn](#output\_secrets\_read\_policy\_arn) | IAM policy ARN that allows read of the effective secret ARNs (may be null if none). |
| <a name="output_ssm_read_policy_arn"></a> [ssm\_read\_policy\_arn](#output\_ssm\_read\_policy\_arn) | IAM policy ARN to allow reading listed SSM Parameters + decrypt (if any listed) |
| <a name="output_wp_admin_secret_arn"></a> [wp\_admin\_secret\_arn](#output\_wp\_admin\_secret\_arn) | ARN of created WP admin secret (if created) |
| <a name="output_wpapp_db_secret_arn"></a> [wpapp\_db\_secret\_arn](#output\_wpapp\_db\_secret\_arn) | ARN of created wpapp DB secret (if created) |
<!-- END_TF_DOCS -->

## Notes

- The IAM role uses IRSA for secure, temporary credentials
- Secret ARNs should use wildcards carefully to avoid over-permissioning
- KMS key permissions are required if secrets are encrypted with customer-managed keys
- The service account must be annotated with the IAM role ARN
