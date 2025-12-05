# Example configuration for CloudFront with ALB origin protection
# This example shows how to configure secure CloudFront distribution with ALB origin protection

# Basic project configuration
project     = "wordpress-secure"
env         = "prod"
region      = "eu-central-1"
owner_email = "admin@example.com"

# WordPress domain configuration
wordpress_domain_name    = "secure-wp.example.com"
wordpress_hosted_zone_id = "Z1234567890ABC"

# Certificate configuration (must be created manually beforehand)
alb_certificate_arn        = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/87654321-4321-4321-4321-210987654321"

# CloudFront configuration
enable_cloudfront                = true
cloudfront_price_class           = "PriceClass_100"
cloudfront_enable_http3          = true
cloudfront_aliases               = ["www.secure-wp.example.com"]
create_cloudfront_route53_record = true

# Origin Protection Configuration
# This is the key security feature that blocks direct ALB access
enable_alb_origin_protection        = true
cloudfront_origin_secret            = "super-secret-origin-key-2024" # Use a strong, unique secret
alb_origin_protection_response_code = 403
alb_origin_protection_response_body = "Access Denied - Direct access not allowed"

# CloudFront restriction (optional additional security)
enable_cloudfront_restriction = true

# Route53 configuration
create_alb_route53_record = false # Disable direct ALB DNS record when using CloudFront

# Security configuration
create_waf               = true
enable_security_baseline = true
enable_cost_budgets      = true

# EKS configuration
eks_cluster_version = "1.30"
eks_node_groups = {
  main = {
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 10
    desired_size   = 3
    capacity_type  = "ON_DEMAND"
  }
}

# Database configuration
aurora_engine_version = "8.0.mysql_aurora.3.05.2"
aurora_instance_class = "db.serverless"
aurora_serverlessv2_scaling = {
  max_capacity = 16
  min_capacity = 0.5
}

# Storage configuration
efs_performance_mode                = "generalPurpose"
efs_throughput_mode                 = "provisioned"
efs_provisioned_throughput_in_mibps = 100

# WordPress configuration
wordpress_pod_port = 8080

# Monitoring and logging
enable_cloudwatch_logs = true
log_retention_days     = 30

# Backup configuration
backup_retention_period = 7
backup_window           = "03:00-04:00"
maintenance_window      = "sun:04:00-sun:05:00"

# Tags
additional_tags = {
  Environment = "production"
  Application = "wordpress"
  Security    = "origin-protected"
  CostCenter  = "marketing"
  Backup      = "enabled"
}

# Network configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

# Security groups (additional customization if needed)
additional_security_group_rules = []

# Karpenter configuration for cost optimization
enable_karpenter = true
karpenter_node_pools = {
  default = {
    requirements = [
      {
        key      = "karpenter.sh/capacity-type"
        operator = "In"
        values   = ["spot", "on-demand"]
      },
      {
        key      = "node.kubernetes.io/instance-type"
        operator = "In"
        values   = ["t3.medium", "t3.large", "t3.xlarge"]
      }
    ]
    limits = {
      cpu    = 1000
      memory = "1000Gi"
    }
    disruption = {
      consolidation_policy = "WhenUnderutilized"
      consolidate_after    = "30s"
      expire_after         = "2160h" # 90 days
    }
  }
}

# Cost optimization
enable_spot_instances    = true
spot_allocation_strategy = "diversified"

# Compliance and governance
enable_config_rules = true
enable_cloudtrail   = true
enable_guardduty    = true

# Performance optimization
enable_efs_intelligent_tiering     = true
enable_aurora_performance_insights = true