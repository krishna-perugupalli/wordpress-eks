#############################################
# Cluster IAM role
#############################################
/* resource "aws_iam_role" "cluster" {
  name = "${local.name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_base" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ])
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "cluster_extra" {
  for_each   = toset(var.extra_cluster_policy_arns)
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
} */

#############################################
# Nodegroup IAM role
#############################################
/* resource "aws_iam_role" "node" {
  name = "${local.name}-nodegroup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_base" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "node_extra" {
  for_each   = toset(var.extra_node_policy_arns)
  role       = aws_iam_role.node.name
  policy_arn = each.value
} */

locals {
  account_number    = data.aws_caller_identity.current.account_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  kms_key_arn       = module.secrets_iam.kms_secrets_arn
}

#############################################
# EKS Roles (Completly new) - Starts from here.
#############################################
### EKS Cluster Role ###
resource "aws_iam_role" "eks_cluster_role" {
  ## count = var.enable_eks ? 1 : 0
  name = "${local.name}-eks_cluster_role"
  tags = var.tags
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = ["ec2.amazonaws.com", "eks.amazonaws.com"]
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role" "ebs_csi_role" {
  # count = var.enable_eks ? 1 : 0
  name = "${local.name}-eks_ebs_csi_role"
  tags = var.tags
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${local.account_number}:oidc-provider/${local.oidc_provider_arn}"
      }
      Condition = {
        "StringEquals" : {
          "${local.oidc_provider_arn}:sub" : "system:serviceaccount:kube-system:ebs-csi-controller-sa",
          "${local.oidc_provider_arn}:aud" : "sts.amazonaws.com"
        }
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy" "ebs_csi_device_encryption" {
  name = "AmazonEbsCsiDeviceEncryption"
  role = aws_iam_role.ebs_csi_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
        Condition = {
          "Bool" : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
        Resource = ["arn:aws:kms:${var.region}:${local.account_number}:key/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey", "kms:Encrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext", "kms:GenerateDataKeyPair", "kms:GenerateDataKeyPairWithoutPlaintext", "kms:ReEncryptFrom", "kms:ReEncryptTo"]
        Resource = ["arn:aws:ssm:${var.region}:${local.account_number}:parameter/osdu/*"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_vpc_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_cni_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_role.name
}

### End EKS Cluster Role ###

### EKS Node Group Role ###
resource "aws_iam_role" "eks_node_group_role" {
  # count = var.enable_eks ? 1 : 0
  name = "${local.name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = ["ec2.amazonaws.com", "eks.amazonaws.com"]
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_readonly-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "efs_readonly_policy-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemReadOnlyAccess"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore-attachment" {
  # count      = var.enable_eks ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy" "kube2iam_access_policy" {
  # count = var.enable_eks ? 1 : 0
  name = "${local.name}-kube2iam-access-policy"
  role = aws_iam_role.eks_node_group_role.id
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect"   = "Allow",
        "Action"   = ["sts:AssumeRole"],
        "Resource" = "arn:aws:iam::${local.account_number}:role/*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eks_node_group_role_kms_policy" {
  # count = var.enable_eks ? 1 : 0
  name = "${local.name}-eks-node-kms-policy"
  role = aws_iam_role.eks_node_group_role.id
  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Action" = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource" = "${local.kms_key_arn}"
      }
    ]
  })
}
### End EKS Node Group Role ###

### EKS Cluster Cluster Management Admin Role ###

resource "aws_iam_role" "cluster_management_role" {
  # count = var.enable_eks ? 1 : 0
  name = "${local.name}-eks-cluster-management-role"
  tags = merge(var.tags, { Name = "${local.name}-eks-cluster-management-role" })
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = concat(["arn:aws:iam::${local.account_number}:root"], var.eks_cluster_management_role_trust_principals)
      }
    }]
    Version = "2012-10-17"
  })

}

resource "aws_iam_role_policy" "cluster_management_access_policy" {
  name = "${local.name}-eks-access-policy"
  role = aws_iam_role.cluster_management_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:AccessKubernetesApi",
          "eks:AssociateIdentityProviderConfig",
          "eks:DescribeCluster",
          "eks:DescribeIdentityProviderConfig",
          "eks:DescribeNodegroup",
          "eks:DescribeUpdate",
          "eks:DisassociateIdentityProviderConfig",
          "eks:ListClusters",
          "eks:ListIdentityProviderConfigs",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion",
          "eks:UpdateNodegroupConfig"
        ]
        Resource = ["arn:aws:eks:${var.region}:${local.account_number}:cluster/${local.name}"]
      },
    ]
  })
}

resource "aws_iam_role_policy" "cluster_management_oidc_policy" {
  name = "${local.name}-get-oidc-provider-access"
  role = aws_iam_role.cluster_management_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "iam:GetOpenIDConnectProvider"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iam::${local.account_number}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "cluster_management_logs_policy" {
  name = "${local.name}-logs-policy"
  role = aws_iam_role.cluster_management_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.region}:${local.account_number}:log-group:*"
      }
    ]
  })
}

resource "aws_eks_access_entry" "cluster_manager" {
  # count         = var.enable_eks ? 1 : 0
  cluster_name  = local.name
  principal_arn = aws_iam_role.cluster_management_role.arn
  type          = "STANDARD"
  depends_on    = [module.eks]
}

resource "aws_eks_access_policy_association" "cluster_manager_policy" {
  # count         = var.enable_eks ? 1 : 0
  cluster_name  = local.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.cluster_management_role.arn
  access_scope {
    type = "cluster"
  }
  depends_on = [aws_eks_access_entry.cluster_manager]
}
