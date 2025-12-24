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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.29 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.13 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.29 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.11 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.cert_manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.letsencrypt_prod](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.letsencrypt_staging](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.selfsigned_issuer](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.cert_manager](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [time_sleep.wait_for_webhook](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Logical name for cert-manager resources | `string` | n/a | yes |
| <a name="input_additional_helm_values"></a> [additional\_helm\_values](#input\_additional\_helm\_values) | Additional Helm values as YAML string | `string` | `null` | no |
| <a name="input_cert_manager_version"></a> [cert\_manager\_version](#input\_cert\_manager\_version) | cert-manager Helm chart version | `string` | `"v1.16.2"` | no |
| <a name="input_create_letsencrypt_issuer"></a> [create\_letsencrypt\_issuer](#input\_create\_letsencrypt\_issuer) | Create Let's Encrypt ClusterIssuers (prod and staging) | `bool` | `true` | no |
| <a name="input_create_selfsigned_issuer"></a> [create\_selfsigned\_issuer](#input\_create\_selfsigned\_issuer) | Create self-signed ClusterIssuer for internal certificates | `bool` | `true` | no |
| <a name="input_enable_prometheus_metrics"></a> [enable\_prometheus\_metrics](#input\_enable\_prometheus\_metrics) | Enable Prometheus metrics for cert-manager | `bool` | `true` | no |
| <a name="input_letsencrypt_email"></a> [letsencrypt\_email](#input\_letsencrypt\_email) | Email address for Let's Encrypt account registration | `string` | `""` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for cert-manager | `string` | `"cert-manager"` | no |
| <a name="input_resource_limits"></a> [resource\_limits](#input\_resource\_limits) | Resource limits for cert-manager controller | <pre>object({<br>    cpu    = string<br>    memory = string<br>  })</pre> | <pre>{<br>  "cpu": "100m",<br>  "memory": "128Mi"<br>}</pre> | no |
| <a name="input_resource_requests"></a> [resource\_requests](#input\_resource\_requests) | Resource requests for cert-manager controller | <pre>object({<br>    cpu    = string<br>    memory = string<br>  })</pre> | <pre>{<br>  "cpu": "10m",<br>  "memory": "32Mi"<br>}</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the cert-manager Helm release |
| <a name="output_helm_release_version"></a> [helm\_release\_version](#output\_helm\_release\_version) | Version of the cert-manager Helm chart deployed |
| <a name="output_letsencrypt_prod_issuer"></a> [letsencrypt\_prod\_issuer](#output\_letsencrypt\_prod\_issuer) | Name of the Let's Encrypt production ClusterIssuer |
| <a name="output_letsencrypt_staging_issuer"></a> [letsencrypt\_staging\_issuer](#output\_letsencrypt\_staging\_issuer) | Name of the Let's Encrypt staging ClusterIssuer |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace where cert-manager is installed |
| <a name="output_selfsigned_issuer"></a> [selfsigned\_issuer](#output\_selfsigned\_issuer) | Name of the self-signed ClusterIssuer |
<!-- END_TF_DOCS -->