# Cost Budgets Module

This module creates AWS Budgets for cost monitoring and alerting.

## Overview

The cost-budgets module helps track AWS spending and sends notifications when costs exceed defined thresholds. It supports monthly budgets with customizable alert thresholds.

## Features

- Monthly cost budgets with configurable limits
- Multiple alert thresholds (e.g., 80%, 100%, 120%)
- SNS topic integration for notifications
- Email notifications for budget alerts
- Forecasted vs actual cost tracking

## Usage

```hcl
module "cost_budgets" {
  source = "../../modules/cost-budgets"

  name              = "wordpress-eks"
  monthly_limit_usd = 500
  
  alert_thresholds = [80, 100, 120]
  alert_emails     = ["devops@example.com"]
  
  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_budgets_budget.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_sns_topic.budgets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.budgets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_iam_policy_document.sns_publish](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_limit_amount"></a> [limit\_amount](#input\_limit\_amount) | Numeric cost limit for the budget period. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Budget name. Appears in console and notifications. | `string` | n/a | yes |
| <a name="input_actual_threshold_percent"></a> [actual\_threshold\_percent](#input\_actual\_threshold\_percent) | Send ACTUAL alert when spend exceeds this percent. | `number` | `100` | no |
| <a name="input_alert_emails"></a> [alert\_emails](#input\_alert\_emails) | Email recipients for notifications. | `list(string)` | `[]` | no |
| <a name="input_create_sns_topic"></a> [create\_sns\_topic](#input\_create\_sns\_topic) | Create an SNS topic for Budgets notifications. | `bool` | `false` | no |
| <a name="input_currency"></a> [currency](#input\_currency) | Currency code for the budget. | `string` | `"USD"` | no |
| <a name="input_existing_sns_topic_arn"></a> [existing\_sns\_topic\_arn](#input\_existing\_sns\_topic\_arn) | Use an existing SNS topic ARN instead of creating one. | `string` | `""` | no |
| <a name="input_forecast_threshold_percent"></a> [forecast\_threshold\_percent](#input\_forecast\_threshold\_percent) | Send FORECASTED alert when forecasted spend exceeds this percent. | `number` | `80` | no |
| <a name="input_sns_subscription_emails"></a> [sns\_subscription\_emails](#input\_sns\_subscription\_emails) | Email addresses to subscribe to the created SNS topic (create\_sns\_topic=true). Confirmation required by recipients. | `list(string)` | `[]` | no |
| <a name="input_sns_topic_kms_key_id"></a> [sns\_topic\_kms\_key\_id](#input\_sns\_topic\_kms\_key\_id) | KMS key ID/ARN for SNS encryption (optional; null uses AWS managed). | `string` | `null` | no |
| <a name="input_sns_topic_name"></a> [sns\_topic\_name](#input\_sns\_topic\_name) | Name of SNS topic to create (used only when create\_sns\_topic=true). | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for created resources (SNS). | `map(string)` | `{}` | no |
| <a name="input_time_unit"></a> [time\_unit](#input\_time\_unit) | Budget period. | `string` | `"MONTHLY"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_budget_id"></a> [budget\_id](#output\_budget\_id) | Terraform resource ID for the budget. |
| <a name="output_budget_name"></a> [budget\_name](#output\_budget\_name) | AWS Budget name. |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | SNS topic ARN used (created or existing). Empty if none. |
<!-- END_TF_DOCS -->

## Notes

- Budget alerts are sent via SNS and email
- Thresholds are percentages of the monthly limit
- Forecasted alerts help predict cost overruns before they occur
- Budget data updates approximately every 8-12 hours
