output "primary_endpoint_address" {
  description = "Primary endpoint address (write)."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Reader endpoint address (read)."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "security_group_id" {
  description = "Security group ID for Redis."
  value       = aws_security_group.redis.id
}
