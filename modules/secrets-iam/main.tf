#############################################
# KMS: Secrets Manager CMK (+ alias)
#############################################
resource "aws_kms_key" "secrets" {
  description             = "CMK for Secrets Manager (${var.name})"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Full admin within account
      {
        Sid       = "EnableRootAdmin",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      # Allow Secrets Manager to use this key via S3/Direct service (ViaService)
      {
        Sid       = "AllowSecretsManagerUse",
        Effect    = "Allow",
        Principal = { Service = "secretsmanager.${var.region}.amazonaws.com" },
        Action = [
          "kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          "StringEquals" = {
            "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

data "aws_caller_identity" "current" {}

#############################################
# Optional: KMS for SSM Parameter Store
#############################################
resource "aws_kms_key" "ssm" {
  count                   = var.create_ssm_kms_key ? 1 : 0
  description             = "CMK for SSM Parameter Store (${var.name})"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "EnableRootAdmin",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowSSMUse",
        Effect    = "Allow",
        Principal = { Service = "ssm.${var.region}.amazonaws.com" },
        Action = [
          "kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
        ],
        Resource = "*",
        Condition = {
          "StringEquals" = {
            "kms:ViaService" = "ssm.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = var.tags
}

resource "aws_kms_alias" "ssm" {
  count         = var.create_ssm_kms_key ? 1 : 0
  name          = "alias/${var.name}-ssm"
  target_key_id = aws_kms_key.ssm[0].key_id
}

#############################################
# Optional: create Secrets Manager secrets
#############################################
# DB app secret
resource "random_password" "wpapp" {
  count   = var.create_wpapp_db_secret && var.wpapp_db_password == "" ? 1 : 0
  length  = 32
  special = true
}

locals {
  wpapp_pass_effective = var.create_wpapp_db_secret ? (var.wpapp_db_password != "" ? var.wpapp_db_password : random_password.wpapp[0].result) : ""
  wpapp_secret_value_json = var.create_wpapp_db_secret ? jsonencode({
    username = var.wpapp_db_username
    password = local.wpapp_pass_effective
    host     = var.wpapp_db_host
    dbname   = var.wpapp_db_database
    port     = var.wpapp_db_port
  }) : null
}

resource "aws_secretsmanager_secret" "wpapp" {
  count                   = var.create_wpapp_db_secret ? 1 : 0
  name                    = var.wpapp_db_secret_name
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "wpapp" {
  count         = var.create_wpapp_db_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.wpapp[0].id
  secret_string = local.wpapp_secret_value_json
}

# WP admin secret
resource "random_password" "wpadmin" {
  count   = var.create_wp_admin_secret && var.wp_admin_password == "" ? 1 : 0
  length  = 24
  special = true
}

locals {
  wpadmin_pass_effective = var.create_wp_admin_secret ? (var.wp_admin_password != "" ? var.wp_admin_password : random_password.wpadmin[0].result) : ""
  wpadmin_secret_value_json = var.create_wp_admin_secret ? jsonencode({
    username = var.wp_admin_username
    password = local.wpadmin_pass_effective
    email    = var.wp_admin_email
  }) : null
}

resource "aws_secretsmanager_secret" "wpadmin" {
  count                   = var.create_wp_admin_secret ? 1 : 0
  name                    = var.wp_admin_secret_name
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "wpadmin" {
  count         = var.create_wp_admin_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.wpadmin[0].id
  secret_string = local.wpadmin_secret_value_json
}

#############################################
# IAM: Least-privilege reader policies
#############################################
# Reader policy for Secrets Manager (attach to ESO or an app role)
# Reader policy for Secrets Manager (ESO) — NO KMS permissions

# Build the effective list of ARNs ESO can read:
# - any external ARNs passed in via var.readable_secret_arns
# - plus the ARNs of secrets we created here (if created)
locals {
  readable_secret_arns_candidate = concat(
    var.readable_secret_arns,
    var.create_wpapp_db_secret ? [aws_secretsmanager_secret.wpapp[0].arn] : [],
    var.create_wp_admin_secret ? [aws_secretsmanager_secret.wpadmin[0].arn] : [],
    (var.create_redis_auth_secret || var.existing_redis_auth_secret_arn != "") ? [local.redis_auth_secret_arn] : []
  )

  readable_secret_arns_effective = distinct(compact(local.readable_secret_arns_candidate))

  has_readable_secrets = length(var.readable_secret_arns) > 0 || var.create_wpapp_db_secret || var.create_wp_admin_secret || var.create_redis_auth_secret || var.existing_redis_auth_secret_arn != ""
}

data "aws_iam_policy_document" "secrets_read" {
  statement {
    sid    = "ReadAllowedSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = local.readable_secret_arns_effective

    dynamic "condition" {
      for_each = var.restrict_to_version_stage != "" ? [1] : []
      content {
        test     = "ForAnyValue:StringEquals"
        variable = "secretsmanager:VersionStage"
        values   = [var.restrict_to_version_stage]
      }
    }

    dynamic "condition" {
      for_each = var.required_secret_tag_key != "" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "aws:ResourceTag/${var.required_secret_tag_key}"
        values   = [var.required_secret_tag_value]
      }
    }
  }
}

resource "aws_iam_policy" "secrets_read" {
  count  = local.has_readable_secrets ? 1 : 0
  name   = "${var.name}-secrets-read"
  policy = data.aws_iam_policy_document.secrets_read.json
  tags   = var.tags
}

# Reader policy for specific SSM Parameters (optional)
data "aws_iam_policy_document" "ssm_read" {
  count = length(var.readable_ssm_parameter_arns) > 0 ? 1 : 0

  statement {
    sid       = "ReadAllowedParameters"
    effect    = "Allow"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:DescribeParameters"]
    resources = var.readable_ssm_parameter_arns
  }

  statement {
    sid       = "AllowKMSDecryptSSM"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = var.create_ssm_kms_key ? [aws_kms_key.ssm[0].arn] : [aws_kms_key.secrets.arn]
  }
}

resource "aws_iam_policy" "ssm_read" {
  count  = length(var.readable_ssm_parameter_arns) > 0 ? 1 : 0
  name   = "${var.name}-ssm-read"
  policy = data.aws_iam_policy_document.ssm_read[0].json
  tags   = var.tags
}

# Optional: generate a Redis AUTH token and store in Secrets Manager as JSON: {"token":"..."}
resource "random_password" "redis_token" {
  count            = var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "" ? 1 : 0
  length           = var.redis_auth_token_length
  special          = true
  override_special = "!#$%^*-_=+"
}

resource "aws_secretsmanager_secret" "redis_auth" {
  count                   = var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "" ? 1 : 0
  name                    = coalesce(var.redis_auth_secret_name, "${var.name}/redis/auth")
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  count     = var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.redis_auth[0].id
  secret_string = jsonencode({
    token = random_password.redis_token[0].result
  })
}

# Safe local to expose either the existing ARN or the created one (without evaluating missing indexes)
locals {
  redis_auth_secret_arn  = var.existing_redis_auth_secret_arn != "" ? var.existing_redis_auth_secret_arn : try(aws_secretsmanager_secret.redis_auth[0].arn, "")
  redis_auth_token_value = var.existing_redis_auth_secret_arn != "" ? "" : try(random_password.redis_token[0].result, "")
}

#############################################
# IRSA role for External Secrets Operator
# - Trusts only the ESO controller SA via OIDC "sub"
# - Attaches the least-privilege secrets_read policy you already defined
#############################################

# Read OIDC provider to get issuer URL (hostpath used in "sub" condition)
data "aws_iam_openid_connect_provider" "eks" {
  arn = var.cluster_oidc_provider_arn
}

# Build trust policy conditions
locals {
  oidc_hostpath = replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")
  eso_sub       = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"
  aud_condition = var.eso_validate_audience ? {
    "StringEquals" = {
      "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
    }
  } : {}
}

data "aws_iam_policy_document" "eso_trust" {
  statement {
    sid     = "ESOWebIdentityTrust"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = [local.eso_sub]
    }
    dynamic "condition" {
      for_each = var.eso_validate_audience ? [1] : []
      content {
        test     = "StringEquals"
        variable = "${local.oidc_hostpath}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.name}-eso-irsa"
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json
  tags               = var.tags
}

# Attach the read policy to the ESO role (created earlier in your file)
resource "aws_iam_role_policy_attachment" "eso_attach_read" {
  count      = local.has_readable_secrets ? 1 : 0
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.secrets_read[0].arn
}
