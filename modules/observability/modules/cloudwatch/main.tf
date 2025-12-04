#############################################
# CloudWatch Monitoring Sub-module
# Legacy CloudWatch Agent and Fluent Bit support
#############################################

data "aws_caller_identity" "current" {}

#############################################
# Locals
#############################################
locals {
  oidc_hostpath     = replace(var.cluster_oidc_issuer_url, "https://", "")
  kms_logs_key_trim = var.kms_logs_key_arn != null ? trimspace(var.kms_logs_key_arn) : ""
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
# Fluent Bit ConfigMap
#############################################
resource "kubernetes_config_map" "fluentbit_config" {
  count = var.install_fluent_bit ? 1 : 0
  metadata {
    name      = "fluent-bit-config"
    namespace = var.namespace
  }

  data = {
    "fluent-bit.conf" = <<-EOT
      [SERVICE]
          Flush         5
          Daemon        off
          Log_Level     info
          Parsers_File  parsers.conf

      [INPUT]
          Name              tail
          Tag               kube.*
          Path              /var/log/containers/*.log
          Parser            docker
          DB                /var/log/flb_kube.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               dataplane.kube-proxy
          Path              /var/log/containers/kube-proxy*.log
          Parser            docker
          DB                /var/log/flb_dataplane_kube-proxy.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               dataplane.aws-node
          Path              /var/log/containers/aws-node*.log
          Parser            docker
          DB                /var/log/flb_dataplane_aws-node.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               dataplane.coredns
          Path              /var/log/containers/coredns*.log
          Parser            docker
          DB                /var/log/flb_dataplane_coredns.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               host.messages
          Path              /var/log/messages
          Parser            syslog
          DB                /var/log/flb_host_messages.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               host.secure
          Path              /var/log/secure
          Parser            syslog
          DB                /var/log/flb_host_secure.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [INPUT]
          Name              tail
          Tag               host.dmesg
          Path              /var/log/dmesg
          Parser            syslog
          DB                /var/log/flb_host_dmesg.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [FILTER]
          Name                kubernetes
          Match               kube.*
          Kube_URL            https://kubernetes.default.svc:443
          Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
          Kube_Tag_Prefix     kube.var.log.containers.
          Merge_Log           On
          Keep_Log            Off
          K8S-Logging.Parser  On
          K8S-Logging.Exclude On

      [OUTPUT]
          Name                  cloudwatch
          Match                 kube.*
          region                ${var.region}
          log_group_name        ${local.lg_app}
          log_stream_prefix     app
          auto_create_group     true

      [OUTPUT]
          Name                  cloudwatch
          Match                 dataplane.*
          region                ${var.region}
          log_group_name        ${local.lg_dataplane}
          log_stream_prefix     dataplane
          auto_create_group     true

      [OUTPUT]
          Name                  cloudwatch
          Match                 host.*
          region                ${var.region}
          log_group_name        ${local.lg_host}
          log_stream_prefix     host
          auto_create_group     true
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name        docker
          Format      json
          Time_Key    time
          Time_Format %Y-%m-%dT%H:%M:%S.%LZ
          Time_Keep   On

      [PARSER]
          Name        syslog
          Format      regex
          Regex       ^(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
          Time_Key    time
          Time_Format %b %d %H:%M:%S

      [PARSER]
          Name        json
          Format      json
          Time_Key    time
          Time_Format %Y-%m-%dT%H:%M:%S.%LZ
          Time_Keep   On
    EOT
  }
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
      values   = ["system:serviceaccount:${var.namespace}:cloudwatch-agent"]
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
      values   = ["system:serviceaccount:${var.namespace}:fluent-bit"]
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
# ServiceAccounts
#############################################
resource "kubernetes_service_account" "cwagent" {
  count = var.install_cloudwatch_agent ? 1 : 0
  metadata {
    name      = "cloudwatch-agent"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cwagent[0].arn
    }
  }
  automount_service_account_token = true
}

resource "kubernetes_service_account" "fluentbit" {
  count = var.install_fluent_bit ? 1 : 0
  metadata {
    name      = "fluent-bit"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluentbit[0].arn
    }
  }
  automount_service_account_token = true
}

#############################################
# EKS managed add-on for CloudWatch Observability
#############################################
resource "aws_eks_addon" "cloudwatch_observability" {
  count                       = var.install_cloudwatch_agent ? 1 : 0
  cluster_name                = var.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

#############################################
# Helm: aws-for-fluent-bit (logs → CloudWatch Logs)
#############################################
resource "helm_release" "fluentbit" {
  count      = var.install_fluent_bit ? 1 : 0
  name       = "aws-for-fluent-bit"
  namespace  = var.namespace
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

  # Disable default CloudWatch configuration (we use custom ConfigMap)
  set {
    name  = "cloudWatch.enabled"
    value = "false"
  }
  set {
    name  = "cloudWatchLogs.enabled"
    value = "false"
  }

  # Use custom ConfigMap for configuration
  set {
    name  = "existingConfigMap"
    value = kubernetes_config_map.fluentbit_config[0].metadata[0].name
  }

  # Configure volume mounts for custom config
  values = [yamlencode({
    config = {
      # Reference the ConfigMap files
      service       = kubernetes_config_map.fluentbit_config[0].data["fluent-bit.conf"]
      customParsers = kubernetes_config_map.fluentbit_config[0].data["parsers.conf"]
    }
    # Mount the ConfigMap as a volume
    volumes = [
      {
        name = "config"
        configMap = {
          name = kubernetes_config_map.fluentbit_config[0].metadata[0].name
        }
      }
    ]
    volumeMounts = [
      {
        name      = "config"
        mountPath = "/fluent-bit/etc/fluent-bit.conf"
        subPath   = "fluent-bit.conf"
        readOnly  = true
      },
      {
        name      = "config"
        mountPath = "/fluent-bit/etc/parsers.conf"
        subPath   = "parsers.conf"
        readOnly  = true
      }
    ]
  })]

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
    kubernetes_config_map.fluentbit_config,
    aws_cloudwatch_log_group.app,
    aws_cloudwatch_log_group.dataplane,
    aws_cloudwatch_log_group.host
  ]
}