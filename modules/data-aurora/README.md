# Aurora MySQL Module

Aurora MySQL Serverless v2 cluster with automated backups and KMS encryption.

## Resources Created

- Aurora MySQL cluster (Serverless v2 or provisioned)
- DB subnet group across multiple AZs
- Security group with configurable access rules
- Secrets Manager integration for credentials
- Optional AWS Backup configuration
- Performance Insights enabled by default

## Key Inputs

- `name` - Logical name prefix for resources
- `vpc_id` - VPC ID for the cluster
- `private_subnet_ids` - Private subnets for DB subnet group (min 2 AZs)
- `storage_kms_key_arn` - KMS key ARN for storage encryption
- `serverless_v2` - Use Serverless v2 (default: true)
- `serverless_min_acu` - Minimum ACU (default: 2)
- `serverless_max_acu` - Maximum ACU (default: 16)

## Key Outputs

- `cluster_arn` - Aurora cluster ARN
- `writer_endpoint` - Writer endpoint for connections
- `reader_endpoint` - Reader endpoint for read-only queries
- `master_user_secret_arn` - Secrets Manager ARN for admin credentials

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
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.aurora](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.aurora](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.aurora](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.backup_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.backup_service_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_rds_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) | resource |
| [aws_rds_cluster_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance) | resource |
| [aws_security_group.db](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.db_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.db_ingress_additional_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.db_ingress_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.db_ingress_node_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.backup_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_rds_engine_version.aurora_mysql](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/rds_engine_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_vault_name"></a> [backup\_vault\_name](#input\_backup\_vault\_name) | Backup vault to store recovery points. Leave empty to auto-create. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Logical name/prefix for DB resources (e.g., project-env) | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnets for DB subnet group (min 2 AZs) | `list(string)` | n/a | yes |
| <a name="input_storage_kms_key_arn"></a> [storage\_kms\_key\_arn](#input\_storage\_kms\_key\_arn) | KMS key ARN for Aurora storage encryption (required) | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC where the cluster will live | `string` | n/a | yes |
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | If not generating, provide the admin password (min 8 chars) | `string` | `""` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Master/admin username | `string` | `"wpadmin"` | no |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | CIDR blocks allowed to connect (for temporary admin/migration access) | `list(string)` | `[]` | no |
| <a name="input_allowed_security_group_ids"></a> [allowed\_security\_group\_ids](#input\_allowed\_security\_group\_ids) | Security Group IDs allowed to connect to the DB port (e.g., EKS node SG) | `list(string)` | `[]` | no |
| <a name="input_apply_immediately"></a> [apply\_immediately](#input\_apply\_immediately) | Apply changes immediately (vs during maintenance window) | `bool` | `false` | no |
| <a name="input_backup_cross_region_copy"></a> [backup\_cross\_region\_copy](#input\_backup\_cross\_region\_copy) | Optional cross-region copy configuration for Aurora backups.<br>Disabled by default to avoid cost/complexity until DR is formally adopted.<br>To enable later:<br>  1) Create or choose a backup vault in the target region.<br>  2) In the STACK, declare provider 'aws' alias for the destination region.<br>  3) Set enabled=true and provide destination\_vault\_name and destination\_region. | <pre>object({<br>    enabled                = bool<br>    destination_vault_name = string<br>    destination_region     = string<br>    delete_after_days      = number<br>  })</pre> | <pre>{<br>  "delete_after_days": 30,<br>  "destination_region": "",<br>  "destination_vault_name": "",<br>  "enabled": false<br>}</pre> | no |
| <a name="input_backup_delete_after_days"></a> [backup\_delete\_after\_days](#input\_backup\_delete\_after\_days) | Retention in days. | `number` | `7` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Automated backup retention days (1-35). Determines how far back you can restore using point-in-time recovery.<br><br>Recommended values by environment:<br>- Production: 7 days (meets typical compliance requirements)<br>- Staging: 1 day (minimal retention for cost savings)<br>- Development: 1 day (minimal retention for cost savings)<br><br>Longer retention increases storage costs but provides more recovery options. | `number` | `7` | no |
| <a name="input_backup_schedule_cron"></a> [backup\_schedule\_cron](#input\_backup\_schedule\_cron) | AWS cron expression (UTC). | `string` | `"cron(0 2 * * ? *)"` | no |
| <a name="input_backup_service_role_arn"></a> [backup\_service\_role\_arn](#input\_backup\_service\_role\_arn) | Optional existing IAM role ARN for AWS Backup service to assume.<br>If null, the module creates a new role with policy:<br>  arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup | `string` | `null` | no |
| <a name="input_copy_tags_to_snapshot"></a> [copy\_tags\_to\_snapshot](#input\_copy\_tags\_to\_snapshot) | Copy tags to DB snapshots | `bool` | `true` | no |
| <a name="input_create_random_password"></a> [create\_random\_password](#input\_create\_random\_password) | Generate a strong random password for the admin user if true | `bool` | `true` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Initial database name | `string` | `"wordpress"` | no |
| <a name="input_deletion_protection"></a> [deletion\_protection](#input\_deletion\_protection) | Enable deletion protection for cluster | `bool` | `true` | no |
| <a name="input_enable_backup"></a> [enable\_backup](#input\_enable\_backup) | Enable AWS Backup for this Aurora cluster. | `bool` | `false` | no |
| <a name="input_enable_source_node_sg_rule"></a> [enable\_source\_node\_sg\_rule](#input\_enable\_source\_node\_sg\_rule) | Create the ingress rule that allows traffic from source\_node\_sg\_id. Set to false if you are not supplying a source security group. | `bool` | `true` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Aurora MySQL engine version (v3.x uses MySQL 8.0 compatibility) | `string` | `null` | no |
| <a name="input_instance_class"></a> [instance\_class](#input\_instance\_class) | Instance class for provisioned replicas (ignored if serverless\_v2 = true) | `string` | `"db.r6g.large"` | no |
| <a name="input_performance_insights_enabled"></a> [performance\_insights\_enabled](#input\_performance\_insights\_enabled) | Enable Performance Insights on instances | `bool` | `true` | no |
| <a name="input_performance_insights_kms_key_arn"></a> [performance\_insights\_kms\_key\_arn](#input\_performance\_insights\_kms\_key\_arn) | KMS key ARN for Performance Insights (optional) | `string` | `null` | no |
| <a name="input_port"></a> [port](#input\_port) | DB port | `number` | `3306` | no |
| <a name="input_preferred_backup_window"></a> [preferred\_backup\_window](#input\_preferred\_backup\_window) | Daily backup window in UTC (hh24:mi-hh24:mi) | `string` | `"02:00-03:00"` | no |
| <a name="input_preferred_maintenance_window"></a> [preferred\_maintenance\_window](#input\_preferred\_maintenance\_window) | Weekly maintenance window in UTC (ddd:hh24:mi-ddd:hh24:mi) | `string` | `"sun:03:00-sun:04:00"` | no |
| <a name="input_provisioned_replica_count"></a> [provisioned\_replica\_count](#input\_provisioned\_replica\_count) | Number of reader instances when not using Serverless v2 | `number` | `1` | no |
| <a name="input_secrets_manager_kms_key_arn"></a> [secrets\_manager\_kms\_key\_arn](#input\_secrets\_manager\_kms\_key\_arn) | KMS key ARN for Secrets Manager secret encryption (optional) | `string` | `null` | no |
| <a name="input_serverless_max_acu"></a> [serverless\_max\_acu](#input\_serverless\_max\_acu) | Serverless v2 maximum ACU (0.5-128). Should be >= serverless\_min\_acu.<br><br>Recommended values by environment:<br>- Production: 16 ACU (handles traffic spikes, ~$1,392/month at max)<br>- Staging: 8 ACU (moderate headroom, ~$696/month at max)<br>- Development: 2 ACU (minimal headroom, ~$174/month at max)<br><br>Aurora automatically scales between min and max based on workload demand. | `number` | `16` | no |
| <a name="input_serverless_min_acu"></a> [serverless\_min\_acu](#input\_serverless\_min\_acu) | Serverless v2 minimum ACU (0.5-128). Aurora Serverless v2 supports fractional ACU values starting from 0.5.<br><br>Recommended values by environment:<br>- Production: 2 ACU (sufficient baseline capacity)<br>- Staging: 1 ACU (50% cost reduction)<br>- Development: 0.5 ACU (75% cost reduction, ~$43.50/month baseline)<br><br>Lower values reduce costs in non-production environments while maintaining full functionality. | `number` | `2` | no |
| <a name="input_serverless_v2"></a> [serverless\_v2](#input\_serverless\_v2) | Use Aurora Serverless v2 if true; else provisioned instances | `bool` | `true` | no |
| <a name="input_skip_final_snapshot"></a> [skip\_final\_snapshot](#input\_skip\_final\_snapshot) | Skip creating a final snapshot when destroying the cluster. | `bool` | `false` | no |
| <a name="input_source_node_sg_id"></a> [source\_node\_sg\_id](#input\_source\_node\_sg\_id) | Primary SG allowed to reach Aurora (e.g., EKS node SG). | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | Aurora cluster ARN |
| <a name="output_master_user_secret_arn"></a> [master\_user\_secret\_arn](#output\_master\_user\_secret\_arn) | Secrets Manager ARN containing the managed master user credentials |
| <a name="output_reader_endpoint"></a> [reader\_endpoint](#output\_reader\_endpoint) | Reader endpoint |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Aurora security group ID |
| <a name="output_writer_endpoint"></a> [writer\_endpoint](#output\_writer\_endpoint) | Writer endpoint |
<!-- END_TF_DOCS -->