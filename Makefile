# Makefile для Текста
#
# Этот репозиторий задуман как хранилище Текста + mkdocs.yml.
# mkdocs.yml описывает структуру Текста, которая определяет сайт и сборку EPUB.
# Сборочная «машинерия» находится в плагине text-forge.
#
# Running `make` with no target shows this help (see `help` target below).

.PHONY: all epub site serve clean help install publish obsidian ingest compass-update grammar books
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
COMMIT ?=
SINCE ?=
AFTER ?=
LIMIT ?=
FULL ?= no
INGEST_EXTRA_ARGS ?=

# Prompt jobs (grammar) run through pi — the harness used everywhere.
# Each target takes <TARGET>_RUNNER=pi|stub; `stub` builds the job file without
# calling a model, so the recipe itself stays testable.
GRAMMAR_DIFF_SCRIPT ?= $(TEXT_FORGE_DIR)/scripts/grammar-diff.py
JOB_SCRIPT ?= $(TEXT_FORGE_DIR)/scripts/job.py
PI_RUN_SCRIPT ?= $(TEXT_FORGE_DIR)/scripts/pi-run.py
GRAMMAR_SINCE ?=
GRAMMAR_FILE ?=
GRAMMAR_SCOPE ?= wtd
GRAMMAR_RUNNER ?= pi

# `make grammar <arg>`: an existing path is a file, anything else is a ref.
# An explicit VAR=value on the command line still takes precedence.
ifeq (grammar,$(firstword $(MAKECMDGOALS)))
  GRAMMAR_ARG := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(GRAMMAR_ARG),)
    $(eval $(GRAMMAR_ARG):;@:)
    $(eval .PHONY: $(GRAMMAR_ARG))
    ifeq ($(wildcard $(GRAMMAR_ARG)),)
      GRAMMAR_SINCE := $(GRAMMAR_ARG)
    else
      GRAMMAR_FILE := $(GRAMMAR_ARG)
    endif
  endif
endif


# Run a prepared job file (prompt + input) through the configured runner.
# Choosing the runner is harness policy, so it stays here; building the job file
# is generic mechanics and lives in text-forge's scripts/job.py.
define run_job
case "$(1)" in \
  stub) echo "stub: model not called (job $(2))";; \
  pi) env -u VIRTUAL_ENV uv run --project "$(TEXT_FORGE_DIR)" python "$(PI_RUN_SCRIPT)" "$(2)";; \
  *) echo "Error: unknown runner '$(1)' (expected: pi|stub)"; exit 1;; \
esac
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

books: ## Regenerate text/books/*.md from livelib (fresh export + curation)
	uv run --project $(TEXT_FORGE_DIR) python -m text_forge.wtd_books_build $(CURDIR)

clean-cache: ## Drop livelib crawl caches (editions/works) — next build re-reads pages from livelib
	rm -f livelib-export/editions-cache.json livelib-export/works-cache.json
	@echo "caches dropped — next make books re-reads edition cards/contents"

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
	@echo "→ Run: env -u VIRTUAL_ENV uv run --project $(TEXT_FORGE_DIR) python $(JOB_SCRIPT) --prompt summarize --input build/summary_source.md --out build/summary-job.md"

grammar: ## Grammar check: no argument — working tree, <sha> — since that commit, <file.md> — whole file | vars: GRAMMAR_RUNNER=pi|stub
	@mkdir -p build
	@if [ ! -f "$(GRAMMAR_DIFF_SCRIPT)" ]; then \
		echo "Error: grammar-diff script not found: $(GRAMMAR_DIFF_SCRIPT)"; \
		echo "Run: make install"; \
		exit 1; \
	fi; \
	DIFF_ARGS=""; \
	if [ -n "$(GRAMMAR_FILE)" ]; then \
		echo "==> grammar: whole file $(GRAMMAR_FILE)"; \
		DIFF_ARGS="--only $(GRAMMAR_FILE)"; \
	elif [ -n "$(GRAMMAR_SINCE)" ]; then \
		BASE=$$(git rev-parse --verify --quiet "$(GRAMMAR_SINCE)^{commit}"); \
		if [ -z "$$BASE" ]; then echo "Error: not a ref or commit: $(GRAMMAR_SINCE)"; exit 1; fi; \
		if ! git rev-parse --verify --quiet "$$BASE^" >/dev/null; then \
			echo "Error: $(GRAMMAR_SINCE) has no parent — it is the root commit. Use: make grammar <file.md>."; \
			exit 1; \
		fi; \
		echo "==> grammar: since $(GRAMMAR_SINCE), inclusive"; \
		DIFF_ARGS="--since $$BASE^"; \
	else \
		echo "==> grammar: working tree vs HEAD"; \
	fi; \
	set +e; \
	env -u VIRTUAL_ENV uv run --project "$(TEXT_FORGE_DIR)" python "$(GRAMMAR_DIFF_SCRIPT)" --root "$(CURDIR)" \
		$$DIFF_ARGS --scope "$(GRAMMAR_SCOPE)" --typo \
		--md build/grammar-input.md --json build/grammar-input.json; \
	RC=$$?; set -e; \
	if [ "$$RC" -eq 2 ]; then exit 0; fi; \
	if [ "$$RC" -ne 0 ]; then echo "Error: grammar-diff failed (exit $$RC)"; exit 1; fi; \
	env -u VIRTUAL_ENV uv run --project "$(TEXT_FORGE_DIR)" python "$(JOB_SCRIPT)" --prompt grammar \
	  --input build/grammar-input.md \
	  --footer 'Проверь добавленные строки выше и запиши отчёт в build/grammar-report.md (создай каталог, если нужно). Каждая находка — с адресом `файл:строка` из входа. В ответ напиши 3–5 строк свободным текстом без markdown-разметки: что проверено, сколько находок, где отчёт. Терминал не рендерит разметку.' \
	  --out build/grammar-job.md; \
	$(call run_job,$(GRAMMAR_RUNNER),build/grammar-job.md); \
	if [ "$(GRAMMAR_RUNNER)" = "pi" ] && [ -f build/grammar-report.md ]; then \
		echo "report: build/grammar-report.md (written by this run)"; \
	fi

##@ Publishing

# Wipe ingested data (dry-run without --yes):
#   uv run python $(TEXT_FORGE_DIR)/scripts/hindsight-wipe-documents-by-tag.py \
#     --api-url $(HINDSIGHT_API_URL) --bank $(HINDSIGHT_BANK) --tag wtd --tag current [--tag chapter:<slug>] [--yes]
ingest: ## WTD -> Hindsight: delta after last ingest | vars: AFTER=<ref> / SINCE=<ref> / COMMIT=<ref> | vars: CHAPTER=<slug> [SECTION=<anchor>] or FULL=yes | vars: APPLY=yes to write (default: preview)
	@if [ ! -f "$(HINDSIGHT_WRAPPER)" ]; then \
		echo "Error: canonical wrapper not found: $(HINDSIGHT_WRAPPER)"; \
		exit 1; \
	fi
	@ARGS="--root $(CURDIR) --api-url $(HINDSIGHT_API_URL) --bank $(HINDSIGHT_BANK) --strategy $(HINDSIGHT_STRATEGY) --batch-size $(HINDSIGHT_BATCH_SIZE)"; \
	if [ "$(APPLY)" = "yes" ]; then ARGS="$$ARGS --yes"; MODE="live ingest"; else MODE="preview"; fi; \
	if [ -n "$(COMMIT)" ]; then ARGS="$$ARGS --commit $(COMMIT)"; fi; \
	if [ -n "$(SINCE)" ]; then ARGS="$$ARGS --since $(SINCE)"; fi; \
	if [ -n "$(AFTER)" ]; then ARGS="$$ARGS --after $(AFTER)"; fi; \
	if [ -n "$(CHAPTER)" ]; then ARGS="$$ARGS --chapter $(CHAPTER)"; fi; \
	if [ -n "$(SECTION)" ]; then ARGS="$$ARGS --section $(SECTION)"; fi; \
	if [ "$(FULL)" = "yes" ]; then \
		if [ -n "$(COMMIT)$(SINCE)$(AFTER)$(CHAPTER)$(SECTION)" ]; then \
			echo "Error: FULL=yes cannot be combined with COMMIT/SINCE/AFTER/CHAPTER/SECTION"; \
			exit 1; \
		fi; \
		ARGS="$$ARGS --all"; \
	fi; \
	if [ -n "$(COMMIT)$(SINCE)$(AFTER)" ] && [ -n "$(CHAPTER)$(SECTION)" ]; then \
		echo "Error: do not combine commit scope with CHAPTER/SECTION filters"; \
		exit 1; \
	fi; \
	if [ -n "$(LIMIT)" ]; then ARGS="$$ARGS --limit $(LIMIT)"; fi; \
	echo "==> Hindsight $$MODE"; \
	env -u VIRTUAL_ENV uv run python "$(HINDSIGHT_WRAPPER)" $$ARGS $(INGEST_EXTRA_ARGS)

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
	@printf 'Проверить грамматику рабочего дерева перед публикацией? [y/N] '; \
	read -r DO_GRAMMAR; \
	case "$$DO_GRAMMAR" in \
		y|Y|yes|YES) \
			echo "==> Grammar check (рабочее дерево)..."; \
			$(MAKE) --no-print-directory grammar || exit 1; \
			echo; \
			echo "Отчёт: $(CURDIR)/build/grammar-report.md"; \
			echo "Публикация остановлена: исправь находки и запусти make publish снова."; \
			exit 1;; \
	esac
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
