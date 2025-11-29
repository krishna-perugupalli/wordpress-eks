# Prometheus Deployment Guide

This guide shows you how to enable the Prometheus monitoring stack in your existing WordPress EKS infrastructure using Terraform Cloud.

## Overview

Your WordPress EKS platform already has the enhanced observability module integrated in `stacks/app/main.tf`. You just need to enable the Prometheus stack by setting the right variables in Terraform Cloud.

## Prerequisites

- Infrastructure stack (`wp-infra`) already deployed
- Application stack (`wp-app`) configured in Terraform Cloud
- EKS cluster running and accessible
- Terraform Cloud workspace access

## Step-by-Step Deployment

### Step 1: Configure Terraform Cloud Variables

1. **Log into Terraform Cloud**
   - Navigate to your `wp-app` workspace
   - Go to **Variables** tab

2. **Set Core Prometheus Variables**

   Add these **Terraform variables** (not environment variables):

   ```hcl
   # Enable Prometheus Stack
   enable_prometheus_stack = true
   
   # Basic Configuration
   prometheus_storage_size = "100Gi"
   prometheus_retention_days = 90
   prometheus_replica_count = 2
   
   # Service Discovery
   enable_service_discovery = true
   ```

3. **Optional: Enable Additional Components**

   ```hcl
   # Enable Grafana (when Task 6 is completed)
   enable_grafana = false
   
   # Enable AlertManager (when Task 8 is completed)  
   enable_alertmanager = false
   
   # Enable Exporters (when Tasks 4-5 are completed)
   enable_wordpress_exporter = false
   enable_mysql_exporter = false
   enable_redis_exporter = false
   ```

### Step 2: Review Configuration

1. **Check Current Variables**
   
   Your `stacks/app/variables.tf` already defines all Prometheus variables with sensible defaults:

   ```hcl
   variable "enable_prometheus_stack" {
     description = "Enable Prometheus monitoring stack"
     type        = bool
     default     = false  # You'll override this to true
   }
   
   variable "prometheus_storage_size" {
     description = "Persistent storage size for Prometheus"
     type        = string
     default     = "50Gi"  # You can override to "100Gi"
   }
   ```

2. **Verify Integration**
   
   Your `stacks/app/main.tf` already includes:

   ```hcl
   module "observability" {
     source = "../../modules/observability"
     
     # ... existing configuration ...
     
     # Prometheus configuration (controlled by variables)
     enable_prometheus_stack      = var.enable_prometheus_stack
     prometheus_storage_size      = var.prometheus_storage_size
     prometheus_retention_days    = var.prometheus_retention_days
     # ... more Prometheus config ...
   }
   ```

### Step 3: Plan and Deploy

1. **Queue a Plan**
   - In Terraform Cloud, go to your `wp-app` workspace
   - Click **"Queue plan"**
   - Review the plan output

2. **Expected Resources**
   
   You should see these new resources being created:

   ```
   # module.observability.module.prometheus[0].aws_iam_role.prometheus
   # module.observability.module.prometheus[0].aws_iam_role_policy.prometheus
   # module.observability.module.prometheus[0].helm_release.kube_prometheus_stack
   # module.observability.kubernetes_namespace.ns (if not exists)
   ```

3. **Apply the Changes**
   - If the plan looks good, click **"Confirm & Apply"**
   - Wait for deployment to complete (typically 5-10 minutes)

### Step 4: Verify Deployment

1. **Update Local kubeconfig**
   
   ```bash
   # From your local machine
   cd stacks/infra
   make kubeconfig
   ```

2. **Check Prometheus Pods**
   
   ```bash
   # Verify namespace exists
   kubectl get namespace observability
   
   # Check Prometheus pods
   kubectl get pods -n observability -l app.kubernetes.io/name=prometheus
   
   # Expected output:
   # NAME                                                 READY   STATUS    RESTARTS   AGE
   # prometheus-kube-prometheus-prometheus-0              2/2     Running   0          5m
   # prometheus-kube-prometheus-prometheus-1              2/2     Running   0          5m
   ```

3. **Check Prometheus Service**
   
   ```bash
   kubectl get svc -n observability prometheus-kube-prometheus-prometheus
   
   # Expected output:
   # NAME                                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
   # prometheus-kube-prometheus-prometheus   ClusterIP   172.20.123.45   <none>        9090/TCP   5m
   ```

4. **Verify Storage**
   
   ```bash
   # Check persistent volumes
   kubectl get pvc -n observability
   
   # Expected output:
   # NAME                                                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
   # prometheus-kube-prometheus-prometheus-db-prometheus-kube... Bound    pvc-12345678-1234-1234-1234-123456789012   100Gi      RWO            gp3            5m
   ```

### Step 5: Access Prometheus (Optional)

1. **Port Forward to Prometheus**
   
   ```bash
   kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
   ```

2. **Open Prometheus UI**
   
   - Navigate to http://localhost:9090
   - Check **Status > Targets** to see discovered services
   - Try a query like `up` to see all monitored services

## Configuration Options

### Production Configuration

For production environments, consider these settings:

```hcl
# Terraform Cloud Variables
enable_prometheus_stack = true
prometheus_storage_size = "200Gi"          # Larger storage
prometheus_retention_days = 90             # 3 months retention
prometheus_replica_count = 3               # More replicas for HA

# Resource limits for production
prometheus_resource_requests = {
  cpu    = "1"
  memory = "4Gi"
}
prometheus_resource_limits = {
  cpu    = "4"
  memory = "16Gi"
}

# Service discovery
enable_service_discovery = true
service_discovery_namespaces = ["default", "wordpress", "kube-system", "observability"]
```

### Development Configuration

For development/testing environments:

```hcl
# Terraform Cloud Variables
enable_prometheus_stack = true
prometheus_storage_size = "20Gi"           # Smaller storage
prometheus_retention_days = 15             # Shorter retention
prometheus_replica_count = 1               # Single replica

# Smaller resource requests
prometheus_resource_requests = {
  cpu    = "200m"
  memory = "1Gi"
}
prometheus_resource_limits = {
  cpu    = "1"
  memory = "4Gi"
}
```

## Monitoring and Troubleshooting

### Check Deployment Status

```bash
# Check all observability pods
kubectl get pods -n observability

# Check Prometheus operator logs
kubectl logs -n observability -l app.kubernetes.io/name=prometheus-operator

# Check Prometheus server logs
kubectl logs -n observability prometheus-kube-prometheus-prometheus-0 -c prometheus
```

### Common Issues

1. **Pods Stuck in Pending**
   - Check if storage class exists: `kubectl get storageclass`
   - Verify node capacity: `kubectl describe nodes`

2. **IRSA Permission Issues**
   - Check IAM role: Look for `{cluster-name}-prometheus-server` role in AWS Console
   - Verify OIDC provider: Check EKS cluster OIDC issuer URL

3. **Service Discovery Not Working**
   - Check ServiceMonitor CRDs: `kubectl get servicemonitor -A`
   - Verify namespace labels: `kubectl get ns --show-labels`

## What's Next

After Prometheus is deployed, you can:

1. **Enable Grafana** (when Task 6 is completed)
   - Set `enable_grafana = true` in Terraform Cloud
   - Access dashboards for WordPress, Kubernetes, and AWS services

2. **Enable AlertManager** (when Task 8 is completed)
   - Set `enable_alertmanager = true`
   - Configure SNS topics for notifications

3. **Enable Exporters** (when Tasks 4-5 are completed)
   - Set `enable_wordpress_exporter = true`
   - Set `enable_mysql_exporter = true`
   - Set `enable_redis_exporter = true`

## 🔗 Related Documentation

- [Enhanced Observability Module README](../../modules/observability.md)
- [Architecture Documentation](../../architecture.md)
- [Getting Started Guide](../../getting-started.md)

## Support

If you encounter issues:

1. Check the [troubleshooting section](#monitoring-and-troubleshooting) above
2. Review Terraform Cloud run logs
3. Check Kubernetes pod logs in the `observability` namespace
4. Verify AWS IAM roles and policies are created correctly