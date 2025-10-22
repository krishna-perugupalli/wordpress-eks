# Get latest version information from here: https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
module "vpc_cni_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.30.0"
  role_name             = "${var.name}-eks_vpc_cni_irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.tags
}

# EBS CSI IRSA
module "ebs_csi_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.30.0"
  role_name             = "${var.name}-eks_ebs_csi_irsa"
  attach_ebs_csi_policy = true
  # Uncomment only if you actually have a CMK module and want CMK-encrypted EBS
  # ebs_csi_kms_cmk_ids   = [module.kms_key.arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# EFS CSI IRSA
module "efs_csi_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.30.0"
  role_name             = "${var.name}-eks_efs_csi_irsa" # <- fixed
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  tags = var.tags
}
