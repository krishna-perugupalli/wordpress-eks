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
<!-- END_TF_DOCS -->

## Notes

- Budget alerts are sent via SNS and email
- Thresholds are percentages of the monthly limit
- Forecasted alerts help predict cost overruns before they occur
- Budget data updates approximately every 8-12 hours
