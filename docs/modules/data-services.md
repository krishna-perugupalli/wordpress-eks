# Data Services Modules

## Overview

The data services modules provide managed storage and caching infrastructure for the WordPress platform. These modules create Aurora MySQL Serverless v2 for the database, ElastiCache Redis for object caching, and EFS for shared file storage.

## Modules

- **data-aurora**: Aurora MySQL Serverless v2 cluster with automated backups
- **elasticache**: Redis replication group with TLS and AUTH
- **data-efs**: Elastic File System with access points for wp-content

---

## Aurora MySQL Module (`data-aurora`)

### Purpose

Provides a highly available, auto-scaling MySQL database using Aurora Serverless v2. Includes automated backups, encryption at rest, and optional cross-region backup copy.

### Key Resources

- **RDS Cluster**: Aurora MySQL 8.0 compatible cluster
- **Cluster Instances**: Serverless v2 instances (auto-scaling ACU)
- **Security Group**: Controls network access to the database
- **DB Subnet Group**: Multi-AZ subnet placement
- **AWS Backup**: Automated backup plan with retention policies
- **Secrets Manager**: Auto-generated admin password (when `create_random_password=true`)

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│              Aurora MySQL Cluster                        │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │  Writer Instance │      │  Reader Instance │        │
│  │  (Serverless v2) │◄────►│  (Serverless v2) │        │
│  │  2-16 ACU        │      │  2-16 ACU        │        │
│  └──────────────────┘      └──────────────────┘        │
│           │                         │                    │
│           └─────────┬───────────────┘                    │
│                     ↓                                    │
│            ┌─────────────────┐                          │
│            │  Storage (EBS)  │                          │
│            │  KMS Encrypted  │                          │
│            └─────────────────┘                          │
└─────────────────────────────────────────────────────────┘
                      │
                      ↓
            ┌──────────────────┐
            │   AWS Backup     │
            │  Daily Snapshots │
            │  7-day retention │
            └──────────────────┘
```

### Configuration

#### Basic Setup

```hcl
module "aurora" {
  source = "../../modules/data-aurora"

  name                  = "wordpress-prod"
  vpc_id                = module.foundation.vpc_id
  private_subnet_ids    = module.foundation.private_subnet_ids
  storage_kms_key_arn   = module.foundation.kms_rds_arn

  db_name                = "wordpress"
  admin_username         = "wpadmin"
  create_random_password = true

  # Serverless v2 scaling
  serverless_v2    = true
  serverless_min_acu = 2
  serverless_max_acu = 16

  # Network access
  source_node_sg_id = module.eks.node_security_group_id

  tags = local.common_tags
}
```

#### With Backup Configuration

```hcl
module "aurora" {
  source = "../../modules/data-aurora"

  # ... basic config ...

  # Automated backups
  backup_retention_days    = 7
  preferred_backup_window  = "02:00-03:00"
  enable_backup            = true
  backup_vault_name        = "wordpress-aurora-backup"
  backup_schedule_cron     = "cron(0 2 * * ? *)"
  backup_delete_after_days = 30

  # Optional: Cross-region backup copy
  backup_cross_region_copy = {
    enabled                = true
    destination_vault_name = "wordpress-dr-vault"
    destination_region     = "us-west-2"
    delete_after_days      = 30
  }
}
```

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `serverless_v2` | Use Serverless v2 (vs provisioned) | `true` |
| `serverless_min_acu` | Minimum Aurora Capacity Units | `2` |
| `serverless_max_acu` | Maximum Aurora Capacity Units | `16` |
| `backup_retention_days` | Automated backup retention | `7` |
| `deletion_protection` | Prevent accidental deletion | `true` |
| `performance_insights_enabled` | Enable Performance Insights | `true` |

### Outputs

- `cluster_id`: Aurora cluster identifier
- `writer_endpoint`: Primary (write) endpoint
- `reader_endpoint`: Read-only endpoint
- `admin_secret_arn`: Secrets Manager ARN for admin credentials
- `security_group_id`: Database security group ID

### Backup and Recovery

#### Automated Backups

The module supports two backup mechanisms:

1. **RDS Automated Backups**: Point-in-time recovery (PITR) up to `backup_retention_days`
2. **AWS Backup**: Snapshot-based backups with lifecycle policies

#### Cross-Region Disaster Recovery

Enable cross-region backup copy for regional DR:

```hcl
backup_cross_region_copy = {
  enabled                = true
  destination_vault_name = "dr-vault"
  destination_region     = "us-west-2"
  delete_after_days      = 30
}
```

**Note**: Cross-region copy is disabled by default to minimize cost and complexity. Enable when formal DR requirements are established.

---

## ElastiCache Redis Module (`elasticache`)

### Purpose

Provides a highly available Redis cluster for WordPress object caching, session storage, and transient data. Includes TLS encryption, AUTH token authentication, and Multi-AZ replication.

### Key Resources

- **Replication Group**: Redis cluster with primary and replicas
- **Security Group**: Controls network access to Redis
- **Subnet Group**: Multi-AZ subnet placement
- **Parameter Group**: Redis configuration tuning
- **Automated Snapshots**: Daily backups with retention

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│           Redis Replication Group                        │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │  Primary Node    │      │  Replica Node    │        │
│  │  AZ-1            │─────►│  AZ-2            │        │
│  │  cache.t4g.small │      │  cache.t4g.small │        │
│  └──────────────────┘      └──────────────────┘        │
│         │                           │                    │
│         └───────────┬───────────────┘                    │
│                     ↓                                    │
│            ┌─────────────────┐                          │
│            │  TLS + AUTH      │                          │
│            │  Encryption      │                          │
│            └─────────────────┘                          │
└─────────────────────────────────────────────────────────┘
                      │
                      ↓
            ┌──────────────────┐
            │  Daily Snapshots │
            │  7-day retention │
            └──────────────────┘
```

### Configuration

#### Basic Setup

```hcl
module "elasticache" {
  source = "../../modules/elasticache"

  name       = "wordpress-prod"
  vpc_id     = module.foundation.vpc_id
  subnet_ids = module.foundation.private_subnet_ids

  # Network access
  node_sg_source_ids = [module.eks.node_security_group_id]

  # Redis configuration
  engine_family = "redis7"
  engine_version = "7.1"
  node_type     = "cache.t4g.small"

  # High availability
  replicas_per_node_group = 1
  automatic_failover      = true
  multi_az                = true

  # Authentication
  auth_token              = module.secrets.redis_auth_token
  enable_auth_token_secret = false

  tags = local.common_tags
}
```

#### With Secrets Manager Integration

```hcl
module "elasticache" {
  source = "../../modules/elasticache"

  # ... basic config ...

  # AUTH token from Secrets Manager
  auth_token_secret_arn    = module.secrets.redis_auth_token_arn
  enable_auth_token_secret = true

  # Snapshots
  snapshot_retention_days = 7
  snapshot_window        = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
}
```

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `engine_family` | Parameter group family | `"redis7"` |
| `engine_version` | Redis version | `"7.1"` |
| `node_type` | Instance class | `"cache.t4g.small"` |
| `replicas_per_node_group` | Replicas per shard | `1` |
| `automatic_failover` | Enable auto-failover | `true` |
| `multi_az` | Multi-AZ placement | `true` |

### Outputs

- `replication_group_id`: Redis replication group ID
- `primary_endpoint`: Primary (write) endpoint
- `reader_endpoint`: Read-only endpoint
- `configuration_endpoint`: Cluster configuration endpoint
- `security_group_id`: Redis security group ID

### Security

#### TLS Encryption

All connections require TLS:

```bash
redis-cli -h <endpoint> --tls --askpass
```

#### AUTH Token

Redis AUTH is enforced. The token can be:
1. Passed directly via `auth_token` variable
2. Read from Secrets Manager via `auth_token_secret_arn`

---

## EFS Module (`data-efs`)

### Purpose

Provides elastic, shared file storage for WordPress wp-content (uploads, themes, plugins). Supports multiple pods reading and writing simultaneously (RWX access mode).

### Key Resources

- **EFS File System**: Elastic, scalable NFS storage
- **Mount Targets**: One per availability zone
- **Security Group**: Controls network access to EFS
- **Access Point**: Fixed POSIX permissions for wp-content
- **AWS Backup**: Automated backup plan with retention policies

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  EFS File System                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  /wp-content (Access Point)                      │  │
│  │  UID: 33 (www-data)                              │  │
│  │  GID: 33 (www-data)                              │  │
│  │  Permissions: 0775                               │  │
│  └──────────────────────────────────────────────────┘  │
│           │                    │                         │
│           ↓                    ↓                         │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │  Mount Target   │  │  Mount Target   │              │
│  │  AZ-1           │  │  AZ-2           │              │
│  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────┘
           │                    │
           ↓                    ↓
  ┌─────────────────┐  ┌─────────────────┐
  │  WordPress Pod  │  │  WordPress Pod  │
  │  AZ-1           │  │  AZ-2           │
  └─────────────────┘  └─────────────────┘
```

### Configuration

#### Basic Setup

```hcl
module "efs" {
  source = "../../modules/data-efs"

  name               = "wordpress-prod"
  vpc_id             = module.foundation.vpc_id
  private_subnet_ids = module.foundation.private_subnet_ids
  kms_key_arn        = module.foundation.kms_efs_arn

  # Network access
  allowed_security_group_ids = [module.eks.node_security_group_id]

  # Performance
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  # Access Point for wp-content
  create_fixed_access_point = true
  ap_path                   = "/wp-content"
  ap_owner_uid              = 33  # www-data
  ap_owner_gid              = 33  # www-data

  tags = local.common_tags
}
```

#### With Backup and Lifecycle

```hcl
module "efs" {
  source = "../../modules/data-efs"

  # ... basic config ...

  # Lifecycle management
  enable_lifecycle_ia = true  # Move to IA after 30 days

  # Backup
  enable_backup            = true
  backup_vault_name        = "wordpress-efs-backup"
  backup_schedule_cron     = "cron(0 1 * * ? *)"
  backup_delete_after_days = 30
}
```

### Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `performance_mode` | Performance mode | `"generalPurpose"` |
| `throughput_mode` | Throughput mode | `"bursting"` |
| `enable_lifecycle_ia` | Move to IA after 30 days | `true` |
| `create_fixed_access_point` | Create /wp-content AP | `true` |
| `ap_owner_uid` | POSIX UID for AP | `33` |
| `ap_owner_gid` | POSIX GID for AP | `33` |

### Outputs

- `file_system_id`: EFS file system ID
- `file_system_arn`: EFS file system ARN
- `access_point_id`: Access point ID (if created)
- `security_group_id`: EFS security group ID

### Kubernetes Integration

#### StorageClass

Create a StorageClass for EFS with Access Point:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-ap
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: <efs_file_system_id>
  directoryPerms: "775"
  gidRangeStart: "33"
  gidRangeEnd: "33"
  basePath: "/wp-content"
```

#### PersistentVolumeClaim

WordPress uses this StorageClass for wp-content:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wordpress-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: efs-ap
  resources:
    requests:
      storage: 10Gi  # Nominal (EFS is elastic)
```

---

## Integration Example

Complete data services stack:

```hcl
# Aurora MySQL
module "aurora" {
  source = "../../modules/data-aurora"

  name                  = var.name
  vpc_id                = module.foundation.vpc_id
  private_subnet_ids    = module.foundation.private_subnet_ids
  storage_kms_key_arn   = module.foundation.kms_rds_arn
  
  db_name                = "wordpress"
  admin_username         = "wpadmin"
  create_random_password = true
  
  serverless_v2      = true
  serverless_min_acu = 2
  serverless_max_acu = 16
  
  source_node_sg_id = module.eks.node_security_group_id
  enable_backup     = true
  
  tags = local.common_tags
}

# ElastiCache Redis
module "elasticache" {
  source = "../../modules/elasticache"

  name       = var.name
  vpc_id     = module.foundation.vpc_id
  subnet_ids = module.foundation.private_subnet_ids
  
  node_sg_source_ids      = [module.eks.node_security_group_id]
  auth_token              = module.secrets.redis_auth_token
  replicas_per_node_group = 1
  
  tags = local.common_tags
}

# EFS
module "efs" {
  source = "../../modules/data-efs"

  name                       = var.name
  vpc_id                     = module.foundation.vpc_id
  private_subnet_ids         = module.foundation.private_subnet_ids
  kms_key_arn                = module.foundation.kms_efs_arn
  allowed_security_group_ids = [module.eks.node_security_group_id]
  
  create_fixed_access_point = true
  enable_backup             = true
  
  tags = local.common_tags
}
```

## Troubleshooting

### Aurora Connection Issues

**Symptoms**: Applications cannot connect to database

**Solution**:
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids <db_sg_id>

# Test connectivity from EKS node
kubectl run -it --rm mysql-client --image=mysql:8.0 --restart=Never -- \
  mysql -h <writer_endpoint> -u <username> -p
```

### Redis AUTH Failures

**Symptoms**: Redis connection refused or AUTH failed

**Solution**:
```bash
# Test with AUTH token
redis-cli -h <primary_endpoint> --tls --askpass

# Verify token in Secrets Manager
aws secretsmanager get-secret-value --secret-id <secret_arn>
```

### EFS Mount Failures

**Symptoms**: Pods stuck in ContainerCreating

**Solution**:
```bash
# Check EFS CSI driver
kubectl get pods -n kube-system -l app=efs-csi-controller

# Verify mount targets
aws efs describe-mount-targets --file-system-id <fs_id>

# Check security group rules (port 2049)
```

## Related Documentation

- **Module Guide**: [WordPress](wordpress.md) - WordPress application configuration
- **Operations**: [Backup and Restore](../operations/backup-restore.md) - Backup procedures
- **Operations**: [HA/DR](../operations/ha-dr.md) - High availability and disaster recovery
- **Reference**: [Variables](../reference/variables.md) - Complete variable reference
