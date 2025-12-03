# cert-manager Module

This module installs and configures [cert-manager](https://cert-manager.io/) for automated TLS certificate management in Kubernetes.

## Features

- Installs cert-manager via Helm chart with CRDs
- Creates ClusterIssuers for Let's Encrypt (production and staging)
- Creates self-signed ClusterIssuer for internal certificates
- Configurable resource requests and limits
- Prometheus metrics integration
- High availability with leader election

## Usage

```hcl
module "cert_manager" {
  source = "../../modules/cert-manager"

  name      = "my-app"
  namespace = "cert-manager"

  # ClusterIssuer configuration
  create_letsencrypt_issuer = true
  letsencrypt_email         = "admin@example.com"
  create_selfsigned_issuer  = true

  # Enable Prometheus metrics
  enable_prometheus_metrics = true

  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

## ClusterIssuers

### Let's Encrypt

When `create_letsencrypt_issuer = true`, the module creates two ClusterIssuers:

- **letsencrypt-prod**: Production Let's Encrypt issuer (rate limited)
- **letsencrypt-staging**: Staging Let's Encrypt issuer (for testing)

Both use HTTP-01 challenge with ALB ingress class.

### Self-Signed

When `create_selfsigned_issuer = true`, creates a self-signed ClusterIssuer for internal certificates (e.g., monitoring components).

## Example Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - my-app.default.svc
    - my-app.default.svc.cluster.local
```

## Requirements

- Kubernetes 1.25+
- Helm provider
- kubectl provider

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| name | Logical name for cert-manager resources | string | required |
| namespace | Kubernetes namespace for cert-manager | string | "cert-manager" |
| cert_manager_version | cert-manager Helm chart version | string | "v1.16.2" |
| enable_prometheus_metrics | Enable Prometheus metrics | bool | true |
| create_letsencrypt_issuer | Create Let's Encrypt ClusterIssuers | bool | true |
| letsencrypt_email | Email for Let's Encrypt registration | string | "" |
| create_selfsigned_issuer | Create self-signed ClusterIssuer | bool | true |
| resource_requests | Resource requests for controller | object | {cpu="10m", memory="32Mi"} |
| resource_limits | Resource limits for controller | object | {cpu="100m", memory="128Mi"} |

## Outputs

| Name | Description |
|------|-------------|
| namespace | Namespace where cert-manager is installed |
| helm_release_name | Name of the Helm release |
| letsencrypt_prod_issuer | Name of Let's Encrypt prod ClusterIssuer |
| letsencrypt_staging_issuer | Name of Let's Encrypt staging ClusterIssuer |
| selfsigned_issuer | Name of self-signed ClusterIssuer |

## Notes

- cert-manager CRDs are installed as part of the Helm release (`installCRDs=true`)
- The namespace is labeled with `cert-manager.io/disable-validation=true` to prevent webhook validation issues during installation
- Resource limits are conservative by default - adjust based on cluster size and certificate volume
