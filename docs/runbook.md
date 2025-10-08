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
1. **Ingress/ALB**:
   - `kubectl get ingress -n <wp-namespace>` to confirm rules.
   - Verify ALB target health in AWS Console or via CLI. Unhealthy targets typically indicate pod readiness issues.
2. **Pods & Deployments**:
   - Check deployment: `kubectl get deployment -n <wp-namespace>`.
   - Inspect pod logs: `kubectl logs deploy/<deployment> -n <wp-namespace>`.
   - Look for database or filesystem errors.
3. **Secrets**:
   - Ensure ESO synced secrets: `kubectl get externalsecret -n <namespace>` and `kubectl describe externalsecret/wp-env`.
   - Compare Kubernetes secret data with AWS Secrets Manager (`aws secretsmanager get-secret-value --secret-id <name>`).
4. **Database Connectivity**:
   - From a debug pod, connect to Aurora endpoint using credentials.
   - Validate Aurora instance status in RDS console.
5. **Filesystem (EFS)**:
   - Check PersistentVolume and PersistentVolumeClaim status (`kubectl get pvc --namespace <wp-namespace>`).
   - Inspect EFS mount targets and security groups in AWS if pods cannot mount.

**Resolution Steps**
- Restart the deployment after fixing underlying issues: `kubectl rollout restart deployment/<name> -n <namespace>`.
- If secrets were rotated, trigger an ESO refresh by annotating the ExternalSecret or reapplying the Terraform module.
- For persistent failures, scale out Karpenter or managed node group if compute is constrained (`kubectl get nodes`, `karpenter` events).

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

## 8. Scaling & Cost Optimisation
- **Karpenter / Node Groups**: Adjust capacity limits in Terraform variables and re-apply.
- **Aurora Serverless range**: Tune `db_serverless_min_acu` / `max_acu` in `stacks/infra`.
- **Redis node type**: Change `node_type` in `modules/elasticache`; ensure quotas permit the instance size.
- **Budgets**: Update thresholds or recipients in `modules/cost-budgets`.

Document any tuning decisions in change management logs.

## 9. When to Escalate
- Prolonged outage (>15 minutes) without clear remediation path.
- Security incidents (suspicious GuardDuty findings, credential leaks).
- Data loss or corruption.
- Terraform state divergence that risks destructive changes.

Escalate to the platform lead/SRE and involve AWS Support if necessary. Capture timelines, actions taken, and lessons learned.
