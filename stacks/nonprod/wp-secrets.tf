# Build a single Secret (wp-env) with all runtime env vars WordPress needs.
# Only the sensitive fields come from Secrets Manager (passwords/tokens).
resource "kubectl_manifest" "wp_env_es" {
  depends_on = [kubectl_manifest.eso_css]

  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "wp-env"
      namespace = "wordpress"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef  = { name = "aws-sm", kind = "ClusterSecretStore" }
      target          = { name = "wp-env", creationPolicy = "Owner" }

      data = [
        # DB password from Secrets Manager (JSON property: password)
        {
          secretKey = "WORDPRESS_DB_PASSWORD"
          remoteRef = {
            key      = module.secrets_iam.wpapp_db_secret_arn
            property = "password"
          }
        },
        # Redis token from Secrets Manager (JSON property: token)
        {
          secretKey = "REDIS_PASSWORD"
          remoteRef = {
            key      = module.secrets_iam.redis_auth_secret_arn
            property = "token"
          }
        }
      ]

      # Non-secret connection metadata comes from Terraform (safe)
      template = {
        type = "Opaque"
        data = {
          WORDPRESS_DB_HOST = module.data_aurora.cluster_endpoint
          WORDPRESS_DB_NAME = "wordpress" # change if your DB name differs
          WORDPRESS_DB_USER = "wpapp"     # change if your DB user differs
          WORDPRESS_DB_PORT = "3306"

          REDIS_HOST   = module.elasticache.primary_endpoint_address
          REDIS_PORT   = "6379"
          REDIS_SCHEME = "tls"
        }
      }
    }
  })
}
