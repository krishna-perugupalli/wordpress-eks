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

output "backup_service_role_arn" {
  description = "IAM role ARN used by AWS Backup for this Aurora cluster (null if backups disabled or external role provided)."
  value       = local.backup_service_role_arn_effective
}
