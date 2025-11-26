output "release_name" {
  description = "Helm release name."
  value       = helm_release.wordpress.name
}

output "namespace" {
  description = "Namespace where WordPress was deployed."
  value       = var.namespace
}

output "domain_name" {
  description = "Domain name configured for WordPress."
  value       = var.domain_name
}

output "service_name" {
  description = "Service name exposed by the chart (same naming logic)"
  value = (
    var.fullname_override != "" ? var.fullname_override :
    (var.name_override != "" ? var.name_override : "${var.name}-wdp")
  )
}

output "target_group_binding_name" {
  description = "Name of the TargetGroupBinding resource"
  value       = "${local.effective_fullname}-tgb"
}
