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

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
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

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }

  tags = var.tags
}

# WAF Association
resource "aws_wafv2_web_acl_association" "alb" {
  count        = var.waf_acl_arn != "" ? 1 : 0
  resource_arn = aws_lb.wordpress.arn
  web_acl_arn  = var.waf_acl_arn
}

# Route53 A Record - conditionally points to ALB or CloudFront
resource "aws_route53_record" "wordpress" {
  count   = var.create_route53_record && !var.route53_points_to_cloudfront ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.wordpress.dns_name
    zone_id                = aws_lb.wordpress.zone_id
    evaluate_target_health = true
  }
}

# Route53 A Record for CloudFront (when CloudFront is used)
resource "aws_route53_record" "wordpress_cloudfront" {
  count   = var.create_route53_record && var.route53_points_to_cloudfront ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_distribution_domain_name
    zone_id                = var.cloudfront_distribution_zone_id
    evaluate_target_health = false
  }
}
