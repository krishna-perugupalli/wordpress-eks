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
<!-- END_TF_DOCS -->

## Notes

- The ClusterSecretStore is cluster-wide and can be used by any namespace
- Secrets are refreshed based on the refreshInterval setting
- The operator validates ExternalSecret resources via webhook
- IRSA provides temporary, scoped credentials for AWS API calls
