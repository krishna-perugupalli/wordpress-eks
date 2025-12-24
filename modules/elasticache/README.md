# ElastiCache Redis Module

ElastiCache Redis replication group with Multi-AZ support and TLS encryption.

## Resources Created

- Redis replication group with automatic failover
- Subnet group across multiple AZs
- Security group with configurable access rules
- Optional AUTH token integration via Secrets Manager
- Automated snapshots with configurable retention

## Key Inputs

- `name` - Logical prefix for resources
- `vpc_id` - VPC ID for the cluster
- `subnet_ids` - Subnets for Redis subnet group
- `engine_version` - Redis engine version (default: "7.1")
- `node_type` - Instance class (default: "cache.t4g.small")
- `replicas_per_node_group` - Number of replicas (default: 1)
- `auth_token` - Redis AUTH token for TLS connections

## Key Outputs

- `primary_endpoint_address` - Primary endpoint for write operations
- `reader_endpoint_address` - Reader endpoint for read operations
- `security_group_id` - Redis security group ID

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

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_elasticache_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_parameter_group) | resource |
| [aws_elasticache_replication_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_replication_group) | resource |
| [aws_elasticache_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/elasticache_subnet_group) | resource |
| [aws_security_group.redis](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress_cidr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_secretsmanager_secret_version.auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Logical prefix (project-env) | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets for ElastiCache subnet group (typically private) | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | Optional CIDR blocks allowed to reach Redis (use sparingly) | `list(string)` | `[]` | no |
| <a name="input_auth_token"></a> [auth\_token](#input\_auth\_token) | Redis AUTH token value to apply directly (typically sourced from secrets-iam output). Overrides auth\_token\_secret\_arn when provided. | `string` | `""` | no |
| <a name="input_auth_token_secret_arn"></a> [auth\_token\_secret\_arn](#input\_auth\_token\_secret\_arn) | Secrets Manager ARN containing JSON {"token":"..."} for Redis AUTH. Optional; if empty, AUTH is disabled. | `string` | `""` | no |
| <a name="input_automatic_failover"></a> [automatic\_failover](#input\_automatic\_failover) | Enable automatic failover (required for Multi-AZ with replicas) | `bool` | `true` | no |
| <a name="input_enable_auth_token_secret"></a> [enable\_auth\_token\_secret](#input\_enable\_auth\_token\_secret) | Set to true when auth\_token\_secret\_arn should be read and applied. | `bool` | `false` | no |
| <a name="input_engine_family"></a> [engine\_family](#input\_engine\_family) | ElastiCache parameter group family, e.g., redis7 | `string` | `"redis7"` | no |
| <a name="input_engine_version"></a> [engine\_version](#input\_engine\_version) | Redis engine version, e.g., 7.1 | `string` | `"7.1"` | no |
| <a name="input_maintenance_window"></a> [maintenance\_window](#input\_maintenance\_window) | Preferred maintenance window, e.g., sun:04:00-sun:05:00 | `string` | `"sun:04:00-sun:05:00"` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Enable Multi-AZ placement | `bool` | `true` | no |
| <a name="input_node_sg_source_ids"></a> [node\_sg\_source\_ids](#input\_node\_sg\_source\_ids) | Security groups allowed to reach Redis (e.g., EKS node SG or pod SG-for-Pods) | `list(string)` | `[]` | no |
| <a name="input_node_type"></a> [node\_type](#input\_node\_type) | Node instance class | `string` | `"cache.t4g.small"` | no |
| <a name="input_replicas_per_node_group"></a> [replicas\_per\_node\_group](#input\_replicas\_per\_node\_group) | Number of replicas per shard (exclude primary). Example: 1 => total 2 nodes. | `number` | `1` | no |
| <a name="input_snapshot_retention_days"></a> [snapshot\_retention\_days](#input\_snapshot\_retention\_days) | Number of days to retain snapshots | `number` | `7` | no |
| <a name="input_snapshot_window"></a> [snapshot\_window](#input\_snapshot\_window) | UTC window for snapshots, e.g., 03:00-04:00 | `string` | `"03:00-04:00"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_primary_endpoint_address"></a> [primary\_endpoint\_address](#output\_primary\_endpoint\_address) | Primary endpoint address (write). |
| <a name="output_reader_endpoint_address"></a> [reader\_endpoint\_address](#output\_reader\_endpoint\_address) | Reader endpoint address (read). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID for Redis. |
<!-- END_TF_DOCS -->