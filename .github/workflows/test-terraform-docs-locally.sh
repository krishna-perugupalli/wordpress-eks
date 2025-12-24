#!/bin/bash
#
# Local Test Script for Terraform Documentation Workflow
# This simulates the GitHub Actions workflow locally for testing
#
# Usage:
#   ./test-terraform-docs-locally.sh [--dry-run] [--module <module-name>]
#
# Options:
#   --dry-run         Show what would be done without making changes
#   --module <name>   Test only a specific module (e.g., modules/aws-auth)
#   --help            Show this help message
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DOCS_VERSION="v0.18.0"
DRY_RUN=false
SPECIFIC_MODULE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --module)
      SPECIFIC_MODULE="$2"
      shift 2
      ;;
    --help)
      head -n 15 "$0" | tail -n 13
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}=================================================="
echo "🧪 Terraform Documentation Local Test"
echo -e "==================================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "modules" ]; then
  echo -e "${RED}❌ Error: modules/ directory not found${NC}"
  echo "Please run this script from the repository root"
  exit 1
fi

# Check if terraform-docs is installed
if ! command -v terraform-docs &> /dev/null; then
  echo -e "${YELLOW}⚠️  terraform-docs not found, installing...${NC}"
  
  # Detect OS
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  
  case $ARCH in
    x86_64)
      ARCH="amd64"
      ;;
    arm64|aarch64)
      ARCH="arm64"
      ;;
  esac
  
  echo "Downloading terraform-docs ${TERRAFORM_DOCS_VERSION} for ${OS}-${ARCH}..."
  
  DOWNLOAD_URL="https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-${OS}-${ARCH}.tar.gz"
  
  curl -sSLo /tmp/terraform-docs.tar.gz "$DOWNLOAD_URL"
  tar -xzf /tmp/terraform-docs.tar.gz -C /tmp
  chmod +x /tmp/terraform-docs
  
  # Try to move to /usr/local/bin, fallback to current directory
  if sudo mv /tmp/terraform-docs /usr/local/bin/ 2>/dev/null; then
    echo -e "${GREEN}✅ Installed terraform-docs to /usr/local/bin/${NC}"
  else
    mv /tmp/terraform-docs ./terraform-docs
    export PATH=".:$PATH"
    echo -e "${GREEN}✅ Installed terraform-docs to current directory${NC}"
  fi
  
  rm -f /tmp/terraform-docs.tar.gz
fi

echo -e "${GREEN}✅ terraform-docs version: $(terraform-docs --version)${NC}"
echo ""

# Check git status
if [ "$DRY_RUN" = false ]; then
  if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠️  Warning: You have uncommitted changes${NC}"
    echo "The script will modify README files. Consider committing or stashing your changes first."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 1
    fi
  fi
fi

echo -e "${BLUE}=================================================="
echo "📦 Discovering Modules"
echo -e "==================================================${NC}"
echo ""

# Find modules
if [ -n "$SPECIFIC_MODULE" ]; then
  if [ ! -d "$SPECIFIC_MODULE" ]; then
    echo -e "${RED}❌ Error: Module not found: $SPECIFIC_MODULE${NC}"
    exit 1
  fi
  module_dirs="$SPECIFIC_MODULE"
  echo "Testing specific module: $SPECIFIC_MODULE"
else
  module_dirs=$(find modules -mindepth 1 -maxdepth 1 -type d | sort)
fi

module_count=$(echo "$module_dirs" | wc -l | tr -d ' ')
echo -e "${GREEN}Found ${module_count} module(s)${NC}"
echo ""

# Counters
updated_count=0
failed_count=0
skipped_count=0
unchanged_count=0

updated_modules=()
failed_modules=()
skipped_modules=()
unchanged_modules=()

# Process each module
for module_dir in $module_dirs; do
  echo -e "${BLUE}=================================================="
  echo "📝 Processing: ${module_dir}"
  echo -e "==================================================${NC}"
  
  # Check if module has required files
  if [ ! -f "${module_dir}/variables.tf" ] && [ ! -f "${module_dir}/outputs.tf" ]; then
    echo -e "${YELLOW}⏭️  Skipping - no variables.tf or outputs.tf${NC}"
    skipped_count=$((skipped_count + 1))
    skipped_modules+=("$module_dir")
    echo ""
    continue
  fi
  
  # Check if README exists and has markers
  if [ ! -f "${module_dir}/README.md" ]; then
    echo -e "${YELLOW}⚠️  No README.md found${NC}"
    echo "Creating README.md with terraform-docs markers..."
    
    if [ "$DRY_RUN" = false ]; then
      cat > "${module_dir}/README.md" <<EOF
# $(basename "$module_dir") Module

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
EOF
      echo -e "${GREEN}✅ Created README.md${NC}"
    else
      echo -e "${YELLOW}[DRY RUN] Would create README.md${NC}"
    fi
  fi
  
  # Check for terraform-docs markers
  if ! grep -q "<!-- BEGIN_TF_DOCS -->" "${module_dir}/README.md" || \
     ! grep -q "<!-- END_TF_DOCS -->" "${module_dir}/README.md"; then
    echo -e "${YELLOW}⚠️  README.md missing terraform-docs markers${NC}"
    echo "Add these markers to your README.md:"
    echo "  <!-- BEGIN_TF_DOCS -->"
    echo "  <!-- END_TF_DOCS -->"
    skipped_count=$((skipped_count + 1))
    skipped_modules+=("$module_dir")
    echo ""
    continue
  fi
  
  # Save original README for comparison
  cp "${module_dir}/README.md" "/tmp/readme-before-$$.md"
  
  # Generate documentation
  cd "${module_dir}"
  
  if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN] Would run: terraform-docs markdown table --output-file README.md --output-mode inject${NC}"
    cd - > /dev/null
    echo ""
    continue
  fi
  
  if terraform-docs markdown table \
    --output-file README.md \
    --output-mode inject \
    --sort-by required \
    --header-from main.tf \
    . 2>&1; then
    
    cd - > /dev/null
    
    # Check if README was modified
    if ! diff -q "${module_dir}/README.md" "/tmp/readme-before-$$.md" > /dev/null 2>&1; then
      echo -e "${GREEN}✅ Documentation updated${NC}"
      updated_count=$((updated_count + 1))
      updated_modules+=("$module_dir")
      
      # Show diff
      echo ""
      echo "Changes:"
      diff -u "/tmp/readme-before-$$.md" "${module_dir}/README.md" | head -n 50 || true
      echo ""
    else
      echo -e "${BLUE}ℹ️  No changes needed${NC}"
      unchanged_count=$((unchanged_count + 1))
      unchanged_modules+=("$module_dir")
    fi
  else
    cd - > /dev/null
    echo -e "${RED}❌ Failed to generate documentation${NC}"
    failed_count=$((failed_count + 1))
    failed_modules+=("$module_dir")
  fi
  
  rm -f "/tmp/readme-before-$$.md"
  echo ""
done

# Summary
echo -e "${BLUE}=================================================="
echo "📊 Summary"
echo -e "==================================================${NC}"
echo ""
echo "Total modules:    ${module_count}"
echo -e "${GREEN}✅ Updated:       ${updated_count}${NC}"
echo -e "${BLUE}ℹ️  Unchanged:     ${unchanged_count}${NC}"
echo -e "${YELLOW}⏭️  Skipped:       ${skipped_count}${NC}"
echo -e "${RED}❌ Failed:        ${failed_count}${NC}"
echo ""

if [ ${#updated_modules[@]} -gt 0 ]; then
  echo -e "${GREEN}Updated modules:${NC}"
  for module in "${updated_modules[@]}"; do
    echo "  - $module"
  done
  echo ""
fi

if [ ${#skipped_modules[@]} -gt 0 ]; then
  echo -e "${YELLOW}Skipped modules:${NC}"
  for module in "${skipped_modules[@]}"; do
    echo "  - $module"
  done
  echo ""
fi

if [ ${#failed_modules[@]} -gt 0 ]; then
  echo -e "${RED}Failed modules:${NC}"
  for module in "${failed_modules[@]}"; do
    echo "  - $module"
  done
  echo ""
fi

# Git status
if [ "$DRY_RUN" = false ] && [ ${updated_count} -gt 0 ]; then
  echo -e "${BLUE}=================================================="
  echo "📋 Git Status"
  echo -e "==================================================${NC}"
  echo ""
  git status --short modules/*/README.md
  echo ""
  
  echo -e "${YELLOW}Next steps:${NC}"
  echo "1. Review the changes: git diff modules/*/README.md"
  echo "2. Commit the changes: git add modules/*/README.md"
  echo "3. Create commit: git commit -m 'docs: update terraform-docs for ${updated_count} module(s)'"
  echo "4. Push to branch: git push origin $(git branch --show-current)"
  echo ""
fi

# Exit code
if [ ${failed_count} -gt 0 ]; then
  echo -e "${RED}⚠️  Some modules failed. Please review the errors above.${NC}"
  exit 1
elif [ ${updated_count} -gt 0 ]; then
  echo -e "${GREEN}✅ Documentation generation completed successfully!${NC}"
  exit 0
else
  echo -e "${BLUE}ℹ️  All documentation is up to date.${NC}"
  exit 0
fi
