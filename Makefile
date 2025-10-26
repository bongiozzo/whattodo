# --- MkDocs to EPUB Conversion Pipeline ---
# This Makefile orchestrates a 4-stage pipeline:
# 1. Extract nav structure from mkdocs.yml
# 2. Combine markdown files
# 3. Convert PyMdown Extensions syntax to Pandoc-compatible markdown via Lua filter
# 4. Generate final EPUB with pandoc, including TOC, CSS, cover image, and metadata

# Configuration
PYTHON := python3
PANDOC := pandoc
DOCS_DIR := text/ru
SCRIPTS_DIR := scripts
BUILD_DIR := build
EPUB_DIR := epub
RELEASE_DIR := $(DOCS_DIR)/assets

# Assets
MKDOCS_CONFIG := mkdocs.yml
COMBINE_SCRIPT := $(SCRIPTS_DIR)/mkdocs-combine.py
LUA_FILTER := $(SCRIPTS_DIR)/pymdown-pandoc.lua
BOOK_META := $(EPUB_DIR)/book_meta.yml
CSS_FILE := $(EPUB_DIR)/styles.css
COVER_IMAGE := $(EPUB_DIR)/cover.jpg

# Build targets
COMBINED_MD := $(BUILD_DIR)/text_combined.txt
PANDOC_MD := $(BUILD_DIR)/pandoc.md
EPUB_OUT := $(BUILD_DIR)/text_book.epub

# --- Phony targets ---
.PHONY: all epub clean test help debug

# Default target
all: epub

# Main EPUB target
epub: $(EPUB_OUT)

# Stage 3: Generate final EPUB from pandoc-converted markdown
# (Metadata comes from BOOK_META file generated from mkdocs.yml)
$(EPUB_OUT): $(PANDOC_MD) $(BOOK_META) $(CSS_FILE) $(COVER_IMAGE)
	@echo "==> Stage 3: Generating EPUB..."
	@mkdir -p $(RELEASE_DIR)
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
	@echo "MkDocs to EPUB Conversion Pipeline"
	@echo ""
	@echo "Targets:"
	@echo "  make all/epub      Build EPUB (default)"
	@echo "  make test          Run validation tests"
	@echo "  make clean         Remove build artifacts"
	@echo "  make help          Show this help message"
	@echo ""
	@echo "Build artifacts:"
	@echo "  $(COMBINED_MD)     - Combined markdown from mkdocs.yml"
	@echo "  $(PANDOC_MD)       - Processed markdown (PyMdown → Pandoc)"
	@echo "  $(EPUB_OUT)        - Final EPUB output"

# Clean target - remove all build artifacts
clean:
	@echo "==> Cleaning build artifacts..."
	rm -rf $(COMBINED_MD) $(EPUB_OUT) $(BUILD_DIR)
	@echo "✓ Cleaned"

# Debug target - show variables
debug:
	@echo "Configuration:"
	@echo "  PYTHON: $(PYTHON)"
	@echo "  PANDOC: $(PANDOC)"
	@echo "  DOCS_DIR: $(DOCS_DIR)"
	@echo "  SCRIPTS_DIR: $(SCRIPTS_DIR)"
	@echo "  BUILD_DIR: $(BUILD_DIR)"
	@echo "  EPUB_DIR: $(EPUB_DIR)"
	@echo "  RELEASE_DIR: $(RELEASE_DIR)"
	
	@echo "  MKDOCS_CONFIG: $(MKDOCS_CONFIG)"
	@echo "  BOOK_META: $(BOOK_META)"
	@echo "  COMBINE_SCRIPT: $(COMBINE_SCRIPT)"
	@echo "  LUA_FILTER: $(LUA_FILTER)"
	@echo "  CSS_FILE: $(CSS_FILE)"
	@echo "  COVER_IMAGE: $(COVER_IMAGE)"

	@echo "  COMBINED_MD: $(COMBINED_MD)"
	@echo "  PANDOC_MD: $(PANDOC_MD)"
	@echo "  EPUB_OUT: $(EPUB_OUT)"