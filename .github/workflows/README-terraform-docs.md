# Terraform Documentation Workflow

This workflow automatically generates and updates Terraform module documentation using [terraform-docs](https://terraform-docs.io/).

## Overview

The `terraform-docs.yml` workflow discovers all Terraform modules in the `modules/` directory and generates standardized documentation for each module's inputs, outputs, providers, and requirements. The generated documentation is automatically injected into each module's README.md file and committed back to the pull request branch.

## Triggers

The workflow runs on:
- **Pull Requests**: When Terraform files in `modules/` are modified
- **Manual Dispatch**: Can be triggered manually via GitHub Actions UI

## Workflow Jobs

### 1. discover-modules

Discovers all module directories under `modules/` that contain Terraform files.

**Outputs:**
- `modules`: JSON array of module directory paths
- `module_count`: Number of modules discovered

### 2. generate-docs

Runs in parallel for each discovered module using a matrix strategy.

**Steps:**
1. Checkout the PR branch
2. Install terraform-docs CLI
3. Generate documentation using terraform-docs
4. Check for changes in README.md
5. Commit changes if documentation was updated
6. Push changes back to PR branch

**Error Handling:**
- Skips modules without `variables.tf` or `outputs.tf`
- Reports generation errors as PR comments
- Continues processing other modules on failure

### 3. documentation-summary

Summarizes the documentation generation results and posts a comment on the PR.

**Comment Types:**
- **Updated**: Documentation was generated and committed
- **Up to Date**: No changes needed
- **Completed with Errors**: Some modules failed (details in separate comments)
- **No Modules**: No modules found or all skipped

## README Format

Each module's README.md should include terraform-docs injection markers:

```markdown
# Module Name

Module description and usage examples...

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

Additional notes...
```

The content between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` will be automatically generated and updated.

## Generated Documentation Sections

terraform-docs generates the following sections:

1. **Requirements**: Terraform and provider version constraints
2. **Providers**: List of providers used by the module
3. **Modules**: Child modules called by this module
4. **Resources**: AWS resources created by the module
5. **Inputs**: Module variables with descriptions, types, and defaults
6. **Outputs**: Module outputs with descriptions

## Configuration

The workflow uses `.terraform-docs.yml` for consistent formatting:

- **Format**: Markdown tables
- **Sorting**: Variables sorted by required/optional
- **Mode**: Inject (preserves custom content outside markers)
- **Sections**: All sections enabled

## Usage

### For Module Authors

1. Create a README.md in your module directory
2. Add the terraform-docs markers:
   ```markdown
   <!-- BEGIN_TF_DOCS -->
   <!-- END_TF_DOCS -->
   ```
3. Create a PR with your module changes
4. The workflow will automatically generate and commit documentation

### For Reviewers

- Check the "Terraform Documentation" comment on PRs
- Review the generated documentation in module README files
- Verify that variable descriptions are clear and accurate

## Troubleshooting

### Documentation Not Generated

**Cause**: Module missing `variables.tf` or `outputs.tf`

**Solution**: Ensure your module has at least one of these files

### Generation Failed

**Cause**: Invalid Terraform syntax or malformed descriptions

**Solution**: 
1. Check the error comment on the PR
2. Fix the Terraform syntax errors
3. Re-run the workflow

### Changes Not Committed

**Cause**: Workflow permissions or branch protection

**Solution**:
1. Verify workflow has `contents: write` permission
2. Check branch protection rules allow github-actions bot

## Manual Execution

To manually run terraform-docs locally:

```bash
# Install terraform-docs
brew install terraform-docs  # macOS
# or download from https://github.com/terraform-docs/terraform-docs/releases

# Generate docs for a specific module
cd modules/your-module
terraform-docs markdown table --output-file README.md --output-mode inject .

# Generate docs for all modules
for dir in modules/*/; do
  echo "Generating docs for ${dir}"
  terraform-docs markdown table --output-file README.md --output-mode inject "${dir}"
done
```

## Best Practices

1. **Write Clear Descriptions**: Variable and output descriptions appear in generated docs
2. **Use Type Constraints**: Specify accurate types for variables
3. **Document Defaults**: Explain why specific defaults were chosen
4. **Add Examples**: Include usage examples above the terraform-docs markers
5. **Keep It Updated**: Let the workflow handle documentation updates automatically

## Related Files

- `.github/workflows/terraform-docs.yml` - Workflow definition
- `.terraform-docs.yml` - terraform-docs configuration
- `modules/*/README.md` - Module documentation files

## References

- [terraform-docs Documentation](https://terraform-docs.io/)
- [terraform-docs GitHub](https://github.com/terraform-docs/terraform-docs)
- [Markdown Table Format](https://terraform-docs.io/user-guide/output-formats/markdown-table/)
