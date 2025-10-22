#############################################
# Control plane log groups (retention)
#############################################
locals {
  cp_logs = var.enable_cluster_logs ? [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ] : []
}

resource "aws_cloudwatch_log_group" "eks_cp" {
  for_each          = toset(local.cp_logs)
  name              = "/aws/eks/${var.name}/cluster/${each.value}"
  retention_in_days = var.control_plane_log_retention_days
  tags              = var.tags
}

#############################################
# EKS (terraform-aws-modules/eks/aws v20)
#############################################

data "aws_caller_identity" "current" {}

locals {
  default_kms_key_arn = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:alias/aws/secretsmanager"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name    = var.name
  cluster_version = var.cluster_version
  vpc_id          = var.vpc_id
  subnet_ids      = var.private_subnet_ids
  enable_irsa     = var.enable_irsa

  # ✅ final working shape
  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = coalesce(var.secrets_kms_key_arn, local.default_kms_key_arn)
  }
  node_security_group_additional_rules = {
    nodes_istiod_port = {
      description                   = "Cluster API to Node group for istiod webhook"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    node_to_node_communication = {
      description = "Allow full access for cross-node communication"
      protocol    = "tcp"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
  }

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = var.name
  }

  eks_managed_node_group_defaults = {
    # We are using the IRSA created below for permissions
    # However, we have to provision a new cluster with the policy attached FIRST
    # before we can disable. Without this initial policy,
    # the VPC CNI fails to assign IPs and nodes cannot join the new cluster
    iam_role_attach_cni_policy = true
  }

  cluster_endpoint_public_access       = var.endpoint_public_access
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access_cidrs = var.endpoint_public_access ? var.public_access_cidrs : null
  cluster_enabled_log_types            = local.cp_logs

  iam_role_arn        = var.cluster_role_arn
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = var.access_entries

  # ----- Managed Add-ons (un-pinned; let AWS pick valid versions) -----
  cluster_addons = {
    vpc-cni = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      # service_account_role_arn = var.service_account_role_arn_vpc_cni
      configuration_values = var.enable_cni_prefix_delegation ? jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = tostring(var.cni_prefix_warm_target)
        }
      }) : null
    }

    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }

    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      timeouts = {
        create = "25m"
        delete = "10m"
      }
    }

    # We use EFS for wp-content; install the EFS CSI driver as an add-on.
    aws-efs-csi-driver = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
      # service_account_role_arn = var.service_account_role_arn_efs_csi
    }
    aws-ebs-csi-driver = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
  }

  # ----- System Managed Node Group -----
  eks_managed_node_groups = {
    system = {
      name           = "system"
      iam_role_arn   = var.node_role_arn
      instance_types = [var.system_node_type]
      ami_type       = var.node_ami_type
      capacity_type  = var.node_capacity_type

      min_size     = var.system_node_min
      max_size     = var.system_node_max
      desired_size = var.system_node_min

      disk_size = var.node_disk_size_gb

      labels = { role = "system" }

      update_config = { max_unavailable = 1 }

      tags = var.tags
    }
  }

  tags = var.tags
}
