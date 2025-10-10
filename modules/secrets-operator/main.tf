locals {
  ns            = var.namespace
  sa_name       = "external-secrets"
  oidc_hostpath = replace(var.cluster_oidc_issuer_url, "https://", "")
}

# Validate input: exactly one of (policy ARN) or (allowed ARNs) must be set
locals {
  _has_policy_arn   = var.secrets_read_policy_arn != ""
  _has_allowed_arns = length(var.allowed_secret_arns) > 0
}

# This throws during plan if neither/both are set
resource "null_resource" "input_guard" {
  lifecycle {
    precondition {
      condition     = (local._has_policy_arn && !local._has_allowed_arns) || (!local._has_policy_arn && local._has_allowed_arns)
      error_message = "Provide exactly one: either secrets_read_policy_arn (Option A) OR allowed_secret_arns (Option B)."
    }
  }
}

data "aws_iam_policy_document" "eso_inline" {
  count = local._has_allowed_arns ? 1 : 0

  statement {
    sid       = "ReadAllowedSecrets"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = var.allowed_secret_arns
  }
}

resource "aws_iam_policy" "eso_inline" {
  count  = local._has_allowed_arns ? 1 : 0
  name   = "${var.name}-eso-read"
  policy = data.aws_iam_policy_document.eso_inline[0].json
  tags   = var.tags
}

# IRSA trust for ESO controller
data "aws_iam_policy_document" "trust" {
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
      values   = ["system:serviceaccount:${local.ns}:${local.sa_name}"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.name}-eso"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# Attach either provided policy ARN (Option A) or the inline-created (Option B)
resource "aws_iam_role_policy_attachment" "eso_attach" {
  role       = aws_iam_role.eso.name
  policy_arn = local._has_policy_arn ? var.secrets_read_policy_arn : aws_iam_policy.eso_inline[0].arn
}

# Namespace + ServiceAccount with IRSA
resource "kubernetes_namespace" "ns" {
  metadata { name = local.ns }
}

resource "kubernetes_service_account" "eso" {
  metadata {
    name      = local.sa_name
    namespace = local.ns
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eso.arn
    }
  }
  automount_service_account_token = true

  depends_on = [kubernetes_namespace.ns]
}

# Helm install ESO with precreated SA, CRDs on
resource "helm_release" "eso" {
  name       = "external-secrets"
  namespace  = local.ns
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = local.sa_name
  }

  depends_on = [kubernetes_service_account.eso]
}
