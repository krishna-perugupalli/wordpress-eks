<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.55 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.55 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_lb.wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.origin_secret_validation_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_listener_rule.origin_secret_validation_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.wordpress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.alb_http_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_https_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.alb_pod_egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.worker_pod_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_wafv2_web_acl_association.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_ec2_managed_prefix_list.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_managed_prefix_list) | data source |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ACM certificate ARN for HTTPS listener | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Base name for resource naming | `string` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | List of public subnet IDs for ALB attachment (must span multiple AZs) | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where ALB will be created | `string` | n/a | yes |
| <a name="input_worker_node_security_group_id"></a> [worker\_node\_security\_group\_id](#input\_worker\_node\_security\_group\_id) | Security group ID of EKS worker nodes | `string` | n/a | yes |
| <a name="input_cloudfront_enabled"></a> [cloudfront\_enabled](#input\_cloudfront\_enabled) | Whether CloudFront is enabled. Origin protection only applies when CloudFront is enabled. | `bool` | `false` | no |
| <a name="input_create_route53_record"></a> [create\_route53\_record](#input\_create\_route53\_record) | Whether to create Route53 A record | `bool` | `true` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | Time in seconds for connection draining | `number` | `30` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Domain name for Route53 record | `string` | `""` | no |
| <a name="input_enable_cloudfront_restriction"></a> [enable\_cloudfront\_restriction](#input\_enable\_cloudfront\_restriction) | Restrict ALB to CloudFront IPs only | `bool` | `false` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection on ALB | `bool` | `false` | no |
| <a name="input_enable_origin_protection"></a> [enable\_origin\_protection](#input\_enable\_origin\_protection) | Enable origin protection to block direct ALB access and only allow CloudFront traffic with valid origin secret | `bool` | `false` | no |
| <a name="input_enable_waf"></a> [enable\_waf](#input\_enable\_waf) | Enable WAF association with ALB | `bool` | `false` | no |
| <a name="input_health_check_healthy_threshold"></a> [health\_check\_healthy\_threshold](#input\_health\_check\_healthy\_threshold) | Number of consecutive successful health checks before marking target healthy | `number` | `2` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Health check interval in seconds | `number` | `30` | no |
| <a name="input_health_check_matcher"></a> [health\_check\_matcher](#input\_health\_check\_matcher) | HTTP status codes to consider healthy | `string` | `"200-399"` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | Health check path | `string` | `"/"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | Health check timeout in seconds | `number` | `5` | no |
| <a name="input_health_check_unhealthy_threshold"></a> [health\_check\_unhealthy\_threshold](#input\_health\_check\_unhealthy\_threshold) | Number of consecutive failed health checks before marking target unhealthy | `number` | `2` | no |
| <a name="input_hosted_zone_id"></a> [hosted\_zone\_id](#input\_hosted\_zone\_id) | Route53 hosted zone ID | `string` | `""` | no |
| <a name="input_origin_protection_response_body"></a> [origin\_protection\_response\_body](#input\_origin\_protection\_response\_body) | Response body to return when origin secret validation fails | `string` | `"Access Denied"` | no |
| <a name="input_origin_protection_response_code"></a> [origin\_protection\_response\_code](#input\_origin\_protection\_response\_code) | HTTP response code to return when origin secret validation fails | `number` | `403` | no |
| <a name="input_origin_secret_value"></a> [origin\_secret\_value](#input\_origin\_secret\_value) | Shared secret header value for CloudFront origin protection. When set, ALB will validate X-Origin-Secret header and reject requests without valid secret. | `string` | `""` | no |
| <a name="input_ssl_policy"></a> [ssl\_policy](#input\_ssl\_policy) | SSL policy for HTTPS listener | `string` | `"ELBSecurityPolicy-TLS13-1-2-2021-06"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_waf_acl_arn"></a> [waf\_acl\_arn](#input\_waf\_acl\_arn) | WAF WebACL ARN for association (optional) | `string` | `""` | no |
| <a name="input_wordpress_pod_port"></a> [wordpress\_pod\_port](#input\_wordpress\_pod\_port) | Port where WordPress pods are listening | `number` | `8080` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer |
| <a name="output_alb_security_group_id"></a> [alb\_security\_group\_id](#output\_alb\_security\_group\_id) | Security group ID of the ALB |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Zone ID of the Application Load Balancer |
| <a name="output_dns_validation"></a> [dns\_validation](#output\_dns\_validation) | DNS configuration validation information |
| <a name="output_http_listener_arn"></a> [http\_listener\_arn](#output\_http\_listener\_arn) | ARN of the HTTP listener |
| <a name="output_https_listener_arn"></a> [https\_listener\_arn](#output\_https\_listener\_arn) | ARN of the HTTPS listener |
| <a name="output_listener_rule_arns"></a> [listener\_rule\_arns](#output\_listener\_rule\_arns) | ARNs of the origin secret validation listener rules |
| <a name="output_origin_protection_config"></a> [origin\_protection\_config](#output\_origin\_protection\_config) | Origin protection configuration details |
| <a name="output_origin_protection_enabled"></a> [origin\_protection\_enabled](#output\_origin\_protection\_enabled) | Whether origin protection is enabled on the ALB |
| <a name="output_route53_record_fqdn"></a> [route53\_record\_fqdn](#output\_route53\_record\_fqdn) | FQDN of the created Route53 record |
| <a name="output_route53_record_type"></a> [route53\_record\_type](#output\_route53\_record\_type) | Type of Route53 record created |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the target group for WordPress pods |
| <a name="output_target_group_name"></a> [target\_group\_name](#output\_target\_group\_name) | Name of the target group |
<!-- END_TF_DOCS -->