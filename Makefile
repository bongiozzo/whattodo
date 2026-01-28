# Makefile для Текста
#
# Этот репозиторий задуман как хранилище Текста + mkdocs.yml.
# mkdocs.yml описывает структуру Текста, которая определяет сайт и сборку EPUB.
# Сборочная «машинерия» находится в плагине text-forge.

.PHONY: all epub site serve clean help info install

help: ## Show available make targets
	@awk 'BEGIN {FS=":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  make %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies (uv sync)
	uv sync

serve: ## Run local preview server (fast, no EPUB)
	@echo "==> Reinstalling text-forge to update shared-data (templates/JS/CSS)..."
	@uv pip install -e .. --force-reinstall --no-deps --quiet
	@echo "==> Checking for existing mkdocs process..."
	@pkill -f "mkdocs serve" || true
	@sleep 0.5
	cd $(CURDIR) && MKDOCS_GIT_COMMITTERS_ENABLED=false uv run python -m mkdocs serve --config-file=$(CURDIR)/mkdocs.yml

epub: ## Build EPUB only
	uv run text-forge epub --config mkdocs.yml

site: ## Build MkDocs site + EPUB
	uv run text-forge build --config mkdocs.yml

all: ## Build everything (EPUB + site)
	uv run text-forge build --config mkdocs.yml

clean: ## Remove build artifacts
	rm -rf build/ public/

info: ## Show project info
	@uv run text-forge info
	@echo "Content root: $(CURDIR)"
	@echo "Config file: mkdocs.yml"