# EFS Storage Module

EFS file system with access points for shared WordPress content storage.

## Resources Created

- EFS file system with encryption at rest
- Mount targets in multiple AZs
- Security group with configurable access rules
- Optional access point for /wp-content
- Optional lifecycle policy for IA storage class
- Optional AWS Backup configuration

## Key Inputs

- `name` - Prefix for resource naming
- `vpc_id` - VPC ID for security group
- `private_subnet_ids` - Private subnets for mount targets (min 2)
- `kms_key_arn` - KMS key ARN for encryption (optional)
- `performance_mode` - Performance mode (default: "generalPurpose")
- `create_fixed_access_point` - Create access point for /wp-content (default: true)

## Key Outputs

- `file_system_id` - EFS file system ID
- `security_group_id` - EFS security group ID
- `access_point_id` - Access point ID (if created)

## Documentation

For detailed configuration, examples, and troubleshooting, see:
- **Module Guide**: [docs/modules/data-services.md](../../docs/modules/data-services.md)
- **Operations**: [docs/operations/backup-restore.md](../../docs/operations/backup-restore.md)
- **Architecture**: [docs/architecture.md](../../docs/architecture.md)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.33 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_efs_access_point.ap](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_access_point) | resource |
| [aws_efs_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_file_system) | resource |
| [aws_efs_mount_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/efs_mount_target) | resource |
| [aws_iam_role.backup_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.backup_service_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.efs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.efs_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.efs_ingress_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.efs_ingress_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_iam_policy_document.backup_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_vault_name"></a> [backup\_vault\_name](#input\_backup\_vault\_name) | Backup vault to store recovery points. Leave empty to auto-create | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Prefix/cluster name for resource naming | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs (min 2) for EFS mount targets | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for EFS SG | `string` | n/a | yes |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | Optional CIDRs allowed to mount (temporary admin/migration) | `list(string)` | `[]` | no |
| <a name="input_allowed_security_group_ids"></a> [allowed\_security\_group\_ids](#input\_allowed\_security\_group\_ids) | SGs allowed to mount EFS (e.g., EKS node SG or SG-for-Pods) | `list(string)` | `[]` | no |
| <a name="input_ap_owner_gid"></a> [ap\_owner\_gid](#input\_ap\_owner\_gid) | POSIX GID for AP owner (www-data=33) | `number` | `33` | no |
| <a name="input_ap_owner_uid"></a> [ap\_owner\_uid](#input\_ap\_owner\_uid) | POSIX UID for AP owner (www-data=33) | `number` | `33` | no |
| <a name="input_ap_path"></a> [ap\_path](#input\_ap\_path) | Directory for the fixed Access Point | `string` | `"/wp-content"` | no |
| <a name="input_backup_delete_after_days"></a> [backup\_delete\_after\_days](#input\_backup\_delete\_after\_days) | Retention in days. | `number` | `30` | no |
| <a name="input_backup_schedule_cron"></a> [backup\_schedule\_cron](#input\_backup\_schedule\_cron) | AWS cron expression (UTC). | `string` | `"cron(0 1 * * ? *)"` | no |
| <a name="input_backup_service_role_arn"></a> [backup\_service\_role\_arn](#input\_backup\_service\_role\_arn) | Optional existing IAM role ARN for AWS Backup service to assume.<br>If null, the module creates a new role with policy:<br>  arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup | `string` | `null` | no |
| <a name="input_create_fixed_access_point"></a> [create\_fixed\_access\_point](#input\_create\_fixed\_access\_point) | Create a fixed AP for /wp-content | `bool` | `true` | no |
| <a name="input_enable_backup"></a> [enable\_backup](#input\_enable\_backup) | Enable AWS Backup for this EFS file system. | `bool` | `false` | no |
| <a name="input_enable_lifecycle_ia"></a> [enable\_lifecycle\_ia](#input\_enable\_lifecycle\_ia) | Enable lifecycle policy to move to IA after 30 days | `bool` | `true` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key ARN for EFS encryption (null to use AWS-managed) | `string` | `null` | no |
| <a name="input_performance_mode"></a> [performance\_mode](#input\_performance\_mode) | EFS performance mode: generalPurpose or maxIO | `string` | `"generalPurpose"` | no |
| <a name="input_provisioned_throughput_mibps"></a> [provisioned\_throughput\_mibps](#input\_provisioned\_throughput\_mibps) | MiB/s if throughput\_mode = provisioned | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |
| <a name="input_throughput_mode"></a> [throughput\_mode](#input\_throughput\_mode) | EFS throughput mode: bursting or provisioned | `string` | `"bursting"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_point_id"></a> [access\_point\_id](#output\_access\_point\_id) | EFS Access Point ID (null if AP disabled) |
| <a name="output_file_system_id"></a> [file\_system\_id](#output\_file\_system\_id) | EFS File System ID |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | EFS security group ID |
<!-- END_TF_DOCS -->