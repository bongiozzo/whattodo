# Makefile для Текста
#
# Этот репозиторий задуман как хранилище Текста + mkdocs.yml.
# mkdocs.yml описывает структуру Текста, которая определяет сайт и сборку EPUB.
# Вся сборочная «машинерия» находится в submodule `text-forge/`.

TEXT_FORGE_DIR := text-forge

.PHONY: all epub site serve clean help info install

help:
	@echo "whattodo (content repo)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  git submodule update --init --recursive"
	@echo ""
	@echo "Targets:"
	@echo "  make install       Install tooling deps (uv sync in text-forge)"
	@echo "  make serve         Fast local preview (no EPUB; git-committers disabled)"
	@echo "  make epub          Build EPUB only"
	@echo "  make site          Build MkDocs site + copy artifacts"
	@echo "  make all           Build EPUB + MkDocs site (default)"
	@echo "  make clean         Remove build artifacts"
	@echo "  make info          Show resolved paths"

install:
	@$(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) install

serve:
	@MKDOCS_GIT_COMMITTERS_ENABLED=false $(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) serve

epub:
	@$(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) epub

site:
	@$(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) site

all:
	@$(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) all

clean:
	@$(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) clean

info:
	@$(MAKE) -C $(TEXT_FORGE_DIR) CONTENT_ROOT=$(CURDIR) info