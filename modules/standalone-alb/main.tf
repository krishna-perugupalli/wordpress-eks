# Standalone ALB Module
# Creates an Application Load Balancer with target group, listeners, security groups, and Route53 record

# Data source for CloudFront prefix list (optional)
data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.enable_cloudfront_restriction ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Security group for WordPress ALB"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alb-sg"
    }
  )
}

# Allow HTTP from internet (or CloudFront)
resource "aws_security_group_rule" "alb_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.enable_cloudfront_restriction ? [] : ["0.0.0.0/0"]
  prefix_list_ids   = var.enable_cloudfront_restriction ? [data.aws_ec2_managed_prefix_list.cloudfront[0].id] : []
  security_group_id = aws_security_group.alb.id
  description       = var.enable_cloudfront_restriction ? "Allow HTTP from CloudFront" : "Allow HTTP from internet"
}

# Allow HTTPS from internet (or CloudFront)
resource "aws_security_group_rule" "alb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.enable_cloudfront_restriction ? [] : ["0.0.0.0/0"]
  prefix_list_ids   = var.enable_cloudfront_restriction ? [data.aws_ec2_managed_prefix_list.cloudfront[0].id] : []
  security_group_id = aws_security_group.alb.id
  description       = var.enable_cloudfront_restriction ? "Allow HTTPS from CloudFront" : "Allow HTTPS from internet"
}

# Allow outbound to worker nodes on pod port
resource "aws_security_group_rule" "alb_pod_egress" {
  type                     = "egress"
  from_port                = var.wordpress_pod_port
  to_port                  = var.wordpress_pod_port
  protocol                 = "tcp"
  source_security_group_id = var.worker_node_security_group_id
  security_group_id        = aws_security_group.alb.id
  description              = "Allow traffic to WordPress pods"
}

# Allow inbound from ALB to worker nodes on pod port
resource "aws_security_group_rule" "worker_pod_ingress" {
  type                     = "ingress"
  from_port                = var.wordpress_pod_port
  to_port                  = var.wordpress_pod_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.worker_node_security_group_id
  description              = "Allow traffic from ALB to WordPress pods"
}

# Application Load Balancer
resource "aws_lb" "wordpress" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-alb"
    }
  )
}

# Target Group for WordPress pods
resource "aws_lb_target_group" "wordpress" {
  name        = "${var.name}-wordpress-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    timeout             = var.health_check_timeout
    interval            = var.health_check_interval
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = var.health_check_matcher
  }

  deregistration_delay = var.deregistration_delay

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-wordpress-tg"
    }
  )
}

# HTTP Listener (redirect to HTTPS or block based on origin protection)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  # Default action: redirect to HTTPS when origin protection is disabled, or return error when enabled
  default_action {
    type = var.enable_origin_protection ? "fixed-response" : "redirect"

    dynamic "redirect" {
      for_each = var.enable_origin_protection ? [] : [1]
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "fixed_response" {
      for_each = var.enable_origin_protection ? [1] : []
      content {
        content_type = "text/plain"
        message_body = var.origin_protection_response_body
        status_code  = var.origin_protection_response_code
      }
    }
  }

  tags = var.tags
}

# Origin Secret Validation Rule for HTTP (redirect to HTTPS with valid secret)
resource "aws_lb_listener_rule" "origin_secret_validation_http" {
  count        = var.enable_origin_protection && var.origin_secret_value != "" ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Secret"
      values           = [var.origin_secret_value]
    }
  }

  tags = var.tags
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  # Default action when origin protection is disabled or no rules match
  default_action {
    type             = var.enable_origin_protection ? "fixed-response" : "forward"
    target_group_arn = var.enable_origin_protection ? null : aws_lb_target_group.wordpress.arn

    dynamic "fixed_response" {
      for_each = var.enable_origin_protection ? [1] : []
      content {
        content_type = "text/plain"
        message_body = var.origin_protection_response_body
        status_code  = var.origin_protection_response_code
      }
    }
  }

  tags = var.tags
}

# Origin Secret Validation Rule for HTTPS
resource "aws_lb_listener_rule" "origin_secret_validation_https" {
  count        = var.enable_origin_protection && var.origin_secret_value != "" ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }

  condition {
    http_header {
      http_header_name = "X-Origin-Secret"
      values           = [var.origin_secret_value]
    }
  }

  tags = var.tags
}

# WAF Association
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.enable_waf ? 1 : 0
  resource_arn = aws_lb.wordpress.arn
  web_acl_arn  = var.waf_acl_arn
}

# Data source to validate hosted zone exists and is accessible
data "aws_route53_zone" "selected" {
  count   = var.create_route53_record && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
}

# Route53 A Record pointing to ALB
resource "aws_route53_record" "wordpress" {
  count   = var.create_route53_record && var.hosted_zone_id != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.wordpress.dns_name
    zone_id                = aws_lb.wordpress.zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
