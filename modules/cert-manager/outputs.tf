output "namespace" {
  description = "Namespace where cert-manager is installed"
  value       = kubernetes_namespace.cert_manager.metadata[0].name
}

output "helm_release_name" {
  description = "Name of the cert-manager Helm release"
  value       = helm_release.cert_manager.name
}

output "helm_release_version" {
  description = "Version of the cert-manager Helm chart deployed"
  value       = helm_release.cert_manager.version
}

output "letsencrypt_prod_issuer" {
  description = "Name of the Let's Encrypt production ClusterIssuer"
  value       = var.create_letsencrypt_issuer ? "letsencrypt-prod" : null
}

output "letsencrypt_staging_issuer" {
  description = "Name of the Let's Encrypt staging ClusterIssuer"
  value       = var.create_letsencrypt_issuer ? "letsencrypt-staging" : null
}

output "selfsigned_issuer" {
  description = "Name of the self-signed ClusterIssuer"
  value       = var.create_selfsigned_issuer ? "selfsigned-issuer" : null
}
