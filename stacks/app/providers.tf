###############################################################################
# Remote state: read infra outputs (EKS, VPC, secrets, endpoints, etc.)
###############################################################################
data "terraform_remote_state" "infra" {
  backend = "remote"
  config = {
    organization = "WpOrbit" # <-- CHANGE THIS
    workspaces = {
      name = "wp-infra" # <-- CHANGE THIS (your infra workspace)
    }
  }
}

###############################################################################
# AWS provider (region driven by your app variables)
###############################################################################
provider "aws" {
  region = var.region
}

###############################################################################
# EKS cluster data (to wire kubernetes/helm/kubectl providers)
###############################################################################
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

###############################################################################
# Kubernetes, Helm, Kubectl providers (auth via EKS token)
###############################################################################
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
