module "aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true

  aws_auth_roles = concat(
    [
      {
        rolearn  = var.node_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ],
    [
      for arn in var.admin_role_arns : {
        rolearn  = arn
        username = "admin:{{SessionName}}"
        groups   = ["system:masters"]
      }
    ],
    var.additional_role_mappings
  )

  aws_auth_users = var.additional_user_mappings
}
