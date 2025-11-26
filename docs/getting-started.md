# Getting Started

This guide walks a new engineer through preparing accounts, configuring Terraform Cloud (TFC), and performing the first end-to-end deployment of WordPress on EKS.

## 1. Prerequisites
- **AWS account** with permissions to create VPCs, IAM roles/policies, EKS, RDS, EFS, ElastiCache, WAF, ACM, CloudWatch, and SNS/Budgets.
- **Terraform Cloud** organisation with access to create workspaces and configure run tasks/variables.
- **Terraform CLI** (v1.6+) for local validation (optional but recommended).
- **AWS CLI** configured locally if you expect to run `make kubeconfig` or interact with the cluster outside Terraform.

## 2. Clone the Repository
```bash
git clone <repo-url>
cd wordpress-eks
```

## 3. Configure Terraform Cloud Workspaces
Create two workspaces in TFC:

| Workspace | Working Directory | Purpose |
|-----------|-------------------|---------|
| `wp-infra` | `stacks/infra` | AWS foundation, EKS cluster, shared services |
| `wp-app`   | `stacks/app`   | Cluster add-ons, WordPress Helm release |

Within each workspace:
1. Set **Execution Mode** to _Remote_.
2. Enable AWS IAM integration:
   - `TFC_AWS_PROVIDER_AUTH = true`
   - `TFC_AWS_RUN_ROLE_ARN = arn:aws:iam::<account-id>:role/<tfc-role>`
3. Configure Terraform variables (HCL or environment) as required. Common examples:
   ```hcl
   region  = "us-east-1"
   project = "wp-sbx"
   env     = "sandbox"
   ```
   Adjust CIDRs, domain names, and feature toggles via `stacks/infra/variables.tf` and `stacks/app/variables.tf` as needed for your environment.

### Variable Files
If you prefer using a `.tfvars` file locally, copy `wordpress-eks.tfvars` to a secure location and pass it with `-var-file`. In Terraform Cloud, translate those entries into workspace variables.

## 4. Run the Infrastructure Stack
1. **Plan**: Trigger a plan on `wp-infra`. Verify the DAG shows expected resources (foundation → IAM → EKS → data/services).
2. **Apply**: When satisfied, apply the plan. On success, the workspace publishes outputs consumed by the app stack (cluster metadata, secrets policy ARN, secret ARNs, database endpoints, etc.).

You can mimic this locally if you have AWS credentials:
```bash
make plan-infra
make apply-infra
```

## 5. Run the Application Stack
1. Ensure the infra workspace completed successfully.
2. In `wp-app`, trigger a plan. The configuration reads remote state from `wp-infra`; any missing outputs will cause a failure so you know infra isn’t ready yet.
3. Apply the plan. This installs ESO, controllers, observability tooling, and the WordPress Helm release configured for Aurora/EFS/Redis.

Local equivalent commands:
```bash
make plan-app
make apply-app
```

## 6. Post-Deployment Tasks
- **Kubeconfig**: Pull credentials to inspect the cluster (requires AWS CLI auth).
  ```bash
  make kubeconfig
  ```
- **DNS**: If using external DNS provider, update the chosen domain to point at the ALB hostname (available in infra stack outputs).
- **Verify TargetGroupBinding**: Check that WordPress pods are registered with the ALB target group:
  ```bash
  kubectl get targetgroupbinding -n wordpress
  kubectl describe targetgroupbinding wordpress-tgb -n wordpress
  ```
- **WordPress Admin**: Log in with bootstrap credentials from the Secrets Manager entry (`<project>-wp-admin`). After the first login, disable bootstrap by setting `wp_admin_bootstrap_enabled = false` in the app workspace.

## 7. Ongoing Operations
- Use `make validate-*` during development to catch syntax or provider issues without touching remote state.
- Coordinate changes across workspaces: run `wp-infra` first, then `wp-app`.
- Schedule periodic reviews of backups (Aurora/EFS via AWS Backup) and secret rotations (`modules/secrets-iam` outputs).

## 8. Troubleshooting Basics
- **Terraform Cloud run failures**: Inspect logs for provider errors, missing permissions, or circular dependencies. Re-run after addressing issues.
- **Remote state issues**: `wp-app` depends on `wp-infra`; ensure the latest infra apply succeeded before re-running app.
- **WordPress pod failures**: See `docs/runbook.md` for detailed remediation steps, covering ESO sync, database connectivity, storage, and TargetGroupBinding checks.
- **TargetGroupBinding issues**: Verify AWS Load Balancer Controller is running and has proper IRSA permissions for target group management.

## 9. Next Steps for New Contributors
- Review the module source under `modules/` to understand configurable options and resource decisions.
- Consider enabling optional features (per-AZ NAT gateways, stricter WAF rules, CloudFront) once the baseline deployment is healthy.
- Extend Terraform Cloud with run tasks (e.g., policy checks, security scans) if required by your organisation.

You are now ready to maintain and iterate on this WordPress-on-EKS platform.
