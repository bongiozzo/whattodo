# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is "Что мне делать? :-)" (What Should I Do? :-)) - a Russian-language collaborative text project about happiness and life goals. It's built using Antora documentation system and can generate multiple output formats including HTML, PDF, and EPUB.

## Key Commands

### Development and Building

```bash
# Install dependencies
npm install

# Build the complete site with Antora
npm run build  # or: npx antora --fetch antora-playbook.yml

# Build using the build script (includes additional formats)
./build.sh

# Generate only books (PDF, EPUB)
asciidoctor-pdf --theme pdf/pdf.yml -D public/ru ru/modules/ROOT/book.adoc
asc-epub3 -a epub3-stylesdir=../../../epub -D public/ru ru/modules/ROOT/book.adoc
```

### Docker Development

```bash
# Build Docker image for development
./docker.sh

# Alternative: use devcontainer in VS Code
# Devcontainer is configured in .devcontainer/devcontainer.json
```

### Alternative Documentation Systems

```bash
# Build with DiploDoc (alternative system)
./diplodoc/build_diplodoc.sh

# GitBook to DiploDoc migration
./diplodoc/gitbook_diplodoc.sh
```

## Architecture

### Content Structure
- **Primary content**: Written in AsciiDoc format in `ru/modules/ROOT/pages/`
- **Navigation**: Defined in `ru/modules/ROOT/nav.adoc` with hierarchical structure
- **Book compilation**: `ru/modules/ROOT/book.adoc` serves as the main entry point for PDF/EPUB generation
- **Multi-format output**: HTML site, PDF book, EPUB, and reduced AsciiDoc

### Build Systems
This project supports multiple documentation build systems:

1. **Antora** (Primary): Modern documentation site generator
   - Config: `antora-playbook.yml`
   - Generates searchable HTML site with Lunr search extension
   - Supports Russian language search

2. **Asciidoctor** (Books): Direct PDF/EPUB generation
   - PDF theme: `pdf/pdf.yml`
   - EPUB styles: `epub/` directory

3. **DiploDoc** (Alternative): Yandex documentation system
   - Config files in `diplodoc/` directory
   - Can convert from other formats

### Content Organization
- **Part 1** (`p1-*`): Introductory chapters about happiness, time, and society
- **Part 2** (`p2-*`): Practical chapters covering systems, education, digital life, etc.
- **References** (`p3-references.adoc`): Bibliography and sources

### Generation Pipeline
1. Navigation structure (`nav.adoc`) is transformed into book TOC (`generated-toc.adoc`)
2. Individual pages are compiled into complete books
3. Multiple output formats generated simultaneously
4. Images optimized for different formats

## Development Environment

### Docker Setup
- Base image: Debian with Node.js, Ruby, and documentation tools
- Pre-installed: Antora, AsciiDoctor suite, Ghostscript
- Workspace mounted at `/antora`

### VS Code Integration
- Devcontainer configuration available
- AsciiDoc snippets in `.vscode/asciidoc.code-snippets`
- Launch configurations for debugging

## Content Guidelines

This is a collaborative text project with specific characteristics:
- **Language**: Russian
- **Format**: Long-form philosophical/practical text
- **Style**: Conversational, personal, with literary references
- **Collaboration**: Uses Git workflow for contributions (Fork -> Edit -> Pull Request)
- **Tone**: Inquisitive rather than prescriptive (note the smiley in title)

## Output Formats

The build system generates:
- **HTML site**: Searchable, responsive documentation site at `public/`
- **PDF book**: Print-ready version with custom theme
- **EPUB**: E-reader compatible format
- **Reduced AsciiDoc**: Flattened single file version

## Technical Notes

- Uses semantic versioning for content (version "ru")
- Supports image optimization for different output formats
- Custom CSS/SCSS for EPUB styling
- GitBook conversion utilities available for migration
- Lunr search index with Russian language support
