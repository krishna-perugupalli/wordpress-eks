# Get latest version information from here: https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
module "vpc_cni_irsa" {
  # count                 = var.enable_eks ? 1 : 0
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.30.0"
  role_name             = "${var.name}-eks_vpc_cni_irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = var.tags
}

# Get latest version information from here: https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest
module "ebs_csi_irsa" {
  # count                 = var.enable_eks ? 1 : 0
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.30.0"
  role_name             = "${var.name}-eks_ebs_csi_irsa"
  attach_ebs_csi_policy = true
  ebs_csi_kms_cmk_ids   = [module.kms_key.arn]


  oidc_providers = {
    main = {
      provider_arn               = module.eks[0].oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

module "efs_csi_irsa" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version               = "5.30.0"
  role_name             = "${var.name}-eks_efs_csi_irsa"
  attach_efs_csi_policy = true


  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }

  tags = var.tags
}
