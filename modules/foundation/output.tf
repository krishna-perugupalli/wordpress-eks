output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
}

output "private_subnet_ids" {
  value = [for k in sort(keys(aws_subnet.private)) : aws_subnet.private[k].id]
}

output "kms_rds_arn" {
  value = aws_kms_key.rds.arn
}

output "kms_efs_arn" {
  value = aws_kms_key.efs.arn
}

output "kms_logs_arn" {
  value = aws_kms_key.logs.arn
}

output "kms_s3_arn" {
  value = aws_kms_key.s3.arn
}

output "media_bucket" {
  value = aws_s3_bucket.media.bucket
}

output "logs_bucket" {
  value = aws_s3_bucket.logs.bucket
}

output "ecr_repo_url" {
  value = aws_ecr_repository.wp.repository_url
}

output "public_zone_id" {
  value       = try(aws_route53_zone.public[0].zone_id, null)
  description = "Route53 hosted zone ID if created"
}

output "azs" {
  description = "Availability Zones used for subnets (in order)"
  value       = local.azs
}
