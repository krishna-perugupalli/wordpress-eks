resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.name}-oac"
  description                       = "OAC for ALB origin"
  origin_access_control_origin_type = "custom"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Default + 2 custom cache policies
resource "aws_cloudfront_cache_policy" "bypass_auth" {
  name        = "${var.name}-bypass-auth"
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl
  min_ttl     = var.min_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config { cookie_behavior = "none" }
    headers_config {
      header_behavior = "whitelist"
      headers { items = ["Host", "Origin", "CloudFront-Viewer-Country"] }
    }
    query_strings_config { query_string_behavior = "none" }
  }
  comment = "Bypass auth/cookies for public pages (we’ll attach to default)"
}

resource "aws_cloudfront_cache_policy" "static_long" {
  name        = "${var.name}-static-long"
  default_ttl = var.static_ttl
  max_ttl     = var.static_ttl
  min_ttl     = 300

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
  comment = "Long TTL for /wp-content/*"
}

# Origin request policy to forward only what’s needed to ALB (Host, basic auth paths)
resource "aws_cloudfront_origin_request_policy" "minimal" {
  name = "${var.name}-origin-req-minimal"
  cookies_config { cookie_behavior = "none" }
  headers_config {
    header_behavior = "whitelist"
    headers { items = ["Host", "CloudFront-Viewer-Country"] }
  }
  query_strings_config { query_string_behavior = "none" }
}

# Response headers (optional: HSTS, security headers)
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.name}-security"
  security_headers_config {
    content_security_policy {
      content_security_policy = "upgrade-insecure-requests; block-all-mixed-content;"
      override                = false
    }
    content_type_options { override = true }
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

locals {
  cf_aliases = concat([var.domain_name], var.aliases)
}

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
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 60
    }
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]

    cache_policy_id            = aws_cloudfront_cache_policy.bypass_auth.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.minimal.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    compress                   = var.compress
  }

  # Bypass cache for /wp-admin/* and /wp-login.php
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
  # Long TTL for static media
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
    geo_restriction { restriction_type = "none" }
  }

  web_acl_id = var.waf_web_acl_arn != "" ? var.waf_web_acl_arn : null

  http_version = var.enable_http3 ? "http3" : "http2"

  tags = var.tags
}
