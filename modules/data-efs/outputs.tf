output "file_system_id" {
  description = "EFS File System ID"
  value       = aws_efs_file_system.this.id
}

output "security_group_id" {
  description = "EFS security group ID"
  value       = aws_security_group.efs.id
}

output "access_point_id" {
  description = "EFS Access Point ID (null if AP disabled)"
  value       = try(aws_efs_access_point.ap[0].id, null)
}
