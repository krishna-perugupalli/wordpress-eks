terraform {
  required_version = ">= 1.5.0, < 1.9.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
