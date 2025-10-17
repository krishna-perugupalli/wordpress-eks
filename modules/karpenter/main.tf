#############################################
# Locals
#############################################
locals {
  oidc_hostpath         = replace(var.cluster_oidc_issuer_url, "https://", "")
  sa_name               = "karpenter"
  ns                    = var.karpenter_namespace
  interruption_queue    = var.enable_interruption_queue ? (var.interruption_queue_name != "" ? var.interruption_queue_name : "${var.name}-karpenter-interruptions") : null
  node_role_name        = "${var.name}-karpenter-node"
  instance_profile_name = "${var.name}-karpenter-node"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#############################################
# Karpenter Controller IRSA (IAM Role + Policy)
#############################################
data "aws_iam_policy_document" "controller_trust" {
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
      values   = ["system:serviceaccount:${local.ns}:${local.sa_name}"]
    }
  }
}

data "aws_iam_policy_document" "controller_policy" {
  statement {
    sid    = "EC2CRUD"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:CreateTags",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
      "ec2:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EKSDescribeCluster"
    effect  = "Allow"
    actions = ["eks:DescribeCluster"]
    resources = [
      "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
    ]
  }

  statement {
    sid    = "SSMParameterAndPricing"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "pricing:GetProducts",
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassNodeRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "ec2.amazonaws.com.cn"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_interruption_queue ? [1] : []
    content {
      sid    = "SQSInterruption"
      effect = "Allow"
      actions = [
        "sqs:GetQueueUrl",
        "sqs:DeleteMessage",
        "sqs:ReceiveMessage",
        "sqs:GetQueueAttributes",
        "sqs:ChangeMessageVisibility"
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_role" "controller" {
  name               = "${var.name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.controller_trust.json
  tags               = var.tags
}

resource "aws_iam_policy" "controller" {
  name        = "${var.name}-karpenter-controller"
  description = "Permissions for Karpenter controller"
  policy      = data.aws_iam_policy_document.controller_policy.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "controller_attach" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

#############################################
# Interruption Queue (optional) + EventBridge
#############################################
resource "aws_sqs_queue" "interruptions" {
  count = var.enable_interruption_queue ? 1 : 0
  name  = local.interruption_queue
  tags  = var.tags
}

resource "aws_cloudwatch_event_rule" "interruptions" {
  count       = var.enable_interruption_queue ? 1 : 0
  name        = "${var.name}-karpenter-interruptions"
  description = "Forward EC2 interruption/rebalance events to SQS for Karpenter"
  event_pattern = jsonencode({
    "source" : ["aws.ec2"],
    "detail-type" : [
      "EC2 Spot Instance Interruption Warning",
      "EC2 Instance Rebalance Recommendation",
      "EC2 Instance State-change Notification"
    ]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "interruptions" {
  count     = var.enable_interruption_queue ? 1 : 0
  rule      = aws_cloudwatch_event_rule.interruptions[0].name
  target_id = "karpenter-interruptions"
  arn       = aws_sqs_queue.interruptions[0].arn
}

resource "aws_sqs_queue_policy" "interruptions" {
  count     = var.enable_interruption_queue ? 1 : 0
  queue_url = aws_sqs_queue.interruptions[0].url
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowEventBridge",
      Effect    = "Allow",
      Principal = { Service = "events.amazonaws.com" },
      Action    = "sqs:SendMessage",
      Resource  = aws_sqs_queue.interruptions[0].arn,
      Condition = { ArnEquals = { "aws:SourceArn" : aws_cloudwatch_event_rule.interruptions[0].arn } }
    }]
  })
}

#############################################
# Karpenter Node IAM Role + Instance Profile
#############################################
resource "aws_iam_role" "node" {
  name = local.node_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_base" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "node_extra" {
  for_each   = toset(var.node_role_additional_policy_arns)
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "node" {
  name = local.instance_profile_name
  role = aws_iam_role.node.name
  tags = var.tags
}

#############################################
# Kubernetes namespace + ServiceAccount (IRSA)
#############################################
resource "kubernetes_namespace" "karpenter" {
  metadata {
    name = local.ns
  }
}

resource "kubernetes_service_account" "controller" {
  metadata {
    name      = local.sa_name
    namespace = local.ns
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.controller.arn
    }
    labels = {
      "app.kubernetes.io/name" = "karpenter"
    }
  }
  automount_service_account_token = true

  depends_on = [
    kubernetes_namespace.karpenter
  ]
}

#############################################
# Helm charts: CRDs first, then controller (OCI)
#############################################
resource "helm_release" "karpenter_crds" {
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = var.controller_chart_version
  namespace  = local.ns
  wait       = true
  timeout    = 600

  depends_on = [
    kubernetes_namespace.karpenter
  ]
}

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = local.ns
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.controller_chart_version
  wait       = true
  timeout    = 600

  # Use our pre-created IRSA SA
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = local.sa_name
  }

  # Cluster wiring
  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  # Instance profile for provisioned nodes
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.node.name
  }

  # Leave clusterEndpoint empty; controller discovers it automatically
  set {
    name  = "settings.aws.clusterEndpoint"
    value = ""
  }

  # Optional: interruption queue
  dynamic "set" {
    for_each = var.enable_interruption_queue ? [1] : []
    content {
      name  = "settings.interruptionQueue"
      value = aws_sqs_queue.interruptions[0].name
    }
  }

  # Useful feature flag
  set {
    name  = "settings.featureGates.drift"
    value = "true"
  }

  depends_on = [
    kubernetes_service_account.controller,
    helm_release.karpenter_crds,
    aws_sqs_queue.interruptions
  ]
}

#############################################
# Karpenter CRDs: EC2NodeClass + NodePool (cluster-scoped)
#############################################
resource "kubectl_manifest" "ec2_nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "web-linux"
    }
    spec = {
      amiFamily = var.ami_family
      role      = aws_iam_role.node.name

      subnetSelectorTerms = [
        { tags = var.subnet_selector_tags }
      ]

      securityGroupSelectorTerms = [
        { tags = var.security_group_selector_tags }
      ]

      tags = var.tags
    }
  })

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "nodepool" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "web-pooled"
    }
    spec = {
      template = {
        metadata = { labels = var.labels }
        spec = {
          nodeClassRef = { name = "web-linux" }
          taints = [
            for t in var.taints : {
              key    = t.key
              value  = t.value
              effect = t.effect
            }
          ]
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = var.capacity_types
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.instance_types
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64", "arm64"]
            }
          ]
        }
      }
      disruption = {
        consolidationPolicy = var.consolidation_policy
        expireAfter         = var.expire_after
      }
      limits = {
        cpu = var.cpu_limit
      }
    }
  })

  depends_on = [
    kubectl_manifest.ec2_nodeclass
  ]
}
