#############################################
# Caller identity
#############################################
data "aws_caller_identity" "current" {}

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
      # Allow Secrets Manager to use this key (service-side usage)
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
# Optional: create module-owned Secrets Manager secrets
#############################################

# --- WP App DB Secret ---
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

# --- WP Admin Secret ---
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

# --- Redis AUTH secret (optional, JSON: {"token":"..."}) ---
resource "random_password" "redis_token" {
  count   = var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "" ? 1 : 0
  length  = var.redis_auth_token_length
  special = false
}

# choose CMK for redis: prefer caller-provided; else module CMK
locals {
  redis_kms_arn = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.secrets.arn
}

resource "aws_secretsmanager_secret" "redis_auth" {
  count                   = var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "" ? 1 : 0
  name                    = coalesce(var.redis_auth_secret_name, "${var.name}/redis/auth")
  kms_key_id              = local.redis_kms_arn
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

# Safe locals for created/existing redis secret reference
locals {
  redis_auth_secret_arn  = var.existing_redis_auth_secret_arn != "" ? var.existing_redis_auth_secret_arn : try(aws_secretsmanager_secret.redis_auth[0].arn, "")
  redis_auth_token_value = var.existing_redis_auth_secret_arn != "" ? "" : try(random_password.redis_token[0].result, "")
}

#############################################
# Build the list of secrets ESO may read
#############################################
locals {
  # What this module created:
  module_created_secret_arns = concat(
    var.create_wpapp_db_secret ? [aws_secretsmanager_secret.wpapp[0].arn] : [],
    var.create_wp_admin_secret ? [aws_secretsmanager_secret.wpadmin[0].arn] : [],
    (var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "") ? [aws_secretsmanager_secret.redis_auth[0].arn] : []
  )

  # Caller-provided + module-created + redis (either existing or created)
  readable_secret_arns_effective = distinct(compact(concat(
    var.readable_secret_arns,
    var.create_wpapp_db_secret ? [aws_secretsmanager_secret.wpapp[0].arn] : [],
    var.create_wp_admin_secret ? [aws_secretsmanager_secret.wpadmin[0].arn] : [],
    (var.create_redis_auth_secret || var.existing_redis_auth_secret_arn != "") ? [local.redis_auth_secret_arn] : []
  )))

  # Plan-time-known flag that avoids unknowns in count/for_each
  has_readable_secrets = (
    length(var.readable_secret_arns) > 0 ||
    var.create_wpapp_db_secret ||
    var.create_wp_admin_secret ||
    var.create_redis_auth_secret ||
    var.existing_redis_auth_secret_arn != ""
  )

  # External secrets: use only caller-provided ARNs for discovery to avoid unknowns
  external_readable_secret_map  = { for idx, arn in var.readable_secret_arns : tostring(idx) => arn }
  external_readable_secret_arns = toset(values(local.external_readable_secret_map))
}

# Discover KMS key for each external secret (if any)
data "aws_secretsmanager_secret" "external" {
  for_each = local.external_readable_secret_map
  arn      = each.value
}

# Distinct set of CMK ARNs needed for decryption:
# - module CMK for module-created secrets
# - chosen redis CMK for module-created redis
# - kms_key_id discovered for external secrets (nulls removed)
locals {
  kms_arns_for_read = distinct(compact(concat(
    (var.create_wpapp_db_secret ? [aws_kms_key.secrets.arn] : []),
    (var.create_wp_admin_secret ? [aws_kms_key.secrets.arn] : []),
    (var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "" ? [local.redis_kms_arn] : []),
    [for s in data.aws_secretsmanager_secret.external : s.kms_key_id]
  )))

  # Plan-time-known switch: if any path implies KMS decrypt, create the policy skeleton now.
  need_kms_policy = (
    var.create_wpapp_db_secret ||
    var.create_wp_admin_secret ||
    (var.create_redis_auth_secret && var.existing_redis_auth_secret_arn == "") ||
    length(var.readable_secret_arns) > 0
  )
}

#############################################
# IAM: Secrets read policy (ESO/app) — NO KMS here
#############################################
data "aws_iam_policy_document" "secrets_read" {
  count = local.has_readable_secrets ? 1 : 0

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
  policy = data.aws_iam_policy_document.secrets_read[0].json
  tags   = var.tags
}

#############################################
# IAM: KMS decrypt policy (derived CMKs) for ESO
#############################################
data "aws_iam_policy_document" "secrets_kms" {
  count = local.need_kms_policy ? 1 : 0

  statement {
    sid       = "KmsDecryptForSecretsManager"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = local.kms_arns_for_read

    # Constrain to Secrets Manager path in this region
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "secrets_kms" {
  count  = local.need_kms_policy ? 1 : 0
  name   = "${var.name}-secrets-kms-decrypt"
  policy = data.aws_iam_policy_document.secrets_kms[0].json
  tags   = var.tags
}

#############################################
# Optional: SSM read policy (includes KMS decrypt)
#############################################
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

#############################################
# IRSA role for External Secrets Operator
#############################################
data "aws_iam_openid_connect_provider" "eks" {
  arn = var.cluster_oidc_provider_arn
}

locals {
  oidc_hostpath = replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")
  eso_sub       = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"
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

# Attach policies to ESO IRSA role
resource "aws_iam_role_policy_attachment" "eso_attach_read" {
  count      = local.has_readable_secrets ? 1 : 0
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.secrets_read[0].arn
}

resource "aws_iam_role_policy_attachment" "eso_attach_kms" {
  count      = local.need_kms_policy ? 1 : 0
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.secrets_kms[0].arn
}

resource "aws_iam_role_policy_attachment" "eso_attach_ssm" {
  count      = length(var.readable_ssm_parameter_arns) > 0 ? 1 : 0
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.ssm_read[0].arn
}

#############################################
# (Optional) Versions helper for ESO
#############################################
data "aws_iam_policy_document" "secrets_versions" {
  count = local.has_readable_secrets ? 1 : 0

  statement {
    sid       = "ListSecretVersions"
    effect    = "Allow"
    actions   = ["secretsmanager:ListSecretVersionIds"]
    resources = local.readable_secret_arns_effective
  }
}

resource "aws_iam_policy" "secrets_versions" {
  count  = local.has_readable_secrets ? 1 : 0
  name   = "${var.name}-secrets-version-list"
  policy = data.aws_iam_policy_document.secrets_versions[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "eso_attach_versions" {
  count      = local.has_readable_secrets ? 1 : 0
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.secrets_versions[0].arn
}
