#############################################
# Infrastructure Stack Validations
#############################################

#############################################
# CloudFront Certificate Validation (us-east-1)
#############################################

# CloudFront certificate validation using terraform_data resource
resource "terraform_data" "cloudfront_certificate_validation" {
  count = var.enable_cloudfront ? 1 : 0

  lifecycle {
    precondition {
      condition     = can(regex("^arn:aws(-[a-z]+)?:acm:us-east-1:[0-9]{12}:certificate/[a-f0-9-]+$", var.cloudfront_certificate_arn))
      error_message = <<-EOT
        CloudFront certificate ARN validation failed:
        Certificate ARN format is invalid or not in us-east-1 region.
        
        Provided ARN: ${var.cloudfront_certificate_arn}
        Expected format: arn:aws:acm:us-east-1:<account-id>:certificate/<certificate-id>
        
        CloudFront requires ACM certificates to be in us-east-1 region regardless of 
        where your other resources are deployed.
        
        Common issues:
        - Wrong region: Must be us-east-1 (not ${var.region})
        - Wrong service: Must be 'acm' (not 'iam' or other)
        - Invalid certificate ID: Must be UUID format
        - Missing parts: ARN must include all components
        
        Valid example:
        arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
        
        To create certificate in us-east-1:
        aws acm request-certificate --domain-name ${var.wordpress_domain_name} --region us-east-1 --validation-method DNS
        
        To find existing certificates:
        aws acm list-certificates --region us-east-1
      EOT
    }
  }
}

#############################################
# Infrastructure Readiness Validation
#############################################

# Comprehensive validation that all infrastructure components are ready for CloudFront
resource "terraform_data" "infrastructure_readiness_validation" {
  count = var.enable_cloudfront ? 1 : 0

  lifecycle {
    precondition {
      condition = alltrue([
        module.foundation.vpc_id != "",
        length(module.foundation.public_subnet_ids) > 0,
        length(module.foundation.private_subnet_ids) > 0,
        module.foundation.logs_bucket != ""
      ])
      error_message = <<-EOT
        Infrastructure readiness validation failed:
        Foundation components are not ready for CloudFront deployment.
        
        Foundation status:
        - VPC ID: "${module.foundation.vpc_id}"
        - Public subnets: ${length(module.foundation.public_subnet_ids)} (need > 0)
        - Private subnets: ${length(module.foundation.private_subnet_ids)} (need > 0)  
        - Logs bucket: "${module.foundation.logs_bucket}"
        
        All foundation components must be successfully deployed before CloudFront.
        
        To resolve:
        1. Check foundation module deployment logs
        2. Verify VPC and subnet creation completed
        3. Ensure S3 bucket creation succeeded
        4. Re-run: terraform apply -target=module.foundation
      EOT
    }
    precondition {
      condition = alltrue([
        module.eks.cluster_name != "",
        module.eks.cluster_endpoint != "",
        module.eks.node_security_group_id != ""
      ])
      error_message = <<-EOT
        Infrastructure readiness validation failed:
        EKS components are not ready for CloudFront deployment.
        
        EKS status:
        - Cluster name: "${module.eks.cluster_name}"
        - Cluster endpoint: "${module.eks.cluster_endpoint}"
        - Node security group: "${module.eks.node_security_group_id}"
        
        EKS cluster must be fully operational before CloudFront deployment.
        
        To resolve:
        1. Check EKS cluster status in AWS Console
        2. Verify cluster is in ACTIVE state
        3. Ensure node groups are healthy
        4. Re-run: terraform apply -target=module.eks
      EOT
    }
    precondition {
      condition = alltrue([
        module.data_aurora.writer_endpoint != "",
        module.data_efs.file_system_id != "",
        module.elasticache.primary_endpoint_address != ""
      ])
      error_message = <<-EOT
        Infrastructure readiness validation failed:
        Data layer components are not ready for CloudFront deployment.
        
        Data layer status:
        - Aurora endpoint: "${module.data_aurora.writer_endpoint}"
        - EFS filesystem: "${module.data_efs.file_system_id}"
        - Redis endpoint: "${module.elasticache.primary_endpoint_address}"
        
        All data services must be operational before CloudFront deployment.
        
        To resolve:
        1. Check Aurora cluster status (should be 'available')
        2. Verify EFS filesystem is in 'available' state
        3. Ensure ElastiCache cluster is 'available'
        4. Re-run data layer deployments if needed
      EOT
    }
  }

  depends_on = [
    module.foundation,
    module.eks,
    module.data_aurora,
    module.data_efs,
    module.elasticache
  ]
}

#############################################
# CloudFront Dependencies Validation
#############################################

# Validation: Ensure all infrastructure dependencies are ready for CloudFront
resource "terraform_data" "cloudfront_dependencies_validation" {
  count = var.enable_cloudfront ? 1 : 0

  lifecycle {
    precondition {
      condition = alltrue([
        module.standalone_alb.alb_dns_name != "",
        module.standalone_alb.alb_zone_id != "",
        var.alb_certificate_arn != "",
        module.foundation.logs_bucket != "",
        contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
      ])
      error_message = <<-EOT
        CloudFront dependencies validation failed:
        One or more required infrastructure components are not ready.
        
        Component Status:
        - ALB DNS name: ${module.standalone_alb.alb_dns_name != "" ? "✓" : "✗"} (${module.standalone_alb.alb_dns_name})
        - ALB Zone ID: ${module.standalone_alb.alb_zone_id != "" ? "✓" : "✗"} (${module.standalone_alb.alb_zone_id})
        - ALB Certificate: ${var.alb_certificate_arn != "" ? "✓" : "✗"} (${var.alb_certificate_arn})
        - S3 Logs Bucket: ${module.foundation.logs_bucket != "" ? "✓" : "✗"} (${module.foundation.logs_bucket})
        - CloudFront Price Class: ${contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class) ? "✓" : "✗"} (${var.cloudfront_price_class})
        
        All components must be successfully deployed before CloudFront.
        
        To resolve:
        1. Ensure infrastructure stack deployment completed successfully
        2. Check AWS Console for any failed resources
        3. Verify ALB is in 'active' state with healthy targets
        4. Confirm ACM certificate is in 'issued' status
        5. Verify CloudFront price class is valid
        6. Re-run: terraform apply (without CloudFront enabled first)
      EOT
    }
  }

  depends_on = [
    module.foundation,
    module.eks,
    module.standalone_alb,
    terraform_data.infrastructure_readiness_validation
  ]
}

#############################################
# DNS Coordination Validation
#############################################

# Validation: Ensure DNS coordination is properly configured
resource "terraform_data" "dns_coordination_validation" {
  lifecycle {
    precondition {
      condition     = local.dns_coordination_valid
      error_message = <<-EOT
        DNS coordination configuration is invalid. Please check:
        1. If CloudFront is enabled, set create_alb_route53_record = false (CloudFront will manage Route53 records)
        2. If CloudFront is enabled, wordpress_domain_name and wordpress_hosted_zone_id must be provided
        
        Current configuration:
        - enable_cloudfront: ${var.enable_cloudfront}
        - create_alb_route53_record: ${var.create_alb_route53_record}
        - wordpress_domain_name: ${var.wordpress_domain_name}
        - wordpress_hosted_zone_id: ${var.wordpress_hosted_zone_id}
      EOT
    }
    precondition {
      condition     = var.enable_cloudfront ? var.cloudfront_certificate_arn != "" : true
      error_message = <<-EOT
        CloudFront certificate ARN is required when CloudFront is enabled.
        
        CloudFront requires an ACM certificate in us-east-1 region.
        
        To resolve:
        1. Create ACM certificate in us-east-1 region
        2. Add domain: ${var.wordpress_domain_name}
        3. Complete domain validation
        4. Set cloudfront_certificate_arn variable to the certificate ARN
        
        Example certificate ARN format:
        arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
      EOT
    }
    precondition {
      condition     = var.enable_cloudfront ? var.create_cloudfront_route53_record : true
      error_message = "When CloudFront is enabled, create_cloudfront_route53_record should be true to manage DNS records properly."
    }
    precondition {
      condition     = var.enable_cloudfront ? var.wordpress_hosted_zone_id != "" : true
      error_message = <<-EOT
        Route53 hosted zone ID is required when CloudFront is enabled.
        
        CloudFront needs to create DNS records pointing to the distribution.
        
        To resolve:
        1. Create Route53 hosted zone for domain: ${var.wordpress_domain_name}
        2. Set wordpress_hosted_zone_id variable to the hosted zone ID
        3. Ensure domain's nameservers point to Route53 hosted zone
        
        You can find the hosted zone ID in Route53 console or using:
        aws route53 list-hosted-zones-by-name --dns-name ${var.wordpress_domain_name}
      EOT
    }
  }
}