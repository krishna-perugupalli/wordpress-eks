SHELL := /bin/bash
.DEFAULT_GOAL := help

INFRA_DIR := stacks/infra
APP_DIR   := stacks/app

# --------- Helpers ----------
.PHONY: help
help: ## Show this help
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*##' $(MAKEFILE_LIST) | sed -E 's/:.*##/: /' | sort
	@echo ""

.PHONY: fmt
fmt: ## terraform fmt recursively
	@terraform fmt -recursive

.PHONY: lint
lint: ## tflint recursively (if installed)
	@if command -v tflint >/dev/null 2>&1; then \
	  tflint --init >/dev/null 2>&1 || true; \
	  echo "→ tflint $(INFRA_DIR)"; tflint --recursive --chdir="$(INFRA_DIR)"; \
	  echo "→ tflint $(APP_DIR)";   tflint --recursive --chdir="$(APP_DIR)"; \
	else echo "tflint not installed; skipping"; fi

.PHONY: validate-infra
validate-infra: ## terraform validate stacks/infra locally (no backend)
	@cd "$(INFRA_DIR)" && terraform init -backend=false && terraform validate

.PHONY: validate-app
validate-app: ## terraform validate stacks/app locally (no backend)
	@cd "$(APP_DIR)" && terraform init -backend=false && terraform validate

# --------- Local plan/app against TFC backend ----------
.PHONY: plan-infra
plan-infra: ## terraform plan (infra) using TFC backend
	@cd "$(INFRA_DIR)" && terraform init -upgrade && terraform plan

.PHONY: apply-infra
apply-infra: ## terraform apply (infra) using TFC backend
	@cd "$(INFRA_DIR)" && terraform init -upgrade && terraform apply -auto-approve

.PHONY: destroy-infra
destroy-infra: ## terraform destroy (infra)
	@cd "$(INFRA_DIR)" && terraform init -upgrade && terraform destroy -auto-approve

.PHONY: plan-app
plan-app: ## terraform plan (app) using TFC backend
	@cd "$(APP_DIR)" && terraform init -upgrade && terraform plan

.PHONY: apply-app
apply-app: ## terraform apply (app) using TFC backend
	@cd "$(APP_DIR)" && terraform init -upgrade && terraform apply -auto-approve

.PHONY: destroy-app
destroy-app: ## terraform destroy (app)
	@cd "$(APP_DIR)" && terraform init -upgrade && terraform destroy -auto-approve

# Convenience: run both stacks in order
.PHONY: plan-all
plan-all: ## plan infra then app
	@$(MAKE) plan-infra && $(MAKE) plan-app

.PHONY: apply-all
apply-all: ## apply infra then app
	@$(MAKE) apply-infra && $(MAKE) apply-app

# After infra apply succeeds, write kubeconfig from local machine
.PHONY: kubeconfig
kubeconfig: ## aws eks update-kubeconfig using infra outputs (needs local AWS auth)
	@cluster=$$(cd "$(INFRA_DIR)" && terraform output -raw cluster_name); \
	region_out=$$(cd "$(INFRA_DIR)" && terraform output -raw region 2>/dev/null || true); \
	region=$${AWS_REGION:-$${region_out:-eu-north-1}}; \
	echo "Using cluster: $$cluster, region: $$region"; \
	aws eks update-kubeconfig --name "$$cluster" --region "$$region"