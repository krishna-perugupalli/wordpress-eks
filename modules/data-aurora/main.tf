#############################################
# Random / Secrets Manager for admin password
#############################################
resource "random_password" "admin" {
  count   = var.create_random_password ? 1 : 0
  length  = 24
  special = true
}

locals {
  admin_password_effective = var.create_random_password ? random_password.admin[0].result : var.admin_password
}

resource "aws_secretsmanager_secret" "admin" {
  name                    = "${var.name}-aurora-admin"
  description             = "Admin credentials for ${var.name} Aurora MySQL"
  kms_key_id              = var.secrets_manager_kms_key_arn
  recovery_window_in_days = 7
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "admin" {
  secret_id = aws_secretsmanager_secret.admin.id
  secret_string = jsonencode({
    username = var.admin_username
    password = local.admin_password_effective
    engine   = "aurora-mysql"
    host     = null
    port     = var.port
    dbname   = var.db_name
  })
}

#############################################
# Ingress guardrails (runtime)
#############################################
locals {
  # True if there is at least one allowed source (SG or CIDR)
  aurora_has_any_ingress = (
    length(var.allowed_security_group_ids) + length(var.allowed_cidr_blocks)
  ) > 0
}

#############################################
# Security Group for Aurora
#############################################
resource "aws_security_group" "db" {
  name        = "${var.name}-aurora-sg"
  description = "Aurora MySQL security group for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = var.tags

  lifecycle {
    # Runtime safety net — never create an unreachable DB
    precondition {
      condition     = local.aurora_has_any_ingress
      error_message = "No ingress allowed to Aurora: set allowed_security_group_ids and/or allowed_cidr_blocks."
    }
  }
}

# Allow from SGs (use count to handle unknown IDs at plan)
resource "aws_security_group_rule" "db_ingress_sg" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "Aurora MySQL from node SG"
}

# Allow from CIDRs
resource "aws_security_group_rule" "db_ingress_cidr" {
  count             = length(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = [var.allowed_cidr_blocks[count.index]]
  description       = "Aurora MySQL from CIDR"
}

#############################################
# Security Group: allow only from provided SGs / CIDRs
#############################################
# SG → SG ingress (one rule per SG), using count (plan-time length is known)
resource "aws_security_group_rule" "ingress_sg" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = var.port
  to_port                  = var.port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db.id
  source_security_group_id = var.allowed_security_group_ids[count.index]
  description              = "Allow MySQL from SG ${var.allowed_security_group_ids[count.index]}"
}

# CIDR ingress (one rule per CIDR), using count
resource "aws_security_group_rule" "ingress_cidr" {
  count             = length(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = var.port
  to_port           = var.port
  protocol          = "tcp"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = [var.allowed_cidr_blocks[count.index]]
  description       = "Allow MySQL from CIDR ${var.allowed_cidr_blocks[count.index]}"
}

# Egress open (required for RDS to reach AWS APIs, monitoring, etc.)
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.db.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress"
}

#############################################
# Subnet group + parameter groups
#############################################
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-aurora-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

# Cluster-level parameter group (Aurora MySQL)
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.name}-aurora-cluster-pg"
  family      = "aurora-mysql8.0"
  description = "Cluster parameters for ${var.name}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }
  # Example: reduce lock wait timeout for web workloads
  parameter {
    name  = "innodb_lock_wait_timeout"
    value = "50"
  }

  tags = var.tags
}

# Instance-level parameter group
resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-aurora-instance-pg"
  family      = "aurora-mysql8.0"
  description = "Instance parameters for ${var.name}"

  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }

  tags = var.tags
}

#############################################
# Aurora Cluster
#############################################
resource "aws_rds_cluster" "this" {
  cluster_identifier     = "${var.name}-aurora"
  engine                 = "aurora-mysql"
  engine_version         = var.engine_version
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  database_name          = var.db_name
  master_username        = var.admin_username
  master_password        = local.admin_password_effective
  port                   = var.port

  storage_encrypted                   = true
  kms_key_id                          = var.storage_kms_key_arn
  backup_retention_period             = var.backup_retention_days
  preferred_backup_window             = var.preferred_backup_window
  preferred_maintenance_window        = var.preferred_maintenance_window
  deletion_protection                 = var.deletion_protection
  copy_tags_to_snapshot               = var.copy_tags_to_snapshot
  apply_immediately                   = var.apply_immediately
  allow_major_version_upgrade         = false
  enable_http_endpoint                = false
  iam_database_authentication_enabled = false

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverless_v2 ? [1] : []
    content {
      min_capacity = var.serverless_min_acu
      max_capacity = var.serverless_max_acu
    }
  }

  tags = var.tags

  depends_on = [
    aws_secretsmanager_secret_version.admin
  ]
}

#############################################
# Serverless v2 writer (and optional readers)
#############################################
resource "aws_rds_cluster_instance" "serverless" {
  count                           = var.serverless_v2 ? 1 : 0
  identifier                      = "${var.name}-aurora-writer-slv2"
  cluster_identifier              = aws_rds_cluster.this.id
  instance_class                  = "db.serverless"
  engine                          = aws_rds_cluster.this.engine
  engine_version                  = aws_rds_cluster.this.engine_version
  db_parameter_group_name         = aws_db_parameter_group.this.name
  publicly_accessible             = false
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_arn
  apply_immediately               = var.apply_immediately

  monitoring_interval = 0

  tags = var.tags
}

resource "aws_rds_cluster_instance" "serverless_reader" {
  count                           = var.serverless_v2 ? 1 : 0
  identifier                      = "${var.name}-aurora-reader-slv2"
  cluster_identifier              = aws_rds_cluster.this.id
  instance_class                  = "db.serverless"
  engine                          = aws_rds_cluster.this.engine
  engine_version                  = aws_rds_cluster.this.engine_version
  db_parameter_group_name         = aws_db_parameter_group.this.name
  publicly_accessible             = false
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_arn
  apply_immediately               = var.apply_immediately

  monitoring_interval = 0

  tags = var.tags
}

#############################################
# Provisioned writer + readers (if not serverless v2)
#############################################
resource "aws_rds_cluster_instance" "provisioned_writer" {
  count                           = var.serverless_v2 ? 0 : 1
  identifier                      = "${var.name}-aurora-writer"
  cluster_identifier              = aws_rds_cluster.this.id
  instance_class                  = var.instance_class
  engine                          = aws_rds_cluster.this.engine
  engine_version                  = aws_rds_cluster.this.engine_version
  db_parameter_group_name         = aws_db_parameter_group.this.name
  publicly_accessible             = false
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_arn
  apply_immediately               = var.apply_immediately
  monitoring_interval             = 0
  tags                            = var.tags
}

resource "aws_rds_cluster_instance" "provisioned_readers" {
  count                           = var.serverless_v2 ? 0 : var.provisioned_replica_count
  identifier                      = "${var.name}-aurora-reader-${count.index}"
  cluster_identifier              = aws_rds_cluster.this.id
  instance_class                  = var.instance_class
  engine                          = aws_rds_cluster.this.engine
  engine_version                  = aws_rds_cluster.this.engine_version
  db_parameter_group_name         = aws_db_parameter_group.this.name
  publicly_accessible             = false
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_kms_key_arn
  apply_immediately               = var.apply_immediately
  monitoring_interval             = 0
  tags                            = var.tags
}

#############################################
# Update secret with final endpoints once cluster is ready
#############################################
resource "aws_secretsmanager_secret_version" "admin_final" {
  secret_id = aws_secretsmanager_secret.admin.id
  secret_string = jsonencode({
    username = var.admin_username
    password = local.admin_password_effective
    engine   = "aurora-mysql"
    host     = aws_rds_cluster.this.endpoint
    reader   = aws_rds_cluster.this.reader_endpoint
    port     = var.port
    dbname   = var.db_name
  })

  depends_on = [
    aws_rds_cluster.this,
    aws_rds_cluster_instance.serverless,
    aws_rds_cluster_instance.serverless_reader,
    aws_rds_cluster_instance.provisioned_writer,
    aws_rds_cluster_instance.provisioned_readers
  ]
}

#############################################
# Optional: AWS Backup for Aurora
#############################################
data "aws_iam_policy_document" "backup_trust_aurora" {
  count = var.enable_backup ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup_aurora" {
  count              = var.enable_backup ? 1 : 0
  name               = "${var.name}-aurora-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_trust_aurora[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_aurora_attach" {
  count      = var.enable_backup ? 1 : 0
  role       = aws_iam_role.backup_aurora[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# If/when cross-region copy is enabled later:
# - The STACK will pass an aliased provider 'aws.xregion' (destination region).
# - This data source will resolve the destination vault ARN via that alias.
/* data "aws_backup_vault" "xregion" {
  count    = var.enable_backup && var.backup_cross_region_copy.enabled ? 1 : 0
  name     = var.backup_cross_region_copy.destination_vault_name
  provider = aws.xregion
} */

resource "aws_backup_plan" "aurora" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name}-aurora-backup"

  rule {
    rule_name         = "daily"
    target_vault_name = var.backup_vault_name
    schedule          = var.backup_schedule_cron

    lifecycle {
      delete_after = var.backup_delete_after_days
    }

    # Cross-region copy is off by default. Turn on by setting enabled=true in the stack.
    /* dynamic "copy_action" {
      for_each = var.backup_cross_region_copy.enabled ? [1] : []
      content {
        destination_vault_arn = data.aws_backup_vault.xregion[0].arn
        lifecycle {
          delete_after = var.backup_cross_region_copy.delete_after_days
        }
      }
    } */
  }

  tags = var.tags
}

resource "aws_backup_selection" "aurora" {
  count        = var.enable_backup ? 1 : 0
  name         = "${var.name}-aurora-selection"
  iam_role_arn = aws_iam_role.backup_aurora[0].arn
  plan_id      = aws_backup_plan.aurora[0].id
  resources    = [aws_rds_cluster.this.arn]
}


