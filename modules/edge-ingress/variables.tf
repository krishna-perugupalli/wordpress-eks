variable "name" {
  description = "Base/cluster name (used in role names and tags)"
  type        = string
}

variable "region" {
  description = "AWS region for the EKS cluster (and regional ACM/WAF)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "Cluster OIDC issuer URL (https://oidc.eks.<region>.amazonaws.com/id/xxxx)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for ALB controller (required by chart)"
  type        = string
}

variable "controller_namespace" {
  description = "Namespace to install AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

# --- New: optional CF -> ALB SG lock-down ---
variable "restrict_alb_to_cloudfront" {
  description = "If true, allow ALB ingress only from CloudFront origin-facing prefix list"
  type        = bool
  default     = false
}

variable "alb_security_group_id" {
  description = "Security Group ID attached to the ALB created by LBC (required if restrict_alb_to_cloudfront = true)"
  type        = string
  default     = ""
}

variable "create_regional_certificate" {
  description = "Create a regional ACM certificate for ALB"
  type        = bool
  default     = true
}

variable "alb_domain_name" {
  description = "FQDN served by the ALB (used when creating regional ACM cert)"
  type        = string
  default     = ""
}

variable "alb_hosted_zone_id" {
  description = "Route53 Hosted Zone ID for alb_domain_name (for DNS validation)"
  type        = string
  default     = ""
}

variable "create_cf_certificate" {
  description = "Create an ACM certificate in us-east-1 for future CloudFront"
  type        = bool
  default     = false
}

variable "cf_domain_name" {
  description = "FQDN for CloudFront (used if create_cf_certificate = true)"
  type        = string
  default     = ""
}

variable "cf_hosted_zone_id" {
  description = "Route53 Hosted Zone ID for cf_domain_name (for DNS validation)"
  type        = string
  default     = ""
}

variable "create_waf_regional" {
  description = "Create a WAFv2 Web ACL (REGIONAL) for ALB"
  type        = bool
  default     = true
}

variable "waf_ruleset_level" {
  description = "Managed rules strictness: 'baseline' or 'strict'"
  type        = string
  default     = "baseline"
  validation {
    condition     = contains(["baseline", "strict"], var.waf_ruleset_level)
    error_message = "waf_ruleset_level must be 'baseline' or 'strict'."
  }
}

variable "tags" {
  description = "Common tags for created resources"
  type        = map(string)
  default     = {}
}

variable "enable_common_ruleset" {
  description = "Enable or disable flag for AWSManagedRulesCommonRuleSet, To unblock some application level issues with WAF"
  type        = string
  default     = false
}
