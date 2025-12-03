variable "name" {
  description = "Logical name/prefix for CloudFront resources."
  type        = string
}

variable "domain_name" {
  description = "Primary DNS name (CNAME) for the distribution."
  type        = string
}

variable "aliases" {
  description = "Additional CNAMEs."
  type        = list(string)
  default     = []
}

variable "alb_dns_name" {
  description = "Public DNS name of the ALB (custom origin)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront."
  type        = string
  validation {
    condition     = can(regex("^arn:aws(-[a-z]+)?:acm:us-east-1:[0-9]{12}:certificate/.+$", var.acm_certificate_arn))
    error_message = "CloudFront requires an ACM certificate in us-east-1. Provide a us-east-1 ACM certificate ARN."
  }
}

variable "waf_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN (CLOUDFRONT scope). Empty to disable."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)."
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "default_ttl" {
  description = "Default TTL for bypass_auth cache policy."
  type        = number
  default     = 60
  validation {
    condition     = var.default_ttl >= 0
    error_message = <<-EOT
      Cache policy TTL validation failed:
      default_ttl must be >= 0.
      
      Current value: ${var.default_ttl}
      
      AWS CloudFront requirement: TTL values must be non-negative integers.
      
      To resolve:
      - Set default_ttl to 0 or greater
      - For no-cache behavior, use TTL=0 with cookie_behavior="none"
    EOT
  }
}

variable "max_ttl" {
  description = "Max TTL for bypass_auth cache policy."
  type        = number
  default     = 300
  validation {
    condition     = var.max_ttl >= 0
    error_message = <<-EOT
      Cache policy TTL validation failed:
      max_ttl must be >= 0.
      
      Current value: ${var.max_ttl}
      
      AWS CloudFront requirement: TTL values must be non-negative integers.
      
      To resolve:
      - Set max_ttl to 0 or greater
      - For no-cache behavior, use TTL=0 with cookie_behavior="none"
    EOT
  }
}

variable "min_ttl" {
  description = "Min TTL for bypass_auth cache policy."
  type        = number
  default     = 0
  validation {
    condition     = var.min_ttl >= 0
    error_message = <<-EOT
      Cache policy TTL validation failed:
      min_ttl must be >= 0.
      
      Current value: ${var.min_ttl}
      
      AWS CloudFront requirement: TTL values must be non-negative integers.
      
      To resolve:
      - Set min_ttl to 0 or greater
      - For no-cache behavior, use TTL=0 with cookie_behavior="none"
    EOT
  }
}

variable "static_ttl" {
  description = "TTL for static_long policy (e.g., /wp-content/*)."
  type        = number
  default     = 86400
}

variable "log_bucket_name" {
  description = "S3 bucket (name only) for CloudFront logs. Bucket policy must allow CF to write."
  type        = string
}

variable "enable_logging" {
  description = "Enable CloudFront access logging to S3 bucket."
  type        = bool
  default     = true
}

variable "log_prefix" {
  description = "Prefix for CloudFront access log files in S3 bucket."
  type        = string
  default     = "cloudfront-logs/"
}

variable "log_include_cookies" {
  description = "Include cookies in CloudFront access logs."
  type        = bool
  default     = false
}

variable "minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol version for CloudFront distribution."
  type        = string
  default     = "TLSv1.2_2021"
}

variable "is_ipv6_enabled" {
  description = "Enable IPv6 support for CloudFront distribution."
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "Default root object for CloudFront distribution."
  type        = string
  default     = "index.php"
}

variable "compress" {
  description = "Enable Gzip/Brotli compression."
  type        = bool
  default     = true
}

variable "enable_http3" {
  description = "Enable HTTP/3 (QUIC)."
  type        = bool
  default     = false
}

variable "origin_secret_value" {
  description = "Optional shared secret header value (X-Origin-Secret) injected by CloudFront and validated at the origin, if configured. Leave empty to disable."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_header_function" {
  description = "Enable CloudFront Function for header manipulation to prevent redirect loops."
  type        = bool
  default     = true
}

variable "custom_error_responses" {
  description = "List of custom error response configurations for CloudFront."
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
      error_code            = 405
      response_code         = 405
      response_page_path    = "/405.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 414
      response_code         = 414
      response_page_path    = "/414.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 416
      response_code         = 416
      response_page_path    = "/416.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 500
      response_code         = 500
      response_page_path    = "/500.html"
      error_caching_min_ttl = 60
    },
    {
      error_code            = 501
      response_code         = 501
      response_page_path    = "/501.html"
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
}

variable "geo_restriction_type" {
  description = "Type of geo restriction (none, whitelist, blacklist)."
  type        = string
  default     = "none"
  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction_type)
    error_message = "Geo restriction type must be one of: none, whitelist, blacklist."
  }
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restriction (ISO 3166-1 alpha-2)."
  type        = list(string)
  default     = []
}

variable "enable_real_time_logs" {
  description = "Enable CloudFront real-time logs."
  type        = bool
  default     = false
}

variable "real_time_log_config_arn" {
  description = "ARN of the real-time log configuration for CloudFront."
  type        = string
  default     = ""
}

variable "enable_origin_shield" {
  description = "Enable CloudFront Origin Shield for improved cache hit ratio."
  type        = bool
  default     = false
}

variable "origin_shield_region" {
  description = "AWS region for Origin Shield (should be closest to your origin)."
  type        = string
  default     = "eu-central-1"
}

variable "enable_smooth_streaming" {
  description = "Enable Microsoft Smooth Streaming for media content."
  type        = bool
  default     = false
}

variable "trusted_signers" {
  description = "List of AWS account IDs for trusted signers (for signed URLs/cookies)."
  type        = list(string)
  default     = []
}

variable "trusted_key_groups" {
  description = "List of CloudFront key group IDs for trusted signers."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}

# Route53 Integration Variables
variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS record creation"
  type        = string
  default     = ""
}

variable "create_route53_record" {
  description = "Whether to create Route53 A record pointing to CloudFront distribution"
  type        = bool
  default     = true
}

variable "route53_record_ttl" {
  description = "TTL for Route53 record (only used for non-alias records)"
  type        = number
  default     = 300
}