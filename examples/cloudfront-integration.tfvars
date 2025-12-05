# CloudFront Integration Example Configuration
# This example shows how to properly configure DNS coordination between ALB and CloudFront

# Basic project configuration
project     = "wp-cf-demo"
env         = "production"
region      = "eu-central-1"
owner_email = "admin@example.com"

# Domain and DNS configuration
wordpress_domain_name    = "wordpress.example.com"
wordpress_hosted_zone_id = "Z1234567890ABC" # Replace with your actual hosted zone ID

# ALB Certificate (regional - eu-central-1)
alb_certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# CloudFront Configuration
enable_cloudfront          = true
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/87654321-4321-4321-4321-210987654321"
cloudfront_aliases         = ["www.wordpress.example.com"]
cloudfront_price_class     = "PriceClass_100"
cloudfront_enable_http3    = true
cloudfront_origin_secret   = "super-secret-origin-header-value"

# DNS Coordination - Option 1: CloudFront enabled (recommended)
create_alb_route53_record        = false # ALB should not create Route53 record when CloudFront is enabled
create_cloudfront_route53_record = true  # CloudFront creates the Route53 record

# DNS Coordination - Option 2: ALB only (for testing/fallback)
# enable_cloudfront                = false
# create_alb_route53_record        = true   # ALB creates the Route53 record
# create_cloudfront_route53_record = false  # CloudFront does not create Route53 record

# Security configuration
enable_cloudfront_restriction = true # Restrict ALB to CloudFront IPs only
create_waf                    = true
waf_rate_limit                = 100

# Infrastructure sizing
vpc_cidr         = "10.80.0.0/16"
private_cidrs    = ["10.80.0.0/20", "10.80.16.0/20", "10.80.32.0/20"]
public_cidrs     = ["10.80.128.0/24", "10.80.129.0/24", "10.80.130.0/24"]
nat_gateway_mode = "single"

# EKS configuration
cluster_version        = "1.32"
endpoint_public_access = false
system_node_type       = "t3.medium"
system_node_min        = 2
system_node_max        = 3

# Database configuration
db_serverless_min_acu    = 2
db_serverless_max_acu    = 16
db_backup_retention_days = 7

# Security baseline
create_cloudtrail = true
create_config     = true
create_guardduty  = true