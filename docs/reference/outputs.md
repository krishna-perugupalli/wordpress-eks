# Terraform Outputs Reference

This document provides a comprehensive reference for all Terraform outputs from the infrastructure and application stacks.

## Table of Contents

- [Infrastructure Stack Outputs](#infrastructure-stack-outputs)
  - [EKS Cluster](#eks-cluster)
  - [Networking](#networking)
  - [Data Services](#data-services)
  - [Secrets](#secrets)
  - [IAM Roles](#iam-roles)
  - [Load Balancer](#load-balancer)
  - [CloudFront CDN](#cloudfront-cdn)
  - [DNS Configuration](#dns-configuration)
- [Application Stack Outputs](#application-stack-outputs)
  - [WordPress](#wordpress)
  - [Monitoring](#monitoring)

---

## Infrastructure Stack Outputs

### EKS Cluster

#### `cluster_name`
- **Type**: `string`
- **Description**: EKS cluster name
- **Usage**: Used for kubectl configuration and cluster identification

#### `cluster_endpoint`
- **Type**: `string`
- **Description**: EKS cluster API server endpoint URL
- **Usage**: Required for kubectl and Kubernetes provider configuration

#### `cluster_oidc_issuer_url`
- **Type**: `string`
- **Description**: OIDC provider issuer URL for the EKS cluster
- **Usage**: Used for IRSA (IAM Roles for Service Accounts) configuration

#### `oidc_provider_arn`
- **Type**: `string`
- **Description**: ARN of the OIDC provider for the EKS cluster
- **Usage**: Required for creating IAM roles with IRSA trust policies

#### `node_security_group_id`
- **Type**: `string`
- **Description**: Security group ID for EKS worker nodes
- **Usage**: Used for configuring additional security group rules

#### `cluster_role_arn`
- **Type**: `string`
- **Description**: IAM role ARN for the EKS cluster
- **Usage**: Cluster service role for EKS control plane

#### `node_role_arn`
- **Type**: `string`
- **Description**: IAM role ARN for EKS worker nodes
- **Usage**: Node instance profile role

---

### Networking

#### `vpc_id`
- **Type**: `string`
- **Description**: VPC ID where resources are deployed
- **Usage**: Required for security group and subnet associations

#### `private_subnet_ids`
- **Type**: `list(string)`
- **Description**: List of private subnet IDs across availability zones
- **Usage**: Used for deploying private resources (EKS nodes, RDS, ElastiCache)

#### `public_subnet_ids`
- **Type**: `list(string)`
- **Description**: List of public subnet IDs across availability zones
- **Usage**: Used for deploying public-facing resources (ALB, NAT gateways)

#### `azs`
- **Type**: `list(string)`
- **Description**: Availability zones used by the foundation module
- **Usage**: Reference for multi-AZ deployments

---

### Data Services

#### `writer_endpoint`
- **Type**: `string`
- **Description**: Aurora MySQL writer endpoint (primary instance)
- **Usage**: Database connection string for write operations

#### `aurora_master_secret_arn`
- **Type**: `string`
- **Description**: Secrets Manager ARN for Aurora master user credentials
- **Usage**: Retrieve database admin credentials securely

#### `redis_endpoint`
- **Type**: `string`
- **Description**: ElastiCache Redis primary endpoint address
- **Usage**: Redis connection string for cache operations

#### `file_system_id`
- **Type**: `string`
- **Description**: EFS file system ID
- **Usage**: Required for EFS CSI driver and access point configuration

---

### Secrets

#### `wpapp_db_secret_arn`
- **Type**: `string`
- **Description**: Secrets Manager ARN for WordPress application database credentials
- **Usage**: External Secrets Operator retrieves these credentials for WordPress

#### `wp_admin_secret_arn`
- **Type**: `string`
- **Description**: Secrets Manager ARN for WordPress admin credentials
- **Usage**: Initial WordPress admin user password

#### `redis_auth_secret_arn`
- **Type**: `string`
- **Description**: Secrets Manager ARN for Redis AUTH token
- **Usage**: Redis authentication for WordPress cache plugin

#### `secrets_read_policy_arn`
- **Type**: `string`
- **Description**: IAM policy ARN granting External Secrets Operator read access
- **Usage**: Attached to ESO service account role

---

### IAM Roles

#### `eso_role_arn`
- **Type**: `string`
- **Description**: IAM role ARN for External Secrets Operator (IRSA)
- **Usage**: Service account annotation for ESO pods

#### `karpenter_role_arn`
- **Type**: `string`
- **Description**: IAM role ARN for Karpenter controller (IRSA)
- **Usage**: Service account annotation for Karpenter pods

#### `karpenter_node_iam_role_name`
- **Type**: `string`
- **Description**: IAM role name for Karpenter-provisioned nodes
- **Usage**: Referenced in Karpenter EC2NodeClass configuration

#### `karpenter_sqs_queue_name`
- **Type**: `string`
- **Description**: SQS queue name for Karpenter interruption handling
- **Usage**: Karpenter monitors this queue for spot interruptions

---

### Load Balancer

#### `alb_arn`
- **Type**: `string`
- **Description**: ARN of the standalone ALB
- **Usage**: ALB resource identification and tagging

#### `alb_dns_name`
- **Type**: `string`
- **Description**: DNS name of the standalone ALB
- **Usage**: Route53 alias target for direct ALB access

#### `alb_zone_id`
- **Type**: `string`
- **Description**: Route53 zone ID of the ALB
- **Usage**: Required for Route53 alias records

#### `alb_security_group_id`
- **Type**: `string`
- **Description**: Security group ID of the ALB
- **Usage**: Configure additional ingress/egress rules

#### `target_group_arn`
- **Type**: `string`
- **Description**: ARN of the target group for WordPress
- **Usage**: TargetGroupBinding references this for pod IP registration

#### `target_group_name`
- **Type**: `string`
- **Description**: Name of the target group
- **Usage**: Target group identification

#### `alb_certificate_arn`
- **Type**: `string`
- **Description**: Regional ACM certificate ARN for ALB
- **Usage**: HTTPS listener certificate (passed through from variable)

#### `waf_regional_arn`
- **Type**: `string`
- **Description**: WAF WebACL ARN for ALB
- **Usage**: WAF association with ALB

#### `alb_origin_protection_enabled`
- **Type**: `bool`
- **Description**: Whether ALB origin protection is enabled
- **Usage**: Indicates if direct ALB access is blocked

#### `alb_dns_validation`
- **Type**: `object`
- **Description**: ALB DNS configuration validation information
- **Usage**: Verify DNS setup for ALB access

---

### CloudFront CDN

#### `cloudfront_distribution_id`
- **Type**: `string`
- **Description**: CloudFront distribution ID
- **Usage**: CloudFront cache invalidation and management
- **Note**: Empty string when CloudFront is disabled

#### `cloudfront_distribution_domain_name`
- **Type**: `string`
- **Description**: CloudFront distribution domain name (e.g., d123456.cloudfront.net)
- **Usage**: Route53 alias target for CloudFront access
- **Note**: Empty string when CloudFront is disabled

#### `cloudfront_distribution_zone_id`
- **Type**: `string`
- **Description**: Route53 zone ID for CloudFront distributions
- **Default**: `Z2FDTNDATAQYW2` (global CloudFront zone ID)
- **Usage**: Required for Route53 alias records pointing to CloudFront

#### `cloudfront_enabled`
- **Type**: `bool`
- **Description**: Whether CloudFront is enabled
- **Usage**: Conditional logic in application stack

#### `cloudfront_route53_record_fqdn`
- **Type**: `string`
- **Description**: FQDN of the Route53 record pointing to CloudFront
- **Usage**: Verify DNS configuration for CloudFront
- **Note**: Empty string when CloudFront is disabled

#### `cloudfront_route53_alias_fqdns`
- **Type**: `list(string)`
- **Description**: FQDNs of alias Route53 records pointing to CloudFront
- **Usage**: Additional domain aliases configured for CloudFront
- **Note**: Empty list when CloudFront is disabled

#### `cloudfront_dns_validation`
- **Type**: `object`
- **Description**: CloudFront DNS configuration validation information
- **Fields**:
  - `cloudfront_domain_name`: CloudFront distribution domain
  - `cloudfront_zone_id`: CloudFront zone ID
  - `primary_domain`: Primary domain name
  - `aliases`: List of domain aliases
  - `hosted_zone_valid`: Whether hosted zone configuration is valid
- **Usage**: Validate CloudFront DNS setup

---

### DNS Configuration

#### `route53_record_fqdn`
- **Type**: `string`
- **Description**: FQDN of the created Route53 record
- **Usage**: Verify DNS record creation

#### `route53_record_type`
- **Type**: `string`
- **Description**: Type of Route53 record created
- **Values**: `alb` or `cloudfront`
- **Usage**: Indicates whether DNS points to ALB or CloudFront

#### `dns_coordination_status`
- **Type**: `object`
- **Description**: Status of DNS coordination between ALB and CloudFront
- **Fields**:
  - `alb_route53_created`: Whether ALB Route53 record was created
  - `cloudfront_route53_created`: Whether CloudFront Route53 record was created
  - `cloudfront_enabled`: Whether CloudFront is enabled
  - `domain_name`: WordPress domain name
  - `hosted_zone_id`: Route53 hosted zone ID
  - `coordination_valid`: Whether DNS coordination is valid
- **Usage**: Validate DNS configuration and troubleshoot routing issues

---

### Other

#### `region`
- **Type**: `string`
- **Description**: AWS region for the stack
- **Usage**: Region reference for application stack

#### `kms_logs_arn`
- **Type**: `string`
- **Description**: KMS key ARN for log encryption
- **Usage**: CloudWatch Logs encryption

#### `log_bucket_name`
- **Type**: `string`
- **Description**: S3 bucket name for CloudFront and ALB logs
- **Usage**: Access log storage and analysis

---

## Application Stack Outputs

### WordPress

#### `wordpress_namespace`
- **Type**: `string`
- **Description**: Namespace where WordPress is installed
- **Usage**: kubectl commands and resource management

#### `wordpress_hostname`
- **Type**: `string`
- **Description**: Public hostname for WordPress
- **Usage**: WordPress site URL configuration

#### `target_group_arn`
- **Type**: `string`
- **Description**: Target group ARN from infrastructure stack
- **Usage**: TargetGroupBinding configuration (passed through from infra stack)

---

### Monitoring

#### `monitoring_namespace`
- **Type**: `string`
- **Description**: Namespace used for monitoring components
- **Usage**: kubectl commands for monitoring resources

#### `monitoring_stack_summary`
- **Type**: `object`
- **Description**: Summary of enabled monitoring components
- **Usage**: Quick reference for monitoring stack configuration

#### `cloudwatch_enabled`
- **Type**: `bool`
- **Description**: Whether CloudWatch monitoring is enabled
- **Usage**: Conditional monitoring logic

#### `cloudwatch_log_groups`
- **Type**: `list(string)`
- **Description**: CloudWatch log group names
- **Usage**: Log access and analysis

#### `prometheus_enabled`
- **Type**: `bool`
- **Description**: Whether Prometheus monitoring stack is enabled
- **Usage**: Conditional monitoring logic

#### `prometheus_url`
- **Type**: `string`
- **Description**: Prometheus server URL for internal cluster access
- **Usage**: Internal service discovery and queries

#### `prometheus_external_url`
- **Type**: `string`
- **Description**: Prometheus server external URL (if exposed)
- **Usage**: External access to Prometheus UI

#### `grafana_enabled`
- **Type**: `bool`
- **Description**: Whether Grafana is enabled
- **Usage**: Conditional monitoring logic

#### `grafana_url`
- **Type**: `string`
- **Description**: Grafana URL for internal cluster access
- **Usage**: Internal service discovery

#### `grafana_external_url`
- **Type**: `string`
- **Description**: Grafana external URL (if exposed)
- **Usage**: External access to Grafana dashboards

#### `alertmanager_enabled`
- **Type**: `bool`
- **Description**: Whether AlertManager is enabled
- **Usage**: Conditional alerting logic

#### `alertmanager_url`
- **Type**: `string`
- **Description**: AlertManager URL for internal cluster access
- **Usage**: Internal service discovery

#### `wordpress_exporter_enabled`
- **Type**: `bool`
- **Description**: Whether WordPress exporter is enabled
- **Usage**: Metrics collection status

#### `mysql_exporter_enabled`
- **Type**: `bool`
- **Description**: Whether MySQL exporter is enabled
- **Usage**: Database metrics collection status

#### `redis_exporter_enabled`
- **Type**: `bool`
- **Description**: Whether Redis exporter is enabled
- **Usage**: Cache metrics collection status

#### `cost_monitoring_enabled`
- **Type**: `bool`
- **Description**: Whether cost monitoring is enabled
- **Usage**: Cost tracking status

#### `cloudfront_monitoring_enabled`
- **Type**: `bool`
- **Description**: Whether CloudFront CDN monitoring is enabled
- **Usage**: CDN metrics collection status

#### `security_features_enabled`
- **Type**: `bool`
- **Description**: Whether security and compliance features are enabled
- **Usage**: Security monitoring status

#### `audit_logging_enabled`
- **Type**: `bool`
- **Description**: Whether audit logging is enabled
- **Usage**: Audit trail status

#### `ha_dr_enabled`
- **Type**: `bool`
- **Description**: Whether high availability and disaster recovery features are enabled
- **Usage**: HA/DR configuration status

---

## Usage Examples

### Accessing Outputs

**From Terraform:**
```hcl
# In application stack, reference infrastructure outputs
data "terraform_remote_state" "infra" {
  backend = "remote"
  config = {
    organization = "WpOrbit"
    workspaces = {
      name = "wp-infra"
    }
  }
}

# Use outputs
cluster_endpoint = data.terraform_remote_state.infra.outputs.cluster_endpoint
```

**From CLI:**
```bash
# View all outputs
terraform output

# View specific output
terraform output cluster_name

# View output in JSON format
terraform output -json

# Use output in scripts
CLUSTER_NAME=$(terraform output -raw cluster_name)
```

### Common Use Cases

**Configure kubectl:**
```bash
aws eks update-kubeconfig \
  --region $(terraform output -raw region) \
  --name $(terraform output -raw cluster_name)
```

**Connect to database:**
```bash
DB_ENDPOINT=$(terraform output -raw writer_endpoint)
mysql -h $DB_ENDPOINT -u wpapp -p
```

**Invalidate CloudFront cache:**
```bash
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"
```

---

## Related Documentation

- [Variables Reference](variables.md) - Input variables for configuration
- [Module Documentation](../modules/) - Module-specific outputs
- [Getting Started Guide](../getting-started.md) - Deployment walkthrough
- [Architecture Overview](../architecture.md) - System design and data flows

