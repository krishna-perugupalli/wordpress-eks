output "namespace" {
  value       = var.namespace
  description = "Namespace where External Secrets Operator is installed"
}

output "service_account" {
  value       = "${var.namespace}/external-secrets"
  description = "ServiceAccount used by ESO (namespaced/name)"
}
