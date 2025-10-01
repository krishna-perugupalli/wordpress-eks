variable "name" {
  description = "Stack/app name used for resource naming."
  type        = string
}

variable "domain_name" {
  description = "Primary viewer FQDN served by CloudFront (e.g., www.example.com)."
  type        = string
}

variable "aliases" {
  description = "Additional CNAMEs for the distribution."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront viewer TLS."
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name to use as the CloudFront origin."
  type        = string
}

variable "alb_host_header" {
  description = "Host header CloudFront sends to the ALB (usually same as domain_name)."
  type        = string
}

variable "waf_web_acl_arn" {
  description = "Optional WAFv2 WebACL ARN with CLOUDFRONT scope."
  type        = string
  default     = ""
}

variable "log_bucket_name" {
  description = "S3 bucket name (no s3:// prefix) for CloudFront logs; should be KMS-encrypted."
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)."
  type        = string
  default     = "PriceClass_100"
}

variable "compress" {
  description = "Enable gzip/brotli compression at CloudFront."
  type        = bool
  default     = true
}

variable "enable_http3" {
  description = "Enable HTTP/3 for viewer connections."
  type        = bool
  default     = true
}

variable "default_ttl" {
  description = "Default TTL (seconds) for dynamic paths."
  type        = number
  default     = 300
}

variable "min_ttl" {
  description = "Minimum TTL (seconds)."
  type        = number
  default     = 0
}

variable "max_ttl" {
  description = "Maximum TTL (seconds)."
  type        = number
  default     = 86400
}

variable "static_ttl" {
  description = "TTL (seconds) for static paths like /wp-content/*."
  type        = number
  default     = 604800
}

variable "tags" {
  description = "Tags to apply to supported resources."
  type        = map(string)
  default     = {}
}
