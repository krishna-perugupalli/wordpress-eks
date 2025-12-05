# High Availability and Disaster Recovery

## Overview

This guide describes the high availability (HA) and disaster recovery (DR) features for the WordPress EKS platform's monitoring stack. These capabilities ensure continuous observability even during failures, including component crashes, node failures, and availability zone outages.

## Key Features

1. **Multi-AZ Deployment** - Components distributed across availability zones
2. **Automatic Recovery** - Self-healing mechanisms for failed components
3. **Backup Policies** - Regular backups of metrics and dashboard data
4. **CloudWatch Fallback** - Critical alerting continues even if monitoring stack fails

## Multi-AZ Deployment

### Topology Spread Constraints

All monitoring components (Prometheus, Grafana, AlertManager) use topology spread constraints to ensure distribution across:

- **Availability Zones**: Pods spread using `topology.kubernetes.io/zone`
- **Nodes**: Pods spread using `kubernetes.io/hostname`

This ensures that failure of a single AZ or node doesn't take down the entire monitoring stack.

### Pod Anti-Affinity

Preferred pod anti-affinity rules ensure replicas of the same component avoid running on the same node when possible, improving resilience to node failures.

### Replica Configuration

Configure replica counts based on environment:

- **Development**: 1 replica per component
- **Staging**: 2 replicas per component  
- **Production**: 3 replicas per component (odd number for AlertManager quorum)

```hcl
# Production configuration
prometheus_replica_count   = 3
grafana_replica_count      = 2
alertmanager_replica_count = 3
```

### Pod Disruption Budgets (PDBs)

PDBs ensure minimum availability during voluntary disruptions (node drains, upgrades):

- **Prometheus**: Minimum 1 pod available (if replicas > 1)
- **Grafana**: Minimum 1 pod available
- **AlertManager**: Minimum 1 pod available (if replicas > 1)

Check PDB status:

```bash
kubectl get pdb -n observability
```

## Automatic Recovery

### Health Check CronJob

A Kubernetes CronJob runs every 5 minutes to check monitoring component health:

**Checks performed**:
- Prometheus pod status and readiness
- Grafana pod status and readiness
- AlertManager pod status and readiness

**Recovery actions**:
- Automatic rollout restart for unhealthy components
- Logging of health check results
- Event generation for monitoring

View health check logs:

```bash
kubectl logs -n observability -l app=monitoring-health-check --tail=50
```

### Liveness and Readiness Probes

All components have configured probes for automatic Kubernetes recovery:

**Prometheus**:
- Liveness: HTTP GET `/-/healthy` on port 9090
- Readiness: HTTP GET `/-/ready` on port 9090

**Grafana**:
- Liveness: HTTP GET `/api/health` on port 3000
- Readiness: HTTP GET `/api/health` on port 3000

**AlertManager**:
- Liveness: HTTP GET `/-/healthy` on port 9093
- Readiness: HTTP GET `/-/ready` on port 9093

### Automatic Restart Policy

All pods are configured with restart policies to automatically recover from crashes:
- StatefulSets (Prometheus, AlertManager): `Always`
- Deployments (Grafana): `Always`

## Backup Policies

### AWS Backup Integration

Automated backups for EBS volumes containing metrics and dashboard data:

**Daily Backups**:
- Schedule: 2 AM UTC daily
- Retention: 30 days (configurable via `backup_retention_days`)
- Target: All EBS volumes tagged with `Component=monitoring`

**Weekly Backups**:
- Schedule: 3 AM UTC on Sundays
- Retention: 90 days
- Target: All EBS volumes tagged with `Component=monitoring`

### Backup Vault

- **Encryption**: All backups encrypted with KMS
- **Cross-region**: Can be configured for cross-region replication
- **Access Control**: IAM-based access control for backup operations

### Recovery Procedures

To restore from backup:

```bash
# 1. Identify the recovery point
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name>

# 2. Restore the EBS volume
aws backup start-restore-job \
  --recovery-point-arn <recovery-point-arn> \
  --metadata file://restore-metadata.json

# 3. Attach restored volume to new PVC
kubectl apply -f restored-pvc.yaml

# 4. Update StatefulSet to use restored PVC
kubectl patch statefulset prometheus -n observability \
  --type='json' -p='[{"op": "replace", "path": "/spec/volumeClaimTemplates/0/spec/volumeName", "value":"<restored-pv-name>"}]'
```

Check backup status:

```bash
# List recent backups
aws backup list-backup-jobs \
  --by-backup-vault-name <vault-name>

# Check backup plan
aws backup get-backup-plan --backup-plan-id <plan-id>
```

## CloudWatch Fallback

### Fallback Alerting

When the monitoring stack is unavailable, CloudWatch alarms provide critical alerting:

**Monitoring Stack Health Alarms**:
- `prometheus-unavailable`: Triggers when Prometheus is down
- `grafana-unavailable`: Triggers when Grafana is down
- `alertmanager-unavailable`: Triggers when AlertManager is down

**Application Critical Alarms** (Fallback):
- `wordpress-critical-fallback`: WordPress pods unavailable
- `database-connections-critical-fallback`: Database connections exceed threshold

### SNS Topic

All fallback alarms publish to a dedicated SNS topic:
- **Topic**: `<name>-monitoring-fallback-alerts`
- **Encryption**: KMS encrypted
- **Subscriptions**: Email notifications (configurable)

Configure fallback email:

```hcl
enable_cloudwatch_fallback = true
fallback_alert_email       = "ops-team@example.com"
```

### Notification Flow

```
Monitoring Stack Failure
    ↓
CloudWatch Detects Missing Metrics
    ↓
CloudWatch Alarm Triggers
    ↓
SNS Topic Receives Alert
    ↓
Email/SMS Notifications Sent
    ↓
Operations Team Responds
```

## Configuration

### Enable HA/DR Features

```hcl
module "observability" {
  source = "../../modules/observability"
  
  # ... core configuration
  
  # Enable backup policies
  enable_backup_policies = true
  backup_retention_days  = 30
  
  # Enable CloudWatch fallback
  enable_cloudwatch_fallback = true
  fallback_alert_email       = "ops-team@example.com"
  
  # Enable automatic recovery
  enable_automatic_recovery = true
  
  # Replica counts for HA
  prometheus_replica_count    = 3
  grafana_replica_count       = 2
  alertmanager_replica_count  = 3
  
  # Database connection threshold for fallback alerts
  database_connection_threshold = 80
}
```

## Monitoring HA/DR Status

### Check Pod Distribution

```bash
# Check pod distribution across AZs
kubectl get pods -n observability -o wide \
  -l app.kubernetes.io/name=prometheus

# Check pod disruption budgets
kubectl get pdb -n observability

# View pod events
kubectl get events -n observability --sort-by='.lastTimestamp'
```

### Verify Fallback Alarms

```bash
# List CloudWatch alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix "<cluster-name>-monitoring"

# Check alarm history
aws cloudwatch describe-alarm-history \
  --alarm-name "<alarm-name>" \
  --max-records 10

# Test SNS notification
aws sns publish \
  --topic-arn <topic-arn> \
  --message "Test alert"
```

### Test Recovery

```bash
# Simulate pod failure
kubectl delete pod -n observability <pod-name>

# Watch automatic recovery
kubectl get pods -n observability -w

# Check health check job logs
kubectl logs -n observability \
  -l app=monitoring-health-check \
  --tail=50
```

## Disaster Recovery Scenarios

### Scenario 1: Complete AZ Failure

**Impact**: Pods in failed AZ are unavailable

**Recovery**:
1. Kubernetes automatically reschedules pods to healthy AZs
2. Topology spread constraints ensure even distribution
3. PDBs prevent all pods from being evicted simultaneously
4. Service endpoints automatically update

**RTO**: 5-10 minutes (automatic)
**RPO**: 0 (no data loss)

### Scenario 2: Prometheus Data Corruption

**Impact**: Metrics data is corrupted or lost

**Recovery**:
1. Identify latest good backup from AWS Backup
2. Restore EBS volume from backup
3. Create new PVC from restored volume
4. Update Prometheus StatefulSet to use new PVC
5. Restart Prometheus pods

**RTO**: 30-60 minutes (manual)
**RPO**: 24 hours (daily backup)

### Scenario 3: Complete Monitoring Stack Failure

**Impact**: No monitoring or alerting available

**Recovery**:
1. CloudWatch fallback alarms trigger immediately
2. Operations team notified via SNS
3. Health check CronJob attempts automatic recovery
4. If automatic recovery fails, manual intervention required
5. Restore from backups if necessary

**RTO**: 15-30 minutes (automatic + manual)
**RPO**: 0 (CloudWatch fallback)

### Scenario 4: Grafana Dashboard Loss

**Impact**: Custom dashboards are lost

**Recovery**:
1. Restore Grafana PVC from AWS Backup
2. Grafana SQLite database contains all dashboards
3. Alternative: Re-import dashboards from ConfigMaps
4. Default dashboards automatically restored

**RTO**: 15-30 minutes (manual)
**RPO**: 24 hours (daily backup)

### Scenario 5: Node Failure

**Impact**: Pods on failed node are unavailable

**Recovery**:
1. Kubernetes detects node failure
2. Pods automatically rescheduled to healthy nodes
3. Topology spread constraints maintain distribution
4. Service endpoints update automatically

**RTO**: 5-10 minutes (automatic)
**RPO**: 0 (no data loss)

## Troubleshooting

### Pods Not Spreading Across AZs

**Symptom**: All pods scheduled in single AZ

**Solution**:
```bash
# Check node labels
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone

# Verify topology spread constraints
kubectl describe pod -n observability <pod-name> | grep -A 10 "Topology Spread Constraints"

# Check for node resource constraints
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Backup Jobs Failing

**Symptom**: AWS Backup jobs in FAILED state

**Solution**:
```bash
# Check backup job details
aws backup describe-backup-job --backup-job-id <job-id>

# Verify IAM permissions
aws iam get-role-policy \
  --role-name <backup-role-name> \
  --policy-name <policy-name>

# Check EBS volume tags
aws ec2 describe-volumes \
  --filters "Name=tag:Component,Values=monitoring"
```

### CloudWatch Fallback Not Triggering

**Symptom**: Monitoring stack down but no CloudWatch alerts

**Solution**:
```bash
# Verify Container Insights is enabled
aws eks describe-cluster --name <cluster-name> \
  | grep containerInsights

# Check CloudWatch alarm configuration
aws cloudwatch describe-alarms \
  --alarm-names <alarm-name>

# Verify SNS topic subscription
aws sns list-subscriptions-by-topic \
  --topic-arn <topic-arn>
```

### Health Check Job Not Running

**Symptom**: CronJob not executing

**Solution**:
```bash
# Check CronJob status
kubectl get cronjob -n observability

# Check recent job executions
kubectl get jobs -n observability \
  -l app=monitoring-health-check

# Check RBAC permissions
kubectl auth can-i get pods \
  --as=system:serviceaccount:observability:monitoring-health-check \
  -n observability

# View CronJob logs
kubectl logs -n observability \
  -l app=monitoring-health-check \
  --tail=100
```

## Emergency Procedures

### Complete Monitoring Stack Failure

1. **Immediate**: CloudWatch fallback alarms trigger automatically
2. **Check**: Review SNS notifications for root cause
3. **Recover**: Health check CronJob attempts automatic recovery
4. **Manual**: If automatic recovery fails:
   ```bash
   kubectl rollout restart statefulset -n observability prometheus-kube-prometheus-prometheus
   kubectl rollout restart deployment -n observability grafana
   kubectl rollout restart statefulset -n observability alertmanager-<name>-alertmanager
   ```

### Data Loss/Corruption

1. **Identify**: Find latest good backup
   ```bash
   aws backup list-recovery-points-by-backup-vault \
     --backup-vault-name <vault-name> \
     --by-resource-type EBS
   ```

2. **Restore**: Create restore job
   ```bash
   aws backup start-restore-job \
     --recovery-point-arn <arn> \
     --metadata file://restore-metadata.json
   ```

3. **Attach**: Update PVC to use restored volume

4. **Verify**: Check data integrity after restore

## Cost Considerations

### Backup Costs

- **Storage**: ~$0.05/GB-month for backup storage
- **Restore**: ~$0.02/GB for restore operations
- **Typical Cost**: $10-50/month for 100GB of monitoring data

### Multi-AZ Costs

- **Data Transfer**: Cross-AZ data transfer at $0.01/GB
- **EBS Volumes**: Multiple volumes for replicas
- **Typical Cost**: $20-100/month additional for HA

### CloudWatch Fallback Costs

- **Alarms**: $0.10/alarm/month
- **SNS**: $0.50/million notifications
- **Typical Cost**: $5-10/month for fallback alerting

## Best Practices

1. **Regular Testing**: Test DR procedures quarterly
2. **Backup Verification**: Regularly verify backup integrity
3. **Alert Tuning**: Adjust CloudWatch fallback thresholds based on actual usage
4. **Documentation**: Keep runbooks updated with recovery procedures
5. **Monitoring**: Monitor the monitoring stack itself using CloudWatch
6. **Capacity Planning**: Ensure sufficient resources for replica counts
7. **Network Resilience**: Ensure network policies allow cross-AZ communication

## Compliance and Audit

### Backup Compliance

- **Retention**: Configurable retention periods meet compliance requirements
- **Encryption**: All backups encrypted at rest with KMS
- **Access Logs**: AWS CloudTrail logs all backup operations
- **Verification**: Regular backup integrity checks

### Audit Trail

All HA/DR operations are logged:
- Kubernetes events for pod scheduling and recovery
- AWS CloudTrail for backup operations
- CloudWatch Logs for health check executions
- SNS delivery logs for fallback notifications

## Quick Reference

| Feature | Default | Production Recommendation |
|---------|---------|---------------------------|
| Prometheus Replicas | 2 | 3 |
| Grafana Replicas | 2 | 2 |
| AlertManager Replicas | 2 | 3 (odd number) |
| Backup Retention | 30 days | 30-90 days |
| Health Check Interval | 5 minutes | 5 minutes |
| CloudWatch Fallback | Disabled | Enabled |

| Scenario | RTO | RPO | Recovery Method |
|----------|-----|-----|-----------------|
| Pod Failure | 2-5 min | 0 | Automatic (Kubernetes) |
| Node Failure | 5-10 min | 0 | Automatic (Multi-AZ) |
| AZ Failure | 5-10 min | 0 | Automatic (Multi-AZ) |
| Data Corruption | 30-60 min | 24 hours | Manual (Restore from backup) |
| Complete Stack Failure | 15-30 min | 0 | Automatic + CloudWatch fallback |

## Related Documentation

- [Observability Module Guide](../modules/observability.md)
- [Network Resilience](./network-resilience.md)
- [Security and Compliance](./security-compliance.md)
- [Troubleshooting Guide](./troubleshooting.md)
