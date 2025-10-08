#############################################
# Inputs & derived
#############################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  allow_any_ingress  = length(var.node_sg_source_ids) + length(var.allowed_cidr_blocks) > 0
  node_sg_source_map = { for idx, sg_id in var.node_sg_source_ids : tostring(idx) => sg_id }
  # replicas_per_node_group: how many replicas per shard (exclude the primary)
  rpng = var.replicas_per_node_group
}

#############################################
# Security Group
#############################################
resource "aws_security_group" "redis" {
  name        = "${var.name}-redis-sg"
  description = "Redis (ElastiCache) SG for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-redis-sg" })

  lifecycle {
    precondition {
      condition     = local.allow_any_ingress
      error_message = "No Redis ingress sources provided. Set node_sg_source_ids and/or allowed_cidr_blocks."
    }
  }
}

# Ingress from Node SGs
resource "aws_security_group_rule" "ingress" {
  for_each                 = local.node_sg_source_map
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = each.value
  description              = "Redis TLS from node SG ${each.value}"
}

# Optional CIDR ingress (migration/ops)
resource "aws_security_group_rule" "ingress_cidr" {
  for_each          = toset(var.allowed_cidr_blocks)
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "tcp"
  security_group_id = aws_security_group.redis.id
  cidr_blocks       = [each.value]
  description       = "Redis TLS from CIDR ${each.value}"
}

# Egress open
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.redis.id
  cidr_blocks       = ["0.0.0.0/0"]
}

#############################################
# Subnet group
#############################################
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis-subnets"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-redis-subnets" })
}

#############################################
# Parameter group (use parameter {} blocks)
#############################################
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name}-redis"
  family = var.engine_family # e.g., "redis7"

  parameter {
    name  = "timeout"
    value = "0"
  }

  # Add more parameter blocks as needed; avoid non-modifiable ones like "appendonly".
}

#############################################
# Auth token (from Secrets Manager) — optional
#############################################
data "aws_secretsmanager_secret_version" "auth" {
  count = var.enable_auth_token_secret && var.auth_token == "" && var.auth_token_secret_arn != "" ? 1 : 0

  secret_id = var.auth_token_secret_arn
}

locals {
  redis_auth_token = var.auth_token != "" ? var.auth_token : (var.enable_auth_token_secret && var.auth_token_secret_arn != "" ? try(jsondecode(data.aws_secretsmanager_secret_version.auth[0].secret_string).token, null) : null)
}

#############################################
# Replication group (cluster mode: 1 node group + replicas)
#############################################
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Redis replication group for ${var.name}"

  engine         = "redis"
  engine_version = var.engine_version

  parameter_group_name = aws_elasticache_parameter_group.this.name
  node_type            = var.node_type
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = local.redis_auth_token

  automatic_failover_enabled = var.automatic_failover
  multi_az_enabled           = var.multi_az

  # --- Provider-compat: cluster_mode as STRING + top-level counts ---
  # enable one shard (node group) with N replicas
  cluster_mode            = "enabled"
  num_node_groups         = 1
  replicas_per_node_group = var.replicas_per_node_group

  maintenance_window       = var.maintenance_window
  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = var.snapshot_window

  tags = var.tags

  lifecycle {
    ignore_changes = [auth_token]
  }
}
