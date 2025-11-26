# CloudFront Integration Guide

This comprehensive guide covers CloudFront deployment, configuration, and troubleshooting for the WordPress EKS platform. CloudFront provides global content delivery network (CDN) capabilities while maintaining the main infrastructure in eu-central-1.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [US-East-1 Certificate Requirements](#us-east-1-certificate-requirements)
4. [Configuration Options](#configuration-options)
5. [DNS Integration](#dns-integration)
6. [Security Configuration](#security-configuration)
7. [Performance Features](#performance-features)
8. [Cost Optimization](#cost-optimization)
9. [Advanced Configuration](#advanced-configuration)
10. [Troubleshooting](#troubleshooting)
11. [Migration Guide](#migration-guide)
12. [Monitoring and Observability](#monitoring-and-observability)

## Overview

The CloudFront integration provides global content delivery network (CDN) capabilities for your WordPress site while maintaining the main infrastructure in eu-central-1. **CloudFront requires ACM certificates to be in the us-east-1 region**, which is handled through a separate certificate provisioning process.

### Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   us-east-1     │    │     Global       │    │  eu-central-1   │
│                 │    │                  │    │                 │
│ ACM Certificate │───▶│ CloudFront       │───▶│ ALB → EKS       │
│ (User Managed)  │    │ Distribution     │    │ WordPress       │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Benefits

- **Global Performance**: Content delivery from 200+ edge locations worldwide
- **DDoS Protection**: AWS Shield Standard protection included
- **SSL/TLS Termination**: Automatic HTTPS with ACM certificates
- **Origin Protection**: Secure communication between CloudFront and ALB
- **Cost Optimization**: Configurable price classes and caching policies

## Prerequisites

### 1. Route53 Hosted Zone

Ensure you have a Route53 hosted zone for your domain:

```bash
aws route53 list-hosted-zones --query 'HostedZones[?Name==`example.com.`]'
```

### 2. Infrastructure Stack Deployment

The infrastructure stack must be deployed first to provide ALB outputs:

```bash
make apply-infra
```

## US-East-1 Certificate Requirements

**Critical**: CloudFront requires ACM certificates to be in the us-east-1 region, regardless of where your main infrastructure is deployed.

### Manual Certificate Setup

You need **two** ACM certificates for a complete setup:

1. **Regional Certificate** (eu-central-1): For ALB HTTPS listener
2. **Global Certificate** (us-east-1): For CloudFront distribution

#### Step 1: Create Regional Certificate (eu-central-1)

```bash
# Create certificate for ALB in your main region
aws acm request-certificate \
  --domain-name wordpress.example.com \
  --subject-alternative-names www.wordpress.example.com \
  --validation-method DNS \
  --region eu-central-1 \
  --tags Key=Name,Value="WordPress ALB Certificate"
```

#### Step 2: Create Global Certificate (us-east-1)

```bash
# Create certificate for CloudFront in us-east-1
aws acm request-certificate \
  --domain-name wordpress.example.com \
  --subject-alternative-names www.wordpress.example.com \
  --validation-method DNS \
  --region us-east-1 \
  --tags Key=Name,Value="WordPress CloudFront Certificate"
```

#### Step 3: Validate Both Certificates

Both certificates will require DNS validation. Add the CNAME records to your Route53 hosted zone:

```bash
# Get validation records for regional certificate
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:eu-central-1:123456789012:certificate/your-cert-id \
  --region eu-central-1 \
  --query 'Certificate.DomainValidationOptions[].ResourceRecord'

# Get validation records for global certificate  
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[].ResourceRecord'
```

#### Step 4: Wait for Validation

Both certificates must be in "ISSUED" status before proceeding:

```bash
# Check regional certificate status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:eu-central-1:123456789012:certificate/your-cert-id \
  --region eu-central-1 \
  --query 'Certificate.Status'

# Check global certificate status
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id \
  --region us-east-1 \
  --query 'Certificate.Status'
```

### Certificate ARN Format Validation

The CloudFront certificate ARN must follow this format:
```
arn:aws:acm:us-east-1:ACCOUNT-ID:certificate/CERTIFICATE-ID
```

The Terraform configuration includes validation to ensure the certificate is from us-east-1:

```hcl
variable "cloudfront_certificate_arn" {
  description = "ACM certificate ARN from us-east-1 for CloudFront"
  type        = string
  validation {
    condition     = can(regex("^arn:aws:acm:us-east-1:", var.cloudfront_certificate_arn))
    error_message = "CloudFront certificate must be from us-east-1 region."
  }
}
```

## Configuration Options

### Basic CloudFront Configuration

```hcl
# Enable CloudFront
enable_cloudfront = true
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"

# Domain configuration
wordpress_domain_name = "wordpress.example.com"
cloudfront_aliases = ["www.wordpress.example.com", "cdn.example.com"]
```

### Infrastructure Stack Integration

CloudFront is deployed as part of the infrastructure stack when enabled:

```hcl
# In your terraform.tfvars or TFC workspace variables
enable_cloudfront = true
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."

# Optional: Additional aliases
cloudfront_aliases = ["www.example.com", "cdn.example.com"]
```

## DNS Integration

The system supports two DNS coordination modes:

### Option 1: CloudFront Primary (Recommended)

Route53 points to CloudFront distribution, which forwards requests to ALB:

```hcl
# DNS Coordination (default behavior when CloudFront is enabled)
create_cloudfront_route53_record = true   # CloudFront creates Route53 record
```

**Benefits:**
- Global CDN performance
- Automatic SSL/TLS termination
- DDoS protection via AWS Shield
- Reduced origin load

### Option 2: ALB Primary (Fallback/Testing)

Route53 points directly to ALB, bypassing CloudFront:

```hcl
# For testing or fallback scenarios
enable_cloudfront = false
# ALB will create Route53 records directly
```

### Automatic Record Creation

The system automatically creates Route53 A records:
- **Primary Domain**: `wordpress.example.com` → CloudFront distribution
- **Aliases**: All domains in `cloudfront_aliases` → CloudFront distribution

## Security Configuration

### Origin Protection

CloudFront and ALB use shared secrets for origin protection:

```hcl
# Origin protection is automatically configured when CloudFront is enabled
# The system generates a secure random secret for ALB validation
```

This configuration:
- Injects custom `X-Origin-Secret` headers from CloudFront
- Validates origin secret headers at the ALB level
- Blocks direct ALB access when protection is enabled

### SSL/TLS Configuration

```hcl
# SSL/TLS protocol version (recommended)
cloudfront_minimum_protocol_version = "TLSv1.2_2021"

# Other options (less secure):
# cloudfront_minimum_protocol_version = "TLSv1.2_2019"
# cloudfront_minimum_protocol_version = "TLSv1.2_2018"
```

### WAF Integration

Integrate with AWS WAF for additional security:

```hcl
cloudfront_waf_web_acl_arn = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/your-web-acl/id"
```

**Note:** WAF for CloudFront must be created in us-east-1 region with CLOUDFRONT scope.

### Security Headers

The CloudFront configuration automatically applies security headers:

- **Content Security Policy (CSP)**: Comprehensive CSP with frame-ancestors directive
- **X-Frame-Options**: Clickjacking protection
- **X-Content-Type-Options**: MIME type sniffing protection
- **Strict-Transport-Security**: HTTPS enforcement
- **Referrer-Policy**: Referrer information control

## Performance Features

### Caching Policies

The CloudFront configuration includes optimized caching for WordPress:

#### Static Content Caching
- **Path Pattern**: `/wp-content/*`
- **TTL**: 24 hours default, 1 year maximum
- **Headers**: Minimal header forwarding for optimal caching

#### Dynamic Content Handling
- **Path Pattern**: Default behavior for all other content
- **TTL**: No caching (0 seconds)
- **Headers**: Comprehensive header and cookie forwarding

#### Admin Area Protection
- **Path Patterns**: `/wp-admin/*`, `/wp-login.php`
- **TTL**: Never cached
- **Security**: Enhanced security headers automatically applied

#### API and Special Endpoints
- **WordPress API** (`/wp-json/*`): Bypass cache for REST API calls
- **AJAX Requests** (`/wp-admin/admin-ajax.php`): Bypass cache for dynamic calls
- **WordPress Cron** (`/wp-cron.php`): Bypass cache for scheduled tasks
- **RSS Feeds** (`/feed/*`): Moderate caching (1-24 hours)
- **Sitemaps** (`/sitemap*.xml`): Moderate caching for SEO

### HTTP/3 Support

Enable HTTP/3 (QUIC protocol) for improved performance:

```hcl
cloudfront_enable_http3 = true
```

**Benefits:**
- Reduced connection establishment time
- Better performance over unreliable networks
- Improved multiplexing without head-of-line blocking

### Compression

Enable automatic content compression:

```hcl
cloudfront_enable_compression = true
```

**Supported Compression:**
- Gzip compression for text-based content
- Brotli compression (when supported by client)
- Automatic compression for CSS, JavaScript, HTML, JSON, XML, and text files

### Origin Shield

Enable Origin Shield for improved cache hit ratios:

```hcl
cloudfront_enable_origin_shield = true
cloudfront_origin_shield_region = "eu-central-1"  # Should match your origin region
```

**Benefits:**
- Reduces load on your origin (ALB)
- Improves cache hit ratio
- Better performance for global users

## Cost Optimization

### Price Class Configuration

CloudFront offers three price classes to control costs based on geographic distribution:

```hcl
# Use all edge locations globally (highest cost, best performance)
cloudfront_price_class = "PriceClass_All"

# Use edge locations in North America, Europe, Asia, Middle East, and Africa
cloudfront_price_class = "PriceClass_200"  # Recommended for most use cases

# Use only North America and Europe edge locations (lowest cost)
cloudfront_price_class = "PriceClass_100"
```

**Price Class Comparison:**
- `PriceClass_All`: ~200+ edge locations worldwide
- `PriceClass_200`: ~100+ edge locations (excludes some expensive regions)
- `PriceClass_100`: ~50+ edge locations (North America and Europe only)

### Logging Configuration

CloudFront access logs are automatically stored in S3:

```hcl
# Enable/disable logging
cloudfront_enable_logging = true

# Customize log file prefix
cloudfront_log_prefix = "cloudfront-logs/"

# Include cookies in logs (increases log size)
cloudfront_log_include_cookies = false
```

### Real-time Logs (Advanced)

For real-time log streaming to Kinesis Data Streams:

```hcl
cloudfront_enable_real_time_logs = true
cloudfront_real_time_log_config_arn = "arn:aws:logs:us-east-1:123456789012:destination:your-destination"
```

## Advanced Configuration

### Geo-restrictions

Control access based on geographic location:

```hcl
# Allowlist specific countries
cloudfront_geo_restriction_type = "whitelist"
cloudfront_geo_restriction_locations = ["US", "CA", "GB", "DE", "FR", "AU"]

# Blocklist specific countries
cloudfront_geo_restriction_type = "blacklist"
cloudfront_geo_restriction_locations = ["CN", "RU", "KP"]

# No restrictions (default)
cloudfront_geo_restriction_type = "none"
cloudfront_geo_restriction_locations = []
```

**Country Codes:** Use ISO 3166-1 alpha-2 country codes (e.g., US, GB, DE, FR, JP, AU).

### Custom Error Pages

Configure custom error responses:

```hcl
cloudfront_custom_error_responses = [
  {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
  },
  {
    error_code            = 500
    response_code         = 500
    response_page_path    = "/500.html"
    error_caching_min_ttl = 60
  }
]
```

### IPv6 Support

```hcl
cloudfront_enable_ipv6 = true  # Default: enabled
```

### Default Root Object

```hcl
cloudfront_default_root_object = "index.php"  # Default for WordPress
```

## Troubleshooting

### ERR_TOO_MANY_REDIRECTS

This is the most common issue when integrating CloudFront with WordPress. The enhanced CloudFront configuration prevents this by properly forwarding headers.

#### Root Cause
WordPress behind CloudFront can create redirect loops when:
- The `Host` header is not properly preserved
- HTTPS detection fails due to missing protocol headers
- WordPress generates incorrect URLs due to missing forwarding headers

#### Solution Implemented
The CloudFront configuration includes comprehensive header forwarding:

**Critical Headers for WordPress:**
- `X-Forwarded-Host`: Preserves the original host header
- `CloudFront-Viewer-Protocol`: Tells WordPress the original protocol (HTTP/HTTPS)
- `X-Forwarded-For`: Preserves client IP information
- `X-Forwarded-Proto`: Additional protocol information

**Origin Request Policies:**
1. **Static Content Policy** (`/wp-content/*`): Minimal headers for optimal caching
2. **Dynamic Content Policy** (default): Comprehensive header and cookie forwarding

#### Verification Steps

1. **Check CloudFront Distribution Status**
   ```bash
   aws cloudfront get-distribution --id YOUR-DISTRIBUTION-ID
   ```

2. **Test Header Forwarding**
   ```bash
   curl -I -H "Host: wordpress.example.com" https://your-cloudfront-domain.cloudfront.net/
   ```

3. **Verify WordPress HTTPS Detection**
   - Access WordPress admin at `/wp-admin/`
   - Check that URLs are generated with HTTPS
   - Verify no redirect loops occur

#### Additional Troubleshooting

If redirect loops persist:

1. **Check WordPress Configuration**
   ```php
   // In wp-config.php, add if not already present:
   if (isset($_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO']) && $_SERVER['HTTP_CLOUDFRONT_FORWARDED_PROTO'] === 'https') {
       $_SERVER['HTTPS'] = 'on';
   }
   ```

2. **Verify ALB Target Health**
   ```bash
   aws elbv2 describe-target-health --target-group-arn YOUR-TARGET-GROUP-ARN
   ```

3. **Check CloudFront Cache Behaviors**
   - Ensure admin paths (`/wp-admin/*`) use dynamic content policy
   - Verify static paths (`/wp-content/*`) use static content policy

### Certificate Validation Errors

#### Error: "CloudFront requires an ACM certificate in us-east-1"

**Solution:**
1. Verify certificate region:
   ```bash
   aws acm describe-certificate --certificate-arn YOUR-CERT-ARN --region us-east-1
   ```
2. If certificate is in wrong region, create a new certificate in us-east-1
3. Update the `cloudfront_certificate_arn` variable

#### Error: "Certificate not found"

**Solution:**
1. Verify certificate exists and is issued:
   ```bash
   aws acm list-certificates --region us-east-1 --certificate-statuses ISSUED
   ```
2. Check certificate ARN format
3. Ensure certificate covers your domain names

### DNS Resolution Issues

#### Error: "hosted zone not found"

**Solution:**
1. Verify hosted zone exists:
   ```bash
   aws route53 list-hosted-zones --query 'HostedZones[?Name==`example.com.`]'
   ```
2. Check hosted zone ID in configuration
3. Verify Route53 permissions

#### DNS Propagation Issues

**Solution:**
1. Check DNS propagation:
   ```bash
   dig wordpress.example.com
   nslookup wordpress.example.com
   ```
2. Verify CloudFront distribution domain:
   ```bash
   aws cloudfront get-distribution --id YOUR-DISTRIBUTION-ID --query 'Distribution.DomainName'
   ```

### Origin Connection Issues

#### Error: "Origin is unreachable"

**Solution:**
1. Verify ALB is healthy:
   ```bash
   aws elbv2 describe-load-balancers --names YOUR-ALB-NAME
   ```
2. Check security groups allow CloudFront IP ranges
3. Verify origin secret header configuration

#### 502/503 Errors from Origin

**Solution:**
1. Check ALB target health:
   ```bash
   aws elbv2 describe-target-health --target-group-arn YOUR-TARGET-GROUP-ARN
   ```
2. Verify WordPress pods are running:
   ```bash
   kubectl get pods -n wordpress
   ```
3. Check application logs for errors

### Performance Issues

#### High Cache Miss Ratio

**Solution:**
1. Review cache behaviors and TTL settings
2. Enable Origin Shield for high-traffic sites
3. Analyze CloudFront access logs for cache patterns

#### Slow Origin Response Times

**Solution:**
1. Enable Origin Shield to reduce origin requests
2. Optimize WordPress performance (caching plugins, database optimization)
3. Consider increasing ALB target group size

## Migration Guide

### From ALB Primary to CloudFront Primary

1. **Prepare CloudFront Configuration**
   ```hcl
   enable_cloudfront = true
   cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/..."
   ```

2. **Deploy CloudFront (without DNS changes)**
   ```bash
   make plan-infra
   make apply-infra
   ```

3. **Test CloudFront Distribution**
   ```bash
   # Test using CloudFront domain directly
   curl -I https://d123456789.cloudfront.net/
   ```

4. **Update DNS to Point to CloudFront**
   - DNS records are automatically updated when CloudFront is enabled
   - Monitor for any issues during DNS propagation

5. **Verify Complete Migration**
   ```bash
   # Test final domain
   curl -I https://wordpress.example.com/
   ```

### From CloudFront Primary to ALB Primary

1. **Disable CloudFront**
   ```hcl
   enable_cloudfront = false
   ```

2. **Apply Changes**
   ```bash
   make apply-infra
   ```

3. **Verify ALB Direct Access**
   ```bash
   curl -I https://wordpress.example.com/
   ```

## Monitoring and Observability

### CloudFront Metrics

Monitor CloudFront performance through CloudWatch:

- **Requests**: Total number of requests
- **BytesDownloaded**: Data transfer from CloudFront
- **CacheHitRate**: Percentage of requests served from cache
- **ErrorRate**: 4xx and 5xx error rates
- **OriginLatency**: Response time from origin

### Access Logs

CloudFront access logs are stored in S3 and include:
- Request timestamp and edge location
- Client IP and User-Agent
- Request method, URI, and query string
- Response status code and bytes transferred
- Cache behavior and TTL information

### Real-time Monitoring

For real-time monitoring, enable real-time logs:

```hcl
cloudfront_enable_real_time_logs = true
cloudfront_real_time_log_config_arn = "arn:aws:logs:us-east-1:123456789012:destination:your-destination"
```

### ALB Metrics

Monitor ALB performance for origin health:
- **TargetResponseTime**: Response time from WordPress pods
- **HealthyHostCount**: Number of healthy targets
- **RequestCount**: Total requests to ALB
- **HTTPCode_Target_2XX_Count**: Successful responses from targets

### WordPress Application Monitoring

- **Pod Health**: Monitor WordPress pod status and resource usage
- **Database Performance**: Monitor Aurora metrics for query performance
- **Cache Performance**: Monitor Redis ElastiCache for object caching

## Complete Configuration Example

See `examples/cloudfront-advanced-configuration.tfvars` for a comprehensive example with all available options.

## Security Best Practices

1. **Always use the latest TLS protocol version**
2. **Enable origin protection with secure random secrets**
3. **Consider WAF integration for additional security**
4. **Use geo-restrictions if appropriate for your use case**
5. **Regularly review access logs for suspicious activity**
6. **Keep certificates up to date and monitor expiration**
7. **Use least-privilege IAM policies for CloudFront management**

## Cost Considerations

1. **Price Class**: Choose based on your user geographic distribution
2. **Origin Shield**: Adds cost but reduces origin load for high-traffic sites
3. **Real-time Logs**: Additional cost for real-time streaming
4. **HTTP/3**: May have slight cost impact
5. **Data Transfer**: Compression reduces transfer costs
6. **Request Pricing**: Consider cache hit ratios to minimize origin requests

## Support and Resources

- **AWS CloudFront Documentation**: https://docs.aws.amazon.com/cloudfront/
- **WordPress Performance Best Practices**: https://wordpress.org/support/article/optimization/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution

For additional support, consult the project documentation or raise an issue in the project repository.