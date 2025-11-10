# Karpenter Integration Guide

This document explains how Karpenter is deployed and configured in the **WordPress on EKS** stack. It covers the infrastructure pieces in `stacks/infra`, the application-layer manifests in `stacks/app`, and the Terraform variables you can tune to change provisioning behaviour.

---

## High-Level Overview

Karpenter provides dynamic node provisioning for the cluster. The design in this repository follows AWS' reference pattern:

1. **Infrastructure stack (`stacks/infra`)**
   - Creates the Karpenter namespace (so Helm can target it later).
   - Uses `terraform-aws-modules/eks//modules/karpenter` to configure:
     - Controller IAM role (IRSA) with the EKS OIDC provider.
     - Node IAM role (with optional KMS decrypt permissions for Secrets/EBS).
     - A dedicated SQS interruption queue.
   - Tags subnets and security groups with `karpenter.sh/discovery=<cluster-name>` so NodeClasses can auto-discover them.
   - Exposes outputs back to Terraform Cloud (`karpenter_role_arn`, `karpenter_node_iam_role_name`, `karpenter_sqs_queue_name`) for the application stack.

2. **Application stack (`stacks/app`)**
   - Installs the Karpenter CRDs and controller via Helm (OCI charts).
   - Annotates the controller service account with the IAM role created in infra.
   - Applies the `NodePool` and `EC2NodeClass` CRDs (via `kubectl_manifest`) describing how nodes should be provisioned (instance families, taints, labels, AZs, volume settings, etc.).

3. **Workloads**
   - WordPress and other workloads simply request resources; when the default node group is full, Karpenter spins up new instances matching the `NodePool` constraints.

---

## Infra Stack Details (`stacks/infra/karpenter.tf`)

| Resource | Purpose |
|----------|---------|
| `kubernetes_namespace.karpenter` | Ensures namespace `karpenter` exists before Helm runs in the app stack. |
| `aws_iam_policy.karpenter_node_role_kms_policy` | Optional decrypt policy so nodes can access Secrets Manager–encrypted data, attached to the node IAM role. |
| `module "karpenter"` | Wraps `terraform-aws-modules/eks/aws//modules/karpenter`; creates controller/node roles, instance profile, hooks IRSA to the cluster OIDC provider, and publishes outputs consumed by the app stack. |

Key outputs from this module:

| Output | Description | Consumed by |
|--------|-------------|-------------|
| `karpenter_role_arn` | IAM role ARN for `karpenter` controller service account. | `stacks/app` Helm release annotations |
| `karpenter_node_iam_role_name` | EC2 role name assigned to provisioned nodes. | `EC2NodeClass` spec |
| `karpenter_sqs_queue_name` | Interruption queue consumed by the controller. | Helm release values |

---

## App Stack Details (`stacks/app/karpenter-manifests.tf`)

### Helm Releases
- `helm_release.karpenter_crds`: Installs CRDs from `oci://public.ecr.aws/karpenter/karpenter-crd`.
- `helm_release.karpenter`: Installs controller from the OCI chart; configures:
  - `settings.clusterName` / `clusterEndpoint`.
  - Service account annotation `eks.amazonaws.com/role-arn` → `local.karpenter_controller_iam_role_arn`.
  - `settings.interruptionQueueName`.

### Custom Resources
- **NodePool (`karpenter.sh/v1`)**
  - Labels new nodes (`intent=apps`, `nodegroup=amd64` by default).
  - References the EC2NodeClass and optional taints.
  - Requirements enforce arch, OS, capacity type, instance types, CPU counts, and AZs.
  - Disruption settings align with variables `karpenter_consolidation_policy`, `karpenter_expire_after`, etc.

- **EC2NodeClass (`karpenter.k8s.aws/v1`)**
  - Defines block device mappings (volume size/type from variables).
  - Sets `amiFamily` (`AL2023` by default) and uses the managed AL2023 alias.
  - Uses the node IAM role name exported by infra.
  - Selects subnets/security groups by the `karpenter.sh/discovery` tag.

All CRDs are applied via `kubectl_manifest` resources so Terraform can manage their lifecycle.

---

## Tunable Variables (`stacks/app/variables.tf`)

| Variable | Description | Default |
|----------|-------------|---------|
| `karpenter_instance_types` | Allowed EC2 instance types. | `["t3a.medium", "t3a.large", ...]` |
| `karpenter_instance_families` | Optional filter for instance families. | `["t3a", "m6a", "c6a"]` |
| `karpenter_cpu_allowed` | CPU counts permitted in NodePool `requirements`. | `["2","4","8","16"]` |
| `karpenter_arch_types` | Architectures (e.g., `amd64`). | `["amd64"]` |
| `karpenter_os_types` | Allowed OS types. | `["linux"]` |
| `karpenter_capacity_types` | `spot`, `on-demand`, or both. | `["spot","on-demand"]` |
| `karpenter_ami_family` | AMI family (AL2023, Bottlerocket…). | `"AL2023"` |
| `karpenter_consolidation_policy` | `WhenEmpty` or `WhenEmptyOrUnderutilized`. | `"WhenEmptyOrUnderutilized"` |
| `karpenter_expire_after` | Maximum node lifetime (e.g., `720h`). | `"720h"` |
| `karpenter_cpu_limit` | Total CPU limit for provisioned nodes. | `"64"` |
| `karpenter_volume_size` | Root volume size for nodes. | `"50Gi"` |
| `karpenter_volume_type` | EBS volume type. | `"gp2"` |
| `karpenter_taints` | Optional taints applied to new nodes. | `[]` |

Adjust these via Terraform Cloud workspace variables or tfvars to shape Karpenter’s provisioning strategy.

---

## Operational Notes

- **Controller upgrades**: Bump the Helm chart version in `helm_release.karpenter` (currently `1.5.0`). Upgrade CRDs first (`karpenter_crds`), then the controller.
- **IRSA dependencies**: The controller Helm release depends on the IAM role from infra; ensure `stacks/infra` is applied before `stacks/app`.
- **Subnet/Security group discovery**: Tags must stay intact (`karpenter.sh/discovery=<cluster-name>`) or NodeClasses will fail to resolve resources.
- **Drift management**: Because CRDs are applied via `kubectl_manifest`, Terraform will plan to replace them when spec fields change—plan/apply carefully to avoid unintended node churn.

---

## Future Enhancements

- Additional NodePools (e.g., GPU, ARM64) based on workload classes.
- Integration with application-specific Provisioners (if adopting Karpenter v1.6+).
- AutoNodeClaim policies once available.

Feel free to extend this document with lessons learned, troubleshooting tips, or changes to the deployment flow.
