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
