config {
  # Enable module inspection (v0.54.0+ syntax)
  call_module_type = "all"
  
  # Force provider installation
  force = false
  
  # Disable rules by default, then enable specific ones
  disabled_by_default = false
}

# AWS plugin for AWS-specific rules
plugin "aws" {
  enabled = true
  version = "0.32.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Terraform core rules - don't use preset, configure rules individually
plugin "terraform" {
  enabled = true
}

# DISABLED: Unused declarations warnings
# These variables/locals are intentionally kept for future use or backward compatibility
rule "terraform_unused_declarations" {
  enabled = false
}

# ENABLED: Critical rules that catch real issues
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

# DISABLED: Documentation rules - can enable later for stricter requirements
rule "terraform_documented_variables" {
  enabled = false
}

rule "terraform_documented_outputs" {
  enabled = false
}
