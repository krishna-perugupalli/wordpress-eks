output "trail_arn" {
  description = "CloudTrail ARN (null if trail disabled)"
  value       = try(aws_cloudtrail.this[0].arn, null)
}

output "kms_key_arn" {
  description = "KMS CMK ARN for security logs"
  value       = aws_kms_key.logs.arn
}

output "security_logs_bucket" {
  description = "S3 bucket for security logs"
  value       = local.security_logs_bucket_name
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID (null if disabled)"
  value       = local.guardduty_detector_id_effective
}
