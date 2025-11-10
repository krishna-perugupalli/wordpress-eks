locals {
  limit_amount_str = tostring(var.limit_amount)

  # Resolve the SNS topic ARN we’ll use:
  # 1) if create_sns_topic=true -> use created topic
  # 2) else if existing_sns_topic_arn != "" -> use that
  # 3) else -> no SNS (emails only)
  resolved_sns_topic_arn = var.create_sns_topic ? aws_sns_topic.budgets[0].arn : (var.existing_sns_topic_arn != "" ? var.existing_sns_topic_arn : null)
  sns_topic_arns_list    = local.resolved_sns_topic_arn != null ? [local.resolved_sns_topic_arn] : []
}

# --- Optional SNS topic creation ---
resource "aws_sns_topic" "budgets" {
  count             = var.create_sns_topic ? 1 : 0
  name              = coalesce(var.sns_topic_name, "${var.name}-budgets-alerts")
  kms_master_key_id = var.sns_topic_kms_key_id
  tags              = var.tags
}

# Allow AWS Budgets to publish to the SNS topic we created
data "aws_iam_policy_document" "sns_publish" {
  count = var.create_sns_topic ? 1 : 0

  statement {
    sid     = "AllowBudgetsToPublish"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    resources = [aws_sns_topic.budgets[0].arn]
  }
}

resource "aws_sns_topic_policy" "budgets" {
  count  = var.create_sns_topic ? 1 : 0
  arn    = aws_sns_topic.budgets[0].arn
  policy = data.aws_iam_policy_document.sns_publish[0].json
}

# Optional: subscribe emails to the created topic (recipients must confirm)
resource "aws_sns_topic_subscription" "email" {
  count     = var.create_sns_topic ? length(var.sns_subscription_emails) : 0
  topic_arn = aws_sns_topic.budgets[0].arn
  protocol  = "email"
  endpoint  = var.sns_subscription_emails[count.index]
}

# --- AWS Budget ---

resource "aws_budgets_budget" "this" {
  name         = var.name
  budget_type  = "COST"
  time_unit    = var.time_unit
  limit_amount = local.limit_amount_str
  limit_unit   = var.currency

  # FORECASTED alert
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.forecast_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.sns_topic_arns_list
  }

  # ACTUAL alert
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.actual_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
    subscriber_sns_topic_arns  = local.sns_topic_arns_list
  }
}
