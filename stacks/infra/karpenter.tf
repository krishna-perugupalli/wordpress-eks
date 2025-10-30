resource "aws_iam_policy" "karpenter_node_role_kms_policy" {
  name = "${local.name}karpenter-kms-policy"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = ["${module.secrets_iam.kms_secrets_arn}"]
      },
    ]
  })
}

module "karpenter" {
  source                        = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                       = "20.24.0"
  cluster_name                  = module.eks.cluster_name
  irsa_oidc_provider_arn        = module.eks[0].oidc_provider_arn
  iam_role_name                 = "${local.name}karpenter-controller"
  iam_role_use_name_prefix      = false
  enable_irsa                   = true
  node_iam_role_name            = "${local.name}karpenter-node-role"
  node_iam_role_use_name_prefix = false
  create_instance_profile       = true
  node_iam_role_additional_policies = {
    "KMSPolicy" = aws_iam_policy.karpenter_node_role_kms_policy[0].arn
  }
}

