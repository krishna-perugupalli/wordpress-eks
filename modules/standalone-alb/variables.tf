# Standalone ALB Module Variables

variable "name" {
  description = "Base name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB attachment (must span multiple AZs)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "waf_acl_arn" {
  description = "WAF WebACL ARN for association (optional)"
  type        = string
  default     = ""
}

variable "enable_waf" {
  description = "Enable WAF association with ALB"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for Route53 record"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "create_route53_record" {
  description = "Whether to create Route53 A record"
  type        = bool
  default     = true
}

variable "wordpress_pod_port" {
  description = "Port where WordPress pods are listening"
  type        = number
  default     = 8080
}

variable "worker_node_security_group_id" {
  description = "Security group ID of EKS worker nodes"
  type        = string
}

variable "enable_cloudfront_restriction" {
  description = "Restrict ALB to CloudFront IPs only"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on ALB"
  type        = bool
  default     = false
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks before marking target healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking target unhealthy"
  type        = number
  default     = 2
}

variable "health_check_matcher" {
  description = "HTTP status codes to consider healthy"
  type        = string
  default     = "200-399"
}

variable "deregistration_delay" {
  description = "Time in seconds for connection draining"
  type        = number
  default     = 30
}



variable "origin_secret_value" {
  description = "Shared secret header value for CloudFront origin protection. When set, ALB will validate X-Origin-Secret header and reject requests without valid secret."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_origin_protection" {
  description = "Enable origin protection to block direct ALB access and only allow CloudFront traffic with valid origin secret"
  type        = bool
  default     = false
}

variable "origin_protection_response_code" {
  description = "HTTP response code to return when origin secret validation fails"
  type        = number
  default     = 403
  validation {
    condition     = contains([400, 401, 403, 404, 503], var.origin_protection_response_code)
    error_message = "Origin protection response code must be one of: 400, 401, 403, 404, 503."
  }
}

variable "origin_protection_response_body" {
  description = "Response body to return when origin secret validation fails"
  type        = string
  default     = "Access Denied"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
