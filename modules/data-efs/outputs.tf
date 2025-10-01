output "filesystem_id" {
  description = "EFS filesystem ID"
  value       = aws_efs_file_system.this.id
}

output "access_point_id" {
  description = "Fixed access point ID (if created)"
  value       = try(aws_efs_access_point.wp[0].id, null)
}

output "mount_security_group_id" {
  description = "Security group ID required to mount EFS"
  value       = aws_security_group.efs.id
}

output "storageclass_dynamic_name" {
  description = "Name of the dynamic AP StorageClass"
  value       = kubernetes_storage_class_v1.efs_ap.metadata[0].name
}

output "storageclass_static_name" {
  description = "Name of the static AP StorageClass (if created)"
  value       = try(kubernetes_storage_class_v1.efs_ap_static[0].metadata[0].name, null)
}
