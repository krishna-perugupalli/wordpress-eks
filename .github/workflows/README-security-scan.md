# Security Scanning Workflow

## Overview

The security scanning workflow uses Checkov to scan Terraform configurations for security misconfigurations and compliance violations, with a **custom severity mapping** tailored for WordPress on EKS infrastructure.

## Custom Severity Mapping

### Why Custom Mapping?

**Important:** Checkov requires an API key to provide severity ratings. Without it, all checks have `null` severity. To solve this, we've created a custom severity mapping based on:

1. **Security impact** for WordPress on EKS workloads
2. **AWS best practices** for production infrastructure
3. **Compliance requirements** (CIS, data protection)
4. **Operational risk** assessment

### Severity Mapping File

The mapping is defined in `.github/workflows/checkov-severity-mapping.json` and categorizes 30 common Checkov checks into severity levels.

### Workflow Failure Thresholds

The workflow implements the following failure logic:

- **CRITICAL severity**: Blocks PR merging
  - IAM permission escalation risks
  - Public exposure vulnerabilities
  - Secrets encryption disabled
  
- **HIGH severity**: Blocks PR merging
  - Missing encryption at rest
  - Weak authentication mechanisms
  - Unrestricted network access
  - Missing audit logging
  
- **MEDIUM severity**: Warning only, does not block 
  - Operational best practices
  - Enhanced monitoring features
  - Backup and recovery configurations
  - Compliance logging requirements
  
- **LOW severity**: Warning only, does not block
  - Informational findings
  - Minor operational improvements
  - Supply chain best practices

### Mapped Checks

**CRITICAL (5 checks):**
- CKV_AWS_109: IAM permissions management without constraints
- CKV_AWS_111: IAM write access without constraints
- CKV_AWS_356: IAM wildcard resource permissions
- CKV_AWS_260: Security group allows public ingress to port 80
- CKV_AWS_58: EKS secrets encryption disabled

**HIGH (8 checks):**
- CKV_AWS_23: Security groups without descriptions
- CKV_AWS_130: VPC subnets assign public IPs by default
- CKV_AWS_158: CloudWatch logs not encrypted by KMS
- CKV_AWS_162: RDS IAM authentication disabled
- CKV_AWS_166: Backup vault not encrypted with KMS CMK
- CKV_AWS_191: ElastiCache not encrypted with KMS CMK
- CKV_AWS_37: EKS control plane logging not fully enabled
- CKV_AWS_382: Security group allows unrestricted egress

**MEDIUM (13 checks):**
- RDS monitoring, backup, and logging configurations
- Load balancer security features
- CloudFront security headers
- Log retention policies
- ECR image immutability

**LOW (4 checks):**
- CloudFormation notifications
- ACM certificate lifecycle
- CloudFront failover configuration
- Terraform module commit hashes

### Unmapped Checks

Any checks not in the mapping are automatically treated as **MEDIUM** severity with a warning logged.

## Customizing Severity Behavior

### Option 1: Skip Specific Checks

Add checks to `.checkov.yml` to skip false positives:

```yaml
skip-check:
  - CKV_AWS_123  # Justification for skipping
```

### Option 2: Use Checkov's Severity Mapping

Create a custom severity mapping file to assign severity to specific checks. See [Checkov documentation](https://www.checkov.io/2.Basics/Suppressing%20and%20Skipping%20Policies.html) for details.

### Option 3: Modify Failure Threshold

Edit `.github/workflows/security-scan.yml` and change the failure logic in the "Evaluate failure thresholds" step:

```bash
# Example: Fail on MEDIUM and above
if [ "${critical_count}" -gt 0 ] || [ "${high_count}" -gt 0 ] || [ "${medium_count}" -gt 0 ]; then
  echo "should_fail=true" >> $GITHUB_OUTPUT
  exit 1
fi
```

## Outputs

### PR Comments

The workflow posts a comment on PRs with:
- Summary table showing passed/failed checks by severity
- Detailed findings for CRITICAL and HIGH issues
- Sample of MEDIUM and unrated issues
- Links to full reports

### GitHub Security Tab

SARIF results are uploaded to the Security tab for:
- Centralized security findings tracking
- Integration with GitHub Advanced Security features
- Historical trend analysis

### Artifacts

Full Checkov results (JSON, SARIF, CLI) are uploaded as artifacts for:
- Detailed offline analysis
- Compliance reporting
- Historical records

## Troubleshooting

### All Checks Show as "Unrated"

This is expected! Most Checkov checks don't have severity ratings. The workflow will still report them but won't block PRs.

### Too Many Warnings

Consider:
1. Adding legitimate exceptions to `.checkov.yml`
2. Fixing the most common issues across the codebase
3. Using Checkov's baseline feature to track known issues

### Need Stricter Enforcement

Modify the failure threshold in the workflow to include MEDIUM severity or all failed checks.

## References

- [Checkov Documentation](https://www.checkov.io/)
- [Checkov Policy Index](https://www.checkov.io/5.Policy%20Index/terraform.html)
- [GitHub Code Scanning](https://docs.github.com/en/code-security/code-scanning)
