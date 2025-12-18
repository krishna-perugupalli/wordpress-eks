# Secrets IAM Module

This module creates IAM roles and policies for External Secrets Operator to access AWS Secrets Manager.

## Overview

The secrets-iam module provisions the necessary IAM resources for Kubernetes pods to securely access secrets stored in AWS Secrets Manager using IRSA (IAM Roles for Service Accounts).

## Features

- IAM role for External Secrets Operator service account
- Least-privilege IAM policy for Secrets Manager access
- IRSA integration with EKS OIDC provider
- Support for specific secret ARN restrictions
- KMS key permissions for encrypted secrets

## Usage

```hcl
module "secrets_iam" {
  source = "../../modules/secrets-iam"

  name                = "wordpress-eks"
  oidc_provider_arn   = module.eks.oidc_provider_arn
  namespace           = "external-secrets"
  service_account     = "external-secrets"
  
  secret_arns = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:wordpress/*"
  ]
  
  kms_key_arns = [
    module.kms.key_arn
  ]
  
  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Notes

- The IAM role uses IRSA for secure, temporary credentials
- Secret ARNs should use wildcards carefully to avoid over-permissioning
- KMS key permissions are required if secrets are encrypted with customer-managed keys
- The service account must be annotated with the IAM role ARN
