# Backup and Restore Procedures

## Overview

This guide covers backup and restore procedures for all data services in the WordPress EKS platform, including Aurora MySQL, EFS shared storage, and monitoring stack data. The platform uses AWS Backup for automated, policy-driven backups with configurable retention periods and cross-region replication.

## Prerequisites

- AWS CLI configured with appropriate credentials
- kubectl access to the EKS cluster
- Terraform Cloud access for infrastructure changes
- IAM permissions for AWS Backup operations
- Understanding of RTO (Recovery Time Objective) and RPO (Recovery Point Objective) requirements

## Backup Architecture

### Backup Services

| Service | Backup Method | Frequency | Retention | RPO | RTO |
|---------|--------------|-----------|-----------|-----|-----|
| Aurora MySQL | AWS Backup + Automated Snapshots | Daily | 30 days | 5 minutes | 30-60 minutes |
| EFS (wp-content) | AWS Backup | Daily | 30 days | 24 hours | 15-30 minutes |
| Prometheus Data | AWS Backup (EBS) | Daily | 30 days | 24 hours | 30-60 minutes |
| Grafana Dashboards | AWS Backup (EBS) | Daily | 30 days | 24 hours | 15-30 minutes |

### Backup Vaults

All backups are stored in AWS Backup vaults with encryption:

- **Primary Vault**: `<project>-<env>-aurora-backup` (Aurora)
- **EFS Vault**: `<project>-<env>-efs-backup` (EFS)
- **Monitoring Vault**: `<project>-<env>-monitoring-backup` (Observability)

### Cross-Region Replication

For disaster recovery, backups can be replicated to a secondary region:

```hcl
backup_cross_region_copy = {
  enabled                = true
  destination_region     = "us-west-2"
  destination_vault_name = "wordpress-eks-dr-vault"
  delete_after_days      = 90
}
```

## Aurora MySQL Backup and Restore

### Automated Backups

Aurora automatically creates continuous backups with point-in-time recovery:

**Configuration**:
- Backup retention: 7-35 days (configurable via `backup_retention_days`)
- Backup window: 02:00-03:00 UTC (configurable via `preferred_backup_window`)
- Automated snapshots: Daily
- Transaction logs: Continuous

**Verify Backup Configuration**:
```bash
# Check cluster backup settings
aws rds describe-db-clusters \
  --db-cluster-identifier <cluster-name> \
  --query 'DBClusters[0].[BackupRetentionPeriod,PreferredBackupWindow]'

# List automated snapshots
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier <cluster-name> \
  --snapshot-type automated
```

### AWS Backup for Aurora

In addition to automated snapshots, AWS Backup provides policy-driven backups:

**Backup Plan**:
- Schedule: Daily at 02:00 UTC (configurable via `backup_schedule_cron`)
- Retention: 30 days (configurable via `backup_delete_after_days`)
- Vault: Encrypted with KMS

**Check Backup Status**:
```bash
# List backup plans
aws backup list-backup-plans

# List recovery points for Aurora
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name> \
  --by-resource-type RDS

# Check recent backup jobs
aws backup list-backup-jobs \
  --by-backup-vault-name <vault-name> \
  --max-results 10
```

### Restore Aurora from Backup

#### Option 1: Point-in-Time Recovery (PITR)

Restore to any point within the backup retention period:

```bash
# 1. Identify the restore time
RESTORE_TIME="2024-01-15T10:30:00Z"

# 2. Restore to new cluster
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier <source-cluster> \
  --db-cluster-identifier <new-cluster-name> \
  --restore-to-time $RESTORE_TIME \
  --vpc-security-group-ids <sg-id> \
  --db-subnet-group-name <subnet-group> \
  --kms-key-id <kms-key-arn>

# 3. Create cluster instance
aws rds create-db-instance \
  --db-instance-identifier <new-cluster-name>-1 \
  --db-cluster-identifier <new-cluster-name> \
  --db-instance-class db.serverless \
  --engine aurora-mysql

# 4. Wait for cluster to be available
aws rds wait db-cluster-available \
  --db-cluster-identifier <new-cluster-name>

# 5. Get new endpoint
aws rds describe-db-clusters \
  --db-cluster-identifier <new-cluster-name> \
  --query 'DBClusters[0].Endpoint'
```

#### Option 2: Restore from AWS Backup

Restore from a specific recovery point:

```bash
# 1. List recovery points
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name> \
  --by-resource-type RDS

# 2. Start restore job
aws backup start-restore-job \
  --recovery-point-arn <recovery-point-arn> \
  --metadata '{
    "DBClusterIdentifier":"<new-cluster-name>",
    "Engine":"aurora-mysql",
    "DBSubnetGroupName":"<subnet-group>",
    "VpcSecurityGroupIds":"<sg-id>"
  }' \
  --iam-role-arn <backup-restore-role-arn>

# 3. Monitor restore job
aws backup describe-restore-job \
  --restore-job-id <job-id>
```

#### Option 3: Restore from Snapshot

Restore from a manual or automated snapshot:

```bash
# 1. List available snapshots
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier <cluster-name>

# 2. Restore from snapshot
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier <new-cluster-name> \
  --snapshot-identifier <snapshot-id> \
  --engine aurora-mysql \
  --vpc-security-group-ids <sg-id> \
  --db-subnet-group-name <subnet-group>

# 3. Create instance and wait for availability
# (same as PITR steps 3-5)
```

### Update Application to Use Restored Database

After restoring to a new cluster:

**Option A: Update Secrets Manager** (Recommended):
```bash
# 1. Get new endpoint
NEW_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier <new-cluster-name> \
  --query 'DBClusters[0].Endpoint' \
  --output text)

# 2. Update secret
aws secretsmanager update-secret \
  --secret-id <wordpress-db-secret> \
  --secret-string "{\"host\":\"$NEW_ENDPOINT\",\"port\":\"3306\",\"username\":\"admin\",\"password\":\"<password>\"}"

# 3. Restart WordPress pods to pick up new secret
kubectl rollout restart deployment -n wordpress wordpress
```

**Option B: Update Terraform** (For permanent change):
```hcl
# In stacks/infra/main.tf or variables
# Point to the new cluster identifier
# Then run terraform apply
```

## EFS Backup and Restore

### Automated EFS Backups

EFS filesystems are backed up using AWS Backup:

**Configuration**:
- Schedule: Daily at 03:00 UTC
- Retention: 30 days
- Vault: Encrypted with KMS
- Target: All EFS filesystems tagged with `Component=wordpress`

**Verify EFS Backup**:
```bash
# List EFS recovery points
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name> \
  --by-resource-type EFS

# Check EFS backup jobs
aws backup list-backup-jobs \
  --by-resource-type EFS \
  --max-results 10
```

### Restore EFS from Backup

#### Full Filesystem Restore

Restore entire EFS filesystem to a new filesystem:

```bash
# 1. List recovery points
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name> \
  --by-resource-type EFS

# 2. Start restore job
aws backup start-restore-job \
  --recovery-point-arn <recovery-point-arn> \
  --metadata '{
    "file-system-id":"<new-fs-id>",
    "Encrypted":"true",
    "KmsKeyId":"<kms-key-arn>",
    "PerformanceMode":"generalPurpose",
    "newFileSystem":"true"
  }' \
  --iam-role-arn <backup-restore-role-arn>

# 3. Monitor restore progress
aws backup describe-restore-job \
  --restore-job-id <job-id>

# 4. Get new filesystem ID
NEW_FS_ID=$(aws backup describe-restore-job \
  --restore-job-id <job-id> \
  --query 'CreatedResourceArn' \
  --output text | cut -d'/' -f2)

# 5. Create mount targets in each AZ
for SUBNET_ID in <subnet-1> <subnet-2> <subnet-3>; do
  aws efs create-mount-target \
    --file-system-id $NEW_FS_ID \
    --subnet-id $SUBNET_ID \
    --security-groups <efs-sg-id>
done
```

#### Selective File Restore

Restore specific files or directories:

```bash
# 1. Mount the restored filesystem to a temporary location
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: efs-restore-helper
  namespace: wordpress
spec:
  containers:
  - name: restore
    image: amazon/aws-cli
    command: ["/bin/sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: original-efs
      mountPath: /mnt/original
    - name: restored-efs
      mountPath: /mnt/restored
  volumes:
  - name: original-efs
    persistentVolumeClaim:
      claimName: wordpress-efs
  - name: restored-efs
    nfs:
      server: <restored-fs-id>.efs.<region>.amazonaws.com
      path: /
EOF

# 2. Copy specific files
kubectl exec -n wordpress efs-restore-helper -- \
  cp -r /mnt/restored/path/to/files /mnt/original/path/to/restore/

# 3. Verify and cleanup
kubectl delete pod -n wordpress efs-restore-helper
```

### Update Application to Use Restored EFS

**Option A: Update PersistentVolume** (Temporary):
```bash
# 1. Scale down WordPress
kubectl scale deployment -n wordpress wordpress --replicas=0

# 2. Update PV to point to new filesystem
kubectl patch pv <pv-name> -p '{
  "spec": {
    "csi": {
      "volumeHandle": "<new-fs-id>"
    }
  }
}'

# 3. Scale up WordPress
kubectl scale deployment -n wordpress wordpress --replicas=3
```

**Option B: Update Terraform** (Permanent):
```hcl
# Update EFS filesystem ID in Terraform
# Then apply changes
terraform apply -target=module.data_efs
```

## Monitoring Stack Backup and Restore

### Prometheus Data Backup

Prometheus data is stored on EBS volumes backed up via AWS Backup:

**Verify Backup**:
```bash
# List EBS recovery points
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <monitoring-vault> \
  --by-resource-type EBS

# Check volume tags
aws ec2 describe-volumes \
  --filters "Name=tag:Component,Values=monitoring" \
  --query 'Volumes[*].[VolumeId,Tags]'
```

### Restore Prometheus Data

```bash
# 1. Identify the recovery point
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <monitoring-vault> \
  --by-resource-type EBS

# 2. Restore EBS volume
aws backup start-restore-job \
  --recovery-point-arn <recovery-point-arn> \
  --metadata '{
    "AvailabilityZone":"<az>",
    "Encrypted":"true",
    "KmsKeyId":"<kms-key-arn>"
  }' \
  --iam-role-arn <backup-restore-role-arn>

# 3. Get restored volume ID
RESTORED_VOLUME_ID=$(aws backup describe-restore-job \
  --restore-job-id <job-id> \
  --query 'CreatedResourceArn' \
  --output text | cut -d'/' -f2)

# 4. Create PV from restored volume
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-restored-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: gp3
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: $RESTORED_VOLUME_ID
EOF

# 5. Update StatefulSet to use restored PV
kubectl patch statefulset -n observability prometheus-kube-prometheus-prometheus \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/volumeClaimTemplates/0/spec/volumeName", "value":"prometheus-restored-pv"}]'

# 6. Restart Prometheus
kubectl rollout restart statefulset -n observability prometheus-kube-prometheus-prometheus
```

### Grafana Dashboard Backup

Grafana dashboards are stored in SQLite database on persistent volume:

**Manual Dashboard Export**:
```bash
# 1. Port-forward to Grafana
kubectl port-forward -n observability svc/grafana 3000:3000

# 2. Export dashboards via API
for DASHBOARD_UID in $(curl -s http://admin:password@localhost:3000/api/search | jq -r '.[].uid'); do
  curl -s http://admin:password@localhost:3000/api/dashboards/uid/$DASHBOARD_UID \
    > dashboard-$DASHBOARD_UID.json
done
```

**Restore Grafana Dashboards**:
```bash
# Option 1: Restore from EBS backup (same as Prometheus)

# Option 2: Re-import dashboards
for DASHBOARD_FILE in dashboard-*.json; do
  curl -X POST http://admin:password@localhost:3000/api/dashboards/db \
    -H "Content-Type: application/json" \
    -d @$DASHBOARD_FILE
done
```

## Backup Validation and Testing

### Regular Backup Testing

Test backup and restore procedures quarterly:

**Backup Validation Checklist**:
- [ ] Verify all backup jobs completed successfully
- [ ] Check backup vault encryption is enabled
- [ ] Confirm retention policies are correct
- [ ] Test cross-region replication (if enabled)
- [ ] Validate backup job notifications

**Restore Testing Checklist**:
- [ ] Restore Aurora to test cluster
- [ ] Verify data integrity after restore
- [ ] Test application connectivity to restored database
- [ ] Restore EFS to test filesystem
- [ ] Verify file permissions and ownership
- [ ] Document restore time (RTO)

### Automated Backup Monitoring

Set up CloudWatch alarms for backup failures:

```bash
# Check for failed backup jobs
aws backup list-backup-jobs \
  --by-state FAILED \
  --max-results 10

# Check backup vault status
aws backup describe-backup-vault \
  --backup-vault-name <vault-name>
```

## Disaster Recovery Scenarios

### Scenario 1: Database Corruption

**Symptoms**: Application errors, data inconsistencies

**Recovery Steps**:
1. Identify last known good state
2. Restore Aurora using PITR to time before corruption
3. Update Secrets Manager with new endpoint
4. Restart WordPress pods
5. Verify data integrity

**RTO**: 30-60 minutes
**RPO**: 5 minutes (transaction log granularity)

### Scenario 2: Accidental File Deletion

**Symptoms**: Missing files in wp-content

**Recovery Steps**:
1. Identify deletion time
2. Mount restored EFS filesystem
3. Copy deleted files to current filesystem
4. Verify file permissions
5. Test application functionality

**RTO**: 15-30 minutes
**RPO**: 24 hours (daily backup)

### Scenario 3: Complete Region Failure

**Symptoms**: All services unavailable in primary region

**Recovery Steps**:
1. Activate cross-region backups
2. Restore Aurora in secondary region
3. Restore EFS in secondary region
4. Deploy infrastructure in secondary region
5. Update DNS to point to secondary region
6. Verify application functionality

**RTO**: 2-4 hours
**RPO**: 24 hours (cross-region replication lag)

### Scenario 4: Monitoring Data Loss

**Symptoms**: Missing metrics or dashboards

**Recovery Steps**:
1. Restore Prometheus EBS volume
2. Restore Grafana EBS volume
3. Update PVs to use restored volumes
4. Restart monitoring pods
5. Verify metrics collection

**RTO**: 30-60 minutes
**RPO**: 24 hours (daily backup)

## Backup Cost Optimization

### Storage Costs

- **Backup Storage**: ~$0.05/GB-month
- **Cross-region Copy**: ~$0.05/GB-month + data transfer
- **Snapshot Storage**: ~$0.05/GB-month

**Typical Monthly Costs**:
- Aurora backups (100GB): ~$5
- EFS backups (50GB): ~$2.50
- Monitoring backups (100GB): ~$5
- **Total**: ~$12.50/month

### Cost Optimization Strategies

1. **Adjust Retention Periods**: Reduce retention for non-critical data
2. **Lifecycle Policies**: Move old backups to cold storage
3. **Incremental Backups**: Only changed data is backed up
4. **Compression**: Enable backup compression where available
5. **Cross-region Replication**: Only enable for critical data

## Troubleshooting

### Backup Job Failures

**Symptom**: Backup jobs in FAILED state

**Diagnosis**:
```bash
# Check failed jobs
aws backup list-backup-jobs \
  --by-state FAILED

# Get job details
aws backup describe-backup-job \
  --backup-job-id <job-id>
```

**Common Causes**:
- IAM permission issues
- Resource not found (deleted)
- Vault encryption key unavailable
- Backup window too short

**Solutions**:
- Verify IAM role has required permissions
- Check resource tags match backup selection
- Verify KMS key policy allows AWS Backup
- Extend backup window if needed

### Restore Job Failures

**Symptom**: Restore jobs fail or timeout

**Diagnosis**:
```bash
# Check restore job status
aws backup describe-restore-job \
  --restore-job-id <job-id>
```

**Common Causes**:
- Insufficient capacity in target AZ
- Network connectivity issues
- IAM permission issues
- Invalid restore metadata

**Solutions**:
- Try different availability zone
- Verify VPC and subnet configuration
- Check IAM restore role permissions
- Validate restore metadata JSON

### Missing Backups

**Symptom**: Expected backups not appearing

**Diagnosis**:
```bash
# Check backup plan
aws backup get-backup-plan \
  --backup-plan-id <plan-id>

# Check backup selection
aws backup get-backup-selection \
  --backup-plan-id <plan-id> \
  --selection-id <selection-id>
```

**Common Causes**:
- Resource tags don't match selection
- Backup plan not associated with resources
- Backup window conflicts
- Service role missing permissions

**Solutions**:
- Verify resource tags
- Check backup selection criteria
- Adjust backup schedule
- Update service role policy

## Best Practices

1. **Regular Testing**: Test restore procedures quarterly
2. **Documentation**: Keep runbooks updated with actual restore times
3. **Monitoring**: Set up alerts for backup failures
4. **Retention**: Balance cost and compliance requirements
5. **Encryption**: Always encrypt backups at rest
6. **Cross-region**: Enable for critical production data
7. **Automation**: Use Terraform to manage backup policies
8. **Validation**: Verify backup integrity regularly
9. **Access Control**: Limit who can delete backups
10. **Audit Trail**: Enable CloudTrail logging for backup operations

## Compliance and Audit

### Backup Compliance

- **Retention**: Configurable to meet regulatory requirements
- **Encryption**: All backups encrypted with KMS
- **Access Logs**: CloudTrail logs all backup operations
- **Immutability**: Backup vault lock prevents deletion

### Audit Trail

All backup and restore operations are logged:
- AWS CloudTrail for API calls
- AWS Backup job history
- Kubernetes events for PV/PVC changes
- Application logs for database connections

## Related Documentation

- [High Availability and Disaster Recovery](./ha-dr.md)
- [Security and Compliance](./security-compliance.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Aurora Module](../modules/data-services.md)
- [EFS Module](../modules/data-services.md)
- [Observability Module](../modules/observability.md)

## References

- [AWS Backup Documentation](https://docs.aws.amazon.com/aws-backup/)
- [Aurora Backup and Restore](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Managing.Backups.html)
- [EFS Backup](https://docs.aws.amazon.com/efs/latest/ug/awsbackup.html)
- [RDS Point-in-Time Recovery](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PIT.html)
