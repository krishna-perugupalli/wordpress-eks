# CloudFront Integration Test Plan

## Test Scenarios

### Test 1: Direct ALB Access (Default Configuration)
**Configuration:**
```hcl
# Infrastructure stack
enable_cloudfront_restriction = false
route53_points_to_cloudfront = false

# Application stack
enable_cloudfront = false
```

**Expected Results:**
- ALB security group allows ingress from 0.0.0.0/0 on ports 80/443
- Route53 A record points to ALB DNS name
- WordPress does not include CloudFront proxy header configuration

**Validation Commands:**
```bash
# Check ALB security group rules
aws ec2 describe-security-groups --group-ids <alb-sg-id>

# Check Route53 record
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Check WordPress configuration (should not include proxy headers)
kubectl exec -n wordpress <wordpress-pod> -- cat /opt/bitnami/wordpress/wp-config.php
```

### Test 2: CloudFront + ALB Integration
**Configuration:**
```hcl
# Infrastructure stack
enable_cloudfront_restriction = true
route53_points_to_cloudfront = true
cloudfront_distribution_domain_name = "d1234567890.cloudfront.net"

# Application stack
enable_cloudfront = true
```

**Expected Results:**
- ALB security group allows ingress from CloudFront prefix list only
- Route53 A record points to CloudFront distribution
- WordPress includes CloudFront proxy header configuration

**Validation Commands:**
```bash
# Check ALB security group uses prefix list
aws ec2 describe-security-groups --group-ids <alb-sg-id> | grep -A5 -B5 "PrefixListIds"

# Check Route53 record points to CloudFront
aws route53 list-resource-record-sets --hosted-zone-id <zone-id> | grep "d1234567890.cloudfront.net"

# Check WordPress configuration includes proxy headers
kubectl exec -n wordpress <wordpress-pod> -- cat /opt/bitnami/wordpress/wp-config.php | grep -A10 "X-Forwarded-Proto"
```

### Test 3: Mixed Configuration (Development)
**Configuration:**
```hcl
# Infrastructure stack
enable_cloudfront_restriction = false  # Allow direct ALB access
route53_points_to_cloudfront = true    # But DNS points to CloudFront

# Application stack
enable_cloudfront = true
```

**Expected Results:**
- ALB security group allows ingress from 0.0.0.0/0 (for testing)
- Route53 A record points to CloudFront distribution
- WordPress includes CloudFront proxy header configuration

## Manual Testing Steps

### 1. Deploy Infrastructure Stack
```bash
cd stacks/infra
terraform plan -var-file="../../examples/cloudfront-integration.tfvars"
terraform apply -var-file="../../examples/cloudfront-integration.tfvars"
```

### 2. Verify Infrastructure Outputs
```bash
terraform output alb_dns_name
terraform output route53_record_fqdn
terraform output route53_record_type
```

### 3. Deploy Application Stack
```bash
cd ../app
terraform plan -var-file="../../examples/cloudfront-integration.tfvars"
terraform apply -var-file="../../examples/cloudfront-integration.tfvars"
```

### 4. Test WordPress Configuration
```bash
# Get WordPress pod name
kubectl get pods -n wordpress

# Check WordPress configuration
kubectl exec -n wordpress <pod-name> -- cat /opt/bitnami/wordpress/wp-config.php | tail -20
```

### 5. Test Security Group Rules
```bash
# Get ALB security group ID
ALB_SG_ID=$(terraform output -raw alb_security_group_id)

# Check security group rules
aws ec2 describe-security-groups --group-ids $ALB_SG_ID --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpProtocol,IpRanges,PrefixListIds]' --output table
```

## Expected Terraform Outputs

### Infrastructure Stack Outputs
```
alb_dns_name = "wp-cf-demo-alb-1234567890.us-east-1.elb.amazonaws.com"
route53_record_fqdn = "wordpress.example.com"
route53_record_type = "cloudfront"  # or "alb" depending on configuration
target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/wp-cf-demo-wordpress-tg/1234567890abcdef"
```

### Application Stack Outputs
```
service_name = "wp-cf-demo-wordpress"
namespace = "wordpress"
```

## Troubleshooting

### Issue: Route53 record not created
**Check:** Verify `create_alb_route53_record = true` and required variables are set
**Solution:** Ensure `wordpress_domain_name` and `wordpress_hosted_zone_id` are provided

### Issue: ALB security group rules incorrect
**Check:** Verify `enable_cloudfront_restriction` setting matches expected behavior
**Solution:** Check CloudFront prefix list exists: `aws ec2 describe-managed-prefix-lists --filters Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing`

### Issue: WordPress not detecting HTTPS
**Check:** Verify `enable_cloudfront = true` in application stack
**Solution:** Check WordPress configuration includes proxy header trust code

## Success Criteria

- [ ] Infrastructure stack deploys without errors
- [ ] Application stack deploys without errors  
- [ ] ALB security group rules match configuration
- [ ] Route53 record points to correct target (ALB or CloudFront)
- [ ] WordPress configuration includes appropriate proxy header handling
- [ ] WordPress site loads correctly via configured domain
- [ ] HTTPS detection works properly when behind CloudFront