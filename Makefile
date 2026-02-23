# Makefile для Текста
#
# Этот репозиторий задуман как хранилище Текста + mkdocs.yml.
# mkdocs.yml описывает структуру Текста, которая определяет сайт и сборку EPUB.
# Сборочная «машинерия» находится в плагине text-forge.

.PHONY: all epub site serve clean help info install publish

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
	MKDOCS_GIT_COMMITTERS_ENABLED=false uv run text-forge build --config mkdocs.yml

all: ## Build everything (EPUB + site)
	MKDOCS_GIT_COMMITTERS_ENABLED=false uv run text-forge build --config mkdocs.yml

clean: ## Remove build artifacts
	rm -rf build/ public/

summary: ## Prepare summary source (then run summarize prompt)
	@mkdir -p build
	uv run python ../scripts/mkdocs-combine.py mkdocs.yml \
		--mode summary \
		--exclude p3-summary.md \
		--index-output build/heading_index.json \
		> build/summary_source.md
	@echo "✓ Source prepared: build/summary_source.md + build/heading_index.json"
	@echo "→ Run summarize prompt to generate text/p3-summary.md"

info: ## Show project info
	@uv run text-forge info
	@echo "Content root: $(CURDIR)"
	@echo "Config file: mkdocs.yml"

publish: ## Bump version tag and push to GitHub (triggers CI/CD)
	@if ! git diff --quiet --ignore-submodules=all || ! git diff --cached --quiet --ignore-submodules=all; then \
		echo "Error: You have uncommitted changes. Please commit or stash them before publishing:"; \
		git status --short --ignore-submodules=all; \
		exit 1; \
	fi
	@LATEST=$$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -1); \
	if [ -z "$$LATEST" ]; then \
		echo "Error: No existing version tag found (expected vMAJOR.MINOR.PATCH)"; \
		exit 1; \
	fi; \
	echo "Current: $$LATEST"; \
	MAJOR=$$(echo "$$LATEST" | sed 's/^v\([0-9]*\)\..*/\1/'); \
	MINOR=$$(echo "$$LATEST" | sed 's/^v[0-9]*\.\([0-9]*\)\..*/\1/'); \
	PATCH=$$(echo "$$LATEST" | sed 's/^v[0-9]*\.[0-9]*\.\([0-9]*\)$$/\1/'); \
	echo "Bump [major/minor/patch] (default: patch):"; \
	read -r BUMP; \
	BUMP=$${BUMP:-patch}; \
	case "$$BUMP" in \
		patch) NEW="v$$MAJOR.$$MINOR.$$((PATCH + 1))" ;; \
		minor) NEW="v$$MAJOR.$$((MINOR + 1)).0" ;; \
		major) NEW="v$$((MAJOR + 1)).0.0" ;; \
		*) echo "Error: use major, minor, or patch"; exit 1 ;; \
	esac; \
	echo "New:     $$NEW"; \
	echo "Push tag $$NEW? [y/N]"; \
	read -r CONFIRM; \
	if [ "$$CONFIRM" != "y" ] && [ "$$CONFIRM" != "Y" ]; then \
		echo "Cancelled"; \
		exit 1; \
	fi; \
	git tag -a "$$NEW" -m "Release $$NEW"; \
	git push origin master "$$NEW"; \
	echo "✓ Tag pushed: $$NEW"; \
	if command -v gh >/dev/null 2>&1; then \
		gh release create "$$NEW" --title "$$NEW" --generate-notes; \
		echo "✓ GitHub release created"; \
		echo "→ https://github.com/bongiozzo/whattodo/releases/tag/$$NEW"; \
	else \
		echo "⚠ gh CLI not found — skipping GitHub release creation"; \
		echo "→ https://github.com/bongiozzo/whattodo/releases/tag/$$NEW"; \
	fi