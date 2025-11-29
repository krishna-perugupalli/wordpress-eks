# WordPress Module

## Overview

The `app-wordpress` module deploys a production-ready WordPress application on EKS using the Bitnami WordPress Helm chart. It integrates with external data services (Aurora MySQL, ElastiCache Redis, EFS), manages secrets via External Secrets Operator, and registers pods with an ALB target group using TargetGroupBinding.

## Key Resources

- **Kubernetes Namespace**: Isolated namespace for WordPress resources
- **External Secrets**: ESO-managed secrets for database credentials and admin passwords
- **Helm Release**: Bitnami WordPress chart with customized configuration
- **TargetGroupBinding**: Registers WordPress pods with ALB target group for direct pod IP routing
- **Database Grant Job**: One-time Kubernetes Job to ensure database user privileges
- **Horizontal Pod Autoscaler**: Automatic scaling based on CPU/memory utilization
- **Metrics Exporter**: Optional sidecar container for Prometheus metrics

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      ALB Target Group                        │
└────────────────────────┬────────────────────────────────────┘
                         │ (TargetGroupBinding)
                         ↓
┌─────────────────────────────────────────────────────────────┐
│              WordPress Pods (HPA: 2-6 replicas)             │
│  ┌──────────────────┐  ┌──────────────────────────────────┐ │
│  │  WordPress       │  │  Metrics Exporter (optional)     │ │
│  │  Container       │  │  Sidecar                         │ │
│  │  Port: 80        │  │  Port: 9090                      │ │
│  └──────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ↓                    ↓                    ↓
    ┌────────┐          ┌─────────┐          ┌────────┐
    │ Aurora │          │  Redis  │          │  EFS   │
    │ MySQL  │          │  Cache  │          │ /wp-   │
    │        │          │         │          │ content│
    └────────┘          └─────────┘          └────────┘
```

## Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `name` | Logical app name | `"wordpress"` |
| `namespace` | Kubernetes namespace | `"wordpress"` |
| `domain_name` | Public hostname | `"example.com"` |
| `target_group_arn` | ALB target group ARN | `"arn:aws:elasticloadbalancing:..."` |
| `db_host` | Aurora writer endpoint | `"cluster.region.rds.amazonaws.com"` |
| `db_name` | Database name | `"wordpress"` |
| `db_user` | Database user | `"wpapp"` |
| `db_secret_arn` | Secrets Manager ARN for DB password | `"arn:aws:secretsmanager:..."` |

### Optional Features

#### Redis Cache Integration

Enable Redis-backed object caching with W3 Total Cache:

```hcl
enable_redis_cache       = true
redis_endpoint           = module.elasticache.primary_endpoint
redis_port               = 6379
redis_connection_scheme  = "tls"
redis_auth_secret_arn    = module.secrets.redis_auth_token_arn
```

#### CloudFront/Proxy HTTPS Detection

Configure WordPress to trust proxy headers when behind CloudFront or ALB:

```hcl
behind_cloudfront = true
```

This injects PHP configuration to detect HTTPS from `X-Forwarded-Proto` headers.

#### Metrics Exporter

Enable Prometheus metrics for WordPress monitoring:

```hcl
enable_metrics_exporter = true
```

Exposes metrics on port 9090 including:
- WordPress version
- Plugin/theme counts
- Post/page counts
- User counts

#### Horizontal Pod Autoscaling

Configure automatic scaling based on resource utilization:

```hcl
replicas_min          = 2
replicas_max          = 6
target_cpu_percent    = 80
target_memory_percent = 80
```

### Storage Configuration

WordPress uses EFS for persistent storage of wp-content (uploads, themes, plugins):

```hcl
storage_class_name = "efs-ap"  # EFS with Access Point
pvc_size          = "10Gi"     # Nominal size (EFS is elastic)
```

### Resource Requests

Configure pod resource requests and limits:

```hcl
resources_requests_cpu    = "250m"
resources_requests_memory = "512Mi"
resources_limits_cpu      = "1000m"
resources_limits_memory   = "1Gi"
```

## Database Bootstrap

The module includes an optional Kubernetes Job that ensures the WordPress database user has required privileges:

```hcl
db_grant_job_enabled = true
```

This job:
1. Connects using admin credentials (from `db_admin_secret_arn`)
2. Creates the database if it doesn't exist
3. Grants full privileges to the WordPress user
4. Runs once before WordPress deployment

## Secrets Management

All sensitive credentials are managed via External Secrets Operator:

### Database Credentials

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: wp-db
spec:
  secretStoreRef:
    name: aws-sm
    kind: ClusterSecretStore
  data:
    - secretKey: password
      remoteRef:
        key: <db_secret_arn>
        property: password
```

### Admin Bootstrap (Optional)

For initial WordPress installation:

```hcl
admin_bootstrap_enabled = true
admin_secret_arn       = "arn:aws:secretsmanager:..."
admin_user             = "wpadmin"
admin_email            = "admin@example.com"
```

## TargetGroupBinding

The module creates a TargetGroupBinding resource to register WordPress pods directly with the ALB target group:

```yaml
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: wordpress-tgb
spec:
  serviceRef:
    name: wordpress
    port: 80
  targetGroupARN: <target_group_arn>
  targetType: ip
```

This enables:
- Direct pod IP registration (no NodePort overhead)
- Faster health checks
- Better integration with ALB features

## Examples

### Basic Deployment

```hcl
module "wordpress" {
  source = "../../modules/app-wordpress"

  name              = "wordpress"
  namespace         = "wordpress"
  domain_name       = "example.com"
  target_group_arn  = module.edge_ingress.target_group_arn

  db_host       = module.aurora.writer_endpoint
  db_name       = "wordpress"
  db_user       = "wpapp"
  db_secret_arn = module.secrets.db_password_arn

  storage_class_name = "efs-ap"
}
```

### Production Deployment with Redis and Metrics

```hcl
module "wordpress" {
  source = "../../modules/app-wordpress"

  name              = "wordpress"
  namespace         = "wordpress"
  domain_name       = "example.com"
  target_group_arn  = module.edge_ingress.target_group_arn

  # Database
  db_host              = module.aurora.writer_endpoint
  db_name              = "wordpress"
  db_user              = "wpapp"
  db_secret_arn        = module.secrets.db_password_arn
  db_admin_secret_arn  = module.aurora.admin_secret_arn
  db_grant_job_enabled = true

  # Redis cache
  enable_redis_cache      = true
  redis_endpoint          = module.elasticache.primary_endpoint
  redis_auth_secret_arn   = module.secrets.redis_auth_token_arn

  # CloudFront integration
  behind_cloudfront = true

  # Metrics
  enable_metrics_exporter = true

  # Scaling
  replicas_min          = 3
  replicas_max          = 10
  target_cpu_percent    = 70
  target_memory_percent = 75

  # Storage
  storage_class_name = "efs-ap"
  pvc_size          = "20Gi"
}
```

## Troubleshooting

### WordPress Pods Not Registering with ALB

**Symptoms**: ALB health checks fail, pods show as unhealthy in target group

**Causes**:
- AWS Load Balancer Controller not running
- TargetGroupBinding CRD not installed
- Security group rules blocking ALB → pod traffic

**Solution**:
```bash
# Check controller status
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check TargetGroupBinding
kubectl get targetgroupbindings -n wordpress

# Verify security group rules allow ALB SG → pod traffic on port 80
```

### Database Connection Failures

**Symptoms**: WordPress shows "Error establishing database connection"

**Causes**:
- Incorrect database credentials
- Security group rules blocking EKS → Aurora traffic
- Database not ready

**Solution**:
```bash
# Check database secret
kubectl get secret wp-db -n wordpress -o yaml

# Test database connectivity from a pod
kubectl run -it --rm mysql-client --image=mysql:8.0 --restart=Never -- \
  mysql -h <db_host> -u <db_user> -p<password> <db_name>
```

### EFS Mount Issues

**Symptoms**: Pods stuck in ContainerCreating, events show mount failures

**Causes**:
- EFS CSI driver not installed
- Security group rules blocking EKS → EFS traffic
- StorageClass misconfigured

**Solution**:
```bash
# Check EFS CSI driver
kubectl get pods -n kube-system -l app=efs-csi-controller

# Check PVC status
kubectl get pvc -n wordpress

# Verify security group rules allow node SG → EFS on port 2049
```

### Redis Cache Not Working

**Symptoms**: WordPress performance unchanged, cache plugin shows errors

**Causes**:
- Redis endpoint unreachable
- AUTH token incorrect
- W3 Total Cache plugin not installed

**Solution**:
```bash
# Test Redis connectivity
kubectl run -it --rm redis-client --image=redis:7 --restart=Never -- \
  redis-cli -h <redis_endpoint> --tls --askpass

# Check Redis secret
kubectl get secret wp-db -n wordpress -o jsonpath='{.data.REDIS_AUTH_TOKEN}' | base64 -d
```

## Related Documentation

- **Module Guide**: [Data Services](data-services.md) - Aurora, Redis, EFS configuration
- **Feature Guide**: [Monitoring](../features/monitoring/README.md) - WordPress metrics and dashboards
- **Operations**: [Troubleshooting](../operations/troubleshooting.md) - Common WordPress issues
- **Reference**: [Variables](../reference/variables.md) - Complete variable reference
