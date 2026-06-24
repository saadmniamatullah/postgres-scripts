.PHONY: lint test setup tune help

SHELL := /bin/bash
SCRIPTS := $(shell find tasks lib -name '*.sh' 2>/dev/null)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

lint: ## Run shellcheck on all scripts
	@shellcheck -x $(SCRIPTS)

test: ## Run all bats tests
	@bats tests/

setup: ## Install PostgreSQL 18 (run as root)
	sudo bash tasks/setup/install.sh

tune: ## Apply OLTP/NVMe tuning (run as root)
	sudo bash tasks/tune/oltp-nvme.sh
