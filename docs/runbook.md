# Runbook – Operating WordPress on EKS

This runbook outlines common operational scenarios, verification steps, and remediation actions. Always record outcomes in your incident tracker and follow up with root-cause analysis where appropriate.

## 1. General Checks
- **Terraform state**: Confirm the latest applies for both workspaces (`wp-infra`, `wp-app`) completed successfully in Terraform Cloud.
- **AWS Health**: Review CloudWatch dashboards and AWS Health for ongoing service issues in the target region.
- **Kubernetes access**: Ensure you can reach the cluster (`make kubeconfig`). If not, validate AWS credentials and that the EKS endpoint is reachable.

## 2. New Deployment / Change Rollout
1. Review the change request and identify whether it affects infra or app stack (or both).
2. In Terraform Cloud:
   - Run `wp-infra` plan/apply first when infrastructure changes are involved.
   - Run `wp-app` afterwards.
3. Post-apply verification:
   - Check Terraform outputs for expected values (ALB hostname, secret ARNs, database endpoints).
   - Verify new Kubernetes resources (`kubectl get pods -n <namespace>`).
   - Confirm the ALB is healthy (`aws elbv2 describe-target-health`).

If the apply fails:
- Inspect the run logs.
- Re-run with targeted resources if required (e.g., `terraform plan -target=module.data_aurora` locally) after addressing issues.

## 3. WordPress Not Serving Traffic
1. **ALB and Target Group**:
   - Verify ALB target health in AWS Console: EC2 → Load Balancers → Target Groups.
   - Check target group has registered targets: `aws elbv2 describe-target-health --target-group-arn <arn>`.
   - Unhealthy targets typically indicate pod readiness issues or security group problems.
2. **TargetGroupBinding**:
   - Check TargetGroupBinding status: `kubectl get targetgroupbinding -n <wp-namespace>`.
   - Inspect binding details: `kubectl describe targetgroupbinding <name> -n <wp-namespace>`.
   - Verify AWS Load Balancer Controller is running: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`.
3. **Pods & Deployments**:
   - Check deployment: `kubectl get deployment -n <wp-namespace>`.
   - Inspect pod logs: `kubectl logs deploy/<deployment> -n <wp-namespace>`.
   - Look for database or filesystem errors.
4. **Security Groups**:
   - Verify ALB security group allows traffic from internet (80/443).
   - Verify worker node security group allows traffic from ALB security group on pod port (8080).
   - Check TargetGroupBinding networking configuration for security group rules.
5. **Secrets**:
   - Ensure ESO synced secrets: `kubectl get externalsecret -n <namespace>` and `kubectl describe externalsecret/wp-env`.
   - Compare Kubernetes secret data with AWS Secrets Manager (`aws secretsmanager get-secret-value --secret-id <name>`).
6. **Database Connectivity**:
   - From a debug pod, connect to Aurora endpoint using credentials.
   - Validate Aurora instance status in RDS console.
7. **Filesystem (EFS)**:
   - Check PersistentVolume and PersistentVolumeClaim status (`kubectl get pvc --namespace <wp-namespace>`).
   - Inspect EFS mount targets and security groups in AWS if pods cannot mount.

**Resolution Steps**
- Restart the deployment after fixing underlying issues: `kubectl rollout restart deployment/<name> -n <namespace>`.
- If TargetGroupBinding is not working, restart the AWS Load Balancer Controller: `kubectl rollout restart deployment/aws-load-balancer-controller -n kube-system`.
- If secrets were rotated, trigger an ESO refresh by annotating the ExternalSecret or reapplying the Terraform module.
- For persistent failures, scale out Karpenter or managed node group if compute is constrained (`kubectl get nodes`, `karpenter` events).
- If targets are not registering, verify the target group ARN in TargetGroupBinding matches the one created by the infrastructure stack.

## 4. Terraform Apply Failures
### Infra stack failures
- Common causes: IAM permission gaps, exhausted CIDRs, conflicting resource names.
- Actions:
  1. Review the failing resource in Terraform logs.
  2. Fix configuration or underlying AWS state.
  3. Re-run plan/apply. For destroyed partial resources, Terraform will attempt to recreate them.

### App stack failures
- Common causes: missing remote state outputs, ESO policy misconfiguration, certificate validation timeouts.
- Actions:
  1. Confirm `wp-infra` workspace outputs include required values (`terraform output` in TFC).
  2. For ACM DNS validation, ensure Route53 zones are correct and that records propagated.
  3. Retry apply once issues are resolved.

## 5. Secrets Rotation
1. Update the secret in AWS Secrets Manager (e.g., rotate WordPress admin password).
2. Ensure version stage `AWSCURRENT` points to the new value (ESO reads this stage by default).
3. Watch ESO status: `kubectl describe externalsecret/wp-env`.
4. Restart WordPress pods to pick up the change if necessary.
5. Record the rotation in your secrets inventory.

## 6. Certificate Renewal / HTTPS Issues
- If using ACM-managed certificates (created by Terraform), renewals are automatic, provided DNS validation records remain intact.
- If the certificate is imported or managed externally:
  1. Update the certificate in ACM.
  2. Update Terraform variable or state if ARN changes.
  3. Re-run `wp-app` apply to propagate the new ARN to the ingress annotations.
- Monitor ALB listener status and ensure TLS handshake succeeds.

## 7. Backup & Restore
### Aurora
1. Identify the desired restore point (AWS Backup recovery point or RDS snapshot).
2. Restore to a new cluster/instance.
3. Update Secrets Manager entry (host) if cutover is required.
4. Run `wp-app` apply to ensure WordPress points to the new endpoint (or update Kubernetes secret directly via ESO).

### EFS
1. Use AWS Backup to restore the filesystem or a specific recovery point to an alternate file system.
2. Update the EFS ID and access point if you plan to switch permanently; otherwise, mount the restored data elsewhere for recovery operations.

## 8. TargetGroupBinding Issues

### Symptoms
- WordPress pods are running but ALB returns 503 Service Unavailable
- Target group shows no registered targets or all targets unhealthy
- TargetGroupBinding status shows errors

### Diagnosis Steps
1. **Check TargetGroupBinding Status**:
   ```bash
   kubectl get targetgroupbinding -n wordpress
   kubectl describe targetgroupbinding wordpress-tgb -n wordpress
   ```

2. **Verify AWS Load Balancer Controller**:
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

3. **Check Target Group in AWS**:
   ```bash
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

4. **Verify Service and Endpoints**:
   ```bash
   kubectl get svc -n wordpress
   kubectl get endpoints -n wordpress
   ```

### Common Issues and Solutions

**Issue**: TargetGroupBinding not creating targets
- **Cause**: AWS Load Balancer Controller not running or lacks permissions
- **Solution**: Verify controller deployment and IRSA role has target group permissions

**Issue**: Targets registered but unhealthy
- **Cause**: Security group rules blocking ALB → pod communication
- **Solution**: Verify ALB security group can reach worker nodes on pod port (8080)

**Issue**: Wrong target group ARN
- **Cause**: Mismatch between infra stack output and TargetGroupBinding spec
- **Solution**: Verify target group ARN matches between Terraform output and TargetGroupBinding

**Issue**: Pod readiness probe failures
- **Cause**: WordPress not responding on health check path
- **Solution**: Check WordPress configuration and database connectivity

### Resolution Steps
1. Restart AWS Load Balancer Controller if needed
2. Verify and fix security group rules
3. Ensure target group ARN is correct
4. Check WordPress pod health and readiness probes
5. Monitor TargetGroupBinding events for specific error messages

For detailed TargetGroupBinding configuration and troubleshooting, see the [TargetGroupBinding Guide](./features/targetgroupbinding.md).

## 9. Scaling & Cost Optimisation
- **Karpenter / Node Groups**: Adjust capacity limits in Terraform variables and re-apply.
- **Aurora Serverless range**: Tune `db_serverless_min_acu` / `max_acu` in `stacks/infra`.
- **Redis node type**: Change `node_type` in `modules/elasticache`; ensure quotas permit the instance size.
- **Budgets**: Update thresholds or recipients in `modules/cost-budgets`.
- **TargetGroupBinding Scaling**: Automatically handles pod scaling events - no manual intervention required.

Document any tuning decisions in change management logs.

## 10. When to Escalate
- Prolonged outage (>15 minutes) without clear remediation path.
- Security incidents (suspicious GuardDuty findings, credential leaks).
- Data loss or corruption.
- Terraform state divergence that risks destructive changes.

Escalate to the platform lead/SRE and involve AWS Support if necessary. Capture timelines, actions taken, and lessons learned.
