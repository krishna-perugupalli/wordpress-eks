locals {
  name = var.project

  # Base tags - always included
  base_tags = {
    Project   = var.project
    Env       = var.env
    Owner     = var.owner_email
    ManagedBy = "Terraform"
  }

  # Optional tags - only included if provided (non-empty)
  optional_tags = merge(
    var.cost_center != "" ? { CostCenter = var.cost_center } : {},
    var.application != "" ? { Application = var.application } : {},
    var.business_unit != "" ? { BusinessUnit = var.business_unit } : {},
    var.compliance_requirements != "" ? { Compliance = var.compliance_requirements } : {},
    var.data_classification != "" ? { DataClassification = var.data_classification } : {},
    var.technical_contact != "" ? { TechnicalContact = var.technical_contact } : {},
    var.product_owner != "" ? { ProductOwner = var.product_owner } : {}
  )

  # Merge all tags: base + optional + custom
  tags = merge(
    local.base_tags,
    local.optional_tags,
    var.tags
  )

  infra_outputs = data.terraform_remote_state.infra.outputs

  cluster_name                      = local.infra_outputs.cluster_name
  cluster_endpoint                  = local.infra_outputs.cluster_endpoint
  cluster_version                   = local.infra_outputs.cluster_version
  cluster_ca_data                   = local.infra_outputs.cluster_certificate_authority_data
  karpenter_controller_iam_role_arn = local.infra_outputs.karpenter_role_arn
  karpenter_sqs_queue_name          = local.infra_outputs.karpenter_sqs_queue_name
  karpenter_node_iam_role_name      = local.infra_outputs.karpenter_node_iam_role_name
  cluster_oidc_issuer_url           = local.infra_outputs.cluster_oidc_issuer_url
  oidc_provider_arn                 = local.infra_outputs.oidc_provider_arn
  vpc_id                            = local.infra_outputs.vpc_id
  azs                               = local.infra_outputs.azs
  secrets_read_policy_arn           = local.infra_outputs.secrets_read_policy_arn
  kms_logs_arn                      = local.infra_outputs.kms_logs_arn
  writer_endpoint                   = local.infra_outputs.writer_endpoint
  aurora_master_secret_arn          = local.infra_outputs.aurora_master_secret_arn
  wpapp_db_secret_arn               = local.infra_outputs.wpapp_db_secret_arn
  wp_admin_secret_arn               = local.infra_outputs.wp_admin_secret_arn
  cf_log_bucket_name                = local.infra_outputs.log_bucket_name
  file_system_id                    = local.infra_outputs.file_system_id
  redis_endpoint                    = try(local.infra_outputs.redis_endpoint, null)
  redis_auth_secret_arn             = try(local.infra_outputs.redis_auth_secret_arn, null)
  target_group_arn                  = local.infra_outputs.target_group_arn

  _ensure_infra_ready = length(keys(local.infra_outputs)) > 0
}
