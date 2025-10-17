provider "aws" {
  region = var.region
}

#############################################
# Kubernetes provider (talk to EKS directly)
#############################################
provider "kubernetes" {
  host                   = module.eks_core.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_core.cluster_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_core.cluster_name, "--region", var.region]
  }
}
