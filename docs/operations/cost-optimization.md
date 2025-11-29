# Cost Optimization and Monitoring

## Overview

This guide covers cost monitoring, optimization strategies, and budget management for the WordPress EKS platform. The platform includes built-in cost tracking through AWS Budgets, CloudWatch metrics, and Prometheus exporters that provide visibility into spending across compute, storage, database, and networking resources.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Access to AWS Cost Explorer and Billing Console
- Terraform Cloud access for infrastructure changes
- kubectl access to the EKS cluster
- Understanding of AWS pricing models

## Cost Monitoring Architecture

### Cost Tracking Components

| Component | Purpose | Metrics Source | Update Frequency |
|-----------|---------|----------------|------------------|
| AWS Budgets | Spending alerts and forecasts | AWS Cost Explorer | Daily |
| Cost Exporter | Prometheus metrics for costs | AWS Cost Explorer API | Hourly |
| CloudWatch Metrics | Resource utilization | AWS CloudWatch | 1-5 minutes |
| Grafana Dashboard | Cost visualization | Prometheus + CloudWatch | Real-time |

### Cost Allocation Tags

All resources are tagged for cost tracking:

```hcl
tags = {
  Project     = "wordpress-eks"
  Environment = "production"
  Owner       = "platform-team@example.com"
  ManagedBy   = "Terraform"
  Component   = "compute|database|storage|networking"
}
```

## AWS Budgets Configuration

### Budget Setup

Configure spending alerts and forecasts:

```hcl
module "cost_budgets" {
  source = "../../modules/cost-budgets"
  
  name                        = "${var.project}-${var.env}-budget"
  limit_amount                = 1000  # Monthly budget in USD
  currency                    = "USD"
  time_unit                   = "MONTHLY"
  
  # Alert thresholds
  forecast_threshold_percent  = 80    # Alert at 80% forecasted
  actual_threshold_percent    = 90    # Alert at 90% actual
  
  # Notification settings
  alert_emails                = ["ops-team@example.com"]
  create_sns_topic            = true
  sns_subscription_emails     = ["finance@example.com"]
  
  tags = var.tags
}
```

### Budget Alerts

**Forecasted Alerts**: Triggered when projected spending exceeds threshold
- **80% threshold**: Warning notification
- Sent to operations team
- Allows proactive cost management

**Actual Alerts**: Triggered when actual spending exceeds threshold
- **90% threshold**: Critical notification
- Sent to operations and finance teams
- Requires immediate action

### Check Budget Status

```bash
# List all budgets
aws budgets describe-budgets \
  --account-id <account-id>

# Get specific budget details
aws budgets describe-budget \
  --account-id <account-id> \
  --budget-name <budget-name>

# Check budget performance
aws budgets describe-budget-performance \
  --account-id <account-id> \
  --budget-name <budget-name>
```

## Cost Monitoring with Prometheus

### Cost Exporter

The cost exporter collects AWS cost data and exposes it as Prometheus metrics:

**Configuration**:
```hcl
enable_cost_monitoring = true
cost_allocation_tags   = ["Environment", "Project", "Owner", "Component", "Service"]
```

**Metrics Exposed**:
- `aws_cost_daily_total`: Total daily cost
- `aws_cost_by_service`: Cost breakdown by AWS service
- `aws_cost_by_tag`: Cost breakdown by allocation tags
- `aws_cost_forecast`: Forecasted monthly cost

**Query Examples**:
```promql
# Total daily cost
sum(aws_cost_daily_total)

# Cost by service
sum by (service) (aws_cost_by_service)

# Cost by environment
sum by (environment) (aws_cost_by_tag{tag="Environment"})

# Month-to-date spending
sum_over_time(aws_cost_daily_total[30d])
```

### Grafana Cost Dashboard

Access the cost tracking dashboard:

```bash
# Port-forward to Grafana
kubectl port-forward -n observability svc/grafana 3000:3000

# Navigate to: http://localhost:3000/d/cost-tracking
```

**Dashboard Panels**:
- Daily cost trend
- Cost by service (pie chart)
- Cost by component (bar chart)
- Month-to-date vs budget
- Cost forecast
- Top 10 expensive resources

## Cost Breakdown by Service

### Compute Costs (EKS)

**Components**:
- EKS control plane: $0.10/hour (~$73/month)
- EC2 worker nodes: Variable based on instance types
- Karpenter spot instances: 60-90% discount vs on-demand
- Data transfer: Cross-AZ and internet egress

**Optimization Strategies**:

1. **Use Spot Instances with Karpenter**:
```hcl
# Karpenter NodePool configuration
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot", "on-demand"]
  - key: kubernetes.io/arch
    operator: In
    values: ["amd64"]
```

2. **Right-size Node Groups**:
```bash
# Analyze node utilization
kubectl top nodes

# Check pod resource requests vs usage
kubectl top pods --all-namespaces
```

3. **Enable Cluster Autoscaling**:
- Karpenter automatically scales based on pending pods
- Consolidation removes underutilized nodes
- Spot instance diversification reduces interruptions

4. **Use Graviton Instances**:
```hcl
# ARM-based instances for 20% cost savings
instance_types = ["t4g.medium", "t4g.large"]
```

**Cost Monitoring**:
```bash
# Check EC2 instance costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://ec2-filter.json

# ec2-filter.json
{
  "Dimensions": {
    "Key": "SERVICE",
    "Values": ["Amazon Elastic Compute Cloud - Compute"]
  }
}
```

### Database Costs (Aurora)

**Components**:
- Aurora Serverless v2 ACUs: $0.12/ACU-hour
- Storage: $0.10/GB-month
- I/O operations: $0.20/million requests
- Backup storage: $0.021/GB-month
- Data transfer: Cross-AZ and internet egress

**Optimization Strategies**:

1. **Right-size ACU Range**:
```hcl
serverlessv2_scaling_configuration {
  min_capacity = 0.5  # Start small
  max_capacity = 16   # Set realistic max
}
```

2. **Optimize Backup Retention**:
```hcl
backup_retention_days = 7  # Reduce from 30 if acceptable
```

3. **Monitor I/O Operations**:
```bash
# Check Aurora I/O metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name VolumeReadIOPs \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-name> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 3600 \
  --statistics Average
```

4. **Use Query Caching**:
- Enable Redis for query result caching
- Reduces database load and I/O costs

**Cost Monitoring**:
```promql
# Aurora ACU usage
aws_rds_serverless_database_capacity{db_cluster_identifier="<cluster>"}

# Storage growth
aws_rds_database_storage_used_bytes{db_cluster_identifier="<cluster>"}
```

### Storage Costs (EFS)

**Components**:
- Standard storage: $0.30/GB-month
- Infrequent Access: $0.025/GB-month
- Throughput: $6.00/MB/s-month (provisioned)
- Data transfer: Cross-AZ

**Optimization Strategies**:

1. **Enable Lifecycle Management**:
```hcl
lifecycle_policy = {
  transition_to_ia = "AFTER_30_DAYS"
}
```

2. **Use Bursting Throughput**:
- Default mode scales with storage size
- Avoid provisioned throughput unless needed

3. **Monitor Storage Growth**:
```bash
# Check EFS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name StorageBytes \
  --dimensions Name=FileSystemId,Value=<fs-id> Name=StorageClass,Value=Total \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Average
```

4. **Clean Up Unused Files**:
```bash
# Find large files
kubectl exec -n wordpress <pod> -- \
  find /var/www/html/wp-content -type f -size +100M

# Find old files
kubectl exec -n wordpress <pod> -- \
  find /var/www/html/wp-content -type f -mtime +365
```

**Cost Monitoring**:
```promql
# EFS storage usage
aws_efs_storage_bytes{file_system_id="<fs-id>"}

# Storage by class
aws_efs_storage_bytes{storage_class="Standard"}
aws_efs_storage_bytes{storage_class="InfrequentAccess"}
```

### Cache Costs (ElastiCache Redis)

**Components**:
- Node hours: Variable by instance type
- Backup storage: $0.085/GB-month
- Data transfer: Cross-AZ

**Optimization Strategies**:

1. **Right-size Node Type**:
```hcl
node_type = "cache.t4g.micro"  # Start small, scale up if needed
```

2. **Use Graviton Instances**:
```hcl
node_type = "cache.t4g.medium"  # 20% cost savings vs t3
```

3. **Optimize Backup Retention**:
```hcl
snapshot_retention_limit = 5  # Reduce if acceptable
```

4. **Monitor Cache Hit Rate**:
```bash
# Check cache efficiency
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CacheHitRate \
  --dimensions Name=CacheClusterId,Value=<cluster-id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 3600 \
  --statistics Average
```

**Cost Monitoring**:
```promql
# Redis memory usage
redis_memory_used_bytes{cluster="<cluster>"}

# Cache hit rate
redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total)
```

### Networking Costs

**Components**:
- NAT Gateway: $0.045/hour + $0.045/GB processed
- Application Load Balancer: $0.0225/hour + $0.008/LCU-hour
- Data transfer: Cross-AZ ($0.01/GB), Internet egress ($0.09/GB)
- VPC endpoints: $0.01/hour per AZ

**Optimization Strategies**:

1. **Minimize Cross-AZ Traffic**:
- Use topology-aware routing
- Co-locate pods with data sources

2. **Optimize NAT Gateway Usage**:
```hcl
# Use single NAT gateway for dev/staging
enable_nat_gateway     = true
single_nat_gateway     = true  # Cost savings for non-prod
one_nat_gateway_per_az = false
```

3. **Use VPC Endpoints**:
```hcl
# Avoid NAT gateway charges for AWS services
enable_s3_endpoint       = true
enable_dynamodb_endpoint = true
```

4. **Monitor Data Transfer**:
```bash
# Check data transfer costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --filter file://data-transfer-filter.json
```

**Cost Monitoring**:
```promql
# NAT gateway data processed
aws_nat_gateway_bytes_out_to_destination{nat_gateway_id="<nat-gw>"}

# ALB request count
aws_alb_request_count{load_balancer="<alb>"}
```

### Monitoring Stack Costs

**Components**:
- EBS volumes: $0.08/GB-month (gp3)
- Backup storage: $0.05/GB-month
- CloudWatch Logs: $0.50/GB ingested, $0.03/GB stored
- Data transfer: Cross-AZ

**Optimization Strategies**:

1. **Right-size Storage**:
```hcl
prometheus_storage_size = "50Gi"  # Start smaller, expand if needed
grafana_storage_size    = "10Gi"
```

2. **Optimize Retention**:
```hcl
prometheus_retention_days = 15  # Reduce from 30 if acceptable
cw_retention_days        = 7   # Reduce CloudWatch retention
```

3. **Use gp3 Volumes**:
```hcl
prometheus_storage_class = "gp3"  # 20% cheaper than gp2
```

4. **Reduce Log Verbosity**:
```yaml
# Fluent Bit configuration
filters:
  - name: grep
    match: "*"
    exclude: log level=debug
```

**Cost Monitoring**:
```bash
# Check EBS costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://ebs-filter.json
```

## Cost Optimization Recommendations

### Quick Wins (Immediate Impact)

1. **Enable Spot Instances**: 60-90% savings on compute
2. **Right-size Databases**: Adjust ACU min/max based on actual usage
3. **Reduce Backup Retention**: Balance cost vs compliance
4. **Use Single NAT Gateway**: For non-production environments
5. **Enable EFS Lifecycle**: Move old files to Infrequent Access

### Medium-term Optimizations

1. **Migrate to Graviton**: 20% cost savings on compute
2. **Implement Caching**: Reduce database load and costs
3. **Optimize Storage**: Clean up unused files and snapshots
4. **Review Reserved Instances**: For predictable workloads
5. **Consolidate Environments**: Reduce infrastructure duplication

### Long-term Strategies

1. **Implement FinOps Culture**: Regular cost reviews
2. **Automate Scaling**: Karpenter for compute, Aurora Serverless for database
3. **Use Savings Plans**: Commit to usage for discounts
4. **Optimize Architecture**: Serverless where appropriate
5. **Monitor Continuously**: Set up cost anomaly detection

## Cost Anomaly Detection

### CloudWatch Alarms

Set up alarms for unexpected cost increases:

```bash
# Create cost anomaly alarm
aws cloudwatch put-metric-alarm \
  --alarm-name high-daily-cost \
  --alarm-description "Alert when daily cost exceeds threshold" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=Currency,Value=USD
```

### Prometheus Alerts

Configure alerts for cost metrics:

```yaml
groups:
  - name: cost-alerts
    rules:
      - alert: HighDailyCost
        expr: aws_cost_daily_total > 100
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Daily cost exceeds $100"
          description: "Current daily cost: ${{ $value }}"
      
      - alert: CostForecastExceeded
        expr: aws_cost_forecast > 3000
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "Monthly forecast exceeds budget"
          description: "Forecasted cost: ${{ $value }}"
```

## Cost Reporting

### Monthly Cost Report

Generate monthly cost breakdown:

```bash
# Get cost by service
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Get cost by tag
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Component
```

### Cost Allocation Report

Enable cost allocation tags:

```bash
# Activate cost allocation tags
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status \
    TagKey=Environment,Status=Active \
    TagKey=Project,Status=Active \
    TagKey=Component,Status=Active
```

### Grafana Reports

Schedule automated cost reports:

1. Create dashboard with cost panels
2. Configure report schedule (weekly/monthly)
3. Set up email distribution list
4. Include cost trends and forecasts

## Troubleshooting

### Budget Alerts Not Triggering

**Symptom**: No notifications despite exceeding threshold

**Diagnosis**:
```bash
# Check budget configuration
aws budgets describe-budget \
  --account-id <account-id> \
  --budget-name <budget-name>

# Check SNS topic subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn <topic-arn>
```

**Solutions**:
- Verify email subscriptions are confirmed
- Check SNS topic policy allows AWS Budgets
- Ensure budget thresholds are correctly configured

### Cost Exporter Not Collecting Data

**Symptom**: Missing cost metrics in Prometheus

**Diagnosis**:
```bash
# Check exporter pod status
kubectl get pods -n observability -l app=cost-exporter

# Check exporter logs
kubectl logs -n observability -l app=cost-exporter
```

**Solutions**:
- Verify IAM permissions for Cost Explorer API
- Check API rate limits
- Ensure cost allocation tags are activated

### Unexpected Cost Increases

**Symptom**: Sudden spike in costs

**Diagnosis**:
```bash
# Check cost anomalies
aws ce get-anomalies \
  --date-interval Start=2024-01-01,End=2024-01-31

# Analyze cost by service
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE
```

**Common Causes**:
- Unintended resource scaling
- Data transfer spikes
- Backup storage growth
- Unused resources not cleaned up

## Best Practices

1. **Tag Everything**: Consistent tagging enables cost allocation
2. **Monitor Continuously**: Set up dashboards and alerts
3. **Review Regularly**: Monthly cost reviews with stakeholders
4. **Right-size Resources**: Match capacity to actual usage
5. **Use Automation**: Karpenter, Aurora Serverless, lifecycle policies
6. **Implement Budgets**: Set spending limits and alerts
7. **Optimize Storage**: Clean up unused data regularly
8. **Leverage Spot**: Use spot instances where possible
9. **Plan Capacity**: Use Reserved Instances or Savings Plans for predictable workloads
10. **Document Changes**: Track cost impact of infrastructure changes

## Cost Optimization Checklist

### Weekly Tasks
- [ ] Review cost dashboard for anomalies
- [ ] Check budget status
- [ ] Monitor resource utilization

### Monthly Tasks
- [ ] Generate cost report by service
- [ ] Review and optimize underutilized resources
- [ ] Analyze cost trends
- [ ] Update budget forecasts
- [ ] Clean up unused snapshots and backups

### Quarterly Tasks
- [ ] Comprehensive cost review with stakeholders
- [ ] Evaluate Reserved Instance opportunities
- [ ] Review and optimize architecture
- [ ] Update cost allocation tags
- [ ] Test cost optimization strategies

## Related Documentation

- [Architecture Overview](../architecture.md)
- [Observability Module](../modules/observability.md)
- [Data Services Module](../modules/data-services.md)
- [Backup and Restore](./backup-restore.md)
- [Troubleshooting Guide](./troubleshooting.md)

## References

- [AWS Cost Management](https://aws.amazon.com/aws-cost-management/)
- [AWS Budgets](https://aws.amazon.com/aws-cost-management/aws-budgets/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)
- [EKS Best Practices - Cost Optimization](https://aws.github.io/aws-eks-best-practices/cost_optimization/)
- [Karpenter Cost Optimization](https://karpenter.sh/docs/concepts/scheduling/)
