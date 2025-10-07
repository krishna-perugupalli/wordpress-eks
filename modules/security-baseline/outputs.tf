output "trail_arn" {
  description = "CloudTrail ARN"
  value       = aws_cloudtrail.this.arn
}

output "logs_bucket_name" {
  description = "S3 bucket for CloudTrail/Config logs"
  value       = aws_s3_bucket.security_logs.bucket
}

output "kms_key_arn" {
  description = "KMS key ARN used for security logs"
  value       = aws_kms_key.security_logs.arn
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.this.id
}

output "security_logs_bucket" {
  value       = aws_s3_bucket.security_logs.bucket
  description = "S3 bucket name for security logs"
}
