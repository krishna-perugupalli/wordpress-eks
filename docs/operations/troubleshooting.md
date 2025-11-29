# Troubleshooting Guide

## Overview

This guide consolidates common issues, diagnostic procedures, and solutions for the WordPress EKS platform. It covers application, infrastructure, monitoring, and operational problems with step-by-step troubleshooting workflows.

## Prerequisites

- kubectl access to the EKS cluster
- AWS CLI configured with appropriate credentials
- Access to Terraform Cloud workspaces
- Access to CloudWatch Logs and metrics
- Understanding of Kubernetes and AWS services

## Quick Diagnostic Commands

### Cluster Health Check

```bash
# Check cluster status
aws eks describe-cluster --name <cluster-name> --query 'cluster.status'

# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check all pods across namespaces
kubectl get pods --all-namespaces | grep -v Running
```

### Application Health Check

```bash
# Check WordPress deployment
kubectl get deployment -n wordpress

# Check WordPress pods
kubectl get pods -n wordpress

# Check services and endpoints
kubectl get svc,endpoints -n wordpress

# Check ingress/ALB
kubectl get ingress -n wordpress
kubectl get targetgroupbinding -n wordpress
```

### Infrastructure Health Check

```bash
# Check Aurora status
aws rds describe-db-clusters \
  --db-cluster-identifier <cluster-name> \
  --query 'DBClusters[0].Status'

# Check EFS status
aws efs describe-file-systems \
  --file-system-id <fs-id> \
  --query 'FileSystems[0].LifeCycleState'

# Check Redis status
aws elasticache describe-replication-groups \
  --replication-group-id <group-id> \
  --query 'ReplicationGroups[0].Status'
```

## Application Issues

### WordPress Not Serving Traffic

**Symptoms**:
- HTTP 503 Service Unavailable
- Connection timeout
- ALB health checks failing

**Diagnostic Steps**:

1. **Check Pod Status**:
```bash
kubectl get pods -n wordpress
kubectl describe pod -n wordpress <pod-name>
kubectl logs -n wordpress <pod-name>
```

2. **Check Service and Endpoints**:
```bash
kubectl get svc -n wordpress
kubectl get endpoints -n wordpress
```

3. **Check TargetGroupBinding**:
```bash
kubectl get targetgroupbinding -n wordpress
kubectl describe targetgroupbinding -n wordpress <tgb-name>
```

4. **Check ALB Target Health**:
```bash
# Get target group ARN from TargetGroupBinding
TG_ARN=$(kubectl get targetgroupbinding -n wordpress <tgb-name> -o jsonpath='{.spec.targetGroupARN}')

# Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

**Common Causes and Solutions**:

| Cause | Symptoms | Solution |
|-------|----------|----------|
| Pod not ready | Pod in CrashLoopBackOff | Check logs, verify database connectivity |
| Database connection failed | Connection refused errors | Verify Aurora endpoint, check secrets |
| EFS mount failed | Pod stuck in ContainerCreating | Check EFS mount targets, security groups |
| Security group misconfiguration | Targets unhealthy | Verify ALB → node security group rules |
| AWS Load Balancer Controller down | TargetGroupBinding not working | Restart controller deployment |

**Resolution Steps**:

```bash
# Restart WordPress deployment
kubectl rollout restart deployment -n wordpress wordpress

# Restart AWS Load Balancer Controller
kubectl rollout restart deployment -n kube-system aws-load-balancer-controller

# Force pod recreation
kubectl delete pod -n wordpress <pod-name>

# Check events for errors
kubectl get events -n wordpress --sort-by='.lastTimestamp'
```

### WordPress Pods Crashing

**Symptoms**:
- Pods in CrashLoopBackOff state
- Frequent pod restarts
- Application errors in logs

**Diagnostic Steps**:

1. **Check Pod Logs**:
```bash
# Current logs
kubectl logs -n wordpress <pod-name>

# Previous container logs
kubectl logs -n wordpress <pod-name> --previous

# Follow logs
kubectl logs -n wordpress <pod-name> -f
```

2. **Check Pod Events**:
```bash
kubectl describe pod -n wordpress <pod-name>
```

3. **Check Resource Limits**:
```bash
kubectl top pod -n wordpress
kubectl describe pod -n wordpress <pod-name> | grep -A 5 "Limits"
```

**Common Causes and Solutions**:

| Cause | Log Indicators | Solution |
|-------|----------------|----------|
| Database connection failed | "Error establishing database connection" | Verify Aurora endpoint, check credentials |
| Out of memory | OOMKilled status | Increase memory limits |
| Missing secrets | "Secret not found" | Check ExternalSecret status |
| File permissions | "Permission denied" | Check EFS permissions, pod security context |
| PHP errors | Fatal error messages | Check WordPress configuration, plugins |

**Resolution Steps**:

```bash
# Check database connectivity
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -- \
  mysql -h <aurora-endpoint> -u <username> -p

# Check EFS mount
kubectl exec -n wordpress <pod-name> -- ls -la /var/www/html/wp-content

# Increase resource limits
kubectl patch deployment -n wordpress wordpress -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "wordpress",
          "resources": {
            "limits": {
              "memory": "2Gi"
            }
          }
        }]
      }
    }
  }
}'
```

### Slow WordPress Performance

**Symptoms**:
- High page load times
- Slow admin dashboard
- Database query timeouts

**Diagnostic Steps**:

1. **Check Resource Utilization**:
```bash
kubectl top pods -n wordpress
kubectl top nodes
```

2. **Check Database Performance**:
```bash
# Aurora CPU utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Database connections
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

3. **Check Redis Cache**:
```bash
# Redis memory usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name BytesUsedForCache \
  --dimensions Name=CacheClusterId,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# Cache hit rate
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name CacheHitRate \
  --dimensions Name=CacheClusterId,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Common Causes and Solutions**:

| Cause | Indicators | Solution |
|-------|-----------|----------|
| Database overload | High CPU, many connections | Scale Aurora ACUs, optimize queries |
| Cache not working | Low cache hit rate | Verify Redis connectivity, check WordPress cache plugin |
| Insufficient resources | High pod CPU/memory | Scale deployment, increase limits |
| Slow EFS | High latency | Check EFS throughput mode, consider provisioned throughput |
| Unoptimized queries | Slow query logs | Enable slow query log, optimize database |

**Resolution Steps**:

```bash
# Scale WordPress deployment
kubectl scale deployment -n wordpress wordpress --replicas=5

# Increase Aurora capacity
# Update Terraform configuration:
# serverless_max_acu = 32
# Then apply changes

# Enable WordPress debug mode
kubectl exec -n wordpress <pod-name> -- \
  wp config set WP_DEBUG true --raw

# Check slow queries
kubectl exec -n wordpress <pod-name> -- \
  wp db query "SHOW FULL PROCESSLIST"
```

## Infrastructure Issues

### Aurora Database Issues

**Connection Failures**:

**Symptoms**: "Error establishing database connection"

**Diagnostic Steps**:
```bash
# Check cluster status
aws rds describe-db-clusters \
  --db-cluster-identifier <cluster-name>

# Check security groups
aws ec2 describe-security-groups \
  --group-ids <db-sg-id>

# Test connectivity from pod
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -- \
  mysql -h <aurora-endpoint> -u <username> -p
```

**Solutions**:
- Verify security group allows traffic from EKS nodes
- Check Aurora endpoint in Secrets Manager
- Verify credentials are correct
- Ensure Aurora is in available state

**High CPU Usage**:

**Symptoms**: Slow queries, connection timeouts

**Diagnostic Steps**:
```bash
# Check CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Check current queries
kubectl exec -n wordpress <pod-name> -- \
  wp db query "SHOW FULL PROCESSLIST"
```

**Solutions**:
- Increase Aurora Serverless max ACUs
- Optimize slow queries
- Enable query caching with Redis
- Review database indexes

**Storage Full**:

**Symptoms**: Write errors, application failures

**Diagnostic Steps**:
```bash
# Check storage usage
aws rds describe-db-clusters \
  --db-cluster-identifier <cluster-name> \
  --query 'DBClusters[0].AllocatedStorage'
```

**Solutions**:
- Aurora automatically scales storage
- Clean up old data if needed
- Review backup retention settings

### EFS Issues

**Mount Failures**:

**Symptoms**: Pods stuck in ContainerCreating

**Diagnostic Steps**:
```bash
# Check pod events
kubectl describe pod -n wordpress <pod-name>

# Check EFS status
aws efs describe-file-systems --file-system-id <fs-id>

# Check mount targets
aws efs describe-mount-targets --file-system-id <fs-id>

# Check security groups
aws ec2 describe-security-groups --group-ids <efs-sg-id>
```

**Solutions**:
- Verify EFS mount targets exist in all AZs
- Check security group allows NFS (port 2049) from nodes
- Ensure EFS CSI driver is running
- Verify PVC and PV are bound

**Slow Performance**:

**Symptoms**: High latency, slow file operations

**Diagnostic Steps**:
```bash
# Check EFS metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EFS \
  --metric-name TotalIOBytes \
  --dimensions Name=FileSystemId,Value=<fs-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Check throughput mode
aws efs describe-file-systems \
  --file-system-id <fs-id> \
  --query 'FileSystems[0].ThroughputMode'
```

**Solutions**:
- Switch to provisioned throughput if needed
- Enable lifecycle management to move old files to IA
- Optimize file access patterns
- Consider using EBS for high-performance workloads

### Redis Cache Issues

**Connection Failures**:

**Symptoms**: Cache errors in WordPress logs

**Diagnostic Steps**:
```bash
# Check Redis status
aws elasticache describe-replication-groups \
  --replication-group-id <group-id>

# Test connectivity
kubectl run -it --rm redis-test --image=redis:7 --restart=Never -- \
  redis-cli -h <redis-endpoint> -p 6379 --tls --askpass ping
```

**Solutions**:
- Verify security group allows traffic from nodes
- Check AUTH token in Secrets Manager
- Ensure TLS is enabled in WordPress plugin
- Verify Redis endpoint is correct

**High Memory Usage**:

**Symptoms**: Evictions, cache misses

**Diagnostic Steps**:
```bash
# Check memory metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name DatabaseMemoryUsagePercentage \
  --dimensions Name=CacheClusterId,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Check evictions
aws cloudwatch get-metric-statistics \
  --namespace AWS/ElastiCache \
  --metric-name Evictions \
  --dimensions Name=CacheClusterId,Value=<cluster-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

**Solutions**:
- Increase node type size
- Adjust maxmemory-policy
- Review cache TTL settings
- Clean up unused keys

## Kubernetes Issues

### Node Issues

**Node Not Ready**:

**Symptoms**: Pods not scheduling, node in NotReady state

**Diagnostic Steps**:
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node conditions
kubectl get node <node-name> -o jsonpath='{.status.conditions}'

# Check kubelet logs
aws ssm start-session --target <instance-id>
sudo journalctl -u kubelet -f
```

**Solutions**:
- Check node resource pressure (disk, memory, PID)
- Verify VPC CNI is functioning
- Check security groups allow node communication
- Restart kubelet if needed
- Terminate and replace node if unrecoverable

**Insufficient Resources**:

**Symptoms**: Pods in Pending state

**Diagnostic Steps**:
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter
```

**Solutions**:
- Karpenter will automatically provision new nodes
- Check Karpenter NodePool configuration
- Verify EC2 instance limits not exceeded
- Review pod resource requests

### Networking Issues

**Pod-to-Pod Communication Failures**:

**Symptoms**: Connection timeouts between pods

**Diagnostic Steps**:
```bash
# Test connectivity
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  curl http://<service-name>.<namespace>.svc.cluster.local

# Check network policies
kubectl get networkpolicy --all-namespaces

# Check VPC CNI
kubectl get pods -n kube-system -l k8s-app=aws-node
kubectl logs -n kube-system -l k8s-app=aws-node
```

**Solutions**:
- Verify network policies allow traffic
- Check VPC CNI is healthy
- Ensure security groups allow pod communication
- Verify CoreDNS is functioning

**DNS Resolution Failures**:

**Symptoms**: "Name or service not known" errors

**Diagnostic Steps**:
```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- \
  nslookup kubernetes.default.svc.cluster.local
```

**Solutions**:
- Restart CoreDNS pods
- Check CoreDNS ConfigMap
- Verify VPC DNS settings
- Check for DNS throttling

### Storage Issues

**PVC Not Binding**:

**Symptoms**: PVC in Pending state

**Diagnostic Steps**:
```bash
# Check PVC status
kubectl get pvc -n <namespace>
kubectl describe pvc -n <namespace> <pvc-name>

# Check storage class
kubectl get storageclass

# Check CSI driver
kubectl get pods -n kube-system | grep csi
```

**Solutions**:
- Verify storage class exists
- Check CSI driver is running
- Ensure IAM permissions for CSI driver
- Verify EBS/EFS resources are available

## Monitoring Issues

### Prometheus Not Collecting Metrics

**Symptoms**: Missing metrics, gaps in dashboards

**Diagnostic Steps**:
```bash
# Check Prometheus pods
kubectl get pods -n observability -l app=kube-prometheus-stack-prometheus

# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Navigate to http://localhost:9090/targets

# Check Prometheus logs
kubectl logs -n observability -l app=kube-prometheus-stack-prometheus
```

**Solutions**:
- Verify service discovery is working
- Check network policies allow scraping
- Ensure targets are healthy
- Review Prometheus configuration

### Grafana Not Accessible

**Symptoms**: Cannot access Grafana UI

**Diagnostic Steps**:
```bash
# Check Grafana pods
kubectl get pods -n observability -l app.kubernetes.io/name=grafana

# Check Grafana service
kubectl get svc -n observability grafana

# Check Grafana logs
kubectl logs -n observability -l app.kubernetes.io/name=grafana
```

**Solutions**:
- Verify Grafana pod is running
- Check service and ingress configuration
- Verify admin password in secrets
- Restart Grafana pod if needed

### AlertManager Not Sending Alerts

**Symptoms**: No alert notifications received

**Diagnostic Steps**:
```bash
# Check AlertManager pods
kubectl get pods -n observability -l app=alertmanager

# Check AlertManager configuration
kubectl get secret -n observability alertmanager-<name>-alertmanager -o yaml

# Check AlertManager logs
kubectl logs -n observability -l app=alertmanager
```

**Solutions**:
- Verify notification channel configuration
- Check SNS topic permissions
- Test notification channels manually
- Review alert routing rules

## Terraform Issues

### Apply Failures

**Symptoms**: Terraform apply fails with errors

**Diagnostic Steps**:
```bash
# Check Terraform Cloud run logs
# Review error messages in TFC UI

# Validate locally
cd stacks/infra  # or stacks/app
terraform init
terraform validate
terraform plan
```

**Common Causes and Solutions**:

| Error | Cause | Solution |
|-------|-------|----------|
| Resource already exists | Duplicate resource | Import existing resource or remove from state |
| Permission denied | IAM permissions | Verify IAM role has required permissions |
| Timeout | Long-running operation | Increase timeout, check resource status |
| Dependency error | Missing dependency | Ensure infra stack applied first |
| State lock | Concurrent operations | Wait for lock release or force unlock |

### State Drift

**Symptoms**: Terraform detects changes not in code

**Diagnostic Steps**:
```bash
# Check for drift
terraform plan

# Refresh state
terraform refresh

# Show state
terraform show
```

**Solutions**:
- Review manual changes made outside Terraform
- Import resources into state if needed
- Update Terraform code to match reality
- Use `terraform apply` to reconcile

## Security Issues

### Secrets Not Available

**Symptoms**: Pods cannot access secrets

**Diagnostic Steps**:
```bash
# Check ExternalSecret status
kubectl get externalsecret -n <namespace>
kubectl describe externalsecret -n <namespace> <secret-name>

# Check External Secrets Operator
kubectl get pods -n external-secrets-operator

# Check AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id <secret-name>
```

**Solutions**:
- Verify ESO is running
- Check IRSA permissions for ESO
- Ensure secret exists in Secrets Manager
- Verify ClusterSecretStore configuration

### Certificate Issues

**Symptoms**: TLS errors, certificate warnings

**Diagnostic Steps**:
```bash
# Check certificate status
kubectl get certificate -n <namespace>
kubectl describe certificate -n <namespace> <cert-name>

# Check cert-manager
kubectl get pods -n cert-manager

# Check certificate details
kubectl get secret -n <namespace> <cert-secret> -o yaml
```

**Solutions**:
- Verify cert-manager is running
- Check ClusterIssuer configuration
- Ensure DNS validation records exist
- Review certificate request logs

## Performance Issues

### High Latency

**Symptoms**: Slow response times

**Diagnostic Steps**:
```bash
# Check ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=<alb-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum

# Check pod metrics
kubectl top pods -n wordpress

# Check database latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name ReadLatency \
  --dimensions Name=DBClusterIdentifier,Value=<cluster-name> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Solutions**:
- Scale application horizontally
- Optimize database queries
- Enable caching
- Review network path
- Check for resource constraints

## Emergency Procedures

### Complete Outage

1. **Assess Impact**: Determine scope of outage
2. **Check Infrastructure**: Verify AWS services are healthy
3. **Check Application**: Verify pods are running
4. **Check Networking**: Verify ALB and TargetGroupBinding
5. **Check Data Services**: Verify Aurora, EFS, Redis
6. **Escalate**: Contact AWS Support if needed

### Data Loss

1. **Stop Changes**: Prevent further data loss
2. **Assess Scope**: Determine what data is affected
3. **Check Backups**: Identify recovery points
4. **Restore**: Follow backup restore procedures
5. **Verify**: Confirm data integrity
6. **Document**: Record incident details

### Security Incident

1. **Isolate**: Contain the incident
2. **Assess**: Determine scope and impact
3. **Notify**: Alert security team
4. **Investigate**: Review logs and events
5. **Remediate**: Fix vulnerabilities
6. **Document**: Complete incident report

## Getting Help

### Internal Escalation

1. Check this troubleshooting guide
2. Review related documentation
3. Check CloudWatch Logs and metrics
4. Contact platform team
5. Escalate to on-call engineer

### AWS Support

When to engage AWS Support:
- AWS service outages
- Quota limit increases
- Complex networking issues
- Performance optimization
- Security incidents

### Community Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [WordPress Support Forums](https://wordpress.org/support/)

## Related Documentation

- [Operations Runbook](../runbook.md)
- [High Availability and Disaster Recovery](./ha-dr.md)
- [Backup and Restore](./backup-restore.md)
- [Security and Compliance](./security-compliance.md)
- [Network Resilience](./network-resilience.md)
- [Architecture Overview](../architecture.md)

## References

- [EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [RDS Troubleshooting](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Troubleshooting.html)
- [EFS Troubleshooting](https://docs.aws.amazon.com/efs/latest/ug/troubleshooting.html)
- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug/)
