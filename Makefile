# Makefile для Текста
#
# Этот репозиторий задуман как хранилище Текста + mkdocs.yml.
# mkdocs.yml описывает структуру Текста, которая определяет сайт и сборку EPUB.
# Сборочная «машинерия» находится в плагине text-forge.
#
# Running `make` with no target shows this help (see `help` target below).

.PHONY: all epub site serve clean help install publish obsidian ingest compass-update changelog grammar
.DEFAULT_GOAL := help

TEXT_FORGE_DIR ?= ../text-forge
SHARED_GOALS_SKILL_DIR ?= ../shared-goals-skill
COMPASS_SCRIPTS ?= $(SHARED_GOALS_SKILL_DIR)/shared-goals/scripts
SHARED_GOALS_ENV_FILE ?= $(CURDIR)/.env
COMPASS_BUILD_DIR ?= build
COMPASS_LOGOS_REMOTE ?=
COMPASS_LOGOS_CONTEXT_PATH ?= $(HOME)/.hermes/skills/shared-goals/shared-goals/state/daily-compass-context.json
HINDSIGHT_WRAPPER ?= $(TEXT_FORGE_DIR)/scripts/hindsight-wtd-ingest-wrapper.py
HINDSIGHT_API_URL ?= http://localhost:8889
HINDSIGHT_BANK ?= hermes
HINDSIGHT_STRATEGY ?= wtd-primary
HINDSIGHT_BATCH_SIZE ?= 25
APPLY ?= no
CHAPTER ?=
SECTION ?=
FROM_COMMIT ?=
SINCE_COMMIT ?=
AFTER_COMMIT ?=
LIMIT ?=
FULL ?= no
INGEST_EXTRA_ARGS ?=

OPENCODE ?= opencode
CHANGELOG_SINCE ?=
GRAMMAR_SINCE ?=

# Allow `make changelog <ref>` / `make grammar <ref>` as a shortcut for CHANGELOG_SINCE=/GRAMMAR_SINCE=
# (an explicit VAR=value on the command line still takes precedence).
ifeq (changelog,$(firstword $(MAKECMDGOALS)))
  CHANGELOG_ARG := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(CHANGELOG_ARG),)
    $(eval $(CHANGELOG_ARG):;@:)
    CHANGELOG_SINCE := $(CHANGELOG_ARG)
  endif
endif
ifeq (grammar,$(firstword $(MAKECMDGOALS)))
  GRAMMAR_ARG := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(GRAMMAR_ARG),)
    $(eval $(GRAMMAR_ARG):;@:)
    GRAMMAR_SINCE := $(GRAMMAR_ARG)
  endif
endif

# Resolve a tag/commit/date (YYYY-MM-DD) to a base ref for diffing since it.
define RESOLVE_SINCE_REF
if git rev-parse --verify --quiet "$(1)^{commit}" >/dev/null 2>&1; then \
	BASE="$(1)"; \
else \
	BASE=$$(git log --oneline --after="$(1)" --reverse -- 'text/*.md' | head -n1 | cut -d' ' -f1); \
	if [ -z "$$BASE" ]; then echo "No commits found after $(1)"; exit 1; fi; \
	BASE="$$BASE^"; \
fi
endef

define ensure_shared_goals_env
set -a; \
if [ -f "$(SHARED_GOALS_ENV_FILE)" ]; then \
	. "$(SHARED_GOALS_ENV_FILE)"; \
fi; \
set +a; \
if [ -z "$${SHARED_GOALS_API_BASE_URL:-}" ] || [ -z "$${SHARED_GOALS_AGENT_KEY_ID:-}" ]; then \
	echo "Set SHARED_GOALS_API_BASE_URL and SHARED_GOALS_AGENT_KEY_ID in $(SHARED_GOALS_ENV_FILE) or export them in shell."; \
	exit 1; \
fi;
endef

help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*?## "}; \
		/^##@/ { printf "\n%s\n", substr($$0, 5); next } \
		/^[a-zA-Z0-9_-]+:.*?##/ { \
			n = split($$2, parts, " \\| "); \
			printf "  make %-12s %s\n", $$1, parts[1]; \
			for (i = 2; i <= n; i++) printf "%20s%s\n", "", parts[i]; \
		}' $(MAKEFILE_LIST)

##@ Environment

install: ## Bootstrap: uv, pandoc, text-forge + shared-goals/skill, uv sync
	@# --- uv ---
	@if command -v uv >/dev/null 2>&1; then \
		echo "  ok    uv $$(uv --version)"; \
	else \
		echo "==> Installing uv..."; \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
		echo "  warn  Restart your shell or run: source $$HOME/.local/bin/env"; \
	fi
	@# --- pandoc ---
	@if command -v pandoc >/dev/null 2>&1; then \
		echo "  ok    $$(pandoc --version | head -n1)"; \
	elif [ "$$(uname -s)" = "Darwin" ]; then \
		echo "==> Installing pandoc via Homebrew..."; \
		brew install pandoc; \
	elif command -v apt-get >/dev/null 2>&1; then \
		echo "==> Installing pandoc via apt-get..."; \
		sudo apt-get update && sudo apt-get install -y pandoc; \
	elif command -v dnf >/dev/null 2>&1; then \
		echo "==> Installing pandoc via dnf..."; \
		sudo dnf install -y pandoc; \
	elif command -v pacman >/dev/null 2>&1; then \
		echo "==> Installing pandoc via pacman..."; \
		sudo pacman -S --noconfirm pandoc; \
	else \
		echo "  warn  pandoc not found. Install from https://pandoc.org/installing.html"; \
	fi
	@# --- text-forge (sibling repo) ---
	@if [ -d "$(TEXT_FORGE_DIR)/.git" ]; then \
		echo "==> Updating text-forge ($(TEXT_FORGE_DIR))..."; \
		git -C "$(TEXT_FORGE_DIR)" pull --ff-only; \
	elif [ -d "$(TEXT_FORGE_DIR)" ]; then \
		echo "  warn  $(TEXT_FORGE_DIR) exists but is not a git repo; skipping update"; \
	else \
		echo "==> Cloning text-forge into $(TEXT_FORGE_DIR)..."; \
		git clone https://github.com/shared-goals/text-forge.git "$(TEXT_FORGE_DIR)"; \
	fi
	@# --- shared-goals/skill (sibling repo) ---
	@if [ -d "$(SHARED_GOALS_SKILL_DIR)/.git" ]; then \
		echo "==> Updating shared-goals/skill ($(SHARED_GOALS_SKILL_DIR))..."; \
		git -C "$(SHARED_GOALS_SKILL_DIR)" pull --ff-only; \
	elif [ -d "$(SHARED_GOALS_SKILL_DIR)" ]; then \
		echo "  warn  $(SHARED_GOALS_SKILL_DIR) exists but is not a git repo; skipping update"; \
	else \
		echo "==> Cloning shared-goals/skill into $(SHARED_GOALS_SKILL_DIR)..."; \
		git clone https://github.com/shared-goals/skill.git "$(SHARED_GOALS_SKILL_DIR)"; \
	fi
	@# --- Python deps ---
	uv sync --upgrade

obsidian: install ## Set up Obsidian: Templater plugin, scripts, hotkeys
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
	@uv run text-forge obsidian install
	@echo "==> Force-updating Templater scripts from text-forge package..."
	@uv run python3 -c "\
import importlib.resources, shutil; \
src = importlib.resources.files('text_forge.obsidian') / 'scripts'; \
[(shutil.copy2(str(src / n), f'obsidian/scripts/{n}'), print(f'  updated obsidian/scripts/{n}')) \
  for n in ('insert_block.js', 'insert_image.js', 'insert_link.js')]"

##@ Build

serve: ## Run local preview server (fast, no EPUB)
	@if [ -f $(TEXT_FORGE_DIR)/text_forge/plugin.py ]; then \
		echo "==> text-forge source detected, reinstalling to pick up local changes..."; \
		uv pip install -e $(TEXT_FORGE_DIR) --force-reinstall --no-deps --quiet; \
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

##@ Content workflows

summary: ## Prepare summary source (then run summarize prompt)
	@mkdir -p build
	uv run python $(TEXT_FORGE_DIR)/scripts/mkdocs-combine.py mkdocs.yml \
		--mode summary \
		--exclude p3-summary.md \
		--index-output build/heading_index.json \
		> build/summary_source.md
	@echo "✓ Source prepared: build/summary_source.md + build/heading_index.json"
	@echo "→ Run summarize prompt to generate text/p3-summary.md"

changelog: ## Russian changelog post since a ref | vars: CHANGELOG_SINCE=<ref> or make changelog <ref>
	@if [ -z "$(CHANGELOG_SINCE)" ]; then \
		echo "Error: set CHANGELOG_SINCE=<tag|commit|date> or run: make changelog <ref>"; \
		exit 1; \
	fi
	@$(call RESOLVE_SINCE_REF,$(CHANGELOG_SINCE)); \
	DIFF=$$(git diff "$$BASE"..HEAD -- 'text/*.md'); \
	if [ -z "$$DIFF" ]; then echo "No changes in text/*.md since $(CHANGELOG_SINCE)"; exit 0; fi; \
	mkdir -p build; \
	echo "$$DIFF" > build/changelog.diff; \
	echo "==> Running opencode changelog prompt (since $(CHANGELOG_SINCE))..."; \
	$(OPENCODE) run \
		"Follow the attached changelog.prompt.md instructions and generate the Telegram post from the attached diff (build/changelog.diff)." \
		-f .github/prompts/changelog.prompt.md -f build/changelog.diff

grammar: ## Grammar check for text/*.md (default: uncommitted diff) | vars: GRAMMAR_SINCE=<ref> or make grammar <ref>
	@if [ -n "$(GRAMMAR_SINCE)" ]; then \
		$(call RESOLVE_SINCE_REF,$(GRAMMAR_SINCE)); \
		DIFF=$$(git diff "$$BASE"..HEAD -- 'text/*.md' | grep '^+' | grep -v '^+++' | sed 's/^+//'); \
	else \
		DIFF=$$(git diff HEAD -- 'text/*.md' | grep '^+' | grep -v '^+++' | sed 's/^+//'); \
	fi; \
	if [ -z "$$DIFF" ]; then echo "No added lines to check."; exit 0; fi; \
	mkdir -p build; \
	echo "$$DIFF" > build/grammar_diff.txt; \
	echo "==> Running opencode grammar check..."; \
	$(OPENCODE) run \
		"Follow the attached grammar.prompt.md instructions and review the added lines in the attached diff (build/grammar_diff.txt)." \
		-f .github/prompts/grammar.prompt.md -f build/grammar_diff.txt

##@ Publishing

ingest: ## WTD -> Hindsight status/ingest | vars: FROM_COMMIT / SINCE_COMMIT / AFTER_COMMIT=<ref> | vars: CHAPTER=<slug> [SECTION=<anchor>] or FULL=yes | vars: APPLY=yes to write (default: preview)
	@if [ ! -f "$(HINDSIGHT_WRAPPER)" ]; then \
		echo "Error: canonical wrapper not found: $(HINDSIGHT_WRAPPER)"; \
		exit 1; \
	fi
	@ARGS="--root $(CURDIR) --api-url $(HINDSIGHT_API_URL) --bank $(HINDSIGHT_BANK) --strategy $(HINDSIGHT_STRATEGY) --batch-size $(HINDSIGHT_BATCH_SIZE)"; \
	if [ "$(APPLY)" = "yes" ]; then ARGS="$$ARGS --yes"; MODE="live ingest"; else MODE="preview"; fi; \
	if [ -n "$(FROM_COMMIT)" ]; then ARGS="$$ARGS --from-commit $(FROM_COMMIT)"; fi; \
	if [ -n "$(SINCE_COMMIT)" ]; then ARGS="$$ARGS --since-commit $(SINCE_COMMIT)"; fi; \
	if [ -n "$(AFTER_COMMIT)" ]; then ARGS="$$ARGS --after-commit $(AFTER_COMMIT)"; fi; \
	if [ -n "$(CHAPTER)" ]; then ARGS="$$ARGS --chapter $(CHAPTER)"; fi; \
	if [ -n "$(SECTION)" ]; then ARGS="$$ARGS --section $(SECTION)"; fi; \
	if [ "$(FULL)" = "yes" ]; then \
		if [ -n "$(FROM_COMMIT)$(SINCE_COMMIT)$(AFTER_COMMIT)$(CHAPTER)$(SECTION)" ]; then \
			echo "Error: FULL=yes cannot be combined with FROM_COMMIT/SINCE_COMMIT/AFTER_COMMIT/CHAPTER/SECTION"; \
			exit 1; \
		fi; \
		ARGS="$$ARGS --all"; \
	fi; \
	if [ -n "$(FROM_COMMIT)$(SINCE_COMMIT)$(AFTER_COMMIT)" ] && [ -n "$(CHAPTER)$(SECTION)" ]; then \
		echo "Error: do not combine commit/diff mode with CHAPTER/SECTION filters"; \
		exit 1; \
	fi; \
	if [ -n "$(LIMIT)" ]; then ARGS="$$ARGS --limit $(LIMIT)"; fi; \
	echo "==> Hindsight $$MODE"; \
	env -u VIRTUAL_ENV uv run python "$(HINDSIGHT_WRAPPER)" $$ARGS $(INGEST_EXTRA_ARGS); \
	if [ -z "$(FROM_COMMIT)$(SINCE_COMMIT)$(AFTER_COMMIT)$(CHAPTER)$(SECTION)" ] && [ "$(FULL)" != "yes" ]; then \
		printf '\nNothing selected. Choose a scope:\n'; \
		printf '  make ingest AFTER_COMMIT=<ref>        # commits after <ref> (use last ingested commit)\n'; \
		printf '  make ingest SINCE_COMMIT=<ref>        # <ref> and everything after it\n'; \
		printf '  make ingest FROM_COMMIT=<ref>         # changes of one commit\n'; \
		printf '  make ingest CHAPTER=<slug>            # one chapter\n'; \
		printf '  make ingest CHAPTER=<slug> SECTION=<anchor>  # one section\n'; \
		printf '  make ingest FULL=yes                  # whole corpus (rare)\n'; \
		printf '\nModifiers:\n'; \
		printf '  APPLY=yes   write to Hindsight (default: preview)\n'; \
		printf '  LIMIT=N     cap processed chunks\n'; \
		printf '\nRemove ingested data (direct script, dry-run without --yes):\n'; \
		printf '  uv run python $(TEXT_FORGE_DIR)/scripts/hindsight-wipe-documents-by-tag.py \\\n'; \
		printf '    --api-url $(HINDSIGHT_API_URL) --bank $(HINDSIGHT_BANK) --tag wtd --tag current\n'; \
		printf '  add --tag chapter:<slug> to narrow, --yes to delete\n'; \
	fi

compass-update: ## Compass.md -> Shared Goals status/update | uses .env: SHARED_GOALS_API_BASE_URL, SHARED_GOALS_AGENT_KEY_ID, OBSIDIAN_VAULT_PATH
	@if [ ! -f "$(COMPASS_SCRIPTS)/compass-update.py" ]; then \
		echo "Error: Shared Goals skill script not found: $(COMPASS_SCRIPTS)/compass-update.py"; \
		echo "Run: make install"; \
		exit 1; \
	fi
	@set -e; \
	$(ensure_shared_goals_env) \
	mkdir -p "$(COMPASS_BUILD_DIR)"; \
	COMPASS_MD="$${OBSIDIAN_VAULT_PATH:-$(HOME)}/Compass.md"; \
	LOGOS_REMOTE="$${COMPASS_LOGOS_REMOTE:-$(COMPASS_LOGOS_REMOTE)}"; \
	LOGOS_ARGS=""; \
	if [ -n "$$LOGOS_REMOTE" ]; then \
		if ssh "$$LOGOS_REMOTE" 'test -f "$${HOME}/.hermes/skills/shared-goals/shared-goals/state/daily-compass-context.json"'; then \
			ssh "$$LOGOS_REMOTE" 'cat "$${HOME}/.hermes/skills/shared-goals/shared-goals/state/daily-compass-context.json"' > "$(COMPASS_BUILD_DIR)/daily-compass-context.json"; \
			LOGOS_ARGS="--logos-context $(COMPASS_BUILD_DIR)/daily-compass-context.json"; \
		fi; \
	elif [ -f "$(COMPASS_LOGOS_CONTEXT_PATH)" ]; then \
		LOGOS_ARGS="--logos-context $(COMPASS_LOGOS_CONTEXT_PATH)"; \
	fi; \
	if command -v uv >/dev/null 2>&1; then \
		uv --project "$(SHARED_GOALS_SKILL_DIR)" run python "$(COMPASS_SCRIPTS)/compass-update.py" --compass-path "$$COMPASS_MD" $$LOGOS_ARGS; \
	else \
		python3 "$(COMPASS_SCRIPTS)/compass-update.py" --compass-path "$$COMPASS_MD" $$LOGOS_ARGS; \
	fi

publish: ## Interactive publish: optional commit, tag, push
	@TAG_CREATED="no"; \
	NEW_TAG=""; \
	BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if ! git diff --quiet --ignore-submodules=all || ! git diff --cached --quiet --ignore-submodules=all; then \
		echo "Working tree is dirty:"; \
		git status --short --ignore-submodules=all; \
		echo "Enter commit message (type 'no' to abort publish):"; \
		read -r COMMIT_MSG; \
		if [ "$$COMMIT_MSG" = "no" ] || [ "$$COMMIT_MSG" = "NO" ] || [ "$$COMMIT_MSG" = "No" ]; then \
			echo "Publish aborted."; \
			exit 1; \
		fi; \
		if [ -z "$$COMMIT_MSG" ]; then \
			echo "Error: commit message cannot be empty"; \
			exit 1; \
		fi; \
		git add -A; \
		git commit -m "$$COMMIT_MSG"; \
	fi; \
	echo "Create and push a version tag? [y/N]"; \
	read -r DO_TAG; \
	case "$$DO_TAG" in \
		y|Y|yes|YES) \
			LATEST=$$(git tag --sort=-version:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' | head -1); \
			if [ -z "$$LATEST" ]; then \
				LATEST="v0.0.0"; \
			fi; \
			echo "Current: $$LATEST"; \
			MAJOR=$$(echo "$$LATEST" | sed 's/^v\([0-9]*\)\..*/\1/'); \
			MINOR=$$(echo "$$LATEST" | sed 's/^v[0-9]*\.\([0-9]*\)\..*/\1/'); \
			PATCH=$$(echo "$$LATEST" | sed 's/^v[0-9]*\.[0-9]*\.\([0-9]*\)$$/\1/'); \
			echo "Version bump [major/minor/patch] (default: patch):"; \
			read -r BUMP; \
			BUMP=$${BUMP:-patch}; \
			case "$$BUMP" in \
				patch) NEW_TAG="v$$MAJOR.$$MINOR.$$((PATCH + 1))" ;; \
				minor) NEW_TAG="v$$MAJOR.$$((MINOR + 1)).0" ;; \
				major) NEW_TAG="v$$((MAJOR + 1)).0.0" ;; \
				*) echo "Error: use major, minor, or patch"; exit 1 ;; \
			esac; \
			echo "New tag: $$NEW_TAG"; \
			if git rev-parse -q --verify "refs/tags/$$NEW_TAG" >/dev/null; then \
				echo "Error: tag $$NEW_TAG already exists"; \
				exit 1; \
			fi; \
			git tag -a "$$NEW_TAG" -m "Release $$NEW_TAG"; \
			TAG_CREATED="yes"; \
			;; \
		*) \
			echo "Skipping tag creation."; \
			;; \
	esac; \
	echo "Push branch $$BRANCH to origin? [y/N]"; \
	read -r DO_PUSH; \
	case "$$DO_PUSH" in \
		y|Y|yes|YES) \
			if [ "$$TAG_CREATED" = "yes" ]; then \
				git push origin "$$BRANCH" "$$NEW_TAG"; \
				echo "Tag pushed: $$NEW_TAG"; \
				if command -v gh >/dev/null 2>&1; then \
					gh release create "$$NEW_TAG" --title "$$NEW_TAG" --generate-notes; \
					echo "GitHub release created: https://github.com/bongiozzo/whattodo/releases/tag/$$NEW_TAG"; \
				else \
					echo "gh CLI not found; skipped GitHub release creation"; \
				fi; \
			else \
				git push origin "$$BRANCH"; \
			fi; \
			echo "Publish completed."; \
			;; \
		*) \
			echo "Push skipped."; \
			;; \
	esac