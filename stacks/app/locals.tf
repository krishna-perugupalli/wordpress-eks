locals {
  name = var.project
  tags = merge(
    {
      Project = var.project
      Env     = var.env
      Owner   = var.owner_email
    },
    var.tags
  )

  infra_outputs = data.terraform_remote_state.infra.outputs

  cluster_name                      = local.infra_outputs.cluster_name
  cluster_endpoint                  = local.infra_outputs.cluster_endpoint
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

  _ensure_infra_ready = length(keys(local.infra_outputs)) > 0
}

locals {
  alb_arn   = try(data.aws_resourcegroupstaggingapi_resources.wp_alb.resource_tag_mapping_list[0].resource_arn, null)
  alb_found = local.alb_arn != null && local.alb_arn != ""
}
