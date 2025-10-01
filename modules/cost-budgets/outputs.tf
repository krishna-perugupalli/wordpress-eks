output "budget_name" {
  description = "AWS Budget name."
  value       = aws_budgets_budget.this.name
}

output "budget_id" {
  description = "Terraform resource ID for the budget."
  value       = aws_budgets_budget.this.id
}

output "sns_topic_arn" {
  description = "SNS topic ARN used (created or existing). Empty if none."
  value       = coalesce(try(aws_sns_topic.budgets[0].arn, null), var.existing_sns_topic_arn, "")
}
