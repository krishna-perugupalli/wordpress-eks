provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.region
    ]
    env = {
      # These two help both locally (SSO) and in CI
      AWS_STS_REGIONAL_ENDPOINTS = "regional"
      AWS_SDK_LOAD_CONFIG        = "1"
      # Optional (local): if you use SSO profiles, pass it through
      # AWS_PROFILE                = var.aws_profile
    }
  }
}
