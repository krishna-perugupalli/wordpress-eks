# Secrets Operator Module

This module deploys External Secrets Operator and configures it to sync secrets from AWS Secrets Manager to Kubernetes.

## Overview

The secrets-operator module installs External Secrets Operator via Helm and creates a ClusterSecretStore for AWS Secrets Manager integration, enabling automatic synchronization of secrets into Kubernetes.

## Features

- External Secrets Operator Helm chart deployment
- ClusterSecretStore for AWS Secrets Manager
- IRSA integration for secure AWS access
- Automatic secret synchronization
- Support for multiple secret stores
- Webhook validation for ExternalSecret resources

## Usage

```hcl
module "secrets_operator" {
  source = "../../modules/secrets-operator"

  name                     = "wordpress-eks"
  namespace                = "external-secrets"
  service_account_role_arn = module.secrets_iam.role_arn
  
  aws_region = "us-east-1"
  
  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

## Creating ExternalSecrets

After deploying this module, create ExternalSecret resources to sync secrets:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: wordpress-db-credentials
  namespace: wordpress
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: wordpress-db-secret
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: wordpress/database
        property: username
    - secretKey: password
      remoteRef:
        key: wordpress/database
        property: password
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.33 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.13 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.33 |
| <a name="provider_null"></a> [null](#provider\_null) | ~> 3.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.eso](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.cluster_secret_store_aws_sm](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.ns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service_account.eso](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [null_resource.input_guard](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region used by External Secrets' ClusterSecretStore | `string` | n/a | yes |
| <a name="input_cluster_oidc_issuer_url"></a> [cluster\_oidc\_issuer\_url](#input\_cluster\_oidc\_issuer\_url) | EKS OIDC issuer URL (https://...) | `string` | n/a | yes |
| <a name="input_eso_role_arn"></a> [eso\_role\_arn](#input\_eso\_role\_arn) | External Secrets Service Account ESO ARN | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Logical name/prefix (usually your cluster name) | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKS OIDC provider ARN | `string` | n/a | yes |
| <a name="input_allowed_secret_arns"></a> [allowed\_secret\_arns](#input\_allowed\_secret\_arns) | (Option B) Exact Secrets Manager ARNs ESO may read; module will create a policy for these | `list(string)` | `[]` | no |
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | External Secrets Helm chart version | `string` | `"0.9.13"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for ESO | `string` | `"external-secrets"` | no |
| <a name="input_secrets_read_policy_arn"></a> [secrets\_read\_policy\_arn](#input\_secrets\_read\_policy\_arn) | (Option A) Existing IAM policy ARN granting secretsmanager:GetSecretValue on specific ARNs | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace where External Secrets Operator is installed |
| <a name="output_service_account"></a> [service\_account](#output\_service\_account) | ServiceAccount used by ESO (namespaced/name) |
<!-- END_TF_DOCS -->

## Notes

- The ClusterSecretStore is cluster-wide and can be used by any namespace
- Secrets are refreshed based on the refreshInterval setting
- The operator validates ExternalSecret resources via webhook
- IRSA provides temporary, scoped credentials for AWS API calls
