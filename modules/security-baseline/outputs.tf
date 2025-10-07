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
  value       = aws_s3_bucket.security_logs.bucket
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID (null if disabled)"
  value       = try(aws_guardduty_detector.this[0].id, null)
}
