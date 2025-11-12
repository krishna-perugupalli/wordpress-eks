data "aws_caller_identity" "current" {}

#############################################
# Locals
#############################################
locals {
  ns                = var.namespace
  oidc_hostpath     = replace(var.cluster_oidc_issuer_url, "https://", "")
  kms_logs_key_trim = trimspace(coalesce(var.kms_logs_key_arn, ""))
  has_kms_logs_key  = local.kms_logs_key_trim != ""

  lg_app       = "/aws/eks/${var.cluster_name}/application"
  lg_dataplane = "/aws/eks/${var.cluster_name}/dataplane"
  lg_host      = "/aws/eks/${var.cluster_name}/host"

  account_number = data.aws_caller_identity.current.account_id

}

#############################################
# CloudWatch Log Groups (encrypted, retention)
#############################################
resource "aws_cloudwatch_log_group" "app" {
  count             = var.install_fluent_bit ? 1 : 0
  name              = local.lg_app
  kms_key_id        = local.has_kms_logs_key ? local.kms_logs_key_trim : null
  retention_in_days = var.cw_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "dataplane" {
  count             = var.install_fluent_bit ? 1 : 0
  name              = local.lg_dataplane
  kms_key_id        = local.has_kms_logs_key ? local.kms_logs_key_trim : null
  retention_in_days = var.cw_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "host" {
  count             = var.install_fluent_bit ? 1 : 0
  name              = local.lg_host
  kms_key_id        = local.has_kms_logs_key ? local.kms_logs_key_trim : null
  retention_in_days = var.cw_retention_days
  tags              = var.tags
}

#############################################
# IRSA: CloudWatch Agent (metrics)
#############################################
data "aws_iam_policy_document" "cwagent_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${local.ns}:cloudwatch-agent"]
    }
  }
}

resource "aws_iam_role" "cwagent" {
  count              = var.install_cloudwatch_agent ? 1 : 0
  name               = "${var.name}-cwagent"
  assume_role_policy = data.aws_iam_policy_document.cwagent_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cwagent_attach" {
  count      = var.install_cloudwatch_agent ? 1 : 0
  role       = aws_iam_role.cwagent[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

#############################################
# IRSA: Fluent Bit (logs → CloudWatch Logs)
#############################################
data "aws_iam_policy_document" "fluentbit_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_hostpath}:sub"
      values   = ["system:serviceaccount:${local.ns}:fluent-bit"]
    }
  }
}

data "aws_iam_policy_document" "fluentbit" {
  statement {
    sid    = "CWLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${local.account_number}:log-group:${local.lg_app}:*",
      "arn:aws:logs:${var.region}:${local.account_number}:log-group:${local.lg_dataplane}:*",
      "arn:aws:logs:${var.region}:${local.account_number}:log-group:${local.lg_host}:*",
      "arn:aws:logs:${var.region}:${local.account_number}:log-group:/aws/eks/*:*"
    ]
  }

  dynamic "statement" {
    for_each = local.has_kms_logs_key ? [1] : []
    content {
      sid    = "AllowCWLogsKmsUsage"
      effect = "Allow"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ]
      resources = [local.kms_logs_key_trim]
      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["logs.${var.region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_role" "fluentbit" {
  count              = var.install_fluent_bit ? 1 : 0
  name               = "${var.name}-fluentbit"
  assume_role_policy = data.aws_iam_policy_document.fluentbit_trust.json
  tags               = var.tags
}

resource "aws_iam_policy" "fluentbit" {
  count  = var.install_fluent_bit ? 1 : 0
  name   = "${var.name}-fluentbit-cwlogs"
  policy = data.aws_iam_policy_document.fluentbit.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "fluentbit_attach" {
  count      = var.install_fluent_bit ? 1 : 0
  role       = aws_iam_role.fluentbit[0].name
  policy_arn = aws_iam_policy.fluentbit[0].arn
}

#############################################
# Namespace + ServiceAccounts
#############################################
resource "kubernetes_namespace" "ns" {
  metadata { name = local.ns }
}

resource "kubernetes_service_account" "cwagent" {
  count = var.install_cloudwatch_agent ? 1 : 0
  metadata {
    name      = "cloudwatch-agent"
    namespace = local.ns
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cwagent[0].arn
    }
  }
  automount_service_account_token = true

  depends_on = [kubernetes_namespace.ns]
}

resource "kubernetes_service_account" "fluentbit" {
  count = var.install_fluent_bit ? 1 : 0
  metadata {
    name      = "fluent-bit"
    namespace = local.ns
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluentbit[0].arn
    }
  }
  automount_service_account_token = true

  depends_on = [kubernetes_namespace.ns]
}

#############################################
# Helm: CloudWatch Agent (Container Insights)
#############################################
# EKS managed add-on for CloudWatch Observability
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = var.cluster_name # pass this into the module
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  # addon_version               = var.cloudwatch_addon_version  # optional: pin if you want
  tags = var.tags
}

#############################################
# Helm: aws-for-fluent-bit (logs → CloudWatch Logs)
#############################################
resource "helm_release" "fluentbit" {
  count      = var.install_fluent_bit ? 1 : 0
  name       = "aws-for-fluent-bit"
  namespace  = local.ns
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = "0.1.32"

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }


  # Primary app logs
  set {
    name  = "cloudWatch.enabled"
    value = "true"
  }
  set {
    name  = "cloudWatch.region"
    value = var.region
  }
  set {
    name  = "cloudWatch.logGroupName"
    value = local.lg_app
  }
  set {
    name  = "cloudWatch.logStreamPrefix"
    value = "app"
  }
  set {
    name  = "cloudWatchLogs.enabled"
    value = "false"
  }

  # Ensure AWS SDK inside Fluent Bit always uses the IRSA role/token
  set {
    name  = "extraEnvs[0].name"
    value = "AWS_ROLE_ARN"
  }
  set {
    name  = "extraEnvs[0].value"
    value = aws_iam_role.fluentbit[0].arn
  }
  set {
    name  = "extraEnvs[1].name"
    value = "AWS_WEB_IDENTITY_TOKEN_FILE"
  }
  set {
    name  = "extraEnvs[1].value"
    value = "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
  }
  set {
    name  = "extraEnvs[2].name"
    value = "AWS_REGION"
  }
  set {
    name  = "extraEnvs[2].value"
    value = var.region
  }
  set {
    name  = "extraEnvs[3].name"
    value = "AWS_DEFAULT_REGION"
  }
  set {
    name  = "extraEnvs[3].value"
    value = var.region
  }

  depends_on = [
    kubernetes_service_account.fluentbit,
    aws_cloudwatch_log_group.app,
    aws_cloudwatch_log_group.dataplane,
    aws_cloudwatch_log_group.host
  ]
}

#############################################
# Robust ALB/TG discovery via Tagging API
#############################################
# We only discover if alarms are requested and no explicit suffixes were provided
locals {
  _need_discovery = var.create_alb_alarms && length(var.alb_arn_suffixes) == 0 && length(var.target_group_arn_suffixes) == 0
  _svc_tag_value  = "${var.service_namespace}/${var.service_name}"
}

# Return 0..N matches safely (no hard failures on 0)
data "aws_resourcegroupstaggingapi_resources" "alb" {
  count = local._need_discovery ? 1 : 0

  resource_type_filters = ["elasticloadbalancing:loadbalancer"]

  tag_filter {
    key    = "kubernetes.io/ingress-name"
    values = [var.ingress_name]
  }
  tag_filter {
    key    = "kubernetes.io/ingress-namespace"
    values = [var.ingress_namespace]
  }
}

data "aws_resourcegroupstaggingapi_resources" "tg" {
  count = local._need_discovery ? 1 : 0

  resource_type_filters = ["elasticloadbalancing:targetgroup"]

  tag_filter {
    key    = "kubernetes.io/service-name"
    values = [local._svc_tag_value]
  }
}

# Extract first match (if any) and build arn_suffix lists
locals {
  _alb_arn = local._need_discovery && length(try(data.aws_resourcegroupstaggingapi_resources.alb[0].resource_tag_mapping_list, [])) > 0 ? data.aws_resourcegroupstaggingapi_resources.alb[0].resource_tag_mapping_list[0].resource_arn : null

  _tg_arn = local._need_discovery && length(try(data.aws_resourcegroupstaggingapi_resources.tg[0].resource_tag_mapping_list, [])) > 0 ? data.aws_resourcegroupstaggingapi_resources.tg[0].resource_tag_mapping_list[0].resource_arn : null

  _alb_suffix_discovered = local._alb_arn != null ? regexreplace(local._alb_arn, "^arn:aws:elasticloadbalancing:[^:]+:[^:]+:loadbalancer/", "") : null

  _tg_suffix_discovered = local._tg_arn != null ? regexreplace(local._tg_arn, "^arn:aws:elasticloadbalancing:[^:]+:[^:]+:targetgroup/", "") : null

  # Final lists fed to alarms: explicit > discovered > empty
  _alb_suffixes = length(var.alb_arn_suffixes) > 0 ? var.alb_arn_suffixes : (local._alb_suffix_discovered != null ? [local._alb_suffix_discovered] : [])

  _tg_suffixes = length(var.target_group_arn_suffixes) > 0 ? var.target_group_arn_suffixes : (local._tg_suffix_discovered != null ? [local._tg_suffix_discovered] : [])

  _tg_alarm_count = length(var.target_group_arn_suffixes) > 0 ? length(var.target_group_arn_suffixes) : (local._tg_suffix_discovered != null ? 1 : 0)
}

#############################################
# Optional: ALB alarms (REGIONAL)
#############################################
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  count               = var.create_alb_alarms ? local._tg_alarm_count : 0
  alarm_name          = "${var.name}-alb5xx-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 5
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = local._tg_suffixes[count.index]
    LoadBalancer = element(local._alb_suffixes, min(count.index, length(local._alb_suffixes) - 1))
  }

  alarm_description = "ALB target 5XX spikes for ${var.name}"
  alarm_actions     = var.alarm_email_sns_topic_arn != "" ? [var.alarm_email_sns_topic_arn] : []
  ok_actions        = var.alarm_email_sns_topic_arn != "" ? [var.alarm_email_sns_topic_arn] : []

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_p95" {
  count               = var.create_alb_alarms ? local._tg_alarm_count : 0
  alarm_name          = "${var.name}-alb-p95-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  threshold           = 800
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p95"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = local._tg_suffixes[count.index]
    LoadBalancer = element(local._alb_suffixes, min(count.index, length(local._alb_suffixes) - 1))
  }

  alarm_description = "ALB p95 latency elevated for ${var.name}"
  alarm_actions     = var.alarm_email_sns_topic_arn != "" ? [var.alarm_email_sns_topic_arn] : []
  ok_actions        = var.alarm_email_sns_topic_arn != "" ? [var.alarm_email_sns_topic_arn] : []

  tags = var.tags
}
