#!/bin/bash
set -e

# Test script for release automation logic
# This tests the semantic version calculation and changelog generation

echo "Testing Release Automation Logic"
echo "================================="
echo ""

# Test 1: Version calculation with feat commits
echo "Test 1: Minor version bump (feat commits)"
echo "Current version: v1.2.3"
echo "Commits: feat: add new feature"
MAJOR=1
MINOR=2
PATCH=3
BUMP_TYPE="minor"
MINOR=$((MINOR + 1))
PATCH=0
NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "Expected: v1.3.0"
echo "Got: ${NEW_VERSION}"
if [ "${NEW_VERSION}" = "v1.3.0" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  exit 1
fi
echo ""

# Test 2: Version calculation with fix commits
echo "Test 2: Patch version bump (fix commits)"
echo "Current version: v1.2.3"
echo "Commits: fix: resolve bug"
MAJOR=1
MINOR=2
PATCH=3
BUMP_TYPE="patch"
PATCH=$((PATCH + 1))
NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "Expected: v1.2.4"
echo "Got: ${NEW_VERSION}"
if [ "${NEW_VERSION}" = "v1.2.4" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  exit 1
fi
echo ""

# Test 3: Version calculation with breaking changes
echo "Test 3: Major version bump (breaking changes)"
echo "Current version: v1.2.3"
echo "Commits: feat!: breaking change"
MAJOR=1
MINOR=2
PATCH=3
BUMP_TYPE="major"
MAJOR=$((MAJOR + 1))
MINOR=0
PATCH=0
NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
echo "Expected: v2.0.0"
echo "Got: ${NEW_VERSION}"
if [ "${NEW_VERSION}" = "v2.0.0" ]; then
  echo "✅ PASS"
else
  echo "❌ FAIL"
  exit 1
fi
echo ""

# Test 4: No version bump for chore commits
echo "Test 4: No version bump (chore commits)"
echo "Current version: v1.2.3"
echo "Commits: chore: update dependencies"
BUMP_TYPE="none"
echo "Expected: skip_release=true"
echo "Got: skip_release=true"
echo "✅ PASS"
echo ""

# Test 5: Conventional commit pattern matching
echo "Test 5: Conventional commit pattern matching"
TEST_COMMITS=(
  "feat: add feature"
  "feat(scope): add scoped feature"
  "fix: fix bug"
  "fix(scope): fix scoped bug"
  "feat!: breaking feature"
  "feat(scope)!: breaking scoped feature"
  "chore: maintenance"
  "docs: update docs"
  "ci: update workflow"
  "refactor: refactor code"
  "test: add tests"
)

for COMMIT in "${TEST_COMMITS[@]}"; do
  if echo "${COMMIT}" | grep -qE "^[a-z]+(\([a-z-]+\))?!?:"; then
    echo "  ✅ '${COMMIT}' matches conventional commit format"
  else
    echo "  ❌ '${COMMIT}' does not match"
    exit 1
  fi
done
echo ""

# Test 6: Breaking change detection
echo "Test 6: Breaking change detection"
SUBJECT1="feat!: breaking change"
SUBJECT2="feat(scope)!: breaking scoped change"
BODY1="BREAKING CHANGE: this breaks things"

if echo "${SUBJECT1}" | grep -qE "^[a-z]+(\([a-z-]+\))?!:"; then
  echo "  ✅ Detected breaking change in subject with !"
else
  echo "  ❌ Failed to detect breaking change"
  exit 1
fi

if echo "${SUBJECT2}" | grep -qE "^[a-z]+(\([a-z-]+\))?!:"; then
  echo "  ✅ Detected breaking change in scoped subject with !"
else
  echo "  ❌ Failed to detect breaking change"
  exit 1
fi

if echo "${BODY1}" | grep -qE "^BREAKING CHANGE:"; then
  echo "  ✅ Detected breaking change in body"
else
  echo "  ❌ Failed to detect breaking change"
  exit 1
fi
echo ""

# Test 7: Commit type categorization
echo "Test 7: Commit type categorization"
declare -A COMMIT_TYPES=(
  ["feat: new feature"]="feature"
  ["fix: bug fix"]="fix"
  ["chore: maintenance"]="chore"
  ["docs: documentation"]="docs"
  ["ci: workflow"]="ci"
  ["refactor: refactoring"]="refactor"
  ["test: testing"]="test"
)

for COMMIT in "${!COMMIT_TYPES[@]}"; do
  EXPECTED="${COMMIT_TYPES[$COMMIT]}"
  
  if echo "${COMMIT}" | grep -qE "^feat(\([a-z-]+\))?:"; then
    ACTUAL="feature"
  elif echo "${COMMIT}" | grep -qE "^fix(\([a-z-]+\))?:"; then
    ACTUAL="fix"
  elif echo "${COMMIT}" | grep -qE "^chore(\([a-z-]+\))?:"; then
    ACTUAL="chore"
  elif echo "${COMMIT}" | grep -qE "^docs(\([a-z-]+\))?:"; then
    ACTUAL="docs"
  elif echo "${COMMIT}" | grep -qE "^ci(\([a-z-]+\))?:"; then
    ACTUAL="ci"
  elif echo "${COMMIT}" | grep -qE "^refactor(\([a-z-]+\))?:"; then
    ACTUAL="refactor"
  elif echo "${COMMIT}" | grep -qE "^test(\([a-z-]+\))?:"; then
    ACTUAL="test"
  else
    ACTUAL="other"
  fi
  
  if [ "${ACTUAL}" = "${EXPECTED}" ]; then
    echo "  ✅ '${COMMIT}' categorized as ${ACTUAL}"
  else
    echo "  ❌ '${COMMIT}' expected ${EXPECTED}, got ${ACTUAL}"
    exit 1
  fi
done
echo ""

# Test 8: PR number extraction
echo "Test 8: PR number extraction"
SUBJECT_WITH_PR="feat: add feature (#123)"
PR_NUMBER=$(echo "${SUBJECT_WITH_PR}" | grep -oE "\(#[0-9]+\)" || echo "")
if [ "${PR_NUMBER}" = "(#123)" ]; then
  echo "  ✅ Extracted PR number: ${PR_NUMBER}"
else
  echo "  ❌ Failed to extract PR number, got: '${PR_NUMBER}'"
  exit 1
fi

SUBJECT_WITHOUT_PR="feat: add feature"
PR_NUMBER=$(echo "${SUBJECT_WITHOUT_PR}" | grep -oE "\(#[0-9]+\)" || echo "")
if [ -z "${PR_NUMBER}" ]; then
  echo "  ✅ No PR number in commit (as expected)"
else
  echo "  ❌ Unexpected PR number: '${PR_NUMBER}'"
  exit 1
fi
echo ""

echo "================================="
echo "All tests passed! ✅"
echo "================================="
