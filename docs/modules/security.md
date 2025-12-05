# Security Baseline Module

## Overview

The `security-baseline` module establishes foundational security controls for the AWS account and region. It configures CloudTrail for audit logging, AWS Config for compliance monitoring, GuardDuty for threat detection, and creates encrypted S3 buckets for security logs.

## Key Resources

- **KMS Key**: Customer-managed key for log encryption
- **S3 Bucket**: Encrypted storage for CloudTrail, Config, and ALB logs
- **CloudTrail**: Multi-region audit trail with CloudWatch Logs integration
- **AWS Config**: Configuration recorder and delivery channel
- **GuardDuty**: Threat detection with S3 and Kubernetes audit log monitoring
- **CloudWatch Log Group**: Centralized CloudTrail logs with retention policies
- **IAM Roles**: Service roles for CloudTrail and Config

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Security Baseline                         │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐ │
│  │  CloudTrail  │    │  AWS Config  │    │  GuardDuty   │ │
│  │  Multi-region│    │  Recorder    │    │  Detector    │ │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘ │
│         │                   │                    │          │
│         └───────────────────┼────────────────────┘          │
│                             ↓                                │
│                    ┌─────────────────┐                      │
│                    │  S3 Bucket      │                      │
│                    │  KMS Encrypted  │                      │
│                    │  Versioned      │                      │
│                    │  Lifecycle      │                      │
│                    └─────────────────┘                      │
│                             │                                │
│                             ↓                                │
│                    ┌─────────────────┐                      │
│                    │  CloudWatch     │                      │
│                    │  Log Group      │                      │
│                    │  90-day retention│                     │
│                    └─────────────────┘                      │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Basic Setup

```hcl
module "security_baseline" {
  source = "../../modules/security-baseline"

  name = "wordpress-prod"

  # Create new S3 bucket for logs
  create_trail_bucket = true
  logs_expire_after_days = 365

  # Enable security services
  create_cloudtrail = true
  create_config     = true
  create_guardduty  = false  # Enable if not already active

  # CloudWatch Logs retention
  cloudtrail_cwl_retention_days = 90

  tags = local.common_tags
}
```

### Using Existing S3 Bucket

If you have a centralized security logs bucket:

```hcl
module "security_baseline" {
  source = "../../modules/security-baseline"

  name = "wordpress-prod"

  # Use existing bucket
  create_trail_bucket = false
  trail_bucket_name   = "my-org-security-logs"

  create_cloudtrail = true
  create_config     = true

  tags = local.common_tags
}
```

### With GuardDuty

```hcl
module "security_baseline" {
  source = "../../modules/security-baseline"

  name = "wordpress-prod"

  create_trail_bucket = true
  create_cloudtrail   = true
  create_config       = true

  # Enable GuardDuty
  create_guardduty     = true
  guardduty_use_existing = false  # Set true if detector already exists

  tags = local.common_tags
}
```

## Key Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `create_trail_bucket` | Create S3 bucket for logs | `false` |
| `trail_bucket_name` | Existing bucket name (if not creating) | `""` |
| `logs_expire_after_days` | S3 lifecycle expiration | `365` |
| `create_cloudtrail` | Enable CloudTrail | `true` |
| `create_config` | Enable AWS Config | `true` |
| `create_guardduty` | Enable GuardDuty | `false` |
| `guardduty_use_existing` | Use existing GuardDuty detector | `true` |
| `cloudtrail_cwl_retention_days` | CloudWatch Logs retention | `90` |

## Outputs

- `kms_logs_key_id`: KMS key ID for log encryption
- `kms_logs_key_arn`: KMS key ARN for log encryption
- `security_logs_bucket_name`: S3 bucket name for security logs
- `security_logs_bucket_arn`: S3 bucket ARN
- `cloudtrail_id`: CloudTrail trail ID
- `guardduty_detector_id`: GuardDuty detector ID (if enabled)

## Security Features

### CloudTrail

**Purpose**: Audit logging for all API calls in the AWS account

**Features**:
- Multi-region trail (captures events from all regions)
- Log file validation (detects tampering)
- CloudWatch Logs integration (real-time monitoring)
- KMS encryption for logs
- S3 bucket with versioning and lifecycle policies

**Events Captured**:
- Management events (control plane operations)
- Data events (optional, not enabled by default)
- Global service events (IAM, CloudFront, Route53)

### AWS Config

**Purpose**: Configuration compliance monitoring and change tracking

**Features**:
- Records configuration changes for all supported resources
- Delivers configuration snapshots to S3
- Enables compliance rules (not configured by default)
- Tracks resource relationships

**Use Cases**:
- Audit configuration changes
- Compliance reporting
- Resource inventory
- Change management

### GuardDuty

**Purpose**: Intelligent threat detection using machine learning

**Features**:
- Analyzes CloudTrail, VPC Flow Logs, and DNS logs
- S3 protection (monitors S3 data events)
- Kubernetes protection (monitors EKS audit logs)
- Automated threat detection
- Integration with Security Hub and EventBridge

**Threat Types Detected**:
- Compromised instances
- Reconnaissance activity
- Unauthorized access attempts
- Cryptocurrency mining
- Data exfiltration

### KMS Encryption

All security logs are encrypted using a customer-managed KMS key:

**Key Policy**:
- Account root has full access
- CloudTrail service can encrypt/decrypt
- CloudWatch Logs service can encrypt/decrypt
- Automatic key rotation enabled
- 30-day deletion window

### S3 Bucket Security

**Bucket Features**:
- Versioning enabled (protects against accidental deletion)
- KMS encryption (SSE-KMS for CloudTrail/Config, SSE-S3 for ALB logs)
- Lifecycle policy (automatic expiration after configured days)
- Bucket policy enforces TLS-only access
- Public access blocked

**Bucket Policy**:
```json
{
  "Statement": [
    {
      "Sid": "AllowCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {"Service": "cloudtrail.amazonaws.com"},
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bucket/*",
      "Condition": {
        "StringEquals": {"s3:x-amz-acl": "bucket-owner-full-control"}
      }
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::bucket", "arn:aws:s3:::bucket/*"],
      "Condition": {
        "Bool": {"aws:SecureTransport": "false"}
      }
    }
  ]
}
```

## CloudWatch Logs Integration

CloudTrail events are streamed to CloudWatch Logs for real-time monitoring and alerting.

### Log Group Configuration

- **Name**: `/aws/cloudtrail/<name>`
- **Retention**: Configurable (default 90 days)
- **Encryption**: KMS encrypted
- **IAM Role**: Dedicated role for CloudTrail → CloudWatch Logs

### Use Cases

1. **Real-time Alerting**: Create metric filters and alarms
2. **Log Insights**: Query CloudTrail events with CloudWatch Logs Insights
3. **Integration**: Forward to Lambda, Kinesis, or third-party SIEM

### Example Metric Filter

Detect root account usage:

```hcl
resource "aws_cloudwatch_log_metric_filter" "root_usage" {
  name           = "RootAccountUsage"
  log_group_name = "/aws/cloudtrail/wordpress-prod"
  pattern        = '{ $.userIdentity.type = "Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType != "AwsServiceEvent" }'

  metric_transformation {
    name      = "RootAccountUsageCount"
    namespace = "Security"
    value     = "1"
  }
}
```

## Compliance Considerations

### CIS AWS Foundations Benchmark

This module helps satisfy several CIS controls:

- **2.1**: CloudTrail enabled in all regions
- **2.2**: CloudTrail log file validation enabled
- **2.3**: S3 bucket for CloudTrail logs not publicly accessible
- **2.4**: CloudTrail logs integrated with CloudWatch Logs
- **2.6**: S3 bucket access logging enabled
- **2.7**: CloudTrail logs encrypted at rest using KMS
- **3.1**: CloudWatch log metric filter and alarm for unauthorized API calls
- **4.1**: GuardDuty enabled (if configured)

### HIPAA/PCI-DSS

- Audit logging (CloudTrail)
- Configuration monitoring (Config)
- Encryption at rest (KMS)
- Encryption in transit (TLS-only bucket policy)
- Log retention policies

## Cost Optimization

### CloudTrail

- **Data Events**: Not enabled by default (high volume/cost)
- **Management Events**: Included, minimal cost
- **S3 Storage**: Use lifecycle policies to expire old logs

### AWS Config

- **Configuration Items**: Charged per item recorded
- **Rules**: Charged per rule evaluation
- **Optimization**: Limit to critical resource types if needed

### GuardDuty

- **CloudTrail Analysis**: ~$4.40 per million events
- **VPC Flow Logs**: ~$1.00 per GB analyzed
- **S3 Protection**: ~$0.50 per million S3 events
- **Kubernetes Audit Logs**: ~$0.50 per million events

**Tip**: GuardDuty offers 30-day free trial. Monitor costs before enabling in production.

## Examples

### Minimal Security Baseline

```hcl
module "security_baseline" {
  source = "../../modules/security-baseline"

  name                = "wordpress-dev"
  create_trail_bucket = true
  create_cloudtrail   = true
  create_config       = false  # Disable Config in dev
  create_guardduty    = false

  logs_expire_after_days        = 90  # Shorter retention for dev
  cloudtrail_cwl_retention_days = 30

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

### Production Security Baseline

```hcl
module "security_baseline" {
  source = "../../modules/security-baseline"

  name                = "wordpress-prod"
  create_trail_bucket = true
  create_cloudtrail   = true
  create_config       = true
  create_guardduty    = true

  logs_expire_after_days        = 2555  # 7 years for compliance
  cloudtrail_cwl_retention_days = 365

  tags = {
    Environment = "prod"
    Compliance  = "PCI-DSS"
    ManagedBy   = "Terraform"
  }
}
```

## Troubleshooting

### CloudTrail Not Logging

**Symptoms**: No logs appearing in S3 or CloudWatch Logs

**Causes**:
- Incorrect S3 bucket policy
- IAM role missing permissions
- KMS key policy doesn't allow CloudTrail

**Solution**:
```bash
# Check CloudTrail status
aws cloudtrail get-trail-status --name <trail_name>

# Verify S3 bucket policy
aws s3api get-bucket-policy --bucket <bucket_name>

# Test CloudTrail logging
aws cloudtrail lookup-events --max-results 1
```

### AWS Config Not Recording

**Symptoms**: Configuration items not appearing in S3

**Causes**:
- Recorder not started
- IAM role missing permissions
- S3 bucket policy incorrect

**Solution**:
```bash
# Check recorder status
aws configservice describe-configuration-recorder-status

# Start recorder if stopped
aws configservice start-configuration-recorder --configuration-recorder-name default
```

### GuardDuty Findings Not Appearing

**Symptoms**: No findings in GuardDuty console

**Causes**:
- Detector not enabled
- Data sources not configured
- No actual threats detected (good!)

**Solution**:
```bash
# Check detector status
aws guardduty list-detectors
aws guardduty get-detector --detector-id <detector_id>

# Generate sample findings for testing
aws guardduty create-sample-findings --detector-id <detector_id>
```

## Related Documentation

- **Operations**: [Security Compliance](../operations/security-compliance.md) - Security validation procedures
- **Operations**: [HA/DR](../operations/ha-dr.md) - Backup and disaster recovery
- **Reference**: [Variables](../reference/variables.md) - Complete variable reference
- **AWS Documentation**: [CloudTrail Best Practices](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/best-practices-security.html)
