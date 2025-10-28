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
  name              = "/aws/eks/${local.name}/cluster/${each.value}"
  retention_in_days = var.control_plane_log_retention_days
  tags              = var.tags
}

locals {
  eks_access_entries_roles = {
    for idx, arn in var.eks_admin_role_arns :
    "admin_role_${idx}" => {
      principal_arn = arn
      type          = "STANDARD"
      policy_associations = [{
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }]
    }
  }

  eks_access_entries_users = {
    for idx, arn in var.eks_admin_user_arns :
    "admin_user_${idx}" => {
      principal_arn = arn
      type          = "STANDARD"
      policy_associations = [{
        policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = { type = "cluster" }
      }]
    }
  }

  eks_access_entries = merge(local.eks_access_entries_roles, local.eks_access_entries_users)
}


#############################################
# EKS (terraform-aws-modules/eks/aws v20)
#############################################

locals {
  default_kms_key_arn = "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:alias/aws/secretsmanager"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name    = local.name
  cluster_version = var.cluster_version
  vpc_id          = module.foundation.vpc_id
  subnet_ids      = module.foundation.private_subnet_ids
  enable_irsa     = var.enable_irsa

  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = coalesce(module.secrets_iam.kms_secrets_arn, local.default_kms_key_arn)
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
    "karpenter.sh/discovery" = local.name
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

  iam_role_arn        = aws_iam_role.eks_cluster_role.arn
  authentication_mode = "API_AND_CONFIG_MAP"

  access_entries = local.eks_access_entries

  # ----- Managed Add-ons (un-pinned; let AWS pick valid versions) -----
  cluster_addons = {
    vpc-cni = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
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
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.efs_csi_irsa.iam_role_arn
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # ----- System Managed Node Group -----
  /* eks_managed_node_groups = {
    system = {
      name           = "system"
      iam_role_arn   = aws_iam_role.eks_node_group_role.arn
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
  } */

  eks_managed_node_groups = {

    default = {
      name                    = "${local.name}-default"
      subnet_ids              = module.foundation.private_subnet_ids
      min_size                = 2
      max_size                = 2
      desired_size            = 2
      force_update_version    = true
      ami_type                = var.node_ami_type
      instance_types          = [var.system_node_type]
      description             = "${local.name} - EKS managed node group launch template"
      ebs_optimized           = true
      disable_api_termination = false
      enable_monitoring       = true
      create_security_group   = false
      create_iam_role         = false
      use_name_prefix         = false
      iam_role_arn            = aws_iam_role.eks_node_group_role.arn
      tags                    = merge({ "service" = "ec2", "EksClusterName" = local.name }, local.tags)

      # Increase default timeouts to reduce likelihood of timeout errors on upgrades
      timeouts = {
        create = "120m"
        update = "120m"
        delete = "60m"
      }

      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 75
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 150
            encrypted             = true
            delete_on_termination = true
            #kms_key_id            = module.kms_key.arn
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
        instance_metadata_tags      = "disabled"
      }
    }
  }

  tags = merge({ "service" = "eks", "Name" = local.name }, local.tags)
}



