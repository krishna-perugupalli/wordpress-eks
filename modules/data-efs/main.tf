#############################################
# Inputs guardrails
#############################################
locals {
  has_any_ingress                = length(var.allowed_security_group_ids) + length(var.allowed_cidr_blocks) > 0
  allowed_security_group_ids_map = { for idx, sg_id in var.allowed_security_group_ids : tostring(idx) => sg_id }
}

#############################################
# Security Group for EFS
#############################################
resource "aws_security_group" "efs" {
  name        = "${var.name}-efs-sg"
  description = "EFS mount access for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-efs-sg" })

  lifecycle {
    precondition {
      condition     = local.has_any_ingress
      error_message = "No EFS ingress sources provided. Set allowed_security_group_ids and/or allowed_cidr_blocks."
    }
  }
}

# SG sources: from SGs
resource "aws_security_group_rule" "efs_ingress_sg" {
  for_each                 = local.allowed_security_group_ids_map
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = each.value
  description              = "NFS from ${each.value}"
}

# SG sources: from CIDRs
resource "aws_security_group_rule" "efs_ingress_cidr" {
  for_each          = toset(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  security_group_id = aws_security_group.efs.id
  cidr_blocks       = [each.value]
  description       = "NFS from ${each.value}"
}

# Egress open (needed for control plane comms)
resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.efs.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All egress"
}

#############################################
# EFS File System
#############################################
resource "aws_efs_file_system" "this" {
  creation_token   = "${var.name}-efs"
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_mibps : null

  encrypted  = true
  kms_key_id = var.kms_key_arn != null ? var.kms_key_arn : null

  dynamic "lifecycle_policy" {
    for_each = var.enable_lifecycle_ia ? [1] : []
    content {
      transition_to_ia = "AFTER_30_DAYS"
    }
  }

  tags = merge(var.tags, {
    Name   = "${var.name}-efs"
    Backup = var.enable_backup ? "daily" : "none"
  })

  lifecycle {
    precondition {
      condition     = var.throughput_mode != "provisioned" || var.provisioned_throughput_mibps > 0
      error_message = "When throughput_mode is provisioned, set provisioned_throughput_mibps to a value greater than 0."
    }
  }
}

#############################################
# Mount Targets (one per private subnet)
#############################################
resource "aws_efs_mount_target" "this" {
  for_each       = { for idx, subnet_id in var.private_subnet_ids : tostring(idx) => subnet_id }
  file_system_id = aws_efs_file_system.this.id
  subnet_id      = each.value
  security_groups = [
    aws_security_group.efs.id
  ]
}

#############################################
# Optional: Fixed Access Point for wp-content
#############################################
resource "aws_efs_access_point" "ap" {
  count          = var.create_fixed_access_point ? 1 : 0
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    uid = var.ap_owner_uid
    gid = var.ap_owner_gid
  }

  root_directory {
    path = var.ap_path
    creation_info {
      owner_gid   = var.ap_owner_gid
      owner_uid   = var.ap_owner_uid
      permissions = "0775"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-efs-ap" })
}

#############################################
# AWS Backup (vault + plan + selection)
#############################################
locals {
  backup_vault_name_effective = var.backup_vault_name != "" ? var.backup_vault_name : "${var.name}-efs-backup"
}

resource "aws_backup_vault" "efs" {
  count       = var.enable_backup ? 1 : 0
  name        = local.backup_vault_name_effective
  kms_key_arn = null
  tags        = var.tags
}

resource "aws_backup_plan" "efs" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name}-efs-backup"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.efs[0].name
    schedule          = var.backup_schedule_cron
    lifecycle {
      delete_after = var.backup_delete_after_days
    }
  }

  tags = var.tags
}

# Select by tag so future filesystems with the tag are included automatically
resource "aws_backup_selection" "efs" {
  count        = var.enable_backup ? 1 : 0
  name         = "${var.name}-efs-selection"
  iam_role_arn = var.backup_service_role_arn != null ? var.backup_service_role_arn : aws_iam_role.backup_service[0].arn
  plan_id      = aws_backup_plan.efs[0].id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "daily"
  }
}

# Minimal IAM role for AWS Backup to tag-select & back up EFS when no role passed in
data "aws_iam_policy_document" "backup_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup_service" {
  count              = var.enable_backup && var.backup_service_role_arn == null ? 1 : 0
  name               = "${var.name}-efs-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = var.tags
}

# AWS managed service role policy for Backup
resource "aws_iam_role_policy_attachment" "backup_service_attach" {
  count      = var.enable_backup && var.backup_service_role_arn == null ? 1 : 0
  role       = aws_iam_role.backup_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
