# Copilot instructions (whattodo)

## Big picture
- This repo is a **MkDocs site** (`mkdocs.yml`, docs in `text/ru/`) plus an **EPUB build pipeline** orchestrated by `Makefile`.
- The EPUB pipeline is intentionally staged:
  1) **Combine** chapters from `mkdocs.yml` nav → `build/text_combined.txt` via `scripts/mkdocs-combine.py`
  2) **Normalize PyMdown syntax** → Pandoc-compatible markdown via `scripts/pymdown-pandoc.lua` → `build/pandoc.md`
  3) **Render EPUB** via `pandoc` using `epub/book_meta.yml` (+ placeholders filled by git) and `epub/epub.css` → `build/text_book.epub`
  4) **Publish site**: copy EPUB + combined text into `text/ru/assets/`, then `mkdocs build` into `public/ru/`

## Common workflows (use these commands)
- Build everything (EPUB + site): `make` or `make all`
- Build EPUB only: `make epub`
- Build site (also generates EPUB first): `make mkdocs` (alias: `make site`)
- Run validation tests (expects build artifacts): `make test`
- Clean outputs: `make clean`

## Project conventions that matter
- **Docs source of truth**: `text/ru/` (this is `docs_dir` in `mkdocs.yml`). Avoid editing generated outputs in `build/` or `public/`.
- **Navigation drives ordering**: `mkdocs.yml` `nav:` is used both for the website and for EPUB/chapter ordering.
- **Anchors/links in the combined markdown** (implemented in `scripts/mkdocs-combine.py`):
  - Each file gets a stable top anchor derived from its path: `#p2-170-opensource-md` style.
  - Links like `(file.md)` become `(#file-md)` and `(file.md#anchor)` becomes `(#anchor)`.
- **Details blocks are rewritten for EPUB**: inside `/// details ... ///` blocks, the combiner replaces inner content with a source URL (built from `site_url` + file + nearest heading anchor).
- **Custom block syntax**: the text uses PyMdown “block” markers like:
  - `/// tip | Caption ... ///`, `/// warning ... ///`, `/// quote ... ///`, etc.
  - The Lua filter converts them to Pandoc `Div`s with matching classes, and captions become an `h6.block-caption`.
- **Images in EPUB**: the Lua filter extracts markdown image attributes `{ width="75%" ... }` but keeps only `width`/`height` for EPUB friendliness.
- **Emoticon no-break**: MkDocs hook `mkdocs/hooks/nobr_emoticons.py` wraps `:-)`/`;-)` etc into `<span class="md-nobr">…</span>`.

## Dependencies / environment assumptions
- Python project config is in `pyproject.toml` (requires Python `>=3.11`).
- External tools required by the Makefile: `pandoc`, `mkdocs`.
- `make` uses git metadata to fill `[edition]` and `[date]` placeholders in `epub/book_meta.yml`.

## When changing the build pipeline
- If you change `scripts/mkdocs-combine.py` or `scripts/pymdown-pandoc.lua`, update/extend fixtures in `scripts/fixtures/` and run `make test`.
- Keep behavior compatible with existing `/// ... ///` blocks used across `text/ru/*.md`.
