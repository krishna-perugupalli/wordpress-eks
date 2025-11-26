output "distribution_id" { value = aws_cloudfront_distribution.this.id }
output "distribution_domain_name" { value = aws_cloudfront_distribution.this.domain_name }
output "distribution_zone_id" { value = aws_cloudfront_distribution.this.hosted_zone_id }
output "distribution_arn" { value = aws_cloudfront_distribution.this.arn }
output "header_function_arn" {
  value       = var.enable_header_function ? aws_cloudfront_function.header_manipulation[0].arn : null
  description = "ARN of the CloudFront Function for header manipulation"
}

output "cache_policy_ids" {
  value = {
    bypass_auth   = aws_cloudfront_cache_policy.bypass_auth.id
    static_long   = aws_cloudfront_cache_policy.static_long.id
    feeds_sitemap = aws_cloudfront_cache_policy.feeds_sitemap.id
  }
  description = "Map of cache policy IDs for reference"
}

output "origin_request_policy_ids" {
  value = {
    minimal           = aws_cloudfront_origin_request_policy.minimal.id
    wordpress_dynamic = aws_cloudfront_origin_request_policy.wordpress_dynamic.id
  }
  description = "Map of origin request policy IDs for reference"
}

output "response_headers_policy_id" {
  value       = aws_cloudfront_response_headers_policy.security.id
  description = "ID of the security response headers policy"
}

output "distribution_status" {
  value       = aws_cloudfront_distribution.this.status
  description = "Current status of the CloudFront distribution"
}

output "distribution_etag" {
  value       = aws_cloudfront_distribution.this.etag
  description = "ETag of the CloudFront distribution for change detection"
}

# Route53 Integration Outputs
output "route53_record_fqdn" {
  value       = var.create_route53_record && var.hosted_zone_id != "" ? aws_route53_record.cloudfront_primary[0].fqdn : ""
  description = "FQDN of the primary Route53 record pointing to CloudFront"
}

output "route53_alias_fqdns" {
  value       = var.create_route53_record && var.hosted_zone_id != "" ? aws_route53_record.cloudfront_aliases[*].fqdn : []
  description = "FQDNs of alias Route53 records pointing to CloudFront"
}

output "hosted_zone_id_used" {
  value       = var.hosted_zone_id
  description = "Hosted zone ID used for Route53 records"
}

output "route53_records_created" {
  value       = var.create_route53_record && var.hosted_zone_id != ""
  description = "Whether Route53 records were created"
}

# Validation outputs for DNS configuration
output "dns_validation" {
  value = {
    cloudfront_domain_name = aws_cloudfront_distribution.this.domain_name
    cloudfront_zone_id     = aws_cloudfront_distribution.this.hosted_zone_id
    primary_domain         = var.domain_name
    aliases                = var.aliases
    hosted_zone_valid      = var.create_route53_record && var.hosted_zone_id != "" ? data.aws_route53_zone.selected[0].zone_id == var.hosted_zone_id : null
  }
  description = "DNS configuration validation information"
}