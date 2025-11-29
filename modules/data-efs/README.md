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
