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
