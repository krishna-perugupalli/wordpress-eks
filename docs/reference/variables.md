# Terraform Variables Reference

This document provides a comprehensive reference for all Terraform variables used across the infrastructure and application stacks.

## Table of Contents

- [Infrastructure Stack Variables](#infrastructure-stack-variables)
  - [General Configuration](#general-configuration)
  - [Networking](#networking)
  - [EKS Configuration](#eks-configuration)
  - [Database (Aurora)](#database-aurora)
  - [Storage (EFS)](#storage-efs)
  - [Security](#security)
  - [Load Balancer & Ingress](#load-balancer--ingress)
  - [CloudFront CDN](#cloudfront-cdn)
- [Application Stack Variables](#application-stack-variables)
  - [General Configuration](#general-configuration-1)
  - [Database](#database)
  - [Edge & Ingress](#edge--ingress)
  - [Karpenter](#karpenter)
  - [Observability](#observability)
  - [WordPress](#wordpress)
  - [Redis Cache](#redis-cache)

---

## Infrastructure Stack Variables

### General Configuration

#### `region`
- **Type**: `string`
- **Default**: `"us-east-1"`
- **Description**: AWS region for resource deployment (e.g., eu-north-1, us-west-2)

#### `project`
- **Type**: `string`
- **Default**: `"wdp"`
- **Description**: Project/environment short name; used as cluster name and tag prefix (e.g., wp-sbx)

#### `env`
- **Type**: `string`
- **Default**: `"sandbox"`
- **Description**: Environment name for the project (e.g., dev, staging, prod)

#### `owner_email`
- **Type**: `string`
- **Default**: `"admin@example.com"`
- **Description**: Owner/Contact email tag for resource tracking

#### `tags`
- **Type**: `map(string)`
- **Default**: `{}`
- **Description**: Extra tags merged into all resources for custom tagging

---

### Networking

#### `vpc_cidr`
- **Type**: `string`
- **Default**: `"10.80.0.0/16"`
- **Description**: VPC CIDR block for the network

#### `private_cidrs`
- **Type**: `list(string)`
- **Default**: `["10.80.0.0/20", "10.80.16.0/20", "10.80.32.0/20"]`
- **Description**: Private subnet CIDRs across 3 availability zones

#### `public_cidrs`
- **Type**: `list(string)`
- **Default**: `["10.80.128.0/24", "10.80.129.0/24", "10.80.130.0/24"]`
- **Description**: Public subnet CIDRs across 3 availability zones

#### `nat_gateway_mode`
- **Type**: `string`
- **Default**: `"single"`
- **Valid Values**: `single`, `ha`
- **Description**: NAT gateway strategy - single NAT for cost savings or HA for high availability

#### `public_access_cidrs`
- **Type**: `list(string)`
- **Default**: `["0.0.0.0/0"]`
- **Description**: Allowed CIDR blocks for public endpoint access

---

### EKS Configuration

#### `cluster_version`
- **Type**: `string`
- **Default**: `"1.32"`
- **Description**: EKS Kubernetes version

#### `endpoint_public_access`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Expose EKS API server public endpoint

#### `enable_irsa`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable IAM Roles for Service Accounts (OIDC provider)

#### `enable_cni_prefix_delegation`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable CNI prefix delegation for higher pod density per node

#### `cni_prefix_warm_target`
- **Type**: `number`
- **Default**: `1`
- **Description**: WARM_PREFIX_TARGET for VPC CNI when prefix delegation is enabled

#### `system_node_type`
- **Type**: `string`
- **Default**: `"t3.medium"`
- **Description**: Instance type for system/managed node group

#### `system_node_min`
- **Type**: `number`
- **Default**: `2`
- **Description**: Minimum nodes for system node group

#### `system_node_max`
- **Type**: `number`
- **Default**: `3`
- **Description**: Maximum nodes for system node group

#### `node_ami_type`
- **Type**: `string`
- **Default**: `"AL2023_x86_64_STANDARD"`
- **Valid Values**: `AL2023_x86_64_STANDARD`, `BOTTLEROCKET_x86_64`
- **Description**: EKS AMI type for managed node group

#### `node_capacity_type`
- **Type**: `string`
- **Default**: `"ON_DEMAND"`
- **Valid Values**: `ON_DEMAND`, `SPOT`
- **Description**: Capacity type for system node group (keep ON_DEMAND for stability)

#### `node_disk_size_gb`
- **Type**: `number`
- **Default**: `50`
- **Description**: Root disk size in GB for system node group

#### `enable_cluster_logs`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable EKS control plane logging to CloudWatch

#### `control_plane_log_retention_days`
- **Type**: `number`
- **Default**: `30`
- **Description**: CloudWatch log retention days for control plane logs

#### `eks_admin_role_arns`
- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: IAM Role ARNs (including SSO permission-set roles) to grant EKS cluster-admin access

#### `eks_admin_user_arns`
- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: IAM User ARNs to grant EKS cluster-admin access

---

### Database (Aurora)

#### `db_name`
- **Type**: `string`
- **Default**: `"wordpress"`
- **Description**: Application database name

#### `db_admin_username`
- **Type**: `string`
- **Default**: `"wpadmin"`
- **Description**: Aurora admin username

#### `db_create_random_password`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Create random admin password (stored in Secrets Manager)

#### `db_serverless_min_acu`
- **Type**: `number`
- **Default**: `2`
- **Description**: Aurora Serverless v2 minimum ACUs (Aurora Capacity Units)

#### `db_serverless_max_acu`
- **Type**: `number`
- **Default**: `16`
- **Description**: Aurora Serverless v2 maximum ACUs

#### `db_backup_retention_days`
- **Type**: `number`
- **Default**: `7`
- **Description**: Aurora automated backup retention period in days

#### `db_backup_window`
- **Type**: `string`
- **Default**: `"02:00-03:00"`
- **Description**: Aurora preferred backup window (UTC)

#### `db_maintenance_window`
- **Type**: `string`
- **Default**: `"sun:03:00-sun:04:00"`
- **Description**: Aurora preferred maintenance window (UTC)

#### `db_deletion_protection`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable Aurora deletion protection

#### `db_skip_final_snapshot`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Skip creating final snapshot when destroying Aurora cluster

#### `db_enable_backup`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable AWS Backup for Aurora

#### `backup_vault_name`
- **Type**: `string`
- **Default**: `""`
- **Description**: AWS Backup vault name (empty string creates default vault)

#### `db_backup_cron`
- **Type**: `string`
- **Default**: `"cron(0 2 * * ? *)"`
- **Description**: AWS Backup cron schedule for Aurora

#### `db_backup_delete_after_days`
- **Type**: `number`
- **Default**: `7`
- **Description**: Days to retain Aurora backups in Backup vault

---

### Storage (EFS)

#### `efs_kms_key_arn`
- **Type**: `string`
- **Default**: `null`
- **Description**: KMS key ARN for EFS encryption; null uses AWS-managed key

#### `efs_performance_mode`
- **Type**: `string`
- **Default**: `"generalPurpose"`
- **Description**: EFS performance mode

#### `efs_throughput_mode`
- **Type**: `string`
- **Default**: `"bursting"`
- **Description**: EFS throughput mode

#### `efs_enable_lifecycle_ia`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable lifecycle policy to transition files to Infrequent Access after 30 days

#### `efs_ap_path`
- **Type**: `string`
- **Default**: `"/wp-content"`
- **Description**: EFS access point path for WordPress content

#### `efs_ap_owner_uid`
- **Type**: `number`
- **Default**: `33`
- **Description**: UID owner for EFS access point (33 = www-data)

#### `efs_ap_owner_gid`
- **Type**: `number`
- **Default**: `33`
- **Description**: GID owner for EFS access point (33 = www-data)

#### `efs_enable_backup`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable AWS Backup for EFS

#### `efs_backup_cron`
- **Type**: `string`
- **Default**: `"cron(0 1 * * ? *)"`
- **Description**: AWS Backup cron schedule for EFS

#### `efs_backup_delete_after_days`
- **Type**: `number`
- **Default**: `30`
- **Description**: Days to retain EFS backups in Backup vault

---

### Security

#### `create_cloudtrail`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Create multi-region account-level CloudTrail

#### `create_config`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable AWS Config recorder and delivery channel

#### `create_guardduty`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable GuardDuty detector in this account/region

---

### Load Balancer & Ingress

#### `wordpress_domain_name`
- **Type**: `string`
- **Default**: `""`
- **Description**: Domain name for WordPress site (e.g., wordpress.example.com)

#### `wordpress_hosted_zone_id`
- **Type**: `string`
- **Default**: `""`
- **Description**: Route53 hosted zone ID for WordPress domain

#### `create_alb_route53_record`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Create Route53 A record pointing to ALB

#### `enable_cloudfront_restriction`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Restrict ALB ingress to CloudFront IP ranges only

#### `alb_enable_deletion_protection`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable deletion protection on ALB

#### `wordpress_pod_port`
- **Type**: `number`
- **Default**: `8080`
- **Description**: Port where WordPress pods listen

#### `alb_certificate_arn`
- **Type**: `string`
- **Required**: Yes
- **Description**: ACM certificate ARN for ALB HTTPS listener (must be pre-created and validated)
- **Validation**: Must start with `arn:aws:acm:`

#### `waf_acl_arn`
- **Type**: `string`
- **Default**: `""`
- **Description**: Existing WAF WebACL ARN for ALB (if not creating new WAF)

#### `create_waf`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Create WAF WebACL for ALB in infrastructure stack

#### `waf_rate_limit`
- **Type**: `number`
- **Default**: `100`
- **Description**: WAF rate limit for wp-login.php (requests per 5 minutes)

#### `waf_enable_managed_rules`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable AWS Managed Rules (Common Rule Set) for OWASP Top 10 protection

#### `enable_alb_origin_protection`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable ALB origin protection to block direct access (requires CloudFront)

#### `alb_origin_protection_response_code`
- **Type**: `number`
- **Default**: `403`
- **Valid Values**: `400`, `401`, `403`, `404`, `503`
- **Description**: HTTP response code when origin secret validation fails

#### `alb_origin_protection_response_body`
- **Type**: `string`
- **Default**: `"Access Denied - Direct access not allowed"`
- **Description**: Response body when origin secret validation fails

---

### CloudFront CDN

#### `enable_cloudfront`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable CloudFront distribution deployment

#### `cloudfront_certificate_arn`
- **Type**: `string`
- **Default**: `""`
- **Required**: Yes (when `enable_cloudfront` is true)
- **Description**: ACM certificate ARN from us-east-1 for CloudFront
- **Validation**: Must be from us-east-1 region

#### `cloudfront_aliases`
- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: Additional domain aliases for CloudFront distribution

#### `cloudfront_price_class`
- **Type**: `string`
- **Default**: `"PriceClass_100"`
- **Valid Values**: `PriceClass_All`, `PriceClass_200`, `PriceClass_100`
- **Description**: CloudFront price class (edge location coverage)

#### `cloudfront_enable_http3`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable HTTP/3 (QUIC) for CloudFront distribution

#### `cloudfront_origin_secret`
- **Type**: `string` (sensitive)
- **Default**: `""`
- **Description**: Shared secret header value for CloudFront origin protection

#### `create_cloudfront_route53_record`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Create Route53 A record pointing to CloudFront distribution

#### `cloudfront_geo_restriction_type`
- **Type**: `string`
- **Default**: `"none"`
- **Valid Values**: `none`, `whitelist`, `blacklist`
- **Description**: Type of geo restriction for CloudFront

#### `cloudfront_geo_restriction_locations`
- **Type**: `list(string)`
- **Default**: `[]`
- **Description**: Country codes for CloudFront geo restriction (ISO 3166-1 alpha-2)
- **Validation**: Must be valid 2-letter country codes

#### `cloudfront_enable_compression`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable automatic content compression (Gzip/Brotli)

#### `cloudfront_enable_logging`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable CloudFront access logging to S3 bucket

#### `cloudfront_log_include_cookies`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Include cookies in CloudFront access logs

#### `cloudfront_log_prefix`
- **Type**: `string`
- **Default**: `"cloudfront-logs/"`
- **Description**: Prefix for CloudFront access log files in S3

#### `cloudfront_enable_origin_shield`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable CloudFront Origin Shield for improved cache hit ratio

#### `cloudfront_origin_shield_region`
- **Type**: `string`
- **Default**: `"eu-central-1"`
- **Description**: AWS region for CloudFront Origin Shield (should be closest to origin)

#### `cloudfront_minimum_protocol_version`
- **Type**: `string`
- **Default**: `"TLSv1.2_2021"`
- **Valid Values**: `SSLv3`, `TLSv1`, `TLSv1_2016`, `TLSv1.1_2016`, `TLSv1.2_2018`, `TLSv1.2_2019`, `TLSv1.2_2021`
- **Description**: Minimum SSL/TLS protocol version for CloudFront

#### `cloudfront_enable_ipv6`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable IPv6 support for CloudFront distribution

#### `cloudfront_default_root_object`
- **Type**: `string`
- **Default**: `"index.php"`
- **Description**: Default root object for CloudFront distribution

---

## Application Stack Variables

### General Configuration

#### `region`
- **Type**: `string`
- **Default**: `"us-east-1"`
- **Description**: AWS region (must match infrastructure stack)

#### `project`
- **Type**: `string`
- **Default**: `"wdp"`
- **Description**: Project/environment short name (must match infrastructure stack)

#### `env`
- **Type**: `string`
- **Default**: `"sandbox"`
- **Description**: Environment name (must match infrastructure stack)

#### `owner_email`
- **Type**: `string`
- **Default**: `"admin@example.com"`
- **Description**: Owner/Contact email tag

#### `tags`
- **Type**: `map(string)`
- **Default**: `{}`
- **Description**: Extra tags merged into resources

---

### Database

#### `db_name`
- **Type**: `string`
- **Default**: `"wordpress"`
- **Description**: Database name (must match infrastructure stack)

#### `db_user`
- **Type**: `string`
- **Default**: `"wpapp"`
- **Description**: Database username for WordPress application

---

### Karpenter

#### `karpenter_instance_types`
- **Type**: `list(string)`
- **Default**: `["t3a.medium", "t3a.large", "t3a.xlarge", "m6a.large", "m6a.xlarge", "c6a.large", "c6a.xlarge"]`
- **Description**: Allowed instance types for Karpenter provisioning

#### `karpenter_capacity_types`
- **Type**: `list(string)`
- **Default**: `["spot", "on-demand"]`
- **Description**: Capacity types mix (spot for cost savings, on-demand for stability)

#### `karpenter_ami_family`
- **Type**: `string`
- **Default**: `"AL2023"`
- **Valid Values**: `AL2023`, `Bottlerocket`
- **Description**: AMI family for Karpenter-provisioned nodes

#### `karpenter_consolidation_policy`
- **Type**: `string`
- **Default**: `"WhenEmptyOrUnderutilized"`
- **Description**: Node consolidation policy for cost optimization

#### `karpenter_expire_after`
- **Type**: `string`
- **Default**: `"720h"`
- **Description**: Node expiration time (e.g., 720h = 30 days)

#### `karpenter_cpu_limit`
- **Type**: `string`
- **Default**: `"64"`
- **Description**: NodePool CPU limit across all nodes

#### `karpenter_volume_size`
- **Type**: `string`
- **Default**: `"50Gi"`
- **Description**: Node volume size

#### `karpenter_volume_type`
- **Type**: `string`
- **Default**: `"gp2"`
- **Description**: Node volume type

---

### Observability

#### `observability_namespace`
- **Type**: `string`
- **Default**: `"observability"`
- **Description**: Namespace for monitoring components

#### `enable_cloudwatch`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable CloudWatch monitoring components

#### `enable_prometheus_stack`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable Prometheus monitoring stack

#### `enable_grafana`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable Grafana dashboard and visualization

#### `enable_alertmanager`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable AlertManager for alert routing

#### `prometheus_storage_size`
- **Type**: `string`
- **Default**: `"50Gi"`
- **Description**: Persistent storage size for Prometheus

#### `prometheus_retention_days`
- **Type**: `number`
- **Default**: `30`
- **Description**: Prometheus metrics retention period in days

#### `grafana_storage_size`
- **Type**: `string`
- **Default**: `"10Gi"`
- **Description**: Persistent storage size for Grafana

#### `enable_wordpress_exporter`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable WordPress metrics exporter

#### `enable_mysql_exporter`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable MySQL/Aurora metrics exporter

#### `enable_redis_exporter`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable Redis/ElastiCache metrics exporter

#### `enable_cost_monitoring`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable AWS cost monitoring and optimization tracking

---

### WordPress

#### `wp_namespace`
- **Type**: `string`
- **Default**: `"wordpress"`
- **Description**: Kubernetes namespace for WordPress

#### `wp_storage_class`
- **Type**: `string`
- **Default**: `"efs-ap"`
- **Description**: StorageClass for WordPress persistent volume (EFS Access Point)

#### `wp_pvc_size`
- **Type**: `string`
- **Default**: `"10Gi"`
- **Description**: PVC size for WordPress

#### `wp_domain_name`
- **Type**: `string`
- **Default**: `"wp-sbx.example.com"`
- **Description**: Public hostname for WordPress (must match alb_domain_name)

#### `wp_replicas_min`
- **Type**: `number`
- **Default**: `2`
- **Description**: Minimum replicas for HPA (Horizontal Pod Autoscaler)

#### `wp_replicas_max`
- **Type**: `number`
- **Default**: `6`
- **Description**: Maximum replicas for HPA

#### `wp_image_tag`
- **Type**: `string`
- **Default**: `"latest"`
- **Description**: WordPress image tag

#### `wp_target_cpu_percent`
- **Type**: `number`
- **Default**: `60`
- **Description**: HPA target CPU utilization percentage

#### `wp_admin_user`
- **Type**: `string`
- **Default**: `"wpadmin"`
- **Description**: Initial WordPress admin username

#### `wp_admin_email`
- **Type**: `string`
- **Default**: `"admin@example.com"`
- **Description**: Initial WordPress admin email

#### `wp_admin_bootstrap_enabled`
- **Type**: `bool`
- **Default**: `true`
- **Description**: Enable one-time admin bootstrap initContainer

---

### Redis Cache

#### `enable_redis_cache`
- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable Redis-backed cache configuration in WordPress

#### `redis_port`
- **Type**: `number`
- **Default**: `6379`
- **Description**: Redis port exposed by ElastiCache

#### `redis_database`
- **Type**: `number`
- **Default**: `0`
- **Description**: Logical Redis database ID

#### `redis_connection_scheme`
- **Type**: `string`
- **Default**: `"tls"`
- **Valid Values**: `tcp`, `tls`, `rediss`
- **Description**: Scheme prefix for Redis connections

---

### Remote State

#### `remote_state_organization`
- **Type**: `string`
- **Default**: `"WpOrbit"`
- **Description**: Terraform Cloud organization for remote state

#### `remote_state_infra_workspace`
- **Type**: `string`
- **Default**: `"wp-infra"`
- **Description**: Terraform Cloud workspace name for infrastructure remote state

---

## Related Documentation

- [Terraform Cloud Variables](terraform-cloud-variables.md) - Terraform Cloud-specific configuration
- [Module Documentation](../modules/) - Module-specific variables and configuration
- [Getting Started Guide](../getting-started.md) - Deployment walkthrough with variable examples
- [Architecture Overview](../architecture.md) - System design and component relationships

