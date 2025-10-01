data "aws_subnet" "vpc" {
  id = var.subnet_ids[0]
}

resource "aws_elasticache_subnet_group" "this" {
  name        = "${var.name}-redis-subnets"
  subnet_ids  = var.subnet_ids
  description = "Redis subnet group"
}

#############################################
# Ingress guardrails (runtime)
#############################################
locals {
  redis_has_any_ingress = length(var.node_sg_source_ids) > 0
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis-sg"
  description = "Redis TLS access for ${var.name}"
  vpc_id      = data.aws_subnet.vpc.vpc_id
  tags        = var.tags

  lifecycle {
    precondition {
      condition     = local.redis_has_any_ingress
      error_message = "No ingress allowed to Redis: provide at least one node_sg_source_id."
    }
  }
}

resource "aws_security_group_rule" "ingress" {
  count                    = length(var.node_sg_source_ids)
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis.id
  source_security_group_id = var.node_sg_source_ids[count.index]
  description              = "Redis TLS from node SG"
}

data "aws_secretsmanager_secret_version" "auth" {
  secret_id = var.auth_token_secret_arn
}

resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name}-redis-pg"
  family = "redis7"

  parameter {
    name  = "appendonly"
    value = "no"
  }
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id       = "${var.name}-rg"
  description                = "Redis for ${var.name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  parameter_group_name       = aws_elasticache_parameter_group.this.name
  security_group_ids         = [aws_security_group.redis.id]
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_id
  transit_encryption_enabled = true
  auth_token                 = jsondecode(data.aws_secretsmanager_secret_version.auth.secret_string)["token"]
  automatic_failover_enabled = true
  multi_az_enabled           = true
  num_node_groups            = 1
  replicas_per_node_group    = var.num_replicas_per_shard
  auto_minor_version_upgrade = true
  port                       = 6379
  tags                       = var.tags
}
