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

variable "route53_points_to_cloudfront" {
  description = "When true, Route53 record points to CloudFront distribution instead of ALB"
  type        = bool
  default     = false
}

variable "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name (required when route53_points_to_cloudfront is true)"
  type        = string
  default     = ""
}

variable "cloudfront_distribution_zone_id" {
  description = "CloudFront distribution zone ID (typically Z2FDTNDATAQYW2 for CloudFront)"
  type        = string
  default     = "Z2FDTNDATAQYW2"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
