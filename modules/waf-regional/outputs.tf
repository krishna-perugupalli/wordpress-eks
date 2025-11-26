output "waf_arn" {
  description = "ARN of the WAF WebACL"
  value       = aws_wafv2_web_acl.regional.arn
}

output "waf_id" {
  description = "ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.regional.id
}

output "waf_name" {
  description = "Name of the WAF WebACL"
  value       = aws_wafv2_web_acl.regional.name
}
