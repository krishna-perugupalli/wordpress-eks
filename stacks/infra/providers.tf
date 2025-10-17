# --- AWS provider (keep as-is) ---
provider "aws" {
  region = var.region
}

# --- Read EKS connection details from the cluster you create in this stack ---
# (Assumes your EKS module block is named "eks-core"; if it's "eks" change the name below.)
data "aws_eks_cluster" "this" {
  name = module.eks-core.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks-core.cluster_name
}

# --- Kubernetes provider that aws-auth (and other K8s resources) will use ---
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}
