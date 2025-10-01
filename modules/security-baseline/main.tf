#############################################
# Locals
#############################################
locals {
  bucket_name = var.trail_bucket_name != "" ? var.trail_bucket_name : lower(replace("${var.name}-sec-logs", "/[^0-9a-z-]/", ""))
}

#############################################
# KMS key for CloudTrail + Config + CW Logs
#############################################
resource "aws_kms_key" "security_logs" {
  description             = "KMS CMK for CloudTrail/Config/CloudWatch Logs (${var.name})"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = var.tags
}

resource "aws_kms_alias" "security_logs" {
  name          = "alias/${var.name}-security-logs"
  target_key_id = aws_kms_key.security_logs.key_id
}

#############################################
# S3 bucket for CloudTrail + AWS Config (SSE-KMS)
#############################################
resource "aws_s3_bucket" "security_logs" {
  bucket = local.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "security_logs" {
  bucket                  = aws_s3_bucket.security_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.security_logs.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    # Required: choose exactly one of filter or prefix. This filter applies to the whole bucket.
    filter {
      prefix = ""
    }

    expiration {
      days = 365
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}


#############################################
# Bucket policy to allow CloudTrail + Config writes
#############################################
data "aws_iam_policy_document" "security_logs_bucket" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.security_logs.arn]
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.security_logs.arn}/AWSLogs/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "AWSConfigWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [
      "${aws_s3_bucket.security_logs.arn}/AWSLogs/*",
      "${aws_s3_bucket.security_logs.arn}/config/*"
    ]
  }

  # Allow AWS services to use the KMS key through S3 for SSE-KMS
  statement {
    sid    = "AllowS3ToUseKMS"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    resources = [aws_kms_key.security_logs.arn]
  }
}

resource "aws_s3_bucket_policy" "security_logs" {
  bucket = aws_s3_bucket.security_logs.id
  policy = data.aws_iam_policy_document.security_logs_bucket.json
}

#############################################
# CloudWatch Log Group for CloudTrail
#############################################
resource "aws_cloudwatch_log_group" "trail" {
  name              = "/aws/cloudtrail/${var.name}"
  kms_key_id        = aws_kms_key.security_logs.arn
  retention_in_days = 90
  tags              = var.tags
}

# IAM role to allow CloudTrail to put logs into CloudWatch Logs
data "aws_iam_policy_document" "trail_to_cw_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "trail_to_cw" {
  name               = "${var.name}-cloudtrail-to-cw"
  assume_role_policy = data.aws_iam_policy_document.trail_to_cw_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "trail_to_cw" {
  statement {
    effect    = "Allow"
    actions   = ["logs:PutLogEvents", "logs:CreateLogStream"]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_policy" "trail_to_cw" {
  name   = "${var.name}-cloudtrail-to-cw"
  policy = data.aws_iam_policy_document.trail_to_cw.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "trail_to_cw" {
  role       = aws_iam_role.trail_to_cw.name
  policy_arn = aws_iam_policy.trail_to_cw.arn
}

#############################################
# CloudTrail (multi-region, SSE-KMS, CW Logs)
#############################################
resource "aws_cloudtrail" "this" {
  name                          = "${var.name}-trail"
  s3_bucket_name                = aws_s3_bucket.security_logs.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.security_logs.arn

  cloud_watch_logs_group_arn = aws_cloudwatch_log_group.trail.arn
  cloud_watch_logs_role_arn  = aws_iam_role.trail_to_cw.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = var.tags

  depends_on = [
    aws_s3_bucket_policy.security_logs,
    aws_iam_role_policy_attachment.trail_to_cw
  ]
}

#############################################
# AWS Config (recorder + delivery channel)
#############################################
resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }

  depends_on = [aws_iam_role_policy_attachment.config_attach]
}

# IAM role for Config
data "aws_iam_policy_document" "config_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.name}-config"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json
  tags               = var.tags
}

# Managed policy is sufficient for account-level Config
resource "aws_iam_role_policy_attachment" "config_attach" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name}-delivery"
  s3_bucket_name = aws_s3_bucket.security_logs.id
  depends_on     = [aws_config_configuration_recorder.this]
}

# Turn on the recorder
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

#############################################
# GuardDuty (account/region)
#############################################
resource "aws_guardduty_detector" "this" {
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
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
  tags = var.tags
}

#############################################
# Optional: Monthly Cost Budget
#############################################
resource "aws_budgets_budget" "monthly" {
  count        = var.create_budget ? 1 : 0
  name         = "${var.name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_amount)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = true
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = true
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = true
    use_blended                = false
  }

  dynamic "notification" {
    for_each = length(var.budget_emails) > 0 ? [1] : []
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = 80
      threshold_type             = "PERCENTAGE"
      notification_type          = "FORECASTED"
      subscriber_email_addresses = var.budget_emails
    }
  }

  tags = var.tags
}
