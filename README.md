# WordPress on EKS (Terraform Cloud)

## Workspaces
- `wp-sbx-infra` → AWS side (VPC, EKS, Aurora, EFS, GuardDuty, Budgets, Secrets, Redis)
  - Working dir: `stacks/infra`
- `wp-sbx-app` → Kubernetes side (ESO, ALB/Ingress, Karpenter, Observability, WordPress)
  - Working dir: `stacks/app`

Remote state: Terraform Cloud (TFC). Auth: TFC OIDC → AWS role (`TFC_AWS_RUN_ROLE_ARN`).

## First-time setup
1. Create both workspaces in TFC and set:
   - `TFC_AWS_PROVIDER_AUTH = true`
   - `TFC_AWS_RUN_ROLE_ARN = arn:aws:iam::<acct>:role/tfc-sandbox-role`
2. Set Terraform vars in each workspace:
   - `region = "eu-north-1"`
   - `project = "wp-sbx"`
3. Run **infra** workspace (apply), then **app** (apply).
4. After first WordPress deploy, disable admin bootstrap in app workspace var:
   - `wp_admin_bootstrap_enabled = false`

## Local developer helpers
```bash
make fmt
make lint
make validate-infra
make validate-app