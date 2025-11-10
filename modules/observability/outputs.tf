output "namespace" {
  value       = var.namespace
  description = "Namespace used for observability agents"
}

output "log_groups" {
  description = "CloudWatch log group names for app/dataplane/host"
  value = {
    application = try(aws_cloudwatch_log_group.app[0].name, null)
    dataplane   = try(aws_cloudwatch_log_group.dataplane[0].name, null)
    host        = try(aws_cloudwatch_log_group.host[0].name, null)
  }
}

output "cwagent_role_arn" {
  description = "IAM role ARN for CloudWatch Agent"
  value       = try(aws_iam_role.cwagent[0].arn, null)
}

output "fluentbit_role_arn" {
  description = "IAM role ARN for Fluent Bit"
  value       = try(aws_iam_role.fluentbit[0].arn, null)
}
