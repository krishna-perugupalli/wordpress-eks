variable "region" {
  description = "AWS region (e.g., eu-north-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project/environment short name; used as cluster name and tag prefix (e.g., wp-sbx)"
  type        = string
  default     = "wdp"
}

variable "env" {
  description = "Environment name for the project"
  type        = string
  default     = "sandbox"
}

variable "owner_email" {
  description = "Owner/Contact email tag"
  type        = string
  default     = "admin@example.com"
}

variable "tags" {
  description = "Extra tags merged into all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------
# Foundation (VPC / networking)
# ---------------------------
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.80.0.0/16"
}

variable "private_cidrs" {
  description = "Private subnet CIDRs (3 AZs)"
  type        = list(string)
  default     = ["10.80.0.0/20", "10.80.16.0/20", "10.80.32.0/20"]
}

variable "public_cidrs" {
  description = "Public subnet CIDRs (3 AZs)"
  type        = list(string)
  default     = ["10.80.128.0/24", "10.80.129.0/24", "10.80.130.0/24"]
}

variable "nat_gateway_mode" {
  description = "NAT gateway strategy: single or ha"
  type        = string
  default     = "single"
  validation {
    condition     = contains(["single", "ha"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be one of: single, ha."
  }
}

variable "public_access_cidrs" {
  description = "Allowed CIDRs for public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------
# EKS Core
# ---------------------------
variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.32"
}

variable "endpoint_public_access" {
  description = "Expose EKS public endpoint"
  type        = bool
  default     = false
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts (OIDC)"
  type        = bool
  default     = true
}

variable "enable_cni_prefix_delegation" {
  description = "Enable CNI prefix delegation for higher pod density"
  type        = bool
  default     = true
}

variable "system_node_type" {
  description = "Instance type for system/nodegroup"
  type        = string
  default     = "t3.medium"
}

variable "system_node_min" {
  description = "Min nodes for system node group"
  type        = number
  default     = 2
}

variable "system_node_max" {
  description = "Max nodes for system node group"
  type        = number
  default     = 3
}

variable "admin_role_arns" {
  type    = list(string)
  default = []
}

variable "node_ami_type" {
  description = "EKS AMI type (e.g., AL2023_x86_64_STANDARD, BOTTLEROCKET_x86_64)"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT (keep ON_DEMAND for system NG)"
  type        = string
  default     = "ON_DEMAND"
}

variable "node_disk_size_gb" {
  description = "Root disk size for system node group"
  type        = number
  default     = 50
}

variable "enable_cluster_logs" {
  description = "Enable control plane logs"
  type        = bool
  default     = true
}

variable "control_plane_log_retention_days" {
  description = "CloudWatch retention for control plane logs"
  type        = number
  default     = 30
}

variable "eks_cluster_management_role_trust_principals" {
  default = []
}

variable "cni_prefix_warm_target" {
  description = "WARM_PREFIX_TARGET for VPC CNI when prefix delegation is enabled"
  type        = number
  default     = 1
}

# ---------------------------
# Aurora MySQL (Serverless v2)
# ---------------------------
variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "wordpress"
}

variable "db_admin_username" {
  description = "Aurora admin username"
  type        = string
  default     = "wpadmin"
}

variable "db_create_random_password" {
  description = "Create random admin password"
  type        = bool
  default     = true
}

variable "db_serverless_min_acu" {
  description = "Aurora Serverless v2 min ACUs"
  type        = number
  default     = 2
}

variable "db_serverless_max_acu" {
  description = "Aurora Serverless v2 max ACUs"
  type        = number
  default     = 16
}

variable "db_backup_retention_days" {
  description = "Aurora backup retention in days"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Aurora preferred backup window (UTC)"
  type        = string
  default     = "02:00-03:00"
}

variable "db_maintenance_window" {
  description = "Aurora preferred maintenance window (UTC)"
  type        = string
  default     = "sun:03:00-sun:04:00"
}

variable "db_deletion_protection" {
  description = "Enable Aurora deletion protection"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip creating a final snapshot when destroying the Aurora cluster"
  type        = bool
  default     = true
}

# AWS Backup for Aurora
variable "db_enable_backup" {
  description = "Enable AWS Backup for Aurora"
  type        = bool
  default     = true
}

variable "backup_vault_name" {
  description = "AWS Backup vault name to use"
  type        = string
  default     = ""
}

variable "db_backup_cron" {
  description = "AWS Backup cron for Aurora"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

variable "db_backup_delete_after_days" {
  description = "Days to retain Aurora backups in Backup vault"
  type        = number
  default     = 7
}

# ---------------------------
# EFS
# ---------------------------
variable "efs_kms_key_arn" {
  description = "KMS key ARN for EFS; null for AWS-managed key"
  type        = string
  default     = null
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

variable "efs_enable_lifecycle_ia" {
  description = "Enable lifecycle to IA (transition after 30 days)"
  type        = bool
  default     = true
}

variable "efs_ap_path" {
  description = "EFS access point path"
  type        = string
  default     = "/wp-content"
}

variable "efs_ap_owner_uid" {
  description = "UID owner for EFS AP"
  type        = number
  default     = 33
}

variable "efs_ap_owner_gid" {
  description = "GID owner for EFS AP"
  type        = number
  default     = 33
}

# AWS Backup for EFS
variable "efs_enable_backup" {
  description = "Enable AWS Backup for EFS"
  type        = bool
  default     = true
}

variable "efs_backup_cron" {
  description = "AWS Backup cron for EFS"
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "efs_backup_delete_after_days" {
  description = "Days to retain EFS backups in Backup vault"
  type        = number
  default     = 30
}

# ---------------------------
# Security baseline
# ---------------------------
variable "create_cloudtrail" {
  description = "Create a multi-region account-level CloudTrail."
  type        = bool
  default     = false
}

variable "create_config" {
  description = "Enable AWS Config recorder + delivery channel."
  type        = bool
  default     = false
}

variable "create_guardduty" {
  description = "Enable GuardDuty detector in this account/region."
  type        = bool
  default     = false
}

# --------------------
# EKS Admin Users/Roles
# --------------------

variable "eks_admin_role_arns" {
  description = "IAM Role ARNs (incl. SSO permission-set roles) to grant EKS cluster-admin."
  type        = list(string)
  default     = []
}

variable "eks_admin_user_arns" {
  description = "IAM User ARNs to grant EKS cluster-admin."
  type        = list(string)
  default     = []
}

# ---------------------------
# Standalone ALB Configuration
# ---------------------------

variable "wordpress_domain_name" {
  description = "Domain name for WordPress site (e.g., wordpress.example.com)"
  type        = string
  default     = ""
}

variable "wordpress_hosted_zone_id" {
  description = "Route53 hosted zone ID for WordPress domain"
  type        = string
  default     = ""
}

variable "create_alb_route53_record" {
  description = "Whether to create Route53 A record for ALB"
  type        = bool
  default     = true
}

variable "enable_cloudfront_restriction" {
  description = "Restrict ALB ingress to CloudFront IP ranges only"
  type        = bool
  default     = false
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection on ALB"
  type        = bool
  default     = false
}

variable "wordpress_pod_port" {
  description = "Port where WordPress pods are listening"
  type        = number
  default     = 8080
}

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for ALB HTTPS listener (must be created and validated manually as prerequisite)"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:acm:", var.alb_certificate_arn))
    error_message = "The alb_certificate_arn must be a valid ACM certificate ARN starting with 'arn:aws:acm:'."
  }
}

variable "waf_acl_arn" {
  description = "WAF WebACL ARN for ALB association (if not creating new WAF in this stack)"
  type        = string
  default     = ""
}

variable "create_waf" {
  description = "Create WAF WebACL for ALB in infrastructure stack"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit for wp-login.php (requests per 5 minutes)"
  type        = number
  default     = 100
}

variable "waf_enable_managed_rules" {
  description = "Enable AWS Managed Rules (Common Rule Set) for OWASP Top 10 protection"
  type        = bool
  default     = true
}

# ---------------------------
# CloudFront Integration (Optional)
# ---------------------------

variable "enable_cloudfront" {
  description = "Enable CloudFront distribution deployment"
  type        = bool
  default     = false
}

variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN from us-east-1 for CloudFront (required when enable_cloudfront is true)"
  type        = string
  default     = ""
  validation {
    condition     = var.cloudfront_certificate_arn == "" || can(regex("^arn:aws(-[a-z]+)?:acm:us-east-1:[0-9]{12}:certificate/.+$", var.cloudfront_certificate_arn))
    error_message = "CloudFront requires an ACM certificate in us-east-1. Provide a us-east-1 ACM certificate ARN."
  }
}

variable "cloudfront_aliases" {
  description = "Additional domain aliases for CloudFront distribution"
  type        = list(string)
  default     = []
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "CloudFront price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "cloudfront_enable_http3" {
  description = "Enable HTTP/3 (QUIC) for CloudFront distribution"
  type        = bool
  default     = false
}

variable "cloudfront_origin_secret" {
  description = "Optional shared secret header value for CloudFront origin protection"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_alb_origin_protection" {
  description = "Enable ALB origin protection to block direct access and only allow CloudFront traffic with valid origin secret"
  type        = bool
  default     = false
}

variable "alb_origin_protection_response_code" {
  description = "HTTP response code to return when ALB origin secret validation fails"
  type        = number
  default     = 403
  validation {
    condition     = contains([400, 401, 403, 404, 503], var.alb_origin_protection_response_code)
    error_message = "ALB origin protection response code must be one of: 400, 401, 403, 404, 503."
  }
}

variable "alb_origin_protection_response_body" {
  description = "Response body to return when ALB origin secret validation fails"
  type        = string
  default     = "Access Denied - Direct access not allowed"
}





variable "create_cloudfront_route53_record" {
  description = "Whether to create Route53 A record pointing to CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_geo_restriction_type" {
  description = "Type of geo restriction for CloudFront (none, whitelist, blacklist)"
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.cloudfront_geo_restriction_type)
    error_message = "CloudFront geo restriction type must be one of: none, whitelist, blacklist."
  }
}

variable "cloudfront_geo_restriction_locations" {
  description = "List of country codes for CloudFront geo restriction (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for location in var.cloudfront_geo_restriction_locations :
      can(regex("^[A-Z]{2}$", location))
    ])
    error_message = "CloudFront geo restriction locations must be valid ISO 3166-1 alpha-2 country codes (e.g., US, GB, DE)."
  }
}

variable "cloudfront_enable_compression" {
  description = "Enable automatic content compression (Gzip/Brotli) for CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_enable_logging" {
  description = "Enable CloudFront access logging to S3 bucket"
  type        = bool
  default     = true
}

variable "cloudfront_log_include_cookies" {
  description = "Include cookies in CloudFront access logs"
  type        = bool
  default     = false
}

variable "cloudfront_log_prefix" {
  description = "Prefix for CloudFront access log files in S3 bucket"
  type        = string
  default     = "cloudfront-logs/"
}

variable "cloudfront_enable_real_time_logs" {
  description = "Enable CloudFront real-time logs"
  type        = bool
  default     = false
}

variable "cloudfront_real_time_log_config_arn" {
  description = "ARN of the real-time log configuration for CloudFront"
  type        = string
  default     = ""
}

variable "cloudfront_enable_origin_shield" {
  description = "Enable CloudFront Origin Shield for improved cache hit ratio"
  type        = bool
  default     = false
}

variable "cloudfront_origin_shield_region" {
  description = "AWS region for CloudFront Origin Shield (should be closest to your origin)"
  type        = string
  default     = "eu-central-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.cloudfront_origin_shield_region))
    error_message = "CloudFront Origin Shield region must be a valid AWS region (e.g., us-east-1, eu-central-1)."
  }
}

variable "cloudfront_custom_error_responses" {
  description = "List of custom error response configurations for CloudFront"
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  default = [
    {
      error_code            = 400
      response_code         = 400
      response_page_path    = "/400.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 403
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 404
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 500
      response_code         = 500
      response_page_path    = "/500.html"
      error_caching_min_ttl = 60
    },
    {
      error_code            = 502
      response_code         = 502
      response_page_path    = "/502.html"
      error_caching_min_ttl = 60
    },
    {
      error_code            = 503
      response_code         = 503
      response_page_path    = "/503.html"
      error_caching_min_ttl = 60
    },
    {
      error_code            = 504
      response_code         = 504
      response_page_path    = "/504.html"
      error_caching_min_ttl = 60
    }
  ]
  validation {
    condition = alltrue([
      for response in var.cloudfront_custom_error_responses :
      response.error_code >= 400 && response.error_code <= 599 &&
      response.response_code >= 200 && response.response_code <= 599 &&
      response.error_caching_min_ttl >= 0
    ])
    error_message = "CloudFront custom error responses must have valid HTTP status codes (error_code: 400-599, response_code: 200-599) and non-negative caching TTL."
  }
}

variable "cloudfront_waf_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN (CLOUDFRONT scope) for CloudFront distribution"
  type        = string
  default     = ""
  validation {
    condition     = var.cloudfront_waf_web_acl_arn == "" || can(regex("^arn:aws(-[a-z]+)?:wafv2:[a-z0-9-]+:[0-9]{12}:global/webacl/.+$", var.cloudfront_waf_web_acl_arn))
    error_message = "CloudFront WAF Web ACL ARN must be a valid global WAFv2 Web ACL ARN or empty string."
  }
}

variable "cloudfront_minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version for CloudFront distribution"
  type        = string
  default     = "TLSv1.2_2021"
  validation {
    condition = contains([
      "SSLv3", "TLSv1", "TLSv1_2016", "TLSv1.1_2016", "TLSv1.2_2018", "TLSv1.2_2019", "TLSv1.2_2021"
    ], var.cloudfront_minimum_protocol_version)
    error_message = "CloudFront minimum protocol version must be one of: SSLv3, TLSv1, TLSv1_2016, TLSv1.1_2016, TLSv1.2_2018, TLSv1.2_2019, TLSv1.2_2021."
  }
}

variable "cloudfront_enable_ipv6" {
  description = "Enable IPv6 support for CloudFront distribution"
  type        = bool
  default     = true
}

variable "cloudfront_default_root_object" {
  description = "Default root object for CloudFront distribution"
  type        = string
  default     = "index.php"
}

variable "cloudfront_enable_smooth_streaming" {
  description = "Enable Microsoft Smooth Streaming for media content"
  type        = bool
  default     = false
}
