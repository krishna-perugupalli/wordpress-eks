# Cost Estimation Workflow

## Overview

The cost estimation workflow provides automated infrastructure cost analysis for Terraform changes using [Infracost](https://www.infracost.io/). It runs on pull requests and feature branch pushes to help teams understand the financial impact of infrastructure changes before deployment.

## Features

- **Automated Cost Analysis**: Estimates monthly AWS infrastructure costs from Terraform code
- **Baseline Comparison**: Compares proposed changes against the base branch (main)
- **Smart Labeling**: Automatically labels PRs based on cost impact severity
- **Detailed Breakdown**: Posts formatted cost summaries with module-level details
- **Impact Alerts**: Highlights significant cost increases (>20% or >$100/month)
- **Multi-Trigger Support**: Works on PRs, feature branches, and main branch pushes

## Triggers

The workflow runs automatically when:

- **Pull Requests**: Any PR that modifies `*.tf` or `*.tfvars` files
- **Push Events**: Commits to `main`, `master`, or `feat-*` branches with Terraform changes
- **Manual Dispatch**: Can be triggered manually from the Actions tab

## Setup

### Prerequisites

1. **Infracost Account** (Free for open source):
   - Sign up at https://www.infracost.io/
   - Infracost is open source (Apache 2.0) with a free tier for public repositories
   - Get your API key from the dashboard

2. **GitHub Secret Configuration**:
   ```
   Repository Settings → Secrets and variables → Actions → New repository secret
   
   Name: INFRACOST_API_KEY
   Value: <your-infracost-api-key>
   ```

### Verification

After adding the secret, the workflow will automatically run on the next PR or push to a feature branch.

## How It Works

### For Pull Requests

1. Checks out both the base branch (e.g., `main`) and the PR branch
2. Discovers all Terraform directories automatically
3. Runs Infracost to generate cost estimates for both branches
4. Calculates the cost difference (baseline vs proposed)
5. Applies appropriate labels based on impact level
6. Posts/updates a PR comment with detailed cost breakdown

### For Feature Branch Pushes

1. Compares the feature branch against `main`
2. Generates cost estimates and calculates differences
3. Writes results to the GitHub Actions workflow summary
4. No labels or comments (since there's no PR)

### For Main Branch Pushes

1. Shows current infrastructure costs
2. No comparison (baseline = current)
3. Writes results to workflow summary

## Cost Impact Levels

The workflow categorizes cost changes into four levels:

| Level | Criteria | Label |
|-------|----------|-------|
| **High** | >20% increase OR >$100/month increase | `high-cost-impact` |
| **Medium** | 10-20% increase | `medium-cost-impact` |
| **Decrease** | Any cost reduction | `cost-decrease` |
| **Neutral** | <10% increase | `cost-neutral` |

## Output Format

### PR Comment Example

```markdown
## Infrastructure Cost Estimation

**High cost impact detected!** This change will significantly increase infrastructure costs.

### Cost Summary

| Metric | Value |
|--------|-------|
| **Baseline Cost** (base) | $1,234.56/month |
| **Proposed Cost** (PR) | $1,543.21/month |
| **Monthly Difference** | +$308.65/month |
| **Percentage Change** | +25.00% |

### Cost Breakdown by Module

| Module | Monthly Cost | Change |
|--------|--------------|--------|
| infra | $1,200.00 | +$250.00 |
| app | $343.21 | +$58.65 |

---
**Tip:** Cost estimates are based on list prices and may not reflect your actual AWS costs due to discounts, reserved instances, or savings plans.
Powered by [Infracost](https://www.infracost.io/)
```

## Workflow Behavior

### Automatic Label Management

- Removes old cost labels before applying new ones
- Only one cost label is active at a time
- Labels are only applied to pull requests (not push events)

### Comment Updates

- Updates existing cost comment instead of creating duplicates
- Finds comments by searching for "Infrastructure Cost Estimation" in the body
- Only posts comments on pull requests

### Error Handling

If cost estimation fails, the workflow:
- Posts a failure comment/summary with troubleshooting steps
- Uploads artifacts for debugging
- Does not block PR merging (informational only)

Common failure reasons:
- Invalid Terraform configuration
- Missing or invalid Infracost API key
- Unsupported resource types
- Network connectivity issues

## Configuration

### Excluding Directories

The workflow automatically excludes:
- `.terraform/` directories
- `.external_modules/` directories

### Customizing Thresholds

To modify cost impact thresholds, edit the "Calculate cost impact" step in `cost-estimation.yml`:

```yaml
# Current thresholds
if (( $(echo "$percent_change > 20" | bc -l) )) || (( $(echo "$total_monthly_diff > 100" | bc -l) )); then
  echo "impact_level=high" >> $GITHUB_OUTPUT
elif (( $(echo "$percent_change > 10" | bc -l) )); then
  echo "impact_level=medium" >> $GITHUB_OUTPUT
```

## Artifacts

The workflow uploads the following artifacts (retained for 30 days):

- `infracost-base.json` - Baseline cost estimate
- `infracost-pr.json` - PR branch cost estimate
- `infracost-diff.json` - Cost difference analysis
- `baseline-output.txt` - Baseline generation logs
- `pr-output.txt` - PR generation logs

## Troubleshooting

### Workflow Not Triggering

**Check:**
- Are you modifying `.tf` or `.tfvars` files?
- Is the workflow file in `.github/workflows/`?
- Are path filters correct?

### "Missing Infracost API Key" Error

**Solution:**
1. Verify the secret name is exactly `INFRACOST_API_KEY`
2. Check the secret is set at the repository level (not environment)
3. Re-add the secret if it was recently rotated

### "Baseline Comparison Unavailable"

**Cause:** The base branch doesn't have Terraform files in the same locations

**Behavior:** Workflow shows PR costs only, without comparison

### Cost Estimates Seem Incorrect

**Remember:**
- Estimates use AWS list prices
- Actual costs may differ due to:
  - Reserved instances
  - Savings plans
  - Enterprise discounts
  - Spot instances
  - Free tier usage

**Recommendation:** Use estimates for relative comparison, not absolute values

### Workflow Times Out

**Solutions:**
- Reduce the number of Terraform directories
- Split large modules into smaller ones
- Check for slow network connectivity to Infracost API

## Integration with Other Workflows

### Terraform CI Workflow

Cost estimation runs independently but complements the CI workflow:
- **CI Workflow**: Validates syntax, formatting, and configuration
- **Cost Workflow**: Estimates financial impact

Both should pass before merging.

### Branch Protection

Consider requiring the cost estimation workflow as a status check:
```
Settings → Branches → Branch protection rules → Require status checks
☑ Infracost Analysis
```

Note: This will block PRs if cost estimation fails (not recommended for informational workflows).

## Best Practices

1. **Review High-Impact Changes**: Always review PRs with `high-cost-impact` label carefully
2. **Document Cost Decisions**: Add comments explaining why cost increases are acceptable
3. **Monitor Trends**: Track cost changes over time using Kubecost for actual runtime costs
4. **Optimize Regularly**: Use cost estimates to identify optimization opportunities
5. **Update Baselines**: Merge cost-optimizing PRs to improve future comparisons

## Limitations

- **Terraform Only**: Does not analyze CloudFormation, CDK, or other IaC tools
- **AWS Focused**: Primarily designed for AWS resources (limited support for other clouds)
- **Static Analysis**: Cannot predict usage-based costs (data transfer, API calls, etc.)
- **No Historical Data**: Each run is independent; no trend analysis
- **List Prices**: Does not account for your specific AWS pricing agreements

## Related Resources

- [Infracost Documentation](https://www.infracost.io/docs/)
- [Infracost GitHub Action](https://github.com/infracost/actions)
- [AWS Pricing Calculator](https://calculator.aws/)
- [Kubecost](https://www.kubecost.com/) - For runtime cost monitoring

## Support

For issues with:
- **This workflow**: Open an issue in this repository
- **Infracost service**: Check [Infracost Community](https://www.infracost.io/community)
- **Cost optimization**: Consult the platform team or review AWS Cost Explorer

## Changelog

### v1.0.0 (Initial Release)
- Automated cost estimation for PRs and feature branches
- Smart labeling based on cost impact
- Detailed cost breakdown by module
- Support for multiple Terraform directories
- Error handling and artifact uploads
