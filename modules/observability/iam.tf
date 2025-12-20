locals {
  loki_sa_name  = "loki"
  tempo_sa_name = "tempo"
}

#############################################
# IAM Roles for Service Accounts (IRSA)
#############################################

# Loki IRSA
module "loki_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  count = var.enable_loki ? 1 : 0

  role_name = "${var.cluster_name}-loki"

  role_policy_arns = {
    policy = aws_iam_policy.loki[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${local.monitoring_namespace}:${local.loki_sa_name}"]
    }
  }

  tags = local.common_tags
}

# Tempo IRSA
module "tempo_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  count = var.enable_tempo ? 1 : 0

  role_name = "${var.cluster_name}-tempo"

  role_policy_arns = {
    policy = aws_iam_policy.tempo[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["${local.monitoring_namespace}:${local.tempo_sa_name}"]
    }
  }

  tags = local.common_tags
}

#############################################
# IAM Policies
#############################################

# Loki S3 Policy
resource "aws_iam_policy" "loki" {
  count = var.enable_loki ? 1 : 0

  name        = "${var.cluster_name}-loki"
  description = "IAM policy for Loki to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.loki[0].arn,
          "${aws_s3_bucket.loki[0].arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Tempo S3 Policy
resource "aws_iam_policy" "tempo" {
  count = var.enable_tempo ? 1 : 0

  name        = "${var.cluster_name}-tempo"
  description = "IAM policy for Tempo to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          aws_s3_bucket.tempo[0].arn,
          "${aws_s3_bucket.tempo[0].arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}
