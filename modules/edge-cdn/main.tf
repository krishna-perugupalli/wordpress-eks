#############################################
# Inputs and locals
#############################################
locals {
  cf_aliases    = concat([var.domain_name], var.aliases)
  origin_secret = var.origin_secret_value
}

#############################################
# Cache policies
#############################################
resource "aws_cloudfront_cache_policy" "bypass_auth" {
  name = "${var.name}-bypass-auth"
  # Treat as a no-cache policy for dynamic WP routes
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

    # Forward required headers; keep cache key simple
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Host", "CloudFront-Viewer-Country"]
      }
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
      items = ["Host", "CloudFront-Viewer-Country"]
    }
  }

  query_strings_config {
    query_string_behavior = "none"
  }
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.name}-security"

  security_headers_config {
    content_security_policy {
      content_security_policy = "upgrade-insecure-requests; block-all-mixed-content;"
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
}

#############################################
# CloudFront distribution (custom origin = ALB)
#############################################
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = var.price_class
  aliases             = local.cf_aliases
  default_root_object = "index.php"

  logging_config {
    bucket          = "${var.log_bucket_name}.s3.amazonaws.com"
    prefix          = "${var.name}/"
    include_cookies = false
  }

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    # Inject the secret header CF -> ALB
    dynamic "custom_header" {
      for_each = local.origin_secret != null && trim(local.origin_secret) != "" ? [1] : []
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

    # NOTE: Do NOT set origin_access_control_id for ALB origins.
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id            = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    compress = var.compress
  }

  # Admin/login bypass cache
  ordered_cache_behavior {
    path_pattern             = "/wp-admin/*"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.minimal.id
    compress                 = var.compress
  }

  ordered_cache_behavior {
    path_pattern             = "/wp-login.php"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.minimal.id
    compress                 = var.compress
  }

  # Static media long TTL
  ordered_cache_behavior {
    path_pattern             = "/wp-content/*"
    target_origin_id         = "alb-origin"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = aws_cloudfront_cache_policy.static_long.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.minimal.id
    compress                 = var.compress
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  web_acl_id   = var.waf_web_acl_arn != "" ? var.waf_web_acl_arn : null
  http_version = var.enable_http3 ? "http3" : "http2"

  tags = var.tags
}
