# --- MkDocs to EPUB Conversion Pipeline ---
# This Makefile orchestrates a 4-stage pipeline:
# 1. Extract nav structure from mkdocs.yml
# 2. Combine markdown files
# 3. Convert PyMdown Extensions syntax to Pandoc-compatible markdown via Lua filter
# 4. Generate final EPUB with pandoc, including TOC, CSS, cover image, and metadata

# Configuration
PYTHON := python3
PANDOC := pandoc
MKDOCS := mkdocs
DOCS_DIR := text/ru
SCRIPTS_DIR := scripts
BUILD_DIR := build
EPUB_DIR := epub
PUBLIC_DIR := public
SITE_DIR := $(PUBLIC_DIR)/ru
ASSETS_DIR := $(SITE_DIR)/assets

# Assets
MKDOCS_CONFIG := mkdocs.yml
COMBINE_SCRIPT := $(SCRIPTS_DIR)/mkdocs-combine.py
LUA_FILTER := $(SCRIPTS_DIR)/pymdown-pandoc.lua
BOOK_META := $(EPUB_DIR)/book_meta.yml
CSS_FILE := $(EPUB_DIR)/epub.css
COVER_IMAGE := $(EPUB_DIR)/cover.jpg

# Build targets
COMBINED_MD := $(BUILD_DIR)/text_combined.txt
PANDOC_MD := $(BUILD_DIR)/pandoc.md
EPUB_OUT := $(BUILD_DIR)/text_book.epub

# --- Phony targets ---
.PHONY: all epub mkdocs site test clean help debug

# Default target - build everything
all: epub mkdocs

# Main EPUB target
epub: $(EPUB_OUT)

# MkDocs site build + copy artifacts
mkdocs: epub
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

# Alias for mkdocs target
site: mkdocs

# Stage 3: Generate final EPUB from pandoc-converted markdown
# (Metadata comes from BOOK_META file generated from mkdocs.yml)
$(EPUB_OUT): $(PANDOC_MD) $(BOOK_META) $(CSS_FILE) $(COVER_IMAGE)
	@echo "==> Stage 3: Generating EPUB..."
	@mkdir -p $(BUILD_DIR)
	$(PANDOC) -f markdown+smart $(PANDOC_MD) \
		-o $@ \
		--standalone \
		--toc \
		--toc-depth=2 \
		--metadata-file=$(BOOK_META) \
		--resource-path=$(DOCS_DIR) \
		--css=$(CSS_FILE) \
		--epub-cover-image=$(COVER_IMAGE) \
		-t epub3
	@echo "✓ EPUB generated: $@"

# Stage 2: Process PyMdown Extensions syntax via Lua filter
# (Combined markdown contains no frontmatter - just content)
$(PANDOC_MD): $(COMBINED_MD) $(LUA_FILTER)
	@echo "==> Stage 2: Converting PyMdown syntax to Pandoc markdown..."
	$(PANDOC) -f markdown+smart $(COMBINED_MD) \
 		--lua-filter=$(LUA_FILTER) \
		--wrap=preserve \
		-t markdown \
		-o $@
	@echo "✓ Pandoc markdown: $@"

# Stage 1: Combine markdown files from mkdocs.yml navigation structure
$(COMBINED_MD): $(MKDOCS_CONFIG) $(COMBINE_SCRIPT)
	@echo "==> Stage 1: Combining markdown files from mkdocs.yml..."
	@mkdir -p $(BUILD_DIR)
	@$(PYTHON) $(COMBINE_SCRIPT) $(MKDOCS_CONFIG) > $@
	@echo "✓ Combined markdown: $@"

# Test target - run validation tests
test:
	@echo "==> Unzipping EPUB for tests..."
	@rm -rf $(BUILD_DIR)/epub
	@unzip -q $(EPUB_OUT) -d $(BUILD_DIR)/epub
	@echo "==> Running tests..."
	@COMBINED_MD=$(COMBINED_MD) PANDOC_MD=$(PANDOC_MD) EPUB_DIR=$(BUILD_DIR)/epub $(PYTHON) -m pytest $(SCRIPTS_DIR)/tests.py -v
	@echo "✓ Tests passed"

# Help target
help:
	@echo "MkDocs + EPUB Build Pipeline"
	@echo ""
	@echo "Targets:"
	@echo "  make all           Build EPUB + MkDocs site (default)"
	@echo "  make epub          Build EPUB only"
	@echo "  make mkdocs/site   Build MkDocs site + copy artifacts"
	@echo "  make test          Run validation tests"
	@echo "  make clean         Remove all build artifacts"
	@echo "  make help          Show this help message"
	@echo ""
	@echo "Build artifacts:"
	@echo "  $(COMBINED_MD)     - Combined markdown from mkdocs.yml"
	@echo "  $(PANDOC_MD)       - Processed markdown (PyMdown → Pandoc)"
	@echo "  $(EPUB_OUT)        - Final EPUB output"
	@echo "  $(SITE_DIR)/        - MkDocs site (with assets)"

# Clean target - remove all build artifacts
clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(SITE_DIR)
	@echo "✓ Cleaned"

# Debug target - show variables
debug:
	@echo "Configuration:"
	@echo "  PYTHON: $(PYTHON)"
	@echo "  PANDOC: $(PANDOC)"
	@echo "  MKDOCS: $(MKDOCS)"
	@echo "  DOCS_DIR: $(DOCS_DIR)"
	@echo "  SCRIPTS_DIR: $(SCRIPTS_DIR)"
	@echo "  BUILD_DIR: $(BUILD_DIR)"
	@echo "  EPUB_DIR: $(EPUB_DIR)"
	@echo "  SITE_DIR: $(SITE_DIR)"
	@echo "  ASSETS_DIR: $(ASSETS_DIR)"
	@echo ""
	@echo "Assets:"
	@echo "  MKDOCS_CONFIG: $(MKDOCS_CONFIG)"
	@echo "  BOOK_META: $(BOOK_META)"
	@echo "  COMBINE_SCRIPT: $(COMBINE_SCRIPT)"
	@echo "  LUA_FILTER: $(LUA_FILTER)"
	@echo "  CSS_FILE: $(CSS_FILE)"
	@echo "  COVER_IMAGE: $(COVER_IMAGE)"
	@echo ""
	@echo "Build targets:"
	@echo "  COMBINED_MD: $(COMBINED_MD)"
	@echo "  PANDOC_MD: $(PANDOC_MD)"
	@echo "  EPUB_OUT: $(EPUB_OUT)"