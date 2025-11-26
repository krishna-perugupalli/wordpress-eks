#############################################
# WAFv2 Regional WebACL for ALB
#############################################

resource "aws_wafv2_web_acl" "regional" {
  name        = "${var.name}-regional-waf"
  description = "Regional WAF WebACL for WordPress ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting for wp-login.php
  rule {
    name     = "RateLimitWpLogin"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit
        aggregate_key_type = "IP"

        scope_down_statement {
          byte_match_statement {
            search_string         = "/wp-login.php"
            positional_constraint = "CONTAINS"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit-wp-login"
      sampled_requests_enabled   = true
    }
  }

  # Block XML-RPC POST requests
  rule {
    name     = "BlockXmlRpc"
    priority = 2

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string         = "/xmlrpc.php"
            positional_constraint = "CONTAINS"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }

        statement {
          byte_match_statement {
            search_string         = "post"
            positional_constraint = "EXACTLY"

            field_to_match {
              method {}
            }

            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-block-xmlrpc"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Common Rule Set (OWASP Top 10)
  dynamic "rule" {
    for_each = var.enable_managed_rules ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 3

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesCommonRuleSet"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-aws-common-rules"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-regional-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-regional-waf"
    }
  )
}
