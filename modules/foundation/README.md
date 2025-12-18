# Foundation Module

This module creates the core networking infrastructure for the WordPress on EKS platform.

## Overview

The foundation module provisions the VPC, subnets, NAT gateways, and other networking components required for the EKS cluster and associated AWS services.

## Features

- Multi-AZ VPC with public and private subnets
- NAT Gateway for private subnet internet access
- VPC endpoints for AWS services (S3, ECR, etc.)
- Flow logs for network monitoring
- Proper subnet tagging for EKS and load balancer discovery
- DHCP options set configuration

## Usage

```hcl
module "foundation" {
  source = "../../modules/foundation"

  name = "wordpress-eks"
  
  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  enable_nat_gateway = true
  single_nat_gateway = false
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Notes

- Public subnets are tagged for external load balancers
- Private subnets are tagged for internal load balancers and EKS
- NAT Gateway costs can be reduced by using single_nat_gateway=true (not recommended for production)
- VPC Flow Logs help with security analysis and troubleshooting
