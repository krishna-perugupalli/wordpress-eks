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
    }

    # We use EFS for wp-content; install the EFS CSI driver as an add-on.
    aws-efs-csi-driver = {
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

#############################################
# IRSA for EBS CSI (for aws-ebs-csi-driver add-on)
#############################################

# Use OIDC issuer directly from the EKS module output (no data source reads)
locals {
  oidc_issuer_url      = module.eks.cluster_oidc_issuer_url             # e.g., https://oidc.eks.<region>.amazonaws.com/id/<uuid>
  oidc_issuer_hostpath = replace(local.oidc_issuer_url, "https://", "") # host/path without scheme
}

data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_hostpath}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
