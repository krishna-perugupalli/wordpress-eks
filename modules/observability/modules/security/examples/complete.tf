#############################################
# Complete Security Module Example
# Demonstrates all security and compliance features
#############################################

# Example KMS key for encryption
resource "aws_kms_key" "monitoring" {
  description             = "KMS key for monitoring encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "monitoring-encryption-key"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "monitoring" {
  name          = "alias/monitoring-encryption"
  target_key_id = aws_kms_key.monitoring.key_id
}

# Example cert-manager ClusterIssuer (must be created separately)
# This is just for reference - cert-manager must be installed first
/*
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: alb
*/

# Security module with all features enabled
module "security" {
  source = "../"

  name         = "wordpress-eks"
  region       = "us-west-2"
  cluster_name = "wordpress-eks-cluster"
  namespace    = "observability"

  # TLS encryption configuration
  enable_tls_encryption   = true
  tls_cert_manager_issuer = "letsencrypt-prod"

  # PII scrubbing configuration with comprehensive rules
  enable_pii_scrubbing = true
  pii_scrubbing_rules = [
    {
      pattern     = "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"
      replacement = "[EMAIL_REDACTED]"
      description = "Email addresses"
    },
    {
      pattern     = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
      replacement = "[SSN_REDACTED]"
      description = "Social Security Numbers"
    },
    {
      pattern     = "\\b\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}\\b"
      replacement = "[CARD_REDACTED]"
      description = "Credit card numbers"
    },
    {
      pattern     = "\\b\\d{3}[\\s.-]?\\d{3}[\\s.-]?\\d{4}\\b"
      replacement = "[PHONE_REDACTED]"
      description = "Phone numbers"
    },
    {
      pattern     = "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"
      replacement = "[IP_REDACTED]"
      description = "IPv4 addresses"
    }
  ]

  # Audit logging configuration
  enable_audit_logging     = true
  audit_log_retention_days = 90

  # RBAC policies for different teams
  rbac_policies = {
    # Developers get viewer access
    "developers-viewer" = {
      subjects = [
        {
          kind      = "Group"
          name      = "developers"
          namespace = "observability"
        }
      ]
      role_ref = {
        kind      = "Role"
        name      = "monitoring-viewer"
        api_group = "rbac.authorization.k8s.io"
      }
    }

    # SRE team gets admin access
    "sre-admin" = {
      subjects = [
        {
          kind      = "Group"
          name      = "sre"
          namespace = "observability"
        }
      ]
      role_ref = {
        kind      = "Role"
        name      = "monitoring-admin"
        api_group = "rbac.authorization.k8s.io"
      }
    }

    # Security team gets viewer access
    "security-viewer" = {
      subjects = [
        {
          kind      = "Group"
          name      = "security"
          namespace = "observability"
        }
      ]
      role_ref = {
        kind      = "Role"
        name      = "monitoring-viewer"
        api_group = "rbac.authorization.k8s.io"
      }
    }
  }

  # KMS encryption
  kms_key_arn = aws_kms_key.monitoring.arn

  tags = {
    Environment = "production"
    Project     = "wordpress-eks"
    Owner       = "platform-team@example.com"
    ManagedBy   = "Terraform"
    Compliance  = "HIPAA,SOC2,GDPR"
  }
}

#############################################
# Outputs
#############################################

output "security_configuration" {
  description = "Security configuration summary"
  value = {
    tls_enabled           = module.security.tls_enabled
    pii_scrubbing_enabled = module.security.pii_scrubbing_enabled
    audit_logging_enabled = module.security.audit_logging_enabled
    audit_log_group       = module.security.audit_log_group_name
    viewer_role           = module.security.monitoring_viewer_role_name
    admin_role            = module.security.monitoring_admin_role_name
  }
}

output "kms_key_info" {
  description = "KMS key information"
  value = {
    key_id    = aws_kms_key.monitoring.key_id
    key_arn   = aws_kms_key.monitoring.arn
    key_alias = aws_kms_alias.monitoring.name
  }
}

output "compliance_features" {
  description = "Compliance features enabled"
  value = {
    encryption_at_rest    = true
    encryption_in_transit = module.security.tls_enabled
    audit_logging         = module.security.audit_logging_enabled
    pii_protection        = module.security.pii_scrubbing_enabled
    access_control        = true
    data_retention        = "90 days"
  }
}
