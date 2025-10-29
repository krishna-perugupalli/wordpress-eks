#############################################
# Identity / Region
#############################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#############################################
# KMS CMK for security logs (CloudTrail/CWL/S3)
#############################################
resource "aws_kms_key" "logs" {
  description             = "CMK for security logs (${var.name})"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowAccountAdmin",
        Effect    = "Allow",
        Principal = { "AWS" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudWatchLogsUse",
        Effect    = "Allow",
        Principal = { "Service" = "logs.${data.aws_region.current.name}.amazonaws.com" },
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"],
        Resource  = "*"
      },
      {
        Sid       = "AllowCloudTrailUse",
        Effect    = "Allow",
        Principal = { "Service" = "cloudtrail.amazonaws.com" },
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"],
        Resource  = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

#############################################
# S3 bucket for security logs (CloudTrail, ALB, etc.)
#############################################
# Ensure a globally-unique bucket. If user supplied a name, use it.
resource "random_id" "suffix" {
  byte_length = 3
}

# If caller provides an existing bucket name, do not create bucket resources; just reference it.
data "aws_s3_bucket" "existing" {
  count  = var.trail_bucket_name != "" ? 1 : 0
  bucket = var.trail_bucket_name
}

locals {
  computed_logs_bucket_name = var.trail_bucket_name != "" ? var.trail_bucket_name : "${var.name}-sec-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "security_logs" {
  count  = var.trail_bucket_name == "" ? 1 : 0
  bucket = local.computed_logs_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "security_logs" {
  count  = var.trail_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.security_logs[0].id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_versioning" "security_logs" {
  count  = var.trail_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.security_logs[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_logs" {
  count  = var.trail_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.security_logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle with a required filter (provider needs either prefix or filter)
resource "aws_s3_bucket_lifecycle_configuration" "security_logs" {
  count  = var.trail_bucket_name == "" ? 1 : 0
  bucket = aws_s3_bucket.security_logs[0].id

  rule {
    id     = "ExpireOldObjects"
    status = "Enabled"
    filter {
      prefix = "" # all objects
    }

    expiration {
      days = var.logs_expire_after_days
    }
  }
}

# Effective bucket identifiers (resource or data)
locals {
  security_logs_bucket_name = var.trail_bucket_name != "" ? data.aws_s3_bucket.existing[0].bucket : aws_s3_bucket.security_logs[0].bucket
  security_logs_bucket_arn  = var.trail_bucket_name != "" ? data.aws_s3_bucket.existing[0].arn : aws_s3_bucket.security_logs[0].arn
}

# Allow services to write & enforce TLS-only access
data "aws_iam_policy_document" "security_logs_policy" {
  statement {
    sid     = "AllowCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${local.security_logs_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "AllowCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [local.security_logs_bucket_arn]
  }

  statement {
    sid     = "AllowELBAccessLogs"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }
    resources = ["${local.security_logs_bucket_arn}/*"]
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      local.security_logs_bucket_arn,
      "${local.security_logs_bucket_arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "security_logs" {
  bucket = local.security_logs_bucket_name
  policy = data.aws_iam_policy_document.security_logs_policy.json
}

#############################################
# CloudWatch Logs group for CloudTrail
#############################################
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.name}"
  kms_key_id        = aws_kms_key.logs.arn
  retention_in_days = var.cloudtrail_cwl_retention_days
  tags              = var.tags
}

#############################################
# CloudTrail (org-level OFF; single-account trail)
#############################################
resource "aws_cloudtrail" "this" {
  count                         = var.create_cloudtrail ? 1 : 0
  name                          = var.name
  s3_bucket_name                = local.security_logs_bucket_name
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = false
  kms_key_id                    = aws_kms_key.logs.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.trail.arn}:*" # CWL needs :*
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail[0].arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags
}

# Role for CloudTrail to write to CloudWatch Logs
data "aws_iam_policy_document" "cloudtrail_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudtrail" {
  count              = var.create_cloudtrail ? 1 : 0
  name               = "${var.name}-cloudtrail"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "cloudtrail_to_cwl" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [aws_cloudwatch_log_group.trail.arn, "${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "cloudtrail_to_cwl" {
  count  = var.create_cloudtrail ? 1 : 0
  name   = "${var.name}-cloudtrail-to-cwl"
  role   = aws_iam_role.cloudtrail[0].name
  policy = data.aws_iam_policy_document.cloudtrail_to_cwl.json
}

#############################################
# AWS Config (recorder + delivery channel)
#############################################
data "aws_iam_policy_document" "config_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  count              = var.create_config ? 1 : 0
  name               = "${var.name}-config"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = var.tags
}

# Inline minimal policy for AWS Config
data "aws_iam_policy_document" "config_inline" {
  statement {
    effect = "Allow"
    actions = [
      "config:Put*",
      "config:Get*",
      "config:Describe*",
      "config:StartConfigurationRecorder",
      "config:StopConfigurationRecorder",
      "s3:PutObject",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "config_inline" {
  count  = var.create_config ? 1 : 0
  name   = "${var.name}-config-inline"
  role   = aws_iam_role.config[0].name
  policy = data.aws_iam_policy_document.config_inline.json
}

resource "aws_config_configuration_recorder" "this" {
  count    = var.create_config ? 1 : 0
  name     = "default"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  count          = var.create_config ? 1 : 0
  name           = "default"
  s3_bucket_name = aws_s3_bucket.security_logs.bucket
  s3_key_prefix  = "config"
  depends_on     = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  count      = var.create_config ? 1 : 0
  name       = aws_config_configuration_recorder.this[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

#############################################
# GuardDuty (OPTIONAL)
#############################################
data "aws_guardduty_detector" "existing" {
  count = var.create_guardduty && var.guardduty_use_existing ? 1 : 0
}

resource "aws_guardduty_detector" "this" {
  count  = var.create_guardduty && !var.guardduty_use_existing ? 1 : 0
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }

  tags = var.tags
}

locals {
  guardduty_detector_id_effective = var.create_guardduty ? (var.guardduty_use_existing ? data.aws_guardduty_detector.existing[0].id : try(aws_guardduty_detector.this[0].id, null)) : null
}
