provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks_core.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_core.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_core.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_core.cluster_ca)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = module.eks_core.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_core.cluster_ca)
  token                  = data.aws_eks_cluster_auth.this.token
}
