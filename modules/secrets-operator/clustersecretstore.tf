# ClusterSecretStore for AWS Secrets Manager
# Name must match what your ExternalSecret resources expect: "aws-sm"
#
# Assumptions:
# - External Secrets Operator is installed via helm_release.external_secrets
# - Namespace is "external-secrets"
# - ServiceAccount name is "external-secrets" (the chart's default)
#
# If you customized the namespace or SA name, change them below.

resource "kubectl_manifest" "cluster_secret_store_aws_sm" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-sm"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets" # <-- change if you use a custom SA
                namespace = "external-secrets" # <-- change if you installed ESO elsewhere
              }
            }
          }
        }
      }
    }
  })

  # Ensure ESO CRDs + controller exist before applying this CR
  depends_on = [
    helm_release.eso
  ]
}
