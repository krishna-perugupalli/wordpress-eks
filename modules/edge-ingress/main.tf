#############################################
# Locals
#############################################
locals {
  oidc_hostpath = replace(var.cluster_oidc_issuer_url, "https://", "")
  sa_name       = "aws-load-balancer-controller"
  sa_ns         = var.controller_namespace
  create_ns     = var.controller_namespace != "kube-system"

  create_regional_cert = var.create_regional_certificate && var.alb_domain_name != "" && var.alb_hosted_zone_id != ""
  create_cf_cert       = var.create_cf_certificate && var.cf_domain_name != "" && var.cf_hosted_zone_id != ""
}

#############################################
# IRSA for AWS Load Balancer Controller
#############################################
data "aws_iam_policy_document" "alb_controller_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${local.sa_ns}:${local.sa_name}"]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_trust.json
  tags               = var.tags
}

# AWS-recommended IAM policy for ALB Controller (core privileges)
data "aws_iam_policy_document" "alb_controller_policy" {
  statement {
    sid    = "ELBPermissions"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:GetCertificate",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteTags",
      "ec2:Describe*",
      "ec2:RevokeSecurityGroupIngress",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebAcl",
      "iam:CreateServiceLinkedRole",
      "cognito-idp:DescribeUserPoolClient",
      "waf-regional:GetWebACLForResource",
      "waf-regional:GetWebACL",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:GetWebACL",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "shield:DeleteProtection",
      "shield:CreateProtection",
      "shield:DescribeSubscription"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.name}-alb-controller"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = data.aws_iam_policy_document.alb_controller_policy.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

#############################################
# Kubernetes namespace (optional) + ServiceAccount (IRSA)
#############################################
resource "kubernetes_namespace" "controller_ns" {
  count = local.create_ns ? 1 : 0
  metadata {
    name = var.controller_namespace
  }
}

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = local.sa_name
    namespace = var.controller_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
  automount_service_account_token = true

  depends_on = [
    kubernetes_namespace.controller_ns
  ]
}

#############################################
# Helm release: AWS Load Balancer Controller
#############################################
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = var.controller_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.2"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = local.sa_name
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    kubernetes_service_account.alb_controller
  ]
}

#############################################
# Optional: Restrict ALB to CloudFront origin-facing IPs
#############################################
data "aws_prefix_list" "cloudfront_origin" {
  count = var.restrict_alb_to_cloudfront ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group_rule" "alb_ingress_cf_only" {
  count             = var.restrict_alb_to_cloudfront ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = var.alb_security_group_id
  prefix_list_ids   = [data.aws_prefix_list.cloudfront_origin[0].id]
  description       = "Allow only CloudFront origin-facing IPs to reach ALB"
}

#############################################
# ACM (Regional) for ALB (DNS validated)
#############################################
resource "aws_acm_certificate" "alb" {
  count             = local.create_regional_cert ? 1 : 0
  domain_name       = var.alb_domain_name
  validation_method = "DNS"
  tags              = var.tags
}

# Stable map for DVO
locals {
  alb_dvo_map = local.create_regional_cert ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = local.alb_dvo_map

  zone_id = var.alb_hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "alb" {
  count                   = local.create_regional_cert ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for r in aws_route53_record.alb_cert_validation : r.fqdn]
}

#############################################
# ACM (us-east-1) for future CloudFront
#############################################
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

resource "aws_acm_certificate" "cf" {
  provider          = aws.use1
  count             = local.create_cf_cert ? 1 : 0
  domain_name       = var.cf_domain_name
  validation_method = "DNS"
  tags              = var.tags
}

locals {
  cf_dvo_map = local.create_cf_cert ? {
    for dvo in aws_acm_certificate.cf[0].domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

resource "aws_route53_record" "cf_cert_validation" {
  for_each = local.cf_dvo_map

  zone_id = var.cf_hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "cf" {
  provider                = aws.use1
  count                   = local.create_cf_cert ? 1 : 0
  certificate_arn         = aws_acm_certificate.cf[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cf_cert_validation : r.fqdn]
}

#############################################
# WAFv2 (REGIONAL) for ALB
#############################################
resource "aws_wafv2_web_acl" "regional" {
  count = var.create_waf_regional ? 1 : 0

  name        = "${var.name}-alb-waf"
  description = "WAF for ALB fronting ${var.name}"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-alb-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 10
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
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  dynamic "rule" {
    for_each = var.waf_ruleset_level == "strict" ? [1] : []
    content {
      name     = "AWS-AWSManagedRulesSQLiRuleSet"
      priority = 30
      override_action {
        none {}
      }
      statement {
        managed_rule_group_statement {
          vendor_name = "AWS"
          name        = "AWSManagedRulesSQLiRuleSet"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "SQLi"
        sampled_requests_enabled   = true
      }
    }
  }

  ## Rate limit rule
  # --- Rate limit /wp-login.php ---
  rule {
    name     = "RateLimitLogin"
    priority = 10
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
        scope_down_statement {
          byte_match_statement {
            search_string         = "/wp-login.php"
            positional_constraint = "EXACTLY"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ratelogin"
      sampled_requests_enabled   = true
    }
  }

  # --- Block XML-RPC POSTs (optional) ---
  rule {
    name     = "BlockXmlRpcPost"
    priority = 11
    action {
      block {}
    }
    statement {
      and_statement {
        statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            search_string         = "/xmlrpc.php"
            positional_constraint = "EXACTLY"
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
        statement {
          byte_match_statement {
            search_string         = "POST"
            positional_constraint = "EXACTLY"
            field_to_match {
              method {}
            }
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "xmlrpc"
      sampled_requests_enabled   = true
    }
  }

  tags = var.tags
}
