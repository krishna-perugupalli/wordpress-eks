# WordPress Application Module

Deploys Bitnami WordPress Helm chart with external Aurora database, EFS storage, and optional Redis cache.

## Resources Created

- WordPress Helm release with HPA
- TargetGroupBinding for ALB integration
- ExternalSecrets for database and admin credentials
- Optional database grant job for user privileges
- Optional Redis cache configuration
- Optional metrics exporter sidecar

## Key Inputs

- `domain_name` - Public hostname for the WordPress site
- `target_group_arn` - ALB target group ARN for pod registration
- `db_host` - Aurora writer endpoint
- `db_secret_arn` - Secrets Manager ARN for database password
- `storage_class_name` - StorageClass for wp-content (default: "efs-ap")
- `enable_redis_cache` - Enable Redis-backed cache (default: false)
- `enable_metrics_exporter` - Enable Prometheus metrics (default: false)

## Key Outputs

- `release_name` - Helm release name
- `namespace` - Kubernetes namespace
- `service_name` - WordPress service name
- `metrics_service_name` - Metrics service name (if enabled)

## Documentation

For detailed configuration, examples, and troubleshooting, see:
- **Module Guide**: [docs/modules/wordpress.md](../../docs/modules/wordpress.md)
- **Getting Started**: [docs/getting-started.md](../../docs/getting-started.md)
- **Operations**: [docs/operations/](../../docs/operations/)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.29 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.13 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.29 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.wordpress](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.wordpress_tgb](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.wp_admin_es](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.wp_db_admin_es](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.wp_db_es](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_config_map.wordpress_metrics_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_job_v1.wp_db_grant_job](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/job_v1) | resource |
| [kubernetes_namespace.ns](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_service.wordpress_metrics](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_db_host"></a> [db\_host](#input\_db\_host) | Aurora writer endpoint | `string` | n/a | yes |
| <a name="input_db_secret_arn"></a> [db\_secret\_arn](#input\_db\_secret\_arn) | Secrets Manager ARN that contains {password} for the DB user | `string` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Public hostname for the site (Ingress host) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Logical app name (used for release name and defaults) | `string` | n/a | yes |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | ARN of the ALB target group to bind the WordPress service to | `string` | n/a | yes |
| <a name="input_admin_bootstrap_enabled"></a> [admin\_bootstrap\_enabled](#input\_admin\_bootstrap\_enabled) | When true, create wp-admin ExternalSecret and wire chart to use it for initial admin password | `bool` | `false` | no |
| <a name="input_admin_email"></a> [admin\_email](#input\_admin\_email) | Admin email (non-secret, chart value) | `string` | `"admin@example.com"` | no |
| <a name="input_admin_secret_arn"></a> [admin\_secret\_arn](#input\_admin\_secret\_arn) | Secrets Manager ARN with admin {password} (and optionally username/email) used when admin\_bootstrap\_enabled=true | `string` | `""` | no |
| <a name="input_admin_user"></a> [admin\_user](#input\_admin\_user) | Admin username (non-secret, chart value) | `string` | `"wpadmin"` | no |
| <a name="input_behind_cloudfront"></a> [behind\_cloudfront](#input\_behind\_cloudfront) | When true, configure WordPress to trust CloudFront/ALB proxy headers for HTTPS detection | `bool` | `false` | no |
| <a name="input_db_admin_secret_arn"></a> [db\_admin\_secret\_arn](#input\_db\_admin\_secret\_arn) | Optional Secrets Manager ARN that contains the Aurora admin credentials | `string` | `""` | no |
| <a name="input_db_admin_secret_key"></a> [db\_admin\_secret\_key](#input\_db\_admin\_secret\_key) | Key name to store the admin password under in the generated Kubernetes Secret | `string` | `"password"` | no |
| <a name="input_db_admin_secret_property"></a> [db\_admin\_secret\_property](#input\_db\_admin\_secret\_property) | Property key within the admin secret JSON that stores the password | `string` | `"password"` | no |
| <a name="input_db_admin_username_key"></a> [db\_admin\_username\_key](#input\_db\_admin\_username\_key) | Key name to store the admin username under in the generated Kubernetes Secret | `string` | `"username"` | no |
| <a name="input_db_admin_username_property"></a> [db\_admin\_username\_property](#input\_db\_admin\_username\_property) | Property key within the admin secret JSON that stores the username (empty to skip) | `string` | `"username"` | no |
| <a name="input_db_grant_job_backoff_limit"></a> [db\_grant\_job\_backoff\_limit](#input\_db\_grant\_job\_backoff\_limit) | Backoff limit for the DB grant Job retries. | `number` | `5` | no |
| <a name="input_db_grant_job_enabled"></a> [db\_grant\_job\_enabled](#input\_db\_grant\_job\_enabled) | When true, run a Kubernetes Job to ensure the DB user has required privileges. | `bool` | `true` | no |
| <a name="input_db_grant_job_image"></a> [db\_grant\_job\_image](#input\_db\_grant\_job\_image) | Container image (with mysql client) used by the DB grant Job. | `string` | `"docker.io/library/mysql:8.0"` | no |
| <a name="input_db_grant_login_password_key"></a> [db\_grant\_login\_password\_key](#input\_db\_grant\_login\_password\_key) | Key inside the wp-db Secret that stores the password for db\_grant\_login\_user. | `string` | `"password"` | no |
| <a name="input_db_grant_login_user"></a> [db\_grant\_login\_user](#input\_db\_grant\_login\_user) | Database user the Job should authenticate as when issuing GRANT statements. Defaults to db\_user. | `string` | `null` | no |
| <a name="input_db_name"></a> [db\_name](#input\_db\_name) | Database name | `string` | `"wordpress"` | no |
| <a name="input_db_port"></a> [db\_port](#input\_db\_port) | DB port | `number` | `3306` | no |
| <a name="input_db_secret_additional_keys"></a> [db\_secret\_additional\_keys](#input\_db\_secret\_additional\_keys) | Additional key names that should mirror the DB password in the Kubernetes Secret | `list(string)` | <pre>[<br>  "WORDPRESS_DATABASE_PASSWORD",<br>  "mariadb-password"<br>]</pre> | no |
| <a name="input_db_secret_key"></a> [db\_secret\_key](#input\_db\_secret\_key) | Primary key stored in the Kubernetes Secret for the DB password | `string` | `"password"` | no |
| <a name="input_db_secret_property"></a> [db\_secret\_property](#input\_db\_secret\_property) | Property key within the app DB secret JSON that stores the password | `string` | `"password"` | no |
| <a name="input_db_user"></a> [db\_user](#input\_db\_user) | Database user | `string` | `"wpapp"` | no |
| <a name="input_enable_metrics_exporter"></a> [enable\_metrics\_exporter](#input\_enable\_metrics\_exporter) | Enable WordPress metrics exporter sidecar container for Prometheus monitoring | `bool` | `false` | no |
| <a name="input_enable_redis_cache"></a> [enable\_redis\_cache](#input\_enable\_redis\_cache) | Enable Redis-backed cache configuration via wordpressExtraConfigContent | `bool` | `false` | no |
| <a name="input_env_extra"></a> [env\_extra](#input\_env\_extra) | Map of extra non-secret env vars injected into the chart | `map(string)` | `{}` | no |
| <a name="input_fullname_override"></a> [fullname\_override](#input\_fullname\_override) | Helm fullnameOverride | `string` | `""` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | WordPress image tag (Bitnami) | `string` | `"sha256-08a8a1c86a0ea118986d629c1c41d15d5a3a45cffa48aea010033e7dad404201"` | no |
| <a name="input_metrics_exporter_image"></a> [metrics\_exporter\_image](#input\_metrics\_exporter\_image) | Container image for WordPress metrics exporter sidecar | `string` | `"bitnami/wordpress:latest"` | no |
| <a name="input_metrics_exporter_resources_limits_cpu"></a> [metrics\_exporter\_resources\_limits\_cpu](#input\_metrics\_exporter\_resources\_limits\_cpu) | CPU limits for metrics exporter sidecar | `string` | `"200m"` | no |
| <a name="input_metrics_exporter_resources_limits_memory"></a> [metrics\_exporter\_resources\_limits\_memory](#input\_metrics\_exporter\_resources\_limits\_memory) | Memory limits for metrics exporter sidecar | `string` | `"256Mi"` | no |
| <a name="input_metrics_exporter_resources_requests_cpu"></a> [metrics\_exporter\_resources\_requests\_cpu](#input\_metrics\_exporter\_resources\_requests\_cpu) | CPU requests for metrics exporter sidecar | `string` | `"50m"` | no |
| <a name="input_metrics_exporter_resources_requests_memory"></a> [metrics\_exporter\_resources\_requests\_memory](#input\_metrics\_exporter\_resources\_requests\_memory) | Memory requests for metrics exporter sidecar | `string` | `"64Mi"` | no |
| <a name="input_name_override"></a> [name\_override](#input\_name\_override) | Helm nameOverride (used only when fullname\_override is empty) | `string` | `""` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace for WordPress | `string` | `"wordpress"` | no |
| <a name="input_php_max_input_vars"></a> [php\_max\_input\_vars](#input\_php\_max\_input\_vars) | php.ini max\_input\_vars appended via phpConfiguration | `number` | `2000` | no |
| <a name="input_pvc_size"></a> [pvc\_size](#input\_pvc\_size) | PVC size for wp-content | `string` | `"10Gi"` | no |
| <a name="input_redis_auth_env_var_name"></a> [redis\_auth\_env\_var\_name](#input\_redis\_auth\_env\_var\_name) | Environment variable name exposed to the pod that carries the Redis auth token | `string` | `"REDIS_AUTH_TOKEN"` | no |
| <a name="input_redis_auth_secret_arn"></a> [redis\_auth\_secret\_arn](#input\_redis\_auth\_secret\_arn) | Secrets Manager ARN that stores the Redis auth token (JSON with `token` key) | `string` | `""` | no |
| <a name="input_redis_auth_secret_property"></a> [redis\_auth\_secret\_property](#input\_redis\_auth\_secret\_property) | Property inside the Redis auth secret JSON that contains the token | `string` | `"token"` | no |
| <a name="input_redis_connection_scheme"></a> [redis\_connection\_scheme](#input\_redis\_connection\_scheme) | Scheme prefix for Redis server URI (tcp, tls, rediss) | `string` | `"tls"` | no |
| <a name="input_redis_database"></a> [redis\_database](#input\_redis\_database) | Redis logical database ID used by W3 Total Cache | `number` | `0` | no |
| <a name="input_redis_endpoint"></a> [redis\_endpoint](#input\_redis\_endpoint) | Redis endpoint hostname (e.g., ElastiCache primary endpoint) | `string` | `""` | no |
| <a name="input_redis_port"></a> [redis\_port](#input\_redis\_port) | Redis port | `number` | `6379` | no |
| <a name="input_replicas_max"></a> [replicas\_max](#input\_replicas\_max) | HPA max replicas | `number` | `6` | no |
| <a name="input_replicas_min"></a> [replicas\_min](#input\_replicas\_min) | HPA min replicas | `number` | `2` | no |
| <a name="input_resources_limits_cpu"></a> [resources\_limits\_cpu](#input\_resources\_limits\_cpu) | Container limits.cpu | `string` | `"1000m"` | no |
| <a name="input_resources_limits_memory"></a> [resources\_limits\_memory](#input\_resources\_limits\_memory) | Container limits.memory | `string` | `"1Gi"` | no |
| <a name="input_resources_requests_cpu"></a> [resources\_requests\_cpu](#input\_resources\_requests\_cpu) | Container requests.cpu | `string` | `"250m"` | no |
| <a name="input_resources_requests_memory"></a> [resources\_requests\_memory](#input\_resources\_requests\_memory) | Container requests.memory | `string` | `"512Mi"` | no |
| <a name="input_storage_class_name"></a> [storage\_class\_name](#input\_storage\_class\_name) | StorageClass name (e.g., efs-ap) | `string` | `"efs-ap"` | no |
| <a name="input_target_cpu_percent"></a> [target\_cpu\_percent](#input\_target\_cpu\_percent) | Target CPU utilization percentage for HPA | `number` | `80` | no |
| <a name="input_target_memory_percent"></a> [target\_memory\_percent](#input\_target\_memory\_percent) | Target memory utilization percentage for HPA (integer, e.g., 80) | `number` | `80` | no |
| <a name="input_wordpress_chart_version"></a> [wordpress\_chart\_version](#input\_wordpress\_chart\_version) | Bitnami WordPress Helm chart version | `string` | `"27.0.10"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | Domain name configured for WordPress. |
| <a name="output_metrics_enabled"></a> [metrics\_enabled](#output\_metrics\_enabled) | Whether WordPress metrics exporter is enabled |
| <a name="output_metrics_service_name"></a> [metrics\_service\_name](#output\_metrics\_service\_name) | Name of the WordPress metrics service (if enabled) |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Namespace where WordPress was deployed. |
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Helm release name. |
| <a name="output_service_name"></a> [service\_name](#output\_service\_name) | Service name exposed by the chart (same naming logic) |
| <a name="output_target_group_binding_name"></a> [target\_group\_binding\_name](#output\_target\_group\_binding\_name) | Name of the TargetGroupBinding resource |
<!-- END_TF_DOCS -->