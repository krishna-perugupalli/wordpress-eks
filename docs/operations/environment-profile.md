# Environment Profile Guide

This guide provides step-by-step instructions for migrating existing WordPress EKS deployments to the new environment profile system for cost optimization.

## Overview

The environment profile feature introduces a single `environment_profile` variable that automatically configures:
- NAT Gateway strategy (HA vs single)
- Aurora Serverless v2 ACU limits
- CloudFront enablement
- Backup retention periods

This migration is **safe and non-destructive** for most resources, but requires careful planning for NAT Gateway and CloudFront changes.

## Pre-Migration Checklist

Before starting the migration, ensure you have:

- [ ] Current Terraform state is clean (`terraform plan` shows no changes)
- [ ] Recent backup of Aurora database (verify in AWS Backup console)
- [ ] Recent backup of EFS filesystem (verify in AWS Backup console)
- [ ] Access to Terraform Cloud workspace
- [ ] Maintenance window scheduled (if changing NAT strategy)
- [ ] DNS TTL reduced to 60 seconds (if disabling CloudFront)
- [ ] Stakeholder notification sent

## Migration Scenarios

### Scenario 1: Production Environment (No Changes)

If your production environment already uses:
- HA NAT Gateway (3 NATs)
- Aurora 2-16 ACU
- CloudFront enabled

**Migration Steps:**

1. Add the environment profile variable to your configuration:
   ```hcl
   environment_profile = "production"
   ```

2. Run terraform plan:
   ```bash
   cd stacks/infra
   terraform plan
   ```

3. Verify no changes are detected (or only minor metadata changes)

4. Apply if needed:
   ```bash
   terraform apply
   ```

**Expected Impact:** None - configuration matches production profile defaults.

---

### Scenario 2: Migrating to Staging Profile

Migrating from production-like configuration to staging profile will:
- Change from HA NAT (3 NATs) to single NAT
- Reduce Aurora max ACU from 16 to 8
- Disable CloudFront
- Reduce backup retention from 7 days to 1 day

**Migration Steps:**

1. **Prepare for CloudFront removal** (if currently enabled):
   
   a. Reduce DNS TTL to 60 seconds:
   ```bash
   # Update Route53 record TTL for wordpress_domain_name
   aws route53 change-resource-record-sets \
     --hosted-zone-id <ZONE_ID> \
     --change-batch file://reduce-ttl.json
   ```
   
   b. Wait for TTL to expire (old TTL duration + 60 seconds)

2. **Add environment profile variable**:
   ```hcl
   environment_profile = "staging"
   ```

3. **Review the plan carefully**:
   ```bash
   cd stacks/infra
   terraform plan -out=staging-migration.tfplan
   ```

4. **Expected changes**:
   - NAT Gateway: 2 NAT Gateways will be destroyed (keeping 1)
   - Route tables: Updated to point to single NAT
   - Aurora: ACU limits updated in-place (no restart)
   - CloudFront: Distribution will be destroyed
   - Route53: Record updated to point to ALB
   - Backup retention: Updated in-place

5. **Apply during maintenance window**:
   ```bash
   terraform apply staging-migration.tfplan
   ```

6. **Monitor the migration**:
   ```bash
   # Watch NAT Gateway changes
   watch -n 5 'aws ec2 describe-nat-gateways --region <REGION> | jq ".NatGateways[] | {State: .State, SubnetId: .SubnetId}"'
   
   # Verify WordPress connectivity
   curl -I https://your-domain.com
   ```

7. **Verify application health**:
   - Check WordPress site loads correctly
   - Verify database connectivity
   - Test admin login
   - Check EFS mount (wp-content uploads)

**Expected Downtime:**
- NAT Gateway change: 2-5 minutes of connectivity disruption
- CloudFront removal: 0-60 seconds (DNS propagation)
- Aurora ACU change: No downtime (in-place update)

**Cost Impact:** ~50% reduction ($250-450/month vs $500-900/month)

---

### Scenario 3: Migrating to Development Profile

Migrating to development profile will:
- Change from HA NAT (3 NATs) to single NAT
- Reduce Aurora min ACU to 0.5, max ACU to 2
- Disable CloudFront
- Reduce backup retention to 1 day
- Change to single-AZ where possible

**Migration Steps:**

Follow the same steps as Scenario 2 (Staging), but use:
```hcl
environment_profile = "development"
```

**Additional Considerations:**
- Aurora will scale down to 0.5 ACU during idle periods (significant cost savings)
- Lower max ACU (2) may cause performance issues under load
- Only suitable for development/testing workloads

**Expected Downtime:** Same as Scenario 2

**Cost Impact:** ~60% reduction ($200-350/month vs $500-900/month)

---

### Scenario 4: Migrating from Single NAT to HA (Staging/Dev → Production)

Upgrading to production profile will:
- Add 2 additional NAT Gateways (total 3)
- Increase Aurora ACU limits
- Enable CloudFront (if configured)
- Increase backup retention to 7 days

**Migration Steps:**

1. **Prepare CloudFront certificate** (if enabling CloudFront):
   - Create ACM certificate in us-east-1
   - Validate domain ownership
   - Note certificate ARN

2. **Add environment profile and CloudFront config**:
   ```hcl
   environment_profile = "production"
   
   # If enabling CloudFront
   enable_cloudfront = true
   cloudfront_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"
   ```

3. **Review the plan**:
   ```bash
   cd stacks/infra
   terraform plan -out=production-upgrade.tfplan
   ```

4. **Expected changes**:
   - NAT Gateway: 2 new NAT Gateways created
   - Route tables: Updated for HA routing
   - Aurora: ACU limits increased (no restart)
   - CloudFront: New distribution created (if enabled)
   - Backup retention: Increased to 7 days

5. **Apply the changes**:
   ```bash
   terraform apply production-upgrade.tfplan
   ```

6. **Update DNS for CloudFront** (if enabled):
   - Wait for CloudFront distribution to deploy (~15-20 minutes)
   - Update Route53 to point to CloudFront
   - Verify HTTPS works through CloudFront

**Expected Downtime:** None (additive changes only)

**Cost Impact:** ~100% increase (from $200-450/month to $500-900/month)

---

## Rollback Procedures

### Rollback from Staging/Development to Production

If you need to rollback after migrating to a lower environment profile:

1. **Immediate rollback** (within same Terraform session):
   ```bash
   # Revert the variable change
   environment_profile = "production"
   
   # Apply immediately
   terraform apply
   ```

2. **Delayed rollback** (after state is committed):
   ```bash
   # Update configuration
   environment_profile = "production"
   
   # Plan and review
   terraform plan -out=rollback.tfplan
   
   # Apply during maintenance window
   terraform apply rollback.tfplan
   ```

**Note:** Rolling back will recreate NAT Gateways and CloudFront, which takes 15-20 minutes.

### Rollback from Production to Staging/Development

Follow the migration steps for the target profile. This is a standard migration, not a rollback.

---

## Potential Issues and Troubleshooting

### Issue 1: NAT Gateway Connectivity Loss

**Symptom:** Pods cannot reach internet after NAT Gateway change

**Cause:** Route table updates not propagated or NAT Gateway not ready

**Resolution:**
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways --region <REGION> \
  --filter "Name=state,Values=available"

# Check route tables
aws ec2 describe-route-tables --region <REGION> \
  --filters "Name=tag:Name,Values=*private*"

# Restart pods if needed
kubectl rollout restart deployment -n wordpress wordpress
```

### Issue 2: Aurora Performance Degradation

**Symptom:** Slow database queries after reducing ACU limits

**Cause:** Max ACU too low for current workload

**Resolution:**
```bash
# Check current ACU usage
aws rds describe-db-clusters --region <REGION> \
  --db-cluster-identifier <CLUSTER_ID> \
  | jq '.DBClusters[0].ServerlessV2ScalingConfiguration'

# Temporarily increase max ACU
environment_profile = "staging"  # or adjust manually
db_serverless_max_acu = 16  # override profile default

terraform apply
```

### Issue 3: CloudFront DNS Not Resolving

**Symptom:** Site unreachable after disabling CloudFront

**Cause:** DNS cache still pointing to CloudFront

**Resolution:**
```bash
# Verify Route53 record updated
aws route53 list-resource-record-sets \
  --hosted-zone-id <ZONE_ID> \
  | jq '.ResourceRecordSets[] | select(.Name=="your-domain.com.")'

# Flush local DNS cache
# macOS
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux
sudo systemd-resolve --flush-caches

# Windows
ipconfig /flushdns
```

### Issue 4: Terraform State Lock

**Symptom:** Terraform apply hangs during NAT Gateway changes

**Cause:** Concurrent route table updates

**Resolution:**
```bash
# Apply with reduced parallelism
terraform apply -parallelism=1

# If still stuck, break the state lock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Issue 5: WordPress Site Errors After Migration

**Symptom:** WordPress shows database connection errors

**Cause:** Aurora scaling down too aggressively

**Resolution:**
```bash
# Check Aurora cluster status
aws rds describe-db-clusters --region <REGION> \
  --db-cluster-identifier <CLUSTER_ID>

# Increase min ACU temporarily
db_serverless_min_acu = 1  # instead of 0.5

terraform apply

# Restart WordPress pods
kubectl rollout restart deployment -n wordpress wordpress
```

---

## Post-Migration Validation

After completing the migration, verify:

### 1. Infrastructure Health
```bash
# Check NAT Gateway count
aws ec2 describe-nat-gateways --region <REGION> \
  --filter "Name=state,Values=available" | jq '.NatGateways | length'

# Check Aurora ACU configuration
aws rds describe-db-clusters --region <REGION> \
  --db-cluster-identifier <CLUSTER_ID> \
  | jq '.DBClusters[0].ServerlessV2ScalingConfiguration'

# Check CloudFront status (if enabled)
aws cloudfront list-distributions | jq '.DistributionList.Items[] | {Id: .Id, Status: .Status}'
```

### 2. Application Health
```bash
# Check WordPress pods
kubectl get pods -n wordpress

# Check WordPress service
kubectl get svc -n wordpress

# Test WordPress connectivity
curl -I https://your-domain.com

# Check WordPress admin
curl -I https://your-domain.com/wp-admin/
```

### 3. Cost Validation
```bash
# Check AWS Cost Explorer for the past 7 days
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-08 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### 4. Backup Validation
```bash
# Verify Aurora backup retention
aws rds describe-db-clusters --region <REGION> \
  --db-cluster-identifier <CLUSTER_ID> \
  | jq '.DBClusters[0].BackupRetentionPeriod'

# Check recent backups
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <VAULT_NAME>
```

---

## Migration Timeline

### Recommended Timeline for Production → Staging/Development

| Phase | Duration | Activities |
|-------|----------|------------|
| **Planning** | 1-2 days | Review guide, schedule maintenance, notify stakeholders |
| **Preparation** | 1 day | Reduce DNS TTL, verify backups, test in non-prod |
| **Execution** | 1-2 hours | Apply Terraform changes, monitor migration |
| **Validation** | 1-2 hours | Verify health, test functionality, check costs |
| **Monitoring** | 7 days | Watch for issues, validate cost savings |

### Recommended Timeline for Staging/Development → Production

| Phase | Duration | Activities |
|-------|----------|------------|
| **Planning** | 1-2 days | Prepare CloudFront certificate, review requirements |
| **Preparation** | 1 day | Verify certificate validation, test configuration |
| **Execution** | 30-45 minutes | Apply Terraform changes (additive only) |
| **CloudFront Deployment** | 15-20 minutes | Wait for CloudFront distribution |
| **DNS Update** | 5-10 minutes | Update Route53 to CloudFront |
| **Validation** | 1-2 hours | Verify health, test functionality |

---

## Best Practices

1. **Always test in non-production first**: Migrate development → staging → production
2. **Schedule maintenance windows**: Even though most changes are non-disruptive, plan for potential issues
3. **Monitor costs closely**: Use AWS Cost Explorer to validate expected savings
4. **Keep backups**: Ensure Aurora and EFS backups are recent before migration
5. **Document your changes**: Keep a record of what was changed and when
6. **Communicate with stakeholders**: Notify users of potential brief disruptions
7. **Use Terraform plan**: Always review the plan before applying
8. **Apply with caution**: Use `-parallelism=1` for NAT Gateway changes if needed

---

## Support and Questions

If you encounter issues during migration:

1. Check the [Troubleshooting Guide](./troubleshooting.md)
2. Review the [Operations Runbook](./runbook.md)
3. Consult the [Cost Optimization Guide](./cost-optimization.md)
4. Check AWS service health dashboard
5. Review Terraform state for inconsistencies

For urgent issues, consider rolling back to the previous configuration and investigating before retrying.
