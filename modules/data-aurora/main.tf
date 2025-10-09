#############################################
# Region/account + discover valid engine version
#############################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Discover a valid Aurora MySQL 8.0 engine version for this region
data "aws_rds_engine_version" "aurora_mysql" {
  engine                 = "aurora-mysql"
  parameter_group_family = "aurora-mysql8.0"
  preferred_versions     = [] # Empty => latest supported by the region
}

#############################################
# Security Group (Aurora)
#############################################
locals {
  _aurora_has_any_ingress           = var.enable_source_node_sg_rule || length(var.allowed_cidr_blocks) > 0
  final_snapshot_identifier_default = lower("${var.name}-aurora-final")
  final_snapshot_identifier_effective = var.skip_final_snapshot ? null : (
    length(trimspace(coalesce(var.final_snapshot_identifier, ""))) > 0
    ? trimspace(var.final_snapshot_identifier)
    : local.final_snapshot_identifier_default
  )
}

resource "aws_security_group" "db" {
  name        = "${var.name}-aurora-sg"
  description = "Aurora MySQL security group for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    precondition {
      condition     = local._aurora_has_any_ingress
      error_message = "Aurora requires at least one ingress source. Keep enable_source_node_sg_rule=true or specify allowed_cidr_blocks."
    }
  }
}

# Plan-stable: single known SG (e.g., node SG) via count
resource "aws_security_group_rule" "db_ingress_node_sg" {
  count                    = var.enable_source_node_sg_rule ? 1 : 0
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.source_node_sg_id
  description              = "Aurora MySQL from node SG"
}

# Optional static CIDRs
resource "aws_security_group_rule" "db_ingress_cidr" {
  for_each          = toset(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = [each.value]
  description       = "Aurora MySQL from ${each.value}"
}

# Egress all
resource "aws_security_group_rule" "db_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = ["0.0.0.0/0"]
}

#############################################
# Subnet group
#############################################
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-aurora-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-aurora-subnets" })
}

#############################################
# Aurora MySQL (Serverless v2)
#############################################
resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name}-aurora"

  engine         = "aurora-mysql"
  engine_version = data.aws_rds_engine_version.aurora_mysql.version

  database_name                 = var.db_name
  master_username               = var.admin_username
  master_password               = var.create_random_password ? null : var.admin_password
  manage_master_user_password   = var.create_random_password
  master_user_secret_kms_key_id = var.secrets_manager_kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  storage_encrypted = true
  kms_key_id        = var.storage_kms_key_arn

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  deletion_protection = var.deletion_protection

  # Serverless v2 scaling (engine_mode remains "provisioned" with this block)
  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_acu
    max_capacity = var.serverless_max_acu
  }

  copy_tags_to_snapshot     = true
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = local.final_snapshot_identifier_effective

  tags = merge(var.tags, { Name = "${var.name}-aurora" })
}

# At least one instance for the cluster (Serverless v2)
resource "aws_rds_cluster_instance" "this" {
  identifier          = "${var.name}-aurora-1"
  cluster_identifier  = aws_rds_cluster.this.id
  instance_class      = "db.serverless"
  engine              = aws_rds_cluster.this.engine
  engine_version      = aws_rds_cluster.this.engine_version
  publicly_accessible = false

  tags = merge(var.tags, { Name = "${var.name}-aurora-1" })
}

#############################################
# AWS Backup (vault + plan + selection)
#############################################
locals {
  backup_vault_name_effective = var.backup_vault_name != "" ? var.backup_vault_name : "${var.name}-aurora-backup"
}

resource "aws_backup_vault" "aurora" {
  count       = var.enable_backup ? 1 : 0
  name        = local.backup_vault_name_effective
  kms_key_arn = null
  tags        = var.tags
}

resource "aws_backup_plan" "aurora" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name}-aurora-backup"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.aurora[0].name
    schedule          = var.backup_schedule_cron
    lifecycle {
      delete_after = var.backup_delete_after_days
    }
  }

  tags = var.tags
}

# Selection by explicit resource ARN (cluster)
resource "aws_backup_selection" "aurora" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name}-aurora-selection"

  iam_role_arn = var.backup_service_role_arn != null ? var.backup_service_role_arn : aws_iam_role.backup_service[0].arn
  plan_id      = aws_backup_plan.aurora[0].id

  resources = [aws_rds_cluster.this.arn]
}

# Minimal IAM role for AWS Backup when not provided
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
  name               = "${var.name}-aurora-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_service_attach" {
  count      = var.enable_backup && var.backup_service_role_arn == null ? 1 : 0
  role       = aws_iam_role.backup_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
