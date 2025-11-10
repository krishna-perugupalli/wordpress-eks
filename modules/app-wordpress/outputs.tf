output "release_name" {
  description = "Helm release name."
  value       = helm_release.wordpress.name
}

output "namespace" {
  description = "Namespace where WordPress was deployed."
  value       = var.namespace
}

output "ingress_hostname" {
  description = "Ingress hostname configured for WordPress."
  value       = var.domain_name
}

output "ingress_name" {
  description = "Deterministic Ingress name used by the chart (matches fullnameOverride/nameOverride logic)"
  value = (
    var.fullname_override != "" ? var.fullname_override :
    (var.name_override != "" ? var.name_override : "${var.name}-wdp")
  )
}

output "service_name" {
  description = "Service name exposed by the chart (same naming logic)"
  value = (
    var.fullname_override != "" ? var.fullname_override :
    (var.name_override != "" ? var.name_override : "${var.name}-wdp")
  )
}
