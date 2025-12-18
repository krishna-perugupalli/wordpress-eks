# EKS
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
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

# ACM Certificate (provided as prerequisite)
output "alb_certificate_arn" {
  description = "Regional ACM certificate ARN for ALB (passed through from variable)"
  value       = var.alb_certificate_arn
}

# WAF
output "waf_regional_arn" {
  description = "WAF WebACL ARN for ALB"
  value       = var.create_waf ? module.waf_regional[0].waf_arn : var.waf_acl_arn
}

# Standalone ALB
output "alb_arn" {
  description = "ARN of the standalone ALB"
  value       = module.standalone_alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the standalone ALB"
  value       = module.standalone_alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the standalone ALB"
  value       = module.standalone_alb.alb_zone_id
}

output "alb_security_group_id" {
  description = "Security group ID of the ALB"
  value       = module.standalone_alb.alb_security_group_id
}

output "target_group_arn" {
  description = "ARN of the target group for WordPress"
  value       = module.standalone_alb.target_group_arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = module.standalone_alb.target_group_name
}

output "route53_record_fqdn" {
  description = "FQDN of the created Route53 record"
  value       = module.standalone_alb.route53_record_fqdn
}

output "route53_record_type" {
  description = "Type of Route53 record created (alb or cloudfront)"
  value       = module.standalone_alb.route53_record_type
}

output "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  value       = module.foundation.public_subnet_ids
}

# CloudFront (conditional outputs)
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_id : ""
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_domain_name : ""
}

output "cloudfront_distribution_zone_id" {
  description = "CloudFront distribution zone ID"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_zone_id : "Z2FDTNDATAQYW2"
}

output "cloudfront_enabled" {
  description = "Whether CloudFront is enabled"
  value       = var.enable_cloudfront
}

# CloudFront Route53 Integration Outputs
output "cloudfront_route53_record_fqdn" {
  description = "FQDN of the Route53 record pointing to CloudFront"
  value       = var.enable_cloudfront ? module.cloudfront[0].route53_record_fqdn : ""
}

output "cloudfront_route53_alias_fqdns" {
  description = "FQDNs of alias Route53 records pointing to CloudFront"
  value       = var.enable_cloudfront ? module.cloudfront[0].route53_alias_fqdns : []
}

output "cloudfront_dns_validation" {
  description = "CloudFront DNS configuration validation information"
  value = var.enable_cloudfront ? module.cloudfront[0].dns_validation : {
    cloudfront_domain_name = ""
    cloudfront_zone_id     = ""
    primary_domain         = ""
    aliases                = []
    hosted_zone_valid      = null
  }
}

output "dns_coordination_status" {
  description = "Status of DNS coordination between ALB and CloudFront"
  value = {
    alb_route53_created        = var.create_alb_route53_record && !var.enable_cloudfront
    cloudfront_route53_created = var.enable_cloudfront && var.create_cloudfront_route53_record
    cloudfront_enabled         = var.enable_cloudfront
    domain_name                = var.wordpress_domain_name
    hosted_zone_id             = var.wordpress_hosted_zone_id
    coordination_valid         = local.dns_coordination_valid
  }
}

# ALB DNS Validation
output "alb_dns_validation" {
  description = "ALB DNS configuration validation information"
  value       = module.standalone_alb.dns_validation
}

# ALB Origin Protection
output "alb_origin_protection_enabled" {
  description = "Whether ALB origin protection is enabled"
  value       = module.standalone_alb.origin_protection_enabled
}

output "alb_origin_protection_config" {
  description = "ALB origin protection configuration details"
  value       = module.standalone_alb.origin_protection_config
  sensitive   = true
}

output "alb_listener_rule_arns" {
  description = "ARNs of the ALB origin secret validation listener rules"
  value       = module.standalone_alb.listener_rule_arns
  sensitive   = true
}
