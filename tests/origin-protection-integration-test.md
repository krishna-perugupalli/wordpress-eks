# ALB Origin Protection Integration Test

This document describes how to test the ALB origin protection functionality that blocks direct ALB access and only allows CloudFront traffic with valid origin secret.

## Test Scenarios

### Scenario 1: Origin Protection Disabled (Default Behavior)
```hcl
# In terraform.tfvars
enable_alb_origin_protection = false
cloudfront_origin_secret     = ""
```

**Expected Behavior:**
- ALB accepts all traffic directly
- HTTP requests redirect to HTTPS (301)
- HTTPS requests forward to WordPress target group
- No origin secret validation

**Test Commands:**
```bash
# Direct ALB access should work
curl -I https://your-alb-domain.com
# Expected: 200 OK (WordPress response)

curl -I http://your-alb-domain.com
# Expected: 301 Moved Permanently (redirect to HTTPS)
```

### Scenario 2: Origin Protection Enabled Without Secret
```hcl
# In terraform.tfvars
enable_alb_origin_protection = true
cloudfront_origin_secret     = ""
```

**Expected Behavior:**
- ALB blocks all traffic (no valid secret configured)
- HTTP requests return 403 Forbidden
- HTTPS requests return 403 Forbidden

**Test Commands:**
```bash
# Direct ALB access should be blocked
curl -I https://your-alb-domain.com
# Expected: 403 Forbidden

curl -I http://your-alb-domain.com
# Expected: 403 Forbidden
```

### Scenario 3: Origin Protection Enabled With Secret
```hcl
# In terraform.tfvars
enable_alb_origin_protection = true
cloudfront_origin_secret     = "your-secret-value-here"
```

**Expected Behavior:**
- ALB blocks traffic without valid X-Origin-Secret header
- ALB allows traffic with correct X-Origin-Secret header
- CloudFront automatically injects the secret header

**Test Commands:**
```bash
# Direct ALB access without secret should be blocked
curl -I https://your-alb-domain.com
# Expected: 403 Forbidden

# Direct ALB access with wrong secret should be blocked
curl -I -H "X-Origin-Secret: wrong-secret" https://your-alb-domain.com
# Expected: 403 Forbidden

# Direct ALB access with correct secret should work
curl -I -H "X-Origin-Secret: your-secret-value-here" https://your-alb-domain.com
# Expected: 200 OK (WordPress response)

# CloudFront access should work (secret injected automatically)
curl -I https://your-cloudfront-domain.com
# Expected: 200 OK (WordPress response via CloudFront)
```

## Terraform Configuration Example

```hcl
# Complete configuration for origin protection
module "standalone_alb" {
  source = "../../modules/standalone-alb"
  
  # Basic ALB configuration
  name                          = "wordpress-prod"
  vpc_id                        = module.foundation.vpc_id
  public_subnet_ids             = module.foundation.public_subnet_ids
  certificate_arn               = var.alb_certificate_arn
  domain_name                   = "wordpress.example.com"
  hosted_zone_id                = "Z1234567890ABC"
  
  # Origin protection configuration
  enable_origin_protection           = true
  origin_secret_value                = var.cloudfront_origin_secret
  origin_protection_response_code    = 403
  origin_protection_response_body    = "Access Denied - Direct access not allowed"
  
  # Other configuration...
  tags = local.tags
}

module "cloudfront" {
  source = "../../modules/cloudfront"
  
  # Basic CloudFront configuration
  name                = "wordpress-prod"
  domain_name         = "wordpress.example.com"
  alb_dns_name        = module.standalone_alb.alb_dns_name
  acm_certificate_arn = var.cloudfront_certificate_arn
  
  # Origin secret configuration (must match ALB)
  origin_secret_value = var.cloudfront_origin_secret
  
  # Other configuration...
  tags = local.tags
}
```

## Security Validation

### 1. Listener Rules Validation
Check that the correct listener rules are created:

```bash
# List ALB listener rules
aws elbv2 describe-rules --listener-arn <https-listener-arn>

# Expected output should include rules with:
# - Priority: 100
# - Condition: http-header X-Origin-Secret
# - Action: forward to target group
```

### 2. CloudFront Origin Configuration
Verify CloudFront injects the origin secret:

```bash
# Describe CloudFront distribution
aws cloudfront get-distribution --id <distribution-id>

# Expected output should include:
# - Origin custom headers with X-Origin-Secret
# - Origin protocol policy: https-only
```

### 3. End-to-End Security Test
```bash
# Test 1: Direct ALB access should fail
curl -v https://your-alb-domain.com 2>&1 | grep "HTTP/"
# Expected: HTTP/1.1 403 Forbidden

# Test 2: CloudFront access should succeed
curl -v https://your-cloudfront-domain.com 2>&1 | grep "HTTP/"
# Expected: HTTP/2 200 OK

# Test 3: Verify CloudFront headers are present
curl -I https://your-cloudfront-domain.com | grep -i cloudfront
# Expected: Various CloudFront headers indicating CDN processing
```

## Troubleshooting

### Common Issues

1. **ALB allows direct access when protection is enabled**
   - Check that `enable_origin_protection = true`
   - Verify `origin_secret_value` is not empty
   - Confirm listener rules were created with correct priority

2. **CloudFront requests are blocked**
   - Ensure CloudFront `origin_secret_value` matches ALB configuration
   - Check CloudFront origin custom headers configuration
   - Verify origin protocol policy is HTTPS-only

3. **Listener rules not created**
   - Check Terraform plan output for rule creation
   - Verify both `enable_origin_protection` and `origin_secret_value` are set
   - Ensure ALB listeners exist before rules are created

### Debugging Commands

```bash
# Check ALB listener configuration
aws elbv2 describe-listeners --load-balancer-arn <alb-arn>

# Check listener rules
aws elbv2 describe-rules --listener-arn <listener-arn>

# Check CloudFront distribution config
aws cloudfront get-distribution-config --id <distribution-id>

# Test with verbose curl
curl -v -H "X-Origin-Secret: test-secret" https://your-alb-domain.com
```

## Expected Terraform Outputs

When origin protection is properly configured, you should see these outputs:

```hcl
alb_origin_protection_enabled = true
alb_origin_protection_config = {
  enabled                = true
  response_code          = 403
  response_body          = "Access Denied - Direct access not allowed"
  secret_header_name     = "X-Origin-Secret"
  has_secret_configured  = true
}
alb_listener_rule_arns = {
  http_rule  = "arn:aws:elasticloadbalancing:region:account:listener-rule/..."
  https_rule = "arn:aws:elasticloadbalancing:region:account:listener-rule/..."
}
```