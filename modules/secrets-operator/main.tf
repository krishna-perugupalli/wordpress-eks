locals {
  ns                  = var.namespace
  sa_name             = "external-secrets"
  oidc_hostpath       = replace(var.cluster_oidc_issuer_url, "https://", "")
  _policy_arn_input   = var.secrets_read_policy_arn == null ? "" : var.secrets_read_policy_arn
  _allowed_arns_input = var.allowed_secret_arns == null ? [] : var.allowed_secret_arns
  _has_policy_arn     = trimspace(local._policy_arn_input) != ""
  _has_allowed_arns   = length(local._allowed_arns_input) > 0
}

# This throws during plan if neither/both are set
resource "null_resource" "input_guard" {
  lifecycle {
    precondition {
      condition     = (local._has_policy_arn && !local._has_allowed_arns) || (!local._has_policy_arn && local._has_allowed_arns)
      error_message = "Provide exactly one: either secrets_read_policy_arn (Option A) OR allowed_secret_arns (Option B)."
    }
  }
}

# Namespace + ServiceAccount with IRSA
resource "kubernetes_namespace" "ns" {
  metadata { name = local.ns }
}

resource "kubernetes_service_account" "eso" {
  metadata {
    name      = local.sa_name
    namespace = local.ns
    annotations = {
      "eks.amazonaws.com/role-arn" = var.eso_role_arn
    }
  }
  automount_service_account_token = true

  depends_on = [kubernetes_namespace.ns]
}

# Helm install ESO with precreated SA, CRDs on
resource "helm_release" "eso" {
  name       = "external-secrets"
  namespace  = local.ns
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.chart_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = local.sa_name
  }

  depends_on = [kubernetes_service_account.eso]
}
