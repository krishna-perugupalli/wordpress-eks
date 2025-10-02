terraform {
  required_version = ">= 1.6.0"

  backend "remote" {
    organization = "WpOrbit"
    workspaces {
      name = "wp-infra" # change per env
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.55"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
