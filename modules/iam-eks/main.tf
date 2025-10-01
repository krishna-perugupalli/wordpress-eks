#############################################
# Cluster IAM role
#############################################
resource "aws_iam_role" "cluster" {
  name = "${var.name}-cluster-role"
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
}

#############################################
# Nodegroup IAM role
#############################################
resource "aws_iam_role" "node" {
  name = "${var.name}-nodegroup-role"
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
}
