variable "name" {
  description = "Logical name/prefix for CloudFront resources."
  type        = string
}

variable "domain_name" {
  description = "Primary DNS name (CNAME) for the distribution."
  type        = string
}

variable "aliases" {
  description = "Additional CNAMEs."
  type        = list(string)
  default     = []
}

variable "alb_dns_name" {
  description = "Public DNS name of the ALB (custom origin)."
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for CloudFront."
  type        = string
}

variable "waf_web_acl_arn" {
  description = "Optional WAFv2 Web ACL ARN (CLOUDFRONT scope). Empty to disable."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)."
  type        = string
  default     = "PriceClass_100"
}

variable "default_ttl" {
  description = "Default TTL for bypass_auth cache policy."
  type        = number
  default     = 60
}

variable "max_ttl" {
  description = "Max TTL for bypass_auth cache policy."
  type        = number
  default     = 300
}

variable "min_ttl" {
  description = "Min TTL for bypass_auth cache policy."
  type        = number
  default     = 0
}

variable "static_ttl" {
  description = "TTL for static_long policy (e.g., /wp-content/*)."
  type        = number
  default     = 86400
}

variable "log_bucket_name" {
  description = "S3 bucket (name only) for CloudFront logs. Bucket policy must allow CF to write."
  type        = string
}

variable "compress" {
  description = "Enable Gzip/Brotli compression."
  type        = bool
  default     = true
}

variable "enable_http3" {
  description = "Enable HTTP/3 (QUIC)."
  type        = bool
  default     = false
}

variable "origin_secret_value" {
  description = "Shared secret header value (X-Origin-Secret) injected by CloudFront and validated at the origin."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
