#############################################
# Inputs and locals
#############################################
locals {
  cf_aliases    = concat([var.domain_name], var.aliases)
  origin_secret = var.origin_secret_value
}

#############################################
# CloudFront Module
#############################################

# All validation is handled at the infrastructure stack level
# This module trusts that inputs have been validated upstream

#############################################
# Cache policies
#############################################
resource "aws_cloudfront_cache_policy" "bypass_auth" {
  name = "${var.name}-bypass-auth"
  # True no-cache policy for dynamic WP routes (prevents caching redirects)
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    # Forward all cookies so auth/session works; effectively disables caching
    cookies_config {
      cookie_behavior = "all"
    }

    # When caching is disabled (TTL=0), headers cannot be part of the cache key
    headers_config {
      header_behavior = "none"
    }

    # Forward all query strings; needed for WP routes like ?p=, ?s=, etc.
    query_strings_config {
      query_string_behavior = "all"
    }
  }

  comment = "No-cache policy for dynamic WordPress paths; forwards cookies and query strings."
}

resource "aws_cloudfront_cache_policy" "static_long" {
  name        = "${var.name}-static-long"
  default_ttl = var.static_ttl
  max_ttl     = var.static_ttl
  min_ttl     = 300

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }

  comment = "Long TTL for /wp-content/*"
}

resource "aws_cloudfront_cache_policy" "feeds_sitemap" {
  name        = "${var.name}-feeds-sitemap"
  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours
  min_ttl     = 300   # 5 minutes

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Accept",
          "Accept-Language"
        ]
      }
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }

  comment = "Medium TTL for WordPress feeds and sitemaps"
}

#############################################
# Origin request and response headers policies
#############################################
resource "aws_cloudfront_origin_request_policy" "minimal" {
  name = "${var.name}-origin-req-minimal"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Host",
        "CloudFront-Viewer-Country",
        "CloudFront-Forwarded-Proto",
        "CloudFront-Viewer-Protocol",
        "CloudFront-Is-Desktop-Viewer",
        "CloudFront-Is-Mobile-Viewer",
        "CloudFront-Is-SmartTV-Viewer",
        "CloudFront-Is-Tablet-Viewer",
        "X-Forwarded-Proto",
        "X-Forwarded-Host",
        "X-Forwarded-For",
        "X-Real-IP",
        "User-Agent"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "none"
  }
}

resource "aws_cloudfront_origin_request_policy" "wordpress_dynamic" {
  name = "${var.name}-dynamic"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Host",
        "CloudFront-Viewer-Country",
        "CloudFront-Forwarded-Proto",
        "CloudFront-Viewer-Protocol",
        "CloudFront-Is-Desktop-Viewer",
        "CloudFront-Is-Mobile-Viewer",
        "CloudFront-Is-SmartTV-Viewer",
        "CloudFront-Is-Tablet-Viewer",
        "X-Forwarded-Proto",
        "X-Forwarded-Host",
        "X-Forwarded-For",
        "X-Real-IP",
        "User-Agent",
        "Referer",
        "Authorization",
        "Accept",
        "Accept-Language",
        "Accept-Encoding",
        "Content-Type",
        "Content-Length",
        "Cache-Control",
        "Pragma",
        "If-Modified-Since",
        "If-None-Match"
      ]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.name}-security"

  security_headers_config {
    content_security_policy {
      content_security_policy = "upgrade-insecure-requests; block-all-mixed-content; frame-ancestors 'self';"
      override                = false
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = false
    }
    xss_protection {
      protection = true
      mode_block = true
      override   = true
    }
  }

  custom_headers_config {
    items {
      header   = "X-Content-Type-Options"
      value    = "nosniff"
      override = true
    }
    items {
      header   = "X-Frame-Options"
      value    = "SAMEORIGIN"
      override = true
    }
    items {
      header   = "Permissions-Policy"
      value    = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()"
      override = false
    }
    items {
      header   = "X-Robots-Tag"
      value    = "noindex, nofollow"
      override = false
    }
  }

  # CORS configuration for WordPress
  cors_config {
    access_control_allow_credentials = false
    access_control_allow_headers {
      items = ["*"]
    }
    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    }
    access_control_allow_origins {
      items = ["*"]
    }
    access_control_expose_headers {
      items = ["*"]
    }
    access_control_max_age_sec = 86400
    origin_override            = false
  }
}

#############################################
# CloudFront Functions for header manipulation
#############################################
resource "aws_cloudfront_function" "header_manipulation" {
  count   = var.enable_header_function ? 1 : 0
  name    = "${var.name}-header-manipulation"
  runtime = "cloudfront-js-1.0"
  comment = "Function to add/modify headers for WordPress compatibility and security"
  publish = true
  code    = <<-EOT
function handler(event) {
    var request = event.request;
    var headers = request.headers;
    var uri = request.uri;
    
    // Ensure X-Forwarded-Host is set correctly to prevent redirect loops
    if (headers.host && headers.host.value) {
        headers['x-forwarded-host'] = {value: headers.host.value};
    }
    
    // Add CloudFront-Viewer-Protocol for WordPress HTTPS detection
    headers['cloudfront-viewer-protocol'] = {value: 'https'};
    
    // Add X-Forwarded-Proto for WordPress HTTPS detection
    headers['x-forwarded-proto'] = {value: 'https'};
    
    // Preserve original IP for WordPress
    if (headers['cloudfront-viewer-address']) {
        var viewerAddress = headers['cloudfront-viewer-address'].value;
        var ip = viewerAddress.split(':')[0]; // Remove port if present
        headers['x-real-ip'] = {value: ip};
    }
    
    // Add security headers for admin areas
    if (uri.startsWith('/wp-admin/') || uri === '/wp-login.php') {
        headers['x-frame-options'] = {value: 'DENY'};
        headers['x-content-type-options'] = {value: 'nosniff'};
        headers['cache-control'] = {value: 'no-cache, no-store, must-revalidate'};
        headers['pragma'] = {value: 'no-cache'};
        headers['expires'] = {value: '0'};
    }
    
    // Add proper cache control for static assets
    if (uri.startsWith('/wp-content/') || uri.startsWith('/wp-includes/')) {
        // Let CloudFront handle caching for static content
        if (headers['cache-control']) {
            delete headers['cache-control'];
        }
    }
    
    // Normalize trailing slashes for consistent caching
    if (uri.endsWith('/') && uri.length > 1) {
        request.uri = uri.slice(0, -1);
    }
    
    return request;
}
EOT
}

#############################################
# CloudFront distribution (custom origin = ALB)
#############################################
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = var.is_ipv6_enabled
  price_class         = var.price_class
  aliases             = local.cf_aliases
  default_root_object = var.default_root_object



  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      bucket          = "${var.log_bucket_name}.s3.amazonaws.com"
      prefix          = var.log_prefix
      include_cookies = var.log_include_cookies
    }
  }

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    # Inject the secret header CF -> ALB
    dynamic "custom_header" {
      for_each = local.origin_secret != null && length(trimspace(local.origin_secret)) > 0 ? [1] : []
      content {
        name  = "X-Origin-Secret"
        value = local.origin_secret
      }
    }

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 60
    }

    # Enable Origin Shield if configured
    dynamic "origin_shield" {
      for_each = var.enable_origin_shield ? [1] : []
      content {
        enabled              = true
        origin_shield_region = var.origin_shield_region
      }
    }

    # NOTE: Do NOT set origin_access_control_id for ALB origins.
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id            = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.wordpress_dynamic.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    # Add CloudFront Function for header manipulation if enabled
    dynamic "function_association" {
      for_each = var.enable_header_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.header_manipulation[0].arn
      }
    }

    # Enable real-time logs if configured
    realtime_log_config_arn = var.enable_real_time_logs && var.real_time_log_config_arn != "" ? var.real_time_log_config_arn : null

    # Configure trusted signers if provided
    trusted_signers    = var.trusted_signers
    trusted_key_groups = var.trusted_key_groups

    smooth_streaming = var.enable_smooth_streaming
    compress         = var.compress
  }

  # Admin/login bypass cache - never cache admin areas
  ordered_cache_behavior {
    path_pattern             = "/wp-admin/*"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.wordpress_dynamic.id

    # Add CloudFront Function for header manipulation if enabled
    dynamic "function_association" {
      for_each = var.enable_header_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.header_manipulation[0].arn
      }
    }

    compress = var.compress
  }

  ordered_cache_behavior {
    path_pattern             = "/wp-login.php"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.wordpress_dynamic.id

    # Add CloudFront Function for header manipulation if enabled
    dynamic "function_association" {
      for_each = var.enable_header_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.header_manipulation[0].arn
      }
    }

    compress = var.compress
  }

  # Static media long TTL - cache static content aggressively
  ordered_cache_behavior {
    path_pattern               = "/wp-content/*"
    target_origin_id           = "alb-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.static_long.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  # Additional cache behavior for WordPress uploads
  ordered_cache_behavior {
    path_pattern               = "/wp-content/uploads/*"
    target_origin_id           = "alb-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.static_long.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  # Cache behavior for WordPress themes and plugins
  ordered_cache_behavior {
    path_pattern               = "/wp-includes/*"
    target_origin_id           = "alb-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.static_long.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  # Cache behavior for WordPress API endpoints - bypass cache
  ordered_cache_behavior {
    path_pattern             = "/wp-json/*"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.wordpress_dynamic.id

    # Add CloudFront Function for header manipulation if enabled
    dynamic "function_association" {
      for_each = var.enable_header_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.header_manipulation[0].arn
      }
    }

    compress = var.compress
  }

  # Cache behavior for WordPress AJAX requests - bypass cache
  ordered_cache_behavior {
    path_pattern             = "/wp-admin/admin-ajax.php"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.wordpress_dynamic.id

    # Add CloudFront Function for header manipulation if enabled
    dynamic "function_association" {
      for_each = var.enable_header_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.header_manipulation[0].arn
      }
    }

    compress = var.compress
  }

  # Cache behavior for WordPress cron - bypass cache
  ordered_cache_behavior {
    path_pattern             = "/wp-cron.php"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.wordpress_dynamic.id

    # Add CloudFront Function for header manipulation if enabled
    dynamic "function_association" {
      for_each = var.enable_header_function ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.header_manipulation[0].arn
      }
    }

    compress = var.compress
  }

  # Cache behavior for WordPress feeds - moderate caching
  ordered_cache_behavior {
    path_pattern               = "/feed/*"
    target_origin_id           = "alb-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.feeds_sitemap.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  # Cache behavior for WordPress sitemaps - moderate caching
  ordered_cache_behavior {
    path_pattern               = "/sitemap*.xml"
    target_origin_id           = "alb-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.feeds_sitemap.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  # Cache behavior for robots.txt - moderate caching
  ordered_cache_behavior {
    path_pattern               = "/robots.txt"
    target_origin_id           = "alb-origin"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.feeds_sitemap.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = var.minimum_protocol_version
  }

  # Custom error pages for better user experience
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type
      locations        = var.geo_restriction_locations
    }
  }

  web_acl_id   = var.waf_web_acl_arn != "" ? var.waf_web_acl_arn : null
  http_version = var.enable_http3 ? "http3" : "http2"

  tags = var.tags
}

#############################################
# Route53 DNS Records for CloudFront
#############################################

# Primary Route53 A record pointing to CloudFront distribution
resource "aws_route53_record" "cloudfront_primary" {
  count   = var.create_route53_record && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Additional Route53 A records for aliases
resource "aws_route53_record" "cloudfront_aliases" {
  count   = var.create_route53_record && var.hosted_zone_id != "" ? length(var.aliases) : 0
  zone_id = var.hosted_zone_id
  name    = var.aliases[count.index]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Data source to validate hosted zone exists and is accessible
data "aws_route53_zone" "selected" {
  count   = var.create_route53_record && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id

  lifecycle {
    postcondition {
      condition     = self.name != ""
      error_message = <<-EOT
        Route53 hosted zone validation failed:
        Hosted zone is not accessible or does not exist.
        
        Hosted zone ID: ${var.hosted_zone_id}
        Domain name: ${var.domain_name}
        
        To resolve:
        1. Verify hosted zone ID is correct
        2. Check hosted zone exists in Route53 console
        3. Ensure AWS credentials have Route53 permissions
        4. Verify hosted zone is in the same AWS account
        
        Find correct hosted zone ID using:
        aws route53 list-hosted-zones-by-name --dns-name ${var.domain_name}
      EOT
    }
    postcondition {
      condition = anytrue([
        self.name == "${var.domain_name}.",
        self.name == var.domain_name,
        endswith(var.domain_name, trimsuffix(self.name, "."))
      ])
      error_message = <<-EOT
        Route53 hosted zone domain mismatch:
        Hosted zone domain does not match CloudFront domain.
        
        CloudFront domain: ${var.domain_name}
        Hosted zone domain: ${self.name}
        Hosted zone ID: ${var.hosted_zone_id}
        
        The hosted zone must be for the same domain or a parent domain.
        
        To resolve:
        1. Use hosted zone for exact domain: ${var.domain_name}
        2. Or use parent domain hosted zone (e.g., example.com for subdomain.example.com)
        3. Create new hosted zone if needed
        4. Update hosted_zone_id variable to correct zone
        
        Create hosted zone using:
        aws route53 create-hosted-zone --name ${var.domain_name} --caller-reference $(date +%s)
      EOT
    }
  }
}