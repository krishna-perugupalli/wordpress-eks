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

# IAM policy for ALB Controller - focused on TargetGroupBinding management
# Removed ALB/Listener creation permissions since ALB is managed by Terraform
data "aws_iam_policy_document" "alb_controller_policy" {
  statement {
    sid    = "TargetGroupManagement"
    effect = "Allow"
    actions = [
      # EC2 permissions for security group management (TargetGroupBinding networking)
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteTags",
      "ec2:Describe*",
      "ec2:RevokeSecurityGroupIngress",
      # Target group management (core TargetGroupBinding functionality)
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      # Service linked role creation
      "iam:CreateServiceLinkedRole"
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

  wait    = true
  timeout = 600

  depends_on = [
    kubernetes_service_account.alb_controller
  ]
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


