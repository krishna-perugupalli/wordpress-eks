output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.this.arn
}

output "writer_endpoint" {
  description = "Writer endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "security_group_id" {
  description = "Aurora security group ID"
  value       = aws_security_group.db.id
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN containing the managed master user credentials"
  value       = try(aws_rds_cluster.this.master_user_secret[0].secret_arn, null)
}
