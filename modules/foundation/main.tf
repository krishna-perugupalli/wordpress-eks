#############################################
# Availability Zones & locals
#############################################
data "aws_availability_zones" "available" {}

locals {
  az_count = length(var.private_cidrs)
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)

  public_map  = { for i, cidr in var.public_cidrs : tostring(i) => { cidr = cidr, az = local.azs[i] } }
  private_map = { for i, cidr in var.private_cidrs : tostring(i) => { cidr = cidr, az = local.azs[i] } }

  single_nat = var.nat_gateway_mode == "single"
  per_az_nat = var.nat_gateway_mode == "per_az"
  no_nat     = var.nat_gateway_mode == "none"

}

#############################################
# VPC
#############################################
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })

  lifecycle {
    precondition {
      condition     = length(var.public_cidrs) == length(var.private_cidrs)
      error_message = "public_cidrs and private_cidrs must be the same length."
    }
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

#############################################
# Subnets
#############################################
resource "aws_subnet" "public" {
  for_each                = local.public_map
  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.name}" = "owned"
  })
}

resource "aws_subnet" "private" {
  for_each          = local.private_map
  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name                                = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb"   = "1"
    "kubernetes.io/cluster/${var.name}" = "owned"
    "karpenter.sh/discovery"            = var.name
  })
}

#############################################
# Public RT
#############################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-public-rt" })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

#############################################
# NAT (single or per-az)
#############################################
resource "aws_eip" "nat_single" {
  count  = local.single_nat ? 1 : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-eip" })
}

resource "aws_nat_gateway" "single" {
  count         = local.single_nat ? 1 : 0
  allocation_id = aws_eip.nat_single[0].id
  subnet_id     = aws_subnet.public["0"].id
  tags          = merge(var.tags, { Name = "${var.name}-natgw" })
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat" {
  for_each = local.per_az_nat ? aws_subnet.public : {}
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "per_az" {
  for_each      = local.per_az_nat ? aws_subnet.public : {}
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  tags          = merge(var.tags, { Name = "${var.name}-natgw-${each.key}" })
  depends_on    = [aws_internet_gateway.igw]
}

#############################################
# Private RT(s)
#############################################
resource "aws_route_table" "private_single" {
  count  = local.single_nat ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-private-rt" })
}

resource "aws_route" "private_single_default" {
  count                  = local.single_nat ? 1 : 0
  route_table_id         = aws_route_table.private_single[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.single[0].id
}

resource "aws_route_table_association" "private_single_assoc" {
  for_each       = local.single_nat ? aws_subnet.private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_single[0].id
}

resource "aws_route_table" "private" {
  for_each = local.per_az_nat ? aws_subnet.private : {}
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-rt-${each.key}" })
}

resource "aws_route" "private_default" {
  for_each               = local.per_az_nat ? aws_route_table.private : {}
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.per_az[each.key].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = local.per_az_nat ? aws_subnet.private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

#############################################
# Private RT(s) for VPC Endpoints (no NAT)
#############################################
resource "aws_route_table" "private_vpc_endpoints" {
  for_each = var.enable_vpc_endpoints && var.nat_gateway_mode == "none" ? aws_subnet.private : {}
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.name}-private-rt-${each.key}-vpc-endpoints" })
}

resource "aws_route_table_association" "private_vpc_endpoints_assoc" {
  for_each       = var.enable_vpc_endpoints && var.nat_gateway_mode == "none" ? aws_subnet.private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_vpc_endpoints[each.key].id
}

#############################################
# KMS
#############################################
resource "aws_kms_key" "rds" {
  description             = "${var.name}-rds"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}
resource "aws_kms_key" "efs" {
  description             = "${var.name}-efs"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}
resource "aws_kms_key" "logs" {
  description             = "${var.name}-logs"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}
resource "aws_kms_key" "s3" {
  description             = "${var.name}-s3"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}

#############################################
# S3: logs + media (+ access logs)
#############################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  bucket_suffix = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "logs" {
  bucket        = "${var.name}-sec-logs-${local.bucket_suffix}"
  force_destroy = false
  tags          = var.tags
}
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  # CloudFront standard logs require ACLs; use Preferred, not Enforced
  rule { object_ownership = "BucketOwnerPreferred" }
}
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      # Use SSE-S3 for compatibility with CloudFront log delivery
      sse_algorithm = "AES256"
    }
  }
}

# Grant ACL permissions required for log delivery
resource "aws_s3_bucket_acl" "logs" {
  bucket     = aws_s3_bucket.logs.id
  acl        = "log-delivery-write"
  depends_on = [aws_s3_bucket_ownership_controls.logs]
}
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "media" {
  bucket        = var.media_bucket_name != "" ? var.media_bucket_name : "${var.name}-media-${local.bucket_suffix}"
  force_destroy = false
  tags          = var.tags
}
resource "aws_s3_bucket_ownership_controls" "media" {
  bucket = aws_s3_bucket.media.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_logging" "media_to_logs" {
  bucket        = aws_s3_bucket.media.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-media/"
}
resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# ECR
#############################################
resource "aws_ecr_repository" "wp" {
  name = "${var.name}/wdp"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.s3.arn
  }
  tags = var.tags
}

#############################################
# VPC Endpoints (when NAT Gateway is disabled)
#############################################

# Security group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  count       = var.enable_vpc_endpoints ? 1 : 0
  name        = "${var.name}-vpc-endpoints"
  description = "Security group for VPC Endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-vpc-endpoints-sg" })
}

# S3 Gateway Endpoint (free)
resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_vpc_endpoints ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    var.nat_gateway_mode == "none" ? [for rt in aws_route_table.private_vpc_endpoints : rt.id] : []
  )

  tags = merge(var.tags, { Name = "${var.name}-s3-endpoint" })
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-ecr-api-endpoint" })
}

# ECR DKR Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-ecr-dkr-endpoint" })
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  count               = var.enable_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, { Name = "${var.name}-secretsmanager-endpoint" })
}

#############################################
# (Optional) Route53 public hosted zone
#############################################
resource "aws_route53_zone" "public" {
  count = var.create_public_hosted_zone ? 1 : 0
  name  = var.domain
  tags  = var.tags
}
