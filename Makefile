# Makefile для Текста
#
# Этот репозиторий задуман как хранилище Текста + mkdocs.yml.
# mkdocs.yml описывает структуру Текста, которая определяет сайт и сборку EPUB.
# Сборочная «машинерия» находится в плагине text-forge.

.PHONY: all epub site serve clean help info install publish obsidian

help: ## Show available make targets
	@awk 'BEGIN {FS=":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  make %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies (uv sync)
	uv sync

serve: ## Run local preview server (fast, no EPUB)
	@if [ -f ../text_forge/plugin.py ]; then \
		echo "==> text-forge source detected, reinstalling to pick up local changes..."; \
		uv pip install -e .. --force-reinstall --no-deps --quiet; \
	fi
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

obsidian: ## Set up Obsidian: install Templater plugin, configure templates/scripts/hotkeys
	@mkdir -p .obsidian/plugins/templater-obsidian
	@if [ -f .obsidian/plugins/templater-obsidian/main.js ]; then \
		echo "  skip  Templater plugin already installed (.obsidian/plugins/templater-obsidian/main.js exists)"; \
	else \
		echo "==> Downloading Templater plugin (latest release)..."; \
		curl -fsSL https://api.github.com/repos/SilentVoid13/Templater/releases/latest \
			| python3 -c "\
import sys, json, urllib.request; \
assets = {a['name']: a['browser_download_url'] for a in json.load(sys.stdin)['assets']}; \
[(open('.obsidian/plugins/templater-obsidian/' + n, 'wb').write(urllib.request.urlopen(assets[n]).read()), print('  Downloaded', n)) \
  for n in ('main.js', 'manifest.json', 'styles.css') if n in assets]"; \
	fi
	@if [ -f .obsidian/plugins/templater-obsidian/data.json ]; then \
		echo "  skip  Templater settings already exist (.obsidian/plugins/templater-obsidian/data.json)"; \
	else \
		echo "==> Writing Templater settings (templates: obsidian/templates, scripts: obsidian/scripts)..."; \
		cp obsidian/templater.json .obsidian/plugins/templater-obsidian/data.json; \
	fi
	@if [ -f .obsidian/community-plugins.json ]; then \
		if python3 -c "import sys,json; p=json.load(open('.obsidian/community-plugins.json')); sys.exit(0 if 'templater-obsidian' in p else 1)" 2>/dev/null; then \
			echo "  skip  Templater already listed in .obsidian/community-plugins.json"; \
		else \
			echo "==> Adding Templater to community plugins..."; \
			python3 -c "import json; f='.obsidian/community-plugins.json'; p=json.load(open(f)); p.append('templater-obsidian'); open(f,'w').write(json.dumps(p, indent=2))"; \
		fi \
	else \
		echo "==> Creating .obsidian/community-plugins.json..."; \
		echo '["templater-obsidian"]' > .obsidian/community-plugins.json; \
	fi
	@if [ -f .obsidian/hotkeys.json ]; then \
		echo "==> Merging hotkeys (adding any missing entries)..."; \
		python3 -c "\
import json, sys; \
src = json.load(open('obsidian/hotkeys.json')); \
dst_file = '.obsidian/hotkeys.json'; \
dst = json.load(open(dst_file)); \
added = [k for k in src if k not in dst]; \
[dst.update({k: src[k]}) for k in added]; \
open(dst_file, 'w').write(json.dumps(dst, indent=2, ensure_ascii=False)); \
print('  added:', ', '.join(added) if added else '(none, all present)')"; \
	else \
		echo "==> Copying hotkeys (Mod+Shift+B/I/L → insert_block/insert_image/insert_link)..."; \
		cp obsidian/hotkeys.json .obsidian/hotkeys.json; \
	fi
	@echo "✓ Obsidian setup complete. Restart Obsidian (or reload plugins) to apply."

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