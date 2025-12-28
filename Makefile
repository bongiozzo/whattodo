# Процесс сборки MkDocs + EPUB
#
# Стадии сборки:
# 1) Объединение глав (порядок берётся из nav в mkdocs.yml) -> build/text_combined.txt
# 2) Нормализация синтаксиса PyMdown -> build/pandoc.md
# 3) Генерация EPUB через pandoc -> build/text_book.epub
# 4) Публикация артефактов сайта + сборка mkdocs -> public/ru (+ public/index.html redirect)
#
# Notes:
# - Скрипты pipeline и EPUB templates находятся в submodule `text-forge`.
# - `make serve` намеренно быстрый и НЕ требует pandoc.

# Configuration
UV_RUN := uv run
PYTHON := $(UV_RUN) python
PANDOC := pandoc
MKDOCS := $(UV_RUN) mkdocs
DOCS_DIR := text/ru
SCRIPTS_DIR := text-forge/scripts
BUILD_DIR := build
EPUB_DIR := text-forge/epub
PUBLIC_DIR := public
SITE_DIR := $(PUBLIC_DIR)/ru

# ASSETS_DIR намеренно не используется: для MkDocs мы копируем artifacts в
# docs tree (text/ru/assets), чтобы они раздавались как static files.

# Assets
MKDOCS_CONFIG := mkdocs.yml
COMBINE_SCRIPT := $(SCRIPTS_DIR)/mkdocs-combine.py
LUA_FILTER := $(SCRIPTS_DIR)/pymdown-pandoc.lua
BOOK_META := $(EPUB_DIR)/book_meta.yml
CSS_FILE := $(EPUB_DIR)/epub.css
# Cover относится к контенту; держим его внутри docs tree.
COVER_IMAGE := $(DOCS_DIR)/img/cover.jpg

# Build targets
COMBINED_MD := $(BUILD_DIR)/text_combined.txt
PANDOC_MD := $(BUILD_DIR)/pandoc.md
EPUB_OUT := $(BUILD_DIR)/text_book.epub
BOOK_META_PROCESSED := $(BUILD_DIR)/book_meta_processed.yml

# --- Phony targets ---
.PHONY: all epub site serve test clean help info install

# Подсказка по использованию
help:
	@echo "MkDocs + EPUB Build Pipeline"
	@echo ""
	@echo "Prerequisites:"
	@echo "  git submodule update --init --recursive"
	@echo ""
	@echo "Targets:"
	@echo "  make help          Show this help message"
	@echo "  make install       Sync dependencies via uv sync"
	@echo "  make serve         Run MkDocs dev server (fast, no EPUB)"
	@echo "  make epub          Build EPUB only"
	@echo "  make site          Build MkDocs site + copy artifacts"
	@echo "  make all           Build EPUB + MkDocs site (default)"
	@echo "  make test          Run validation tests"
	@echo "  make clean         Remove all build artifacts"
	@echo "  make info          Show build configuration"
	@echo ""
	@echo "Overrides (examples):"
	@echo "  make PYTHON='uv run python' MKDOCS='uv run mkdocs'"
	@echo ""
	@echo "Build artifacts:"
	@echo "  $(COMBINED_MD) - Combined markdown from mkdocs.yml"
	@echo "  $(PANDOC_MD)           - Processed markdown (PyMdown → Pandoc)"
	@echo "  $(EPUB_OUT)            - Final EPUB output"
	@echo "  $(SITE_DIR)/                   - MkDocs site (with assets)"

install:
	@echo "==> Syncing dependencies via uv sync..."
	uv sync

# Быстрый предпросмотр сайта (не строит EPUB).
# Если нужно, чтобы локально работали ссылки на EPUB/combined text,
# один раз запустите `make site` (он копирует artifacts в text/ru/assets).
serve:
	MKDOCS_GIT_COMMITTERS_ENABLED=false $(MKDOCS) serve --config-file=$(MKDOCS_CONFIG)

# Main EPUB target
epub: $(EPUB_OUT)

# Собрать главы markdown в единый файл согласно структуре nav в mkdocs.yml
$(COMBINED_MD): $(MKDOCS_CONFIG) $(COMBINE_SCRIPT)
	@echo "==> Stage 1: Combining markdown files from mkdocs.yml..."
	@mkdir -p $(BUILD_DIR)
	@$(PYTHON) $(COMBINE_SCRIPT) $(MKDOCS_CONFIG) > $@
	@echo "✓ Combined markdown: $@"

# Обработать синтаксис расширений PyMdown через Lua filter
$(PANDOC_MD): $(COMBINED_MD) $(LUA_FILTER)
	@echo "==> Stage 2: Converting PyMdown syntax to Pandoc markdown..."
	$(PANDOC) -f markdown+smart $(COMBINED_MD) \
		--lua-filter=$(LUA_FILTER) \
		--wrap=preserve \
		-t markdown \
		-o $@
	@echo "✓ Pandoc markdown: $@"

# Process book metadata — заменить git placeholders
$(BOOK_META_PROCESSED): $(BOOK_META)
	@echo "==> Processing book metadata..."
	@mkdir -p $(BUILD_DIR)
	@GIT_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.1.0"); \
	GIT_DATE=$$(git log -1 --format=%cs 2>/dev/null || true); \
	if [ -z "$$GIT_DATE" ]; then GIT_DATE=$$(date -u +%Y-%m-%d); fi; \
	GIT_DATE_DISPLAY=$$(echo "$$GIT_DATE" | $(PYTHON) -c "import sys, datetime; d = datetime.datetime.strptime(sys.stdin.read().strip(), '%Y-%m-%d'); print(d.strftime('%d %B %Y').replace('January', 'января').replace('February', 'февраля').replace('March', 'марта').replace('April', 'апреля').replace('May', 'мая').replace('June', 'июня').replace('July', 'июля').replace('August', 'августа').replace('September', 'сентября').replace('October', 'октября').replace('November', 'ноября').replace('December', 'декабря'))"); \
	EDITION="$$GIT_TAG, $$GIT_DATE_DISPLAY"; \
	sed -e "s/\[edition\]/$$EDITION/" \
	    -e "s/\[date\]/$$GIT_DATE/" \
	    $(BOOK_META) > $@
	@echo "✓ Metadata processed: $@"

# Генерация финального EPUB из pandoc-конвертированного markdown
# (Metadata берётся из BOOK_META_PROCESSED с подставленными git placeholders)
$(EPUB_OUT): $(PANDOC_MD) $(BOOK_META_PROCESSED) $(CSS_FILE) $(COVER_IMAGE)
	@echo "==> Stage 3: Generating EPUB..."
	@mkdir -p $(BUILD_DIR)
	$(PANDOC) -f markdown+smart $(PANDOC_MD) \
		-o $@ \
		--standalone \
		--toc \
		--toc-depth=2 \
		--metadata-file=$(BOOK_META_PROCESSED) \
		--resource-path=$(DOCS_DIR) \
		--css=$(CSS_FILE) \
		--epub-cover-image=$(COVER_IMAGE) \
		-t epub3
	@echo "✓ EPUB generated: $@"

# Создание сайта MkDocs + копирование артефактов
site: epub
	@echo "==> Copying artifacts for MkDocs..."
	@mkdir -p $(DOCS_DIR)/assets
	cp $(EPUB_OUT) $(DOCS_DIR)/assets/
	cp $(COMBINED_MD) $(DOCS_DIR)/assets/
	@echo "✓ Artifacts copied to $(DOCS_DIR)/assets"
	@echo "==> Building MkDocs site..."
	$(MKDOCS) build --config-file=$(MKDOCS_CONFIG) --site-dir=$(SITE_DIR) --strict
	@echo "✓ MkDocs site built: $(SITE_DIR)"
	@echo "==> Creating redirect from / to /ru/..."
	@mkdir -p $(PUBLIC_DIR)
	@echo '<!DOCTYPE html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=/ru/"><link rel="canonical" href="/ru/"><title>Redirecting to /ru/...</title></head><body><p>Redirecting to <a href="/ru/">/ru/</a>...</p><script>window.location.href="/ru/";</script></body></html>' > $(PUBLIC_DIR)/index.html
	@echo "✓ Redirect created: $(PUBLIC_DIR)/index.html"

# Default target — собрать всё
all: epub site

# Запустить набор тестов для проверки сгенерированного EPUB
test: $(EPUB_OUT)
	@echo "==> Unzipping EPUB for tests..."
	@rm -rf $(BUILD_DIR)/epub
	@unzip -q $(EPUB_OUT) -d $(BUILD_DIR)/epub
	@echo "==> Running tests..."
	@COMBINED_MD=$(CURDIR)/$(COMBINED_MD) PANDOC_MD=$(CURDIR)/$(PANDOC_MD) EPUB_DIR=$(BUILD_DIR)/epub $(PYTHON) -m pytest $(SCRIPTS_DIR)/tests.py -v
	@echo "✓ Tests passed"

# Очистка артефактов сборки
clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(SITE_DIR)
	rm -rf .pytest_cache .cache **/__pycache__
	rm -f $(PUBLIC_DIR)/index.html
	@echo "✓ Cleaned"

# Вывод переменных окружения и настроек
info:
	@echo "Настройки:"
	@echo "  PYTHON: $(PYTHON)"
	@echo "  PANDOC: $(PANDOC)"
	@echo "  MKDOCS: $(MKDOCS)"
	@echo "  DOCS_DIR: $(DOCS_DIR)"
	@echo "  SCRIPTS_DIR: $(SCRIPTS_DIR)"
	@echo "  BUILD_DIR: $(BUILD_DIR)"
	@echo "  EPUB_DIR: $(EPUB_DIR)"
	@echo "  SITE_DIR: $(SITE_DIR)"
	@echo ""
	@echo "Ресурсы:"
	@echo "  MKDOCS_CONFIG: $(MKDOCS_CONFIG)"
	@echo "  BOOK_META: $(BOOK_META)"
	@echo "  COMBINE_SCRIPT: $(COMBINE_SCRIPT)"
	@echo "  LUA_FILTER: $(LUA_FILTER)"
	@echo "  CSS_FILE: $(CSS_FILE)"
	@echo "  COVER_IMAGE: $(COVER_IMAGE)"
	@echo ""
	@echo "Цели сборки:"
	@echo "  COMBINED_MD: $(COMBINED_MD)"
	@echo "  PANDOC_MD: $(PANDOC_MD)"
	@echo "  EPUB_OUT: $(EPUB_OUT)"