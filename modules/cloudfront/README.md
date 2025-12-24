<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.45 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.45 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudfront_cache_policy.bypass_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_cache_policy.feeds_sitemap](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_cache_policy.static_long](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_function.header_manipulation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function) | resource |
| [aws_cloudfront_origin_request_policy.minimal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_request_policy) | resource |
| [aws_cloudfront_origin_request_policy.wordpress_dynamic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_request_policy) | resource |
| [aws_cloudfront_response_headers_policy.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_route53_record.cloudfront_aliases](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.cloudfront_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ACM certificate ARN in us-east-1 for CloudFront. | `string` | n/a | yes |
| <a name="input_alb_dns_name"></a> [alb\_dns\_name](#input\_alb\_dns\_name) | Public DNS name of the ALB (custom origin). | `string` | n/a | yes |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Primary DNS name (CNAME) for the distribution. | `string` | n/a | yes |
| <a name="input_log_bucket_name"></a> [log\_bucket\_name](#input\_log\_bucket\_name) | S3 bucket (name only) for CloudFront logs. Bucket policy must allow CF to write. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Logical name/prefix for CloudFront resources. | `string` | n/a | yes |
| <a name="input_aliases"></a> [aliases](#input\_aliases) | Additional CNAMEs. | `list(string)` | `[]` | no |
| <a name="input_compress"></a> [compress](#input\_compress) | Enable Gzip/Brotli compression. | `bool` | `true` | no |
| <a name="input_create_route53_record"></a> [create\_route53\_record](#input\_create\_route53\_record) | Whether to create Route53 A record pointing to CloudFront distribution | `bool` | `true` | no |
| <a name="input_custom_error_responses"></a> [custom\_error\_responses](#input\_custom\_error\_responses) | List of custom error response configurations for CloudFront. | <pre>list(object({<br>    error_code            = number<br>    response_code         = number<br>    response_page_path    = string<br>    error_caching_min_ttl = number<br>  }))</pre> | <pre>[<br>  {<br>    "error_caching_min_ttl": 300,<br>    "error_code": 400,<br>    "response_code": 400,<br>    "response_page_path": "/400.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 300,<br>    "error_code": 403,<br>    "response_code": 404,<br>    "response_page_path": "/404.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 300,<br>    "error_code": 404,<br>    "response_code": 404,<br>    "response_page_path": "/404.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 300,<br>    "error_code": 405,<br>    "response_code": 405,<br>    "response_page_path": "/405.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 300,<br>    "error_code": 414,<br>    "response_code": 414,<br>    "response_page_path": "/414.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 300,<br>    "error_code": 416,<br>    "response_code": 416,<br>    "response_page_path": "/416.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 60,<br>    "error_code": 500,<br>    "response_code": 500,<br>    "response_page_path": "/500.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 60,<br>    "error_code": 501,<br>    "response_code": 501,<br>    "response_page_path": "/501.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 60,<br>    "error_code": 502,<br>    "response_code": 502,<br>    "response_page_path": "/502.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 60,<br>    "error_code": 503,<br>    "response_code": 503,<br>    "response_page_path": "/503.html"<br>  },<br>  {<br>    "error_caching_min_ttl": 60,<br>    "error_code": 504,<br>    "response_code": 504,<br>    "response_page_path": "/504.html"<br>  }<br>]</pre> | no |
| <a name="input_default_root_object"></a> [default\_root\_object](#input\_default\_root\_object) | Default root object for CloudFront distribution. | `string` | `"index.php"` | no |
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | Default TTL for bypass\_auth cache policy. | `number` | `60` | no |
| <a name="input_enable_header_function"></a> [enable\_header\_function](#input\_enable\_header\_function) | Enable CloudFront Function for header manipulation to prevent redirect loops. | `bool` | `true` | no |
| <a name="input_enable_http3"></a> [enable\_http3](#input\_enable\_http3) | Enable HTTP/3 (QUIC). | `bool` | `false` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enable CloudFront access logging to S3 bucket. | `bool` | `true` | no |
| <a name="input_enable_origin_shield"></a> [enable\_origin\_shield](#input\_enable\_origin\_shield) | Enable CloudFront Origin Shield for improved cache hit ratio. | `bool` | `false` | no |
| <a name="input_enable_real_time_logs"></a> [enable\_real\_time\_logs](#input\_enable\_real\_time\_logs) | Enable CloudFront real-time logs. | `bool` | `false` | no |
| <a name="input_enable_smooth_streaming"></a> [enable\_smooth\_streaming](#input\_enable\_smooth\_streaming) | Enable Microsoft Smooth Streaming for media content. | `bool` | `false` | no |
| <a name="input_geo_restriction_locations"></a> [geo\_restriction\_locations](#input\_geo\_restriction\_locations) | List of country codes for geo restriction (ISO 3166-1 alpha-2). | `list(string)` | `[]` | no |
| <a name="input_geo_restriction_type"></a> [geo\_restriction\_type](#input\_geo\_restriction\_type) | Type of geo restriction (none, whitelist, blacklist). | `string` | `"none"` | no |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route53 hosted zone ID for DNS record creation | `string` | `""` | no |
| <a name="input_is_ipv6_enabled"></a> [is\_ipv6\_enabled](#input\_is\_ipv6\_enabled) | Enable IPv6 support for CloudFront distribution. | `bool` | `true` | no |
| <a name="input_log_include_cookies"></a> [log\_include\_cookies](#input\_log\_include\_cookies) | Include cookies in CloudFront access logs. | `bool` | `false` | no |
| <a name="input_log_prefix"></a> [log\_prefix](#input\_log\_prefix) | Prefix for CloudFront access log files in S3 bucket. | `string` | `"cloudfront-logs/"` | no |
| <a name="input_max_ttl"></a> [max\_ttl](#input\_max\_ttl) | Max TTL for bypass\_auth cache policy. | `number` | `300` | no |
| <a name="input_min_ttl"></a> [min\_ttl](#input\_min\_ttl) | Min TTL for bypass\_auth cache policy. | `number` | `0` | no |
| <a name="input_minimum_protocol_version"></a> [minimum\_protocol\_version](#input\_minimum\_protocol\_version) | Minimum SSL/TLS protocol version for CloudFront distribution. | `string` | `"TLSv1.2_2021"` | no |
| <a name="input_origin_secret_value"></a> [origin\_secret\_value](#input\_origin\_secret\_value) | Optional shared secret header value (X-Origin-Secret) injected by CloudFront and validated at the origin, if configured. Leave empty to disable. | `string` | `""` | no |
| <a name="input_origin_shield_region"></a> [origin\_shield\_region](#input\_origin\_shield\_region) | AWS region for Origin Shield (should be closest to your origin). | `string` | `"eu-central-1"` | no |
| <a name="input_price_class"></a> [price\_class](#input\_price\_class) | CloudFront price class (PriceClass\_All, PriceClass\_200, PriceClass\_100). | `string` | `"PriceClass_100"` | no |
| <a name="input_real_time_log_config_arn"></a> [real\_time\_log\_config\_arn](#input\_real\_time\_log\_config\_arn) | ARN of the real-time log configuration for CloudFront. | `string` | `""` | no |
| <a name="input_route53_record_ttl"></a> [route53\_record\_ttl](#input\_route53\_record\_ttl) | TTL for Route53 record (only used for non-alias records) | `number` | `300` | no |
| <a name="input_static_ttl"></a> [static\_ttl](#input\_static\_ttl) | TTL for static\_long policy (e.g., /wp-content/*). | `number` | `86400` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags. | `map(string)` | `{}` | no |
| <a name="input_trusted_key_groups"></a> [trusted\_key\_groups](#input\_trusted\_key\_groups) | List of CloudFront key group IDs for trusted signers. | `list(string)` | `[]` | no |
| <a name="input_trusted_signers"></a> [trusted\_signers](#input\_trusted\_signers) | List of AWS account IDs for trusted signers (for signed URLs/cookies). | `list(string)` | `[]` | no |
| <a name="input_waf_web_acl_arn"></a> [waf\_web\_acl\_arn](#input\_waf\_web\_acl\_arn) | Optional WAFv2 Web ACL ARN (CLOUDFRONT scope). Empty to disable. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cache_policy_ids"></a> [cache\_policy\_ids](#output\_cache\_policy\_ids) | Map of cache policy IDs for reference |
| <a name="output_distribution_arn"></a> [distribution\_arn](#output\_distribution\_arn) | n/a |
| <a name="output_distribution_domain_name"></a> [distribution\_domain\_name](#output\_distribution\_domain\_name) | n/a |
| <a name="output_distribution_etag"></a> [distribution\_etag](#output\_distribution\_etag) | ETag of the CloudFront distribution for change detection |
| <a name="output_distribution_id"></a> [distribution\_id](#output\_distribution\_id) | n/a |
| <a name="output_distribution_status"></a> [distribution\_status](#output\_distribution\_status) | Current status of the CloudFront distribution |
| <a name="output_distribution_zone_id"></a> [distribution\_zone\_id](#output\_distribution\_zone\_id) | n/a |
| <a name="output_dns_validation"></a> [dns\_validation](#output\_dns\_validation) | DNS configuration validation information |
| <a name="output_header_function_arn"></a> [header\_function\_arn](#output\_header\_function\_arn) | ARN of the CloudFront Function for header manipulation |
| <a name="output_hosted_zone_id_used"></a> [hosted\_zone\_id\_used](#output\_hosted\_zone\_id\_used) | Hosted zone ID used for Route53 records |
| <a name="output_origin_request_policy_ids"></a> [origin\_request\_policy\_ids](#output\_origin\_request\_policy\_ids) | Map of origin request policy IDs for reference |
| <a name="output_response_headers_policy_id"></a> [response\_headers\_policy\_id](#output\_response\_headers\_policy\_id) | ID of the security response headers policy |
| <a name="output_route53_alias_fqdns"></a> [route53\_alias\_fqdns](#output\_route53\_alias\_fqdns) | FQDNs of alias Route53 records pointing to CloudFront |
| <a name="output_route53_record_fqdn"></a> [route53\_record\_fqdn](#output\_route53\_record\_fqdn) | FQDN of the primary Route53 record pointing to CloudFront |
| <a name="output_route53_records_created"></a> [route53\_records\_created](#output\_route53\_records\_created) | Whether Route53 records were created |
<!-- END_TF_DOCS -->