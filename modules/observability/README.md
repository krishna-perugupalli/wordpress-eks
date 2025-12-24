<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.60 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.13 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 1.14 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.33 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.60 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.13 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | ~> 1.14 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | ~> 2.33 |
| <a name="provider_time"></a> [time](#provider\_time) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints_addons"></a> [eks\_blueprints\_addons](#module\_eks\_blueprints\_addons) | aws-ia/eks-blueprints-addons/aws | ~> 1.0 |
| <a name="module_loki_irsa"></a> [loki\_irsa](#module\_loki\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0 |
| <a name="module_tempo_irsa"></a> [tempo\_irsa](#module\_tempo\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.loki](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.tempo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.yace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.yace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.yace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_s3_bucket.loki](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.tempo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.loki](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.tempo](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [helm_release.loki](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.mysql_exporter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.redis_exporter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.tempo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.yace](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.grafana_secret](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.monitoring_namespace](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.servicemonitor_crd](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.servicemonitor_mysql](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.servicemonitor_redis](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.servicemonitor_wordpress](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.servicemonitor_yace](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_config_map.aws_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.cost_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.kubernetes_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.loki_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.tempo_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_config_map.wordpress_dashboards](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map) | resource |
| [kubernetes_manifest.alertmanager_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.aws_alerts](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.cost_alerts](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.kubernetes_alerts](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.wordpress_alerts](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [time_sleep.wait_for_grafana_secret](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_for_servicemonitor_crd](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_iam_policy_document.yace](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.yace_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_ca_data"></a> [cluster\_ca\_data](#input\_cluster\_ca\_data) | EKS cluster certificate authority data | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | EKS cluster API endpoint | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name | `string` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS cluster Kubernetes version | `string` | n/a | yes |
| <a name="input_oidc_provider_arn"></a> [oidc\_provider\_arn](#input\_oidc\_provider\_arn) | EKS OIDC provider ARN for IRSA | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_enable_alerting"></a> [enable\_alerting](#input\_enable\_alerting) | Enable PrometheusRule alert definitions | `bool` | `false` | no |
| <a name="input_enable_alertmanager"></a> [enable\_alertmanager](#input\_enable\_alertmanager) | Enable Alertmanager | `bool` | `true` | no |
| <a name="input_enable_aws_dashboards"></a> [enable\_aws\_dashboards](#input\_enable\_aws\_dashboards) | Enable AWS service dashboards (RDS, ElastiCache, etc.) | `bool` | `true` | no |
| <a name="input_enable_cost_dashboards"></a> [enable\_cost\_dashboards](#input\_enable\_cost\_dashboards) | Enable cost allocation dashboards | `bool` | `true` | no |
| <a name="input_enable_fluentbit"></a> [enable\_fluentbit](#input\_enable\_fluentbit) | Enable Fluent Bit for log forwarding | `bool` | `true` | no |
| <a name="input_enable_grafana"></a> [enable\_grafana](#input\_enable\_grafana) | Enable Grafana | `bool` | `true` | no |
| <a name="input_enable_loki"></a> [enable\_loki](#input\_enable\_loki) | Enable Loki for log aggregation | `bool` | `true` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | Enable Metrics Server | `bool` | `true` | no |
| <a name="input_enable_prometheus"></a> [enable\_prometheus](#input\_enable\_prometheus) | Enable Prometheus (kube-prometheus-stack) | `bool` | `true` | no |
| <a name="input_enable_tempo"></a> [enable\_tempo](#input\_enable\_tempo) | Enable Tempo for distributed tracing | `bool` | `true` | no |
| <a name="input_enable_wp_dashboards"></a> [enable\_wp\_dashboards](#input\_enable\_wp\_dashboards) | Enable WordPress-specific dashboards | `bool` | `true` | no |
| <a name="input_enable_yace"></a> [enable\_yace](#input\_enable\_yace) | Enable YACE CloudWatch exporter | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name for resource tagging (used in YACE discovery) | `string` | `""` | no |
| <a name="input_grafana_namespace"></a> [grafana\_namespace](#input\_grafana\_namespace) | Namespace for Grafana (default: managed by Blueprints) | `string` | `""` | no |
| <a name="input_grafana_secret_arn"></a> [grafana\_secret\_arn](#input\_grafana\_secret\_arn) | ARN of the Secrets Manager secret containing Grafana admin credentials | `string` | `""` | no |
| <a name="input_loki_retention_days"></a> [loki\_retention\_days](#input\_loki\_retention\_days) | Retention period for Loki logs in days | `number` | `30` | no |
| <a name="input_mysql_endpoint"></a> [mysql\_endpoint](#input\_mysql\_endpoint) | Aurora MySQL writer endpoint | `string` | `""` | no |
| <a name="input_notification_provider"></a> [notification\_provider](#input\_notification\_provider) | Primary notification provider: 'slack' or 'sns' | `string` | `"slack"` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Project name for resource tagging (used in YACE discovery) | `string` | `""` | no |
| <a name="input_prometheus_namespace"></a> [prometheus\_namespace](#input\_prometheus\_namespace) | Namespace for Prometheus stack (default: managed by Blueprints) | `string` | `""` | no |
| <a name="input_redis_endpoint"></a> [redis\_endpoint](#input\_redis\_endpoint) | ElastiCache Redis primary endpoint address | `string` | `""` | no |
| <a name="input_slack_webhook_url"></a> [slack\_webhook\_url](#input\_slack\_webhook\_url) | Slack webhook URL for alert notifications (when provider=slack) | `string` | `""` | no |
| <a name="input_sns_topic_arn"></a> [sns\_topic\_arn](#input\_sns\_topic\_arn) | SNS topic ARN for alert notifications (when provider=sns) | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags for AWS resources | `map(string)` | `{}` | no |
| <a name="input_tempo_retention_hours"></a> [tempo\_retention\_hours](#input\_tempo\_retention\_hours) | Retention period for Tempo traces in hours | `number` | `168` | no |
| <a name="input_wordpress_namespace"></a> [wordpress\_namespace](#input\_wordpress\_namespace) | Namespace where WordPress is deployed (for ServiceMonitor targeting) | `string` | `"wordpress"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alerting_enabled"></a> [alerting\_enabled](#output\_alerting\_enabled) | Current alerting toggle state |
| <a name="output_alertmanager_config_deployed"></a> [alertmanager\_config\_deployed](#output\_alertmanager\_config\_deployed) | Alertmanager configuration deployment status |
| <a name="output_alertmanager_namespace"></a> [alertmanager\_namespace](#output\_alertmanager\_namespace) | Namespace where Alertmanager is deployed |
| <a name="output_dashboard_configmaps"></a> [dashboard\_configmaps](#output\_dashboard\_configmaps) | List of dashboard ConfigMap names created for Grafana provisioning |
| <a name="output_fluentbit_namespace"></a> [fluentbit\_namespace](#output\_fluentbit\_namespace) | Namespace where Fluent Bit is deployed |
| <a name="output_grafana_admin_secret_name"></a> [grafana\_admin\_secret\_name](#output\_grafana\_admin\_secret\_name) | Kubernetes secret containing Grafana admin credentials |
| <a name="output_grafana_dashboard_folders"></a> [grafana\_dashboard\_folders](#output\_grafana\_dashboard\_folders) | List of Grafana folders created for dashboard organization |
| <a name="output_grafana_url"></a> [grafana\_url](#output\_grafana\_url) | Grafana service URL |
| <a name="output_notification_provider"></a> [notification\_provider](#output\_notification\_provider) | Configured notification provider for alerts |
| <a name="output_prometheus_namespace"></a> [prometheus\_namespace](#output\_prometheus\_namespace) | Namespace where Prometheus is deployed |
| <a name="output_prometheus_rules_count"></a> [prometheus\_rules\_count](#output\_prometheus\_rules\_count) | Number of deployed PrometheusRule resources |
| <a name="output_prometheus_rules_deployed"></a> [prometheus\_rules\_deployed](#output\_prometheus\_rules\_deployed) | List of deployed PrometheusRule resource names |
| <a name="output_yace_namespace"></a> [yace\_namespace](#output\_yace\_namespace) | Namespace where YACE exporter is deployed |
| <a name="output_yace_role_arn"></a> [yace\_role\_arn](#output\_yace\_role\_arn) | IAM role ARN for YACE IRSA |
| <a name="output_yace_service_name"></a> [yace\_service\_name](#output\_yace\_service\_name) | Service name for YACE exporter |
<!-- END_TF_DOCS -->