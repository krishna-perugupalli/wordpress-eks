#############################################
# Locals
#############################################
locals {
  ns            = var.controller_namespace
  oidc_hostpath = replace(var.cluster_oidc_issuer_url, "https://", "")
  efs_name      = "${var.name}-efs"
  mount_sg_name = "${var.name}-efs-sg"
}

#############################################
# EFS FileSystem (+ lifecycle) + SG + Mount Targets
#############################################
resource "aws_efs_file_system" "this" {
  creation_token                  = local.efs_name
  encrypted                       = true
  kms_key_id                      = var.kms_key_arn
  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_mibps : null
  tags                            = merge(var.tags, { Name = local.efs_name })

  dynamic "lifecycle_policy" {
    for_each = var.enable_lifecycle_ia ? [1] : []
    content {
      transition_to_ia = "AFTER_30_DAYS"
      # Optionally (newer providers support this):
      # transition_to_primary_storage_class = "AFTER_1_ACCESS"
    }
  }
}

# Access policy (NOT lifecycle) — optional, permissive minimal mount
resource "aws_efs_file_system_policy" "this" {
  file_system_id = aws_efs_file_system.this.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowClientMount",
      Effect    = "Allow",
      Principal = "*",
      Action    = ["elasticfilesystem:ClientMount"],
      Resource  = aws_efs_file_system.this.arn
    }]
  })
}

# Tight SG: allow NFS 2049 only from SGs/CIDRs you pass
resource "aws_security_group" "efs" {
  name        = local.mount_sg_name
  description = "EFS mount access for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "efs_ingress_sg" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "Allow NFS from SG ${var.allowed_security_group_ids[count.index]}"
}

resource "aws_security_group_rule" "efs_ingress_cidr" {
  count             = length(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  security_group_id = aws_security_group.efs.id
  cidr_blocks       = [var.allowed_cidr_blocks[count.index]]
  description       = "Allow NFS from CIDR ${var.allowed_cidr_blocks[count.index]}"
}

resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.efs.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

# Mount targets in each private subnet (one per subnet; ensure one subnet per AZ)
resource "aws_efs_mount_target" "this" {
  count           = length(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

#############################################
# Optional: Fixed Access Point for /wp-content
#############################################
resource "aws_efs_access_point" "wp" {
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
      permissions = "0755"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-wp-ap" })
}

#############################################
# IRSA for EFS CSI Driver
#############################################
data "aws_iam_policy_document" "efs_csi_trust" {
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
      values   = ["system:serviceaccount:${var.controller_namespace}:efs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "efs_csi" {
  name               = "${var.name}-efs-csi"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi_attach" {
  role       = aws_iam_role.efs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}

#############################################
# Helm: AWS EFS CSI Driver
#############################################
resource "kubernetes_service_account" "efs_csi" {
  metadata {
    name      = "efs-csi-controller-sa"
    namespace = var.controller_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.efs_csi.arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-efs-csi-driver"
    }
  }
  automount_service_account_token = true
}

resource "helm_release" "efs_csi" {
  name       = "aws-efs-csi-driver"
  namespace  = var.controller_namespace
  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = "2.6.6"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = kubernetes_service_account.efs_csi.metadata[0].name
  }

  depends_on = [
    kubernetes_service_account.efs_csi
  ]
}

#############################################
# StorageClasses
#############################################
# Dynamic AP provisioning (recommended)
resource "kubernetes_storage_class_v1" "efs_ap" {
  metadata {
    name = "efs-ap"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "false"
    }
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.this.id
    basePath         = "/dynamic"
    directoryPerms   = "0770"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
  }

  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"

  depends_on = [helm_release.efs_csi]
}

# Optional: Static AP StorageClass (binds to the fixed AP)
resource "kubernetes_storage_class_v1" "efs_ap_static" {
  count = var.create_fixed_access_point ? 1 : 0

  metadata {
    name = "efs-ap-static"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.this.id
    basePath         = "/"
    directoryPerms   = "0755"
    gidRangeStart    = "2001"
    gidRangeEnd      = "3000"
  }

  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"

  depends_on = [helm_release.efs_csi]
}

#############################################
# Optional: AWS Backup for EFS
#############################################
data "aws_iam_policy_document" "backup_trust_efs" {
  count = var.enable_backup ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup_efs" {
  count              = var.enable_backup ? 1 : 0
  name               = "${var.name}-efs-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_trust_efs[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_efs_attach" {
  count      = var.enable_backup ? 1 : 0
  role       = aws_iam_role.backup_efs[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_plan" "efs" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name}-efs-backup"

  rule {
    rule_name         = "daily"
    target_vault_name = var.backup_vault_name
    schedule          = var.backup_schedule_cron
    lifecycle {
      delete_after = var.backup_delete_after_days
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "efs" {
  count        = var.enable_backup ? 1 : 0
  name         = "${var.name}-efs-selection"
  iam_role_arn = aws_iam_role.backup_efs[0].arn
  plan_id      = aws_backup_plan.efs[0].id
  resources    = [aws_efs_file_system.this.arn]
}
