output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.this.arn
}

output "cluster_id" {
  description = "Aurora cluster ID"
  value       = aws_rds_cluster.this.id
}

output "writer_endpoint" {
  description = "Cluster writer endpoint"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Cluster reader endpoint"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "db_security_group_id" {
  description = "Security group ID attached to the cluster"
  value       = aws_security_group.db.id
}

output "admin_secret_arn" {
  description = "Secrets Manager secret ARN with admin creds + endpoints"
  value       = aws_secretsmanager_secret.admin.arn
}
