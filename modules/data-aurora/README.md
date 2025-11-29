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
