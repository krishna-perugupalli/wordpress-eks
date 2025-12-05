# CloudFront Advanced Configuration Example
# This example demonstrates all available CloudFront configuration options

# Basic CloudFront Configuration
enable_cloudfront          = true
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
cloudfront_aliases         = ["www.example.com", "cdn.example.com"]

# Price Class Configuration (6.1)
# Options: PriceClass_All, PriceClass_200, PriceClass_100
cloudfront_price_class = "PriceClass_200" # Use edge locations in North America, Europe, Asia, Middle East, and Africa

# Logging Configuration (6.2)
cloudfront_enable_logging      = true
cloudfront_log_prefix          = "cloudfront-logs/"
cloudfront_log_include_cookies = false

# Geo-restrictions Configuration (6.3)
# Allowlist example - only allow specific countries
cloudfront_geo_restriction_type      = "whitelist"
cloudfront_geo_restriction_locations = ["US", "CA", "GB", "DE", "FR", "AU"]

# Alternative: Blocklist example - block specific countries
# cloudfront_geo_restriction_type = "blacklist"
# cloudfront_geo_restriction_locations = ["CN", "RU", "KP"]

# Alternative: No geo-restrictions
# cloudfront_geo_restriction_type = "none"
# cloudfront_geo_restriction_locations = []

# HTTP/3 and Compression Configuration (6.4, 6.5)
cloudfront_enable_http3       = true
cloudfront_enable_compression = true

# Advanced Performance Features
cloudfront_enable_origin_shield = true
cloudfront_origin_shield_region = "eu-central-1" # Should be closest to your origin

# Security Configuration
cloudfront_minimum_protocol_version = "TLSv1.2_2021"
cloudfront_enable_ipv6              = true
cloudfront_waf_web_acl_arn          = "" # Optional: Add WAF Web ACL ARN for additional security

# Real-time Logging (Advanced)
cloudfront_enable_real_time_logs    = false
cloudfront_real_time_log_config_arn = "" # Optional: Add real-time log configuration ARN

# Custom Error Pages
cloudfront_custom_error_responses = [
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
  }
]

# Content and Media Configuration
cloudfront_default_root_object     = "index.php"
cloudfront_enable_smooth_streaming = false # Enable for media streaming content

# Origin Protection
cloudfront_origin_secret     = "your-secure-random-secret-here" # Use a strong random value
enable_alb_origin_protection = true

# Route53 Integration
create_cloudfront_route53_record = true