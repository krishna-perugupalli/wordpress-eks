output "wordpress_namespace" {
  description = "Namespace where WordPress is installed"
  value       = var.wp_namespace
}

output "wordpress_hostname" {
  description = "Public hostname for WordPress"
  value       = var.wp_domain_name
}

output "target_group_arn" {
  description = "Target group ARN from infrastructure stack"
  value       = local.target_group_arn
}

#############################################
# cert-manager Outputs
#############################################
output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.enable_cert_manager
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = var.enable_cert_manager ? module.cert_manager[0].namespace : null
}

output "letsencrypt_prod_issuer" {
  description = "Name of the Let's Encrypt production ClusterIssuer"
  value       = var.enable_cert_manager ? module.cert_manager[0].letsencrypt_prod_issuer : null
}

output "letsencrypt_staging_issuer" {
  description = "Name of the Let's Encrypt staging ClusterIssuer"
  value       = var.enable_cert_manager ? module.cert_manager[0].letsencrypt_staging_issuer : null
}

output "selfsigned_issuer" {
  description = "Name of the self-signed ClusterIssuer"
  value       = var.enable_cert_manager ? module.cert_manager[0].selfsigned_issuer : null
}

#############################################
# Basic Observability Outputs
#############################################
output "monitoring_namespace" {
  description = "Namespace used for observability agents"
  value       = module.observability.namespace
}

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names for app/dataplane/host"
  value       = module.observability.log_groups
}

output "cwagent_role_arn" {
  description = "IAM role ARN for CloudWatch Agent"
  value       = module.observability.cwagent_role_arn
}

output "fluentbit_role_arn" {
  description = "IAM role ARN for Fluent Bit"
  value       = module.observability.fluentbit_role_arn
}
