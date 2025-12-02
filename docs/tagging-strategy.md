# AWS Tagging Strategy

## Overview

This project implements a comprehensive tagging strategy following AWS Well-Architected Framework best practices. Tags are used for cost allocation, security compliance, operational management, and resource governance.

## Tag Categories

### 1. Required Tags (Always Applied)

These tags are automatically applied to all resources:

| Tag | Source | Example | Purpose |
|-----|--------|---------|---------|
| `Project` | `var.project` | `wdp` | Project identifier |
| `Env` | `var.env` | `production` | Environment name |
| `Owner` | `var.owner_email` | `admin@example.com` | Resource owner contact |
| `Environment` | `var.environment_profile` | `production` | Environment profile (infra stack only) |
| `ManagedBy` | Hardcoded | `Terraform` | Infrastructure as Code tool |

### 2. Optional Tags (Conditionally Applied)

These tags are only applied if you provide non-empty values:

| Tag | Variable | Example | Purpose |
|-----|----------|---------|---------|
| `CostCenter` | `var.cost_center` | `platform-engineering` | Cost allocation and chargeback |
| `Application` | `var.application` | `wordpress-platform` | Application grouping |
| `BusinessUnit` | `var.business_unit` | `Engineering` | Department ownership |
| `Compliance` | `var.compliance_requirements` | `SOC2,GDPR` | Compliance requirements |
| `DataClassification` | `var.data_classification` | `internal` | Data sensitivity level |
| `TechnicalContact` | `var.technical_contact` | `devops@example.com` | Technical point of contact |
| `ProductOwner` | `var.product_owner` | `john.doe@example.com` | Product ownership |

### 3. Custom Tags

Additional tags can be provided via the `tags` variable:

```hcl
tags = {
  Department  = "IT"
  Criticality = "high"
  Customer    = "acme-corp"
}
```

## Configuration

### Infrastructure Stack (stacks/infra)

```hcl
# Required
project             = "wdp"
env                 = "production"
environment_profile = "production"
owner_email         = "platform-team@company.com"

# Optional - only include if needed
cost_center              = "platform-engineering"
application              = "wordpress-platform"
business_unit            = "Engineering"
compliance_requirements  = "SOC2,GDPR,HIPAA"
data_classification      = "internal"
technical_contact        = "devops@company.com"
product_owner            = "john.doe@company.com"

# Custom tags
tags = {
  Department  = "IT"
  Criticality = "high"
}
```

### Application Stack (stacks/app)

Same variables as infrastructure stack. Tags are automatically inherited and applied consistently.

## Data Classification Levels

| Level | Description | Use Cases |
|-------|-------------|-----------|
| `public` | Publicly accessible data | Marketing content, public documentation |
| `internal` | Internal use only | WordPress uploads, internal documentation |
| `confidential` | Sensitive business data | Database credentials, customer data |
| `restricted` | Highly sensitive data | PII, financial records, health information |

## Tag Inheritance

Tags flow through the infrastructure in this order:

1. **Base tags** (Project, Env, Owner, ManagedBy, Environment)
2. **Optional tags** (only if provided)
3. **Custom tags** (from `var.tags`)
4. **Resource-specific tags** (Name, Service, etc.)

Example final tag set:
```hcl
{
  # Base tags
  Project     = "wdp"
  Env         = "production"
  Owner       = "admin@example.com"
  Environment = "production"
  ManagedBy   = "Terraform"
  
  # Optional tags (if provided)
  CostCenter         = "platform-engineering"
  Application        = "wordpress-platform"
  BusinessUnit       = "Engineering"
  Compliance         = "SOC2,GDPR"
  DataClassification = "internal"
  TechnicalContact   = "devops@example.com"
  ProductOwner       = "john.doe@example.com"
  
  # Custom tags
  Department  = "IT"
  Criticality = "high"
  
  # Resource-specific
  Name    = "wdp-vpc"
  Service = "networking"
}
```

## AWS Cost Allocation Tags

### Enabling Cost Allocation Tags

After deploying infrastructure, activate these tags in AWS Billing Console:

```bash
aws ce update-cost-allocation-tags-status \
  --cost-allocation-tags-status \
    TagKey=Project,Status=Active \
    TagKey=Environment,Status=Active \
    TagKey=CostCenter,Status=Active \
    TagKey=Application,Status=Active \
    TagKey=Owner,Status=Active \
    TagKey=BusinessUnit,Status=Active
```

### Cost Explorer Queries

**Cost by Project:**
```
Group by: Tag -> Project
Filter: None
```

**Cost by Environment:**
```
Group by: Tag -> Environment
Filter: None
```

**Cost by Cost Center:**
```
Group by: Tag -> CostCenter
Filter: None
```

## Tag Governance with AWS Config

### Required Tags Rule

Enforce that all resources have required tags:

```hcl
resource "aws_config_config_rule" "required_tags" {
  name = "required-tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Project"
    tag2Key = "Environment"
    tag3Key = "Owner"
    tag4Key = "ManagedBy"
  })
}
```

### Tag Value Compliance

Ensure tags have valid values:

```hcl
resource "aws_config_config_rule" "tag_value_compliance" {
  name = "environment-tag-values"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key           = "Environment"
    tag1Value         = "production,staging,development"
    tag2Key           = "ManagedBy"
    tag2Value         = "Terraform"
  })
}
```

## Service-Specific Tags

### Database Resources (Aurora)

```hcl
tags = merge(var.tags, {
  Name               = "${var.name}-aurora"
  Service            = "database"
  BackupPolicy       = "daily"
  DataClassification = "confidential"  # Databases contain sensitive data
})
```

### Storage Resources (EFS)

```hcl
tags = merge(var.tags, {
  Name               = "${var.name}-efs"
  Service            = "storage"
  Backup             = var.enable_backup ? "daily" : "none"
  DataClassification = "internal"  # WordPress uploads
})
```

### Networking Resources (VPC)

```hcl
tags = merge(var.tags, {
  Name         = "${var.name}-vpc"
  Service      = "networking"
  SecurityZone = "private"
})
```

### Compute Resources (EKS)

```hcl
tags = merge(var.tags, {
  Name    = "${var.name}-eks"
  Service = "compute"
})
```

## Kubernetes-Specific Tags

These tags are required for EKS and Karpenter functionality:

### Subnet Tags

**Public Subnets:**
```hcl
"kubernetes.io/role/elb"            = "1"
"kubernetes.io/cluster/${var.name}" = "owned"
```

**Private Subnets:**
```hcl
"kubernetes.io/role/internal-elb"   = "1"
"kubernetes.io/cluster/${var.name}" = "owned"
"karpenter.sh/discovery"            = var.name
```

### Security Group Tags

```hcl
"karpenter.sh/discovery" = var.name
```

## Best Practices

### 1. Consistency
- Use the same tag keys across all resources
- Maintain consistent capitalization (PascalCase recommended)
- Use consistent value formats

### 2. Automation
- Always use variables for tag values
- Never hardcode tag values in modules
- Use locals for tag merging logic

### 3. Documentation
- Document tag purpose and valid values
- Include examples in tfvars files
- Update this guide when adding new tags

### 4. Validation
- Use variable validation for enum-like tags
- Validate tag format (email, etc.)
- Use AWS Config rules for enforcement

### 5. Cost Management
- Always include cost allocation tags
- Enable tags in AWS Billing Console
- Review cost reports monthly

### 6. Security
- Tag resources by data classification
- Tag by compliance requirements
- Use tags for IAM policy conditions

## Tag-Based IAM Policies

### Restrict Access by Environment

```hcl
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Environment": "development"
        }
      }
    }
  ]
}
```

### Enforce Tagging on Resource Creation

```hcl
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": [
        "ec2:RunInstances",
        "rds:CreateDBInstance"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestTag/Project": "*",
          "aws:RequestTag/Environment": "*",
          "aws:RequestTag/Owner": "*"
        }
      }
    }
  ]
}
```

## Reporting and Monitoring

### CloudWatch Insights Query

Find resources missing required tags:

```sql
fields @timestamp, resourceId, tags
| filter ispresent(tags.Project) = 0 
    or ispresent(tags.Environment) = 0 
    or ispresent(tags.Owner) = 0
| sort @timestamp desc
```

### AWS CLI Query

List all resources with specific tag:

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=wdp \
  --resource-type-filters ec2 rds efs
```

## Migration Guide

If you have existing infrastructure without these tags:

1. **Add variables to tfvars:**
   ```hcl
   cost_center = "platform-engineering"
   application = "wordpress-platform"
   # ... other optional tags
   ```

2. **Plan the changes:**
   ```bash
   make plan-infra
   make plan-app
   ```

3. **Review tag additions:**
   - Most resources will show tag additions only
   - No resource recreation required

4. **Apply changes:**
   ```bash
   make apply-infra
   make apply-app
   ```

5. **Enable cost allocation tags in AWS Console**

6. **Wait 24 hours for cost data to populate**

## References

- [AWS Tagging Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)
- [AWS Well-Architected Framework - Tagging](https://docs.aws.amazon.com/wellarchitected/latest/framework/a-tagging.html)
- [AWS Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
- [Terraform AWS Provider - Default Tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)
