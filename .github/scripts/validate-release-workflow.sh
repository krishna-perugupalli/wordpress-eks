#!/bin/bash
set -e

echo "Validating Release Workflow"
echo "============================"
echo ""

WORKFLOW_FILE=".github/workflows/release.yml"

# Check if workflow file exists
if [ ! -f "${WORKFLOW_FILE}" ]; then
  echo "❌ Workflow file not found: ${WORKFLOW_FILE}"
  exit 1
fi
echo "✅ Workflow file exists"

# Check for required workflow components
echo ""
echo "Checking workflow structure..."

# Check for workflow name
if grep -q "^name: Release Automation" "${WORKFLOW_FILE}"; then
  echo "✅ Workflow name defined"
else
  echo "❌ Workflow name missing"
  exit 1
fi

# Check for triggers
if grep -q "on:" "${WORKFLOW_FILE}"; then
  echo "✅ Workflow triggers defined"
else
  echo "❌ Workflow triggers missing"
  exit 1
fi

# Check for push trigger on main
if grep -A 3 "on:" "${WORKFLOW_FILE}" | grep -q "main"; then
  echo "✅ Push trigger on main branch configured"
else
  echo "❌ Push trigger on main branch missing"
  exit 1
fi

# Check for manual workflow dispatch
if grep -q "workflow_dispatch:" "${WORKFLOW_FILE}"; then
  echo "✅ Manual workflow dispatch configured"
else
  echo "❌ Manual workflow dispatch missing"
  exit 1
fi

# Check for semantic-release job
if grep -q "semantic-release:" "${WORKFLOW_FILE}"; then
  echo "✅ Semantic release job defined"
else
  echo "❌ Semantic release job missing"
  exit 1
fi

# Check for required steps
REQUIRED_STEPS=(
  "Checkout repository"
  "Get latest tag"
  "Get commits since last release"
  "Calculate semantic version"
  "Generate changelog"
  "Create Git tag"
  "Create GitHub Release"
)

for STEP in "${REQUIRED_STEPS[@]}"; do
  if grep -q "name: ${STEP}" "${WORKFLOW_FILE}"; then
    echo "✅ Step found: ${STEP}"
  else
    echo "❌ Step missing: ${STEP}"
    exit 1
  fi
done

# Check for conventional commit patterns
echo ""
echo "Checking conventional commit support..."

if grep -q "feat:" "${WORKFLOW_FILE}"; then
  echo "✅ Feature commit detection"
fi

if grep -q "fix:" "${WORKFLOW_FILE}"; then
  echo "✅ Fix commit detection"
fi

if grep -q "BREAKING CHANGE:" "${WORKFLOW_FILE}"; then
  echo "✅ Breaking change detection"
fi

# Check for version calculation logic
echo ""
echo "Checking version calculation logic..."

if grep -q "MAJOR" "${WORKFLOW_FILE}" && \
   grep -q "MINOR" "${WORKFLOW_FILE}" && \
   grep -q "PATCH" "${WORKFLOW_FILE}"; then
  echo "✅ Semantic version components (MAJOR.MINOR.PATCH)"
else
  echo "❌ Semantic version components missing"
  exit 1
fi

# Check for changelog generation
echo ""
echo "Checking changelog generation..."

if grep -q "CHANGELOG" "${WORKFLOW_FILE}"; then
  echo "✅ Changelog generation logic present"
else
  echo "❌ Changelog generation missing"
  exit 1
fi

# Check for changelog sections
CHANGELOG_SECTIONS=(
  "BREAKING CHANGES"
  "Features"
  "Bug Fixes"
)

for SECTION in "${CHANGELOG_SECTIONS[@]}"; do
  if grep -q "${SECTION}" "${WORKFLOW_FILE}"; then
    echo "✅ Changelog section: ${SECTION}"
  fi
done

# Check for Git operations
echo ""
echo "Checking Git operations..."

if grep -q "git tag" "${WORKFLOW_FILE}"; then
  echo "✅ Git tag creation"
else
  echo "❌ Git tag creation missing"
  exit 1
fi

if grep -q "git push" "${WORKFLOW_FILE}"; then
  echo "✅ Git push operation"
else
  echo "❌ Git push operation missing"
  exit 1
fi

# Check for GitHub Release creation
echo ""
echo "Checking GitHub Release creation..."

if grep -q "softprops/action-gh-release" "${WORKFLOW_FILE}"; then
  echo "✅ GitHub Release action configured"
else
  echo "❌ GitHub Release action missing"
  exit 1
fi

# Check for permissions
echo ""
echo "Checking permissions..."

if grep -q "permissions:" "${WORKFLOW_FILE}"; then
  echo "✅ Workflow permissions defined"
  
  if grep -A 5 "permissions:" "${WORKFLOW_FILE}" | grep -q "contents: write"; then
    echo "✅ Contents write permission (required for tags/releases)"
  else
    echo "❌ Contents write permission missing"
    exit 1
  fi
else
  echo "❌ Workflow permissions missing"
  exit 1
fi

echo ""
echo "============================"
echo "✅ All validation checks passed!"
echo "============================"
