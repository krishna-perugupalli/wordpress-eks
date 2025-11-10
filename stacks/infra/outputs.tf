# EKS
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

# Networking/KMS
output "vpc_id" {
  value = module.foundation.vpc_id
}

output "private_subnet_ids" {
  value = module.foundation.private_subnet_ids
}

output "kms_logs_arn" {
  value = module.security_baseline.kms_key_arn
}

# Data layer
output "writer_endpoint" {
  value = module.data_aurora.writer_endpoint
}

output "aurora_master_secret_arn" {
  description = "Secrets Manager ARN for the Aurora master user credentials"
  value       = module.data_aurora.master_user_secret_arn
}

output "redis_endpoint" {
  value = module.elasticache.primary_endpoint_address
}

# Secrets
output "wpapp_db_secret_arn" {
  value = module.secrets_iam.wpapp_db_secret_arn
}

output "wp_admin_secret_arn" {
  value = module.secrets_iam.wp_admin_secret_arn
}

output "redis_auth_secret_arn" {
  value = module.secrets_iam.redis_auth_secret_arn
}

## Region
output "region" {
  value       = var.region
  description = "AWS region for the stack"
}

output "secrets_read_policy_arn" {
  description = "IAM policy ARN that grants External Secrets Operator read access."
  value       = module.secrets_iam.secrets_read_policy_arn
}

output "cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}
output "node_role_arn" {
  value = aws_iam_role.eks_node_group_role.arn
}

output "log_bucket_name" {
  description = "CloudFront log S3 bucket name"
  value       = module.foundation.logs_bucket
}

output "azs" {
  description = "Availability Zones used by the foundation module"
  value       = module.foundation.azs
}

output "eso_role_arn" {
  description = "IAM Role ARN for the External Secrets Operator (IRSA)."
  value       = module.secrets_iam.eso_role_arn
}

output "karpenter_role_arn" {
  description = "IAM Role ARN for the Karpenter Controller (IRSA)."
  value       = module.karpenter.iam_role_arn
}

output "karpenter_sqs_queue_name" {
  description = "SQS queue name for Karpenter interruptions."
  value       = module.karpenter.queue_name
}

output "karpenter_node_iam_role_name" {
  description = "IAM Role name for Karpenter nodes."
  value       = module.karpenter.node_iam_role_name
}

output "file_system_id" {
  description = "EFS File System ID"
  value       = module.data_efs.file_system_id
}
