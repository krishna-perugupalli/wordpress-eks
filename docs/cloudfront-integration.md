# CloudFront Integration Guide

This document explains how to integrate CloudFront with the standalone ALB architecture.

## Overview

The standalone ALB architecture supports optional CloudFront integration through:

1. **ALB Security Group Restriction**: Restrict ALB ingress to CloudFront IP ranges only
2. **Conditional Route53 Records**: Route53 can point to either ALB directly or CloudFront distribution
3. **WordPress Proxy Header Trust**: WordPress trusts X-Forwarded-Proto headers from CloudFront/ALB

## Configuration Variables

### Infrastructure Stack (`stacks/infra`)

```hcl
# Enable CloudFront IP restriction on ALB security group
enable_cloudfront_restriction = true

# Route53 record configuration
route53_points_to_cloudfront = true
cloudfront_distribution_domain_name = "d1234567890.cloudfront.net"
cloudfront_distribution_zone_id = "Z2FDTNDATAQYW2"  # Standard CloudFront zone ID
```

### Application Stack (`stacks/app`)

```hcl
# Enable CloudFront proxy header trust in WordPress
enable_cloudfront = true
```

## Deployment Scenarios

### Scenario 1: Direct ALB Access (Default)

```hcl
# Infrastructure stack
enable_cloudfront_restriction = false
route53_points_to_cloudfront = false

# Application stack  
enable_cloudfront = false
```

**Result**: 
- ALB accepts traffic from internet (0.0.0.0/0)
- Route53 points directly to ALB
- WordPress doesn't trust proxy headers

### Scenario 2: CloudFront + ALB (Recommended)

```hcl
# Infrastructure stack
enable_cloudfront_restriction = true
route53_points_to_cloudfront = true
cloudfront_distribution_domain_name = "d1234567890.cloudfront.net"

# Application stack
enable_cloudfront = true
```

**Result**:
- ALB only accepts traffic from CloudFront IP ranges
- Route53 points to CloudFront distribution
- WordPress trusts X-Forwarded-Proto headers for HTTPS detection

### Scenario 3: CloudFront + ALB (Development/Testing)

```hcl
# Infrastructure stack
enable_cloudfront_restriction = false  # Allow direct ALB access for testing
route53_points_to_cloudfront = true
cloudfront_distribution_domain_name = "d1234567890.cloudfront.net"

# Application stack
enable_cloudfront = true
```

**Result**:
- ALB accepts traffic from both CloudFront and internet (for testing)
- Route53 points to CloudFront distribution
- WordPress trusts proxy headers

## CloudFront Distribution Setup

The CloudFront distribution should be configured separately (not managed by this Terraform). Key settings:

### Origin Configuration
- **Origin Domain**: Use ALB DNS name from `alb_dns_name` output
- **Origin Protocol Policy**: HTTPS Only
- **Origin Path**: Leave empty
- **Origin Custom Headers**: None required

### Behavior Configuration
- **Viewer Protocol Policy**: Redirect HTTP to HTTPS
- **Allowed HTTP Methods**: GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
- **Cache Policy**: Managed-CachingDisabled (for WordPress)
- **Origin Request Policy**: Managed-CORS-S3Origin or custom policy

### Custom Headers
CloudFront automatically adds these headers that WordPress will trust:
- `X-Forwarded-Proto: https`
- `CloudFront-Forwarded-Proto: https`

## Security Considerations

### ALB Security Group Rules

When `enable_cloudfront_restriction = true`:

```hcl
# HTTP from CloudFront only
resource "aws_security_group_rule" "alb_http_ingress" {
  type            = "ingress"
  from_port       = 80
  to_port         = 80
  protocol        = "tcp"
  prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront[0].id]
  # ...
}

# HTTPS from CloudFront only  
resource "aws_security_group_rule" "alb_https_ingress" {
  type            = "ingress"
  from_port       = 443
  to_port         = 443
  protocol        = "tcp"
  prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront[0].id]
  # ...
}
```

### WordPress Configuration

When `enable_cloudfront = true`, WordPress is configured to:

```php
// Trust proxy headers for HTTPS detection when behind CloudFront/ALB
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
if (isset($_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO']) && $_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
define('FORCE_SSL_ADMIN', true);
```

## Troubleshooting

### Issue: WordPress shows mixed content warnings

**Cause**: WordPress not detecting HTTPS properly behind CloudFront
**Solution**: Ensure `enable_cloudfront = true` in application stack

### Issue: ALB health checks failing

**Cause**: ALB restricted to CloudFront IPs but health checks come from ALB IP ranges
**Solution**: ALB health checks use internal VPC communication, not affected by ingress rules

### Issue: Direct ALB access blocked

**Cause**: `enable_cloudfront_restriction = true` blocks direct access
**Solution**: Access via CloudFront distribution or temporarily set to `false` for testing

## Migration Path

To migrate from direct ALB to CloudFront:

1. **Deploy CloudFront distribution** pointing to ALB DNS name
2. **Update infrastructure stack**:
   ```hcl
   route53_points_to_cloudfront = true
   cloudfront_distribution_domain_name = "d1234567890.cloudfront.net"
   ```
3. **Update application stack**:
   ```hcl
   enable_cloudfront = true
   ```
4. **Test CloudFront access** before restricting ALB
5. **Restrict ALB to CloudFront** (optional):
   ```hcl
   enable_cloudfront_restriction = true
   ```

## Example Terraform Configuration

```hcl
# terraform.tfvars for infrastructure stack
enable_cloudfront_restriction = true
route53_points_to_cloudfront = true
cloudfront_distribution_domain_name = "d1234567890.cloudfront.net"
wordpress_domain_name = "wordpress.example.com"
wordpress_hosted_zone_id = "Z1234567890ABC"

# terraform.tfvars for application stack  
enable_cloudfront = true
wp_domain_name = "wordpress.example.com"
```