# Enhanced Monitoring Migration Guide

## Overview

This guide provides step-by-step instructions for migrating from the legacy CloudWatch-only monitoring to the enhanced Prometheus-based monitoring stack, or for enabling the enhanced stack alongside existing CloudWatch monitoring.

## Migration Strategies

### Strategy 1: Hybrid Deployment (Recommended)

Run both CloudWatch and Prometheus stack side-by-side. This is the safest approach as it maintains existing monitoring while validating the new stack.

**Pros:**
- Zero downtime
- Gradual validation
- Easy rollback
- Maintains existing alerts

**Cons:**
- Higher resource usage
- Increased costs during migration
- Requires monitoring both systems

### Strategy 2: Direct Migration

Disable CloudWatch and enable Prometheus stack in a single deployment.

**Pros:**
- Faster migration
- Lower ongoing costs
- Simpler architecture

**Cons:**
- Higher risk
- Potential monitoring gaps
- Requires thorough pre-validation

## Pre-Migration Checklist

Before starting the migration, ensure:

- [ ] EKS cluster has sufficient capacity for monitoring components
- [ ] Storage classes (gp3) are available and tested
- [ ] IAM roles and OIDC provider are properly configured
- [ ] Secrets Manager contains required credentials (MySQL, Redis, Grafana)
- [ ] Network policies allow Prometheus to scrape metrics
- [ ] Backup of existing CloudWatch dashboards and alarms
- [ ] Team trained on Prometheus/Grafana usage
- [ ] Runbooks updated for new monitoring stack

## Phase 1: Enable Hybrid Mode

### Step 1: Update Variables

Add to your `terraform.tfvars`:

```hcl
# Keep existing CloudWatch enabled
enable_cloudwatch        = true
install_cloudwatch_agent = true
install_fluent_bit       = true

# Enable Prometheus stack
enable_prometheus_stack = true
enable_grafana          = true
enable_alertmanager     = true

# Basic Prometheus configuration
prometheus_storage_size      = "100Gi"
prometheus_retention_days    = 30
prometheus_storage_class     = "gp3"
prometheus_replica_count     = 2

# Basic Grafana configuration
grafana_storage_size  = "20Gi"
grafana_storage_class = "gp3"
enable_aws_iam_auth   = true

# Basic AlertManager configuration
alertmanager_storage_size  = "10Gi"
alertmanager_replica_count = 2

# Enable service discovery
enable_service_discovery     = true
service_discovery_namespaces = ["wordpress", "kube-system"]

# Security features
enable_security_features = true
enable_tls_encryption    = true
enable_pii_scrubbing     = true
enable_audit_logging     = true
```

### Step 2: Plan and Apply

```bash
cd stacks/app
terraform plan -out=monitoring-migration.tfplan
# Review the plan carefully
terraform apply monitoring-migration.tfplan
```

### Step 3: Verify Deployment

Check that all monitoring components are running:

```bash
# Check namespace
kubectl get ns observability

# Check Prometheus
kubectl get pods -n observability -l app=prometheus
kubectl get pvc -n observability -l app=prometheus

# Check Grafana
kubectl get pods -n observability -l app=grafana
kubectl get pvc -n observability -l app=grafana

# Check AlertManager
kubectl get pods -n observability -l app=alertmanager
kubectl get pvc -n observability -l app=alertmanager
```

### Step 4: Verify Metrics Collection

Port-forward to Prometheus:

```bash
kubectl port-forward -n observability svc/prometheus-server 9090:9090
```

Visit http://localhost:9090/targets and verify:
- All targets are "UP"
- WordPress metrics are being scraped
- MySQL metrics are being scraped (if enabled)
- Redis metrics are being scraped (if enabled)
- Kubernetes metrics are being scraped

### Step 5: Access Grafana

Port-forward to Grafana:

```bash
kubectl port-forward -n observability svc/grafana 3000:80
```

Visit http://localhost:3000 and verify:
- Login works (use admin credentials)
- Default dashboards are loaded
- Data sources are configured
- Metrics are displaying correctly

## Phase 2: Enable Exporters

### Step 1: Enable WordPress Exporter

Add to `terraform.tfvars`:

```hcl
enable_wordpress_exporter = true
wordpress_namespace       = "wordpress"
```

Apply changes:

```bash
terraform apply
```

Verify WordPress metrics:

```bash
# Check WordPress pods have exporter sidecar
kubectl get pods -n wordpress -o jsonpath='{.items[*].spec.containers[*].name}'

# Should see both wordpress and wordpress-exporter containers
```

### Step 2: Enable MySQL Exporter

Create monitoring user in Aurora:

```sql
CREATE USER 'monitoring'@'%' IDENTIFIED BY 'secure-password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitoring'@'%';
FLUSH PRIVILEGES;
```

Store password in Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name mysql-monitoring-password \
  --secret-string "secure-password" \
  --region us-east-1
```

Add to `terraform.tfvars`:

```hcl
enable_mysql_exporter = true
mysql_connection_config = {
  host                = "aurora-cluster-endpoint.region.rds.amazonaws.com"
  port                = 3306
  username            = "monitoring"
  password_secret_ref = "arn:aws:secretsmanager:region:account:secret:mysql-monitoring-password"
  database            = "wordpress"
}
```

Apply and verify:

```bash
terraform apply
kubectl get pods -n observability -l app=mysql-exporter
```

### Step 3: Enable Redis Exporter

Add to `terraform.tfvars`:

```hcl
enable_redis_exporter = true
redis_connection_config = {
  host                = "redis-cluster.cache.amazonaws.com"
  port                = 6379
  password_secret_ref = "arn:aws:secretsmanager:region:account:secret:redis-auth-token"
  tls_enabled         = true
}
```

Apply and verify:

```bash
terraform apply
kubectl get pods -n observability -l app=redis-exporter
```

### Step 4: Enable Cost Monitoring

Add to `terraform.tfvars`:

```hcl
enable_cost_monitoring = true
cost_allocation_tags   = ["Environment", "Project", "Owner", "Component"]
```

Apply:

```bash
terraform apply
```

## Phase 3: Configure Alerting

### Step 1: Set Up Notification Channels

Create SNS topic for alerts:

```bash
aws sns create-topic --name monitoring-alerts --region us-east-1
aws sns subscribe \
  --topic-arn arn:aws:sns:region:account:monitoring-alerts \
  --protocol email \
  --notification-endpoint ops-team@example.com
```

Add to `terraform.tfvars`:

```hcl
sns_topic_arn = "arn:aws:sns:region:account:monitoring-alerts"

# Optional: Add Slack
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

# Optional: Add PagerDuty
pagerduty_integration_key = "your-pagerduty-integration-key"
```

### Step 2: Configure Alert Routing

Add to `terraform.tfvars`:

```hcl
alert_routing_config = {
  group_by        = ["alertname", "cluster", "service"]
  group_wait      = "10s"
  group_interval  = "10s"
  repeat_interval = "1h"
  routes = [
    {
      match = {
        severity = "critical"
      }
      match_re = {}
      receiver = "pagerduty"
      group_by = ["alertname"]
      continue = true
    },
    {
      match = {
        severity = "warning"
      }
      match_re = {}
      receiver = "slack"
      group_by = ["alertname", "service"]
      continue = false
    },
    {
      match = {}
      match_re = {}
      receiver = "email"
      group_by = ["alertname"]
      continue = false
    }
  ]
}
```

Apply:

```bash
terraform apply
```

### Step 3: Test Alerts

Trigger a test alert:

```bash
kubectl exec -n observability deployment/alertmanager -- \
  amtool alert add test_alert \
  --alertmanager.url=http://localhost:9093 \
  --annotation=summary="Test alert" \
  --annotation=description="This is a test alert"
```

Verify alert is received via configured channels.

## Phase 4: Validation Period

Run both systems in parallel for at least 2 weeks:

### Week 1: Validation
- [ ] Compare metrics between CloudWatch and Prometheus
- [ ] Verify all critical alerts are firing in both systems
- [ ] Test dashboard functionality in Grafana
- [ ] Validate exporter metrics accuracy
- [ ] Check storage usage and performance
- [ ] Review alert routing and notifications

### Week 2: Optimization
- [ ] Tune resource requests/limits
- [ ] Adjust retention periods
- [ ] Optimize service discovery
- [ ] Fine-tune alert thresholds
- [ ] Update runbooks for new system
- [ ] Train team on Prometheus/Grafana

## Phase 5: Disable CloudWatch (Optional)

Once validated, you can disable CloudWatch monitoring:

### Step 1: Update Variables

Modify `terraform.tfvars`:

```hcl
# Disable CloudWatch
enable_cloudwatch        = false
install_cloudwatch_agent = false
install_fluent_bit       = false

# Keep Prometheus stack enabled
enable_prometheus_stack = true
enable_grafana          = true
enable_alertmanager     = true
```

### Step 2: Plan and Apply

```bash
terraform plan -out=disable-cloudwatch.tfplan
# Review carefully - this will remove CloudWatch components
terraform apply disable-cloudwatch.tfplan
```

### Step 3: Verify

```bash
# CloudWatch components should be removed
kubectl get pods -n observability

# Only Prometheus stack components should remain
```

### Step 4: Clean Up CloudWatch Resources

Optionally delete CloudWatch log groups:

```bash
aws logs delete-log-group --log-group-name /aws/eks/cluster-name/application
aws logs delete-log-group --log-group-name /aws/eks/cluster-name/dataplane
aws logs delete-log-group --log-group-name /aws/eks/cluster-name/host
```

## Rollback Procedures

### Rollback from Hybrid to CloudWatch Only

If issues are encountered, disable Prometheus stack:

```hcl
enable_cloudwatch       = true
enable_prometheus_stack = false
enable_grafana          = false
enable_alertmanager     = false
```

Apply:

```bash
terraform apply
```

### Rollback from Prometheus Only to Hybrid

Re-enable CloudWatch:

```hcl
enable_cloudwatch       = true
enable_prometheus_stack = true
```

Apply:

```bash
terraform apply
```

## Troubleshooting

### Prometheus Not Starting

Check PVC status:

```bash
kubectl get pvc -n observability
kubectl describe pvc prometheus-storage -n observability
```

Check pod logs:

```bash
kubectl logs -n observability deployment/prometheus-server
```

### Grafana Not Accessible

Check service:

```bash
kubectl get svc -n observability grafana
kubectl describe svc grafana -n observability
```

Check pod status:

```bash
kubectl get pods -n observability -l app=grafana
kubectl logs -n observability deployment/grafana
```

### Metrics Not Appearing

Check ServiceMonitor resources:

```bash
kubectl get servicemonitors -n observability
kubectl describe servicemonitor wordpress -n observability
```

Check Prometheus targets:

```bash
kubectl port-forward -n observability svc/prometheus-server 9090:9090
# Visit http://localhost:9090/targets
```

### Alerts Not Firing

Check AlertManager configuration:

```bash
kubectl get configmap -n observability alertmanager-config -o yaml
```

Check AlertManager status:

```bash
kubectl port-forward -n observability svc/alertmanager 9093:9093
# Visit http://localhost:9093/#/status
```

## Post-Migration Tasks

After successful migration:

1. **Update Documentation**
   - Update runbooks with new monitoring procedures
   - Document new alert response procedures
   - Update architecture diagrams

2. **Team Training**
   - Train team on Prometheus query language (PromQL)
   - Train team on Grafana dashboard creation
   - Train team on AlertManager configuration

3. **Optimize Configuration**
   - Right-size resource allocations
   - Tune retention periods
   - Optimize service discovery
   - Fine-tune alert thresholds

4. **Clean Up**
   - Remove old CloudWatch dashboards (if migrated fully)
   - Delete unused CloudWatch alarms
   - Clean up old log groups

## Cost Comparison

### CloudWatch Only
- CloudWatch Logs: ~$0.50/GB ingested + $0.03/GB stored
- CloudWatch Metrics: ~$0.30/metric/month
- CloudWatch Alarms: ~$0.10/alarm/month

### Prometheus Stack
- EBS Storage (gp3): ~$0.08/GB/month
- EC2 Compute: Included in EKS node costs
- Data Transfer: Minimal (internal cluster traffic)

### Typical Savings
For a medium-sized deployment:
- CloudWatch: ~$500-800/month
- Prometheus: ~$100-200/month (storage + compute)
- **Potential savings: 60-75%**

## Support

For issues during migration:
- Check [Enhanced Monitoring Guide](./README.md)
- Review [Troubleshooting Runbook](../../runbook.md)
- Review [Operations Troubleshooting](../../operations/troubleshooting.md)
- Contact platform team
