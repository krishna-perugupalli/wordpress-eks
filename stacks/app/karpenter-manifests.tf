#############################################
# Helm charts: CRDs first, then controller (OCI)
#############################################
resource "helm_release" "karpenter_crds" {
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = "0.37.8"
  namespace  = "karpenter"
  wait       = true
  timeout    = 600
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "0.37.8"

  set {
    name  = "settings.clusterName"
    value = local.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = local.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = local.karpenter_controller_iam_role_arn
  }

  set {
    name  = "settings.interruptionQueueName"
    value = local.karpenter_sqs_queue_name
  }
  depends_on = [
    helm_release.karpenter_crds
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_amd64" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "amd64"
      annotations = {
        "kubernetes.io/description" = "Compute optimized NodePool for compute intensive workloads"
      }
    }
    spec = {
      template = {
        spec = {
          labels = {
            intent    = "apps"
            nodegroup = "amd64"
          }
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          taints = [
            for t in var.karpenter_taints : {
              key    = t.key
              value  = t.value
              effect = t.effect
            }
          ]
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = var.karpenter_arch_types
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = var.karpenter_os_types
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = var.karpenter_capacity_types
            },
            {
              key      = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values   = var.karpenter_instance_families
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "In"
              values   = var.karpenter_instance_types
            },
            {
              key      = "karpenter.k8s.aws/instance-cpu"
              operator = "In"
              values   = var.karpenter_cpu_allowed
            },
            {
              key      = "topology.kubernetes.io/zone"
              operator = "In"
              values   = local.azs
            }
          ]
        }
      }
      disruption = {
        consolidationPolicy = var.karpenter_consolidation_policy
        consolidateAfter    = "60s"  # scale down nodes after 60 seconds without workloads (excluding daemons)
        expireAfter         = "168h" # expire nodes after 7 days = 7 * 24h
      }
    }
    depends_on = [kubectl_manifest.karpenter_nodeclass]
  })
}

resource "kubectl_manifest" "karpenter_nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
      annotations = {
        "kubernetes.io/description" = "Graviton Compute optimized EC2NodeClass"
      }
    }
    spec = {
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            deleteOnTermination = true
            volumeSize          = var.karpenter_volume_size
            volumeType          = var.karpenter_volume_type
          }
        }
      ]

      amiFamily = var.karpenter_ami_family
      amiSelectorTerms = [
        {
          ssmParameter = "/aws/service/eks/optimized-ami/${var.cluster_version}/amazon-linux-2023/${var.arch}/standard/recommended/image_id"
        }
      ]
      role = local.karpenter_node_iam_role_name

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cluster_name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = local.cluster_name
          }
        }
      ]
    }
    depends_on = [helm_release.karpenter]
  })
}
