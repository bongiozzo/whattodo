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
npx antora --fetch antora-playbook.yml

# Build using the build script (includes additional formats)
./build.sh

# Generate only books (PDF, EPUB)
asciidoctor-pdf --theme pdf/pdf.yml -D public/ru ru/modules/ROOT/book.adoc
asc-epub3 -a epub3-stylesdir=../../../epub -D public/ru ru/modules/ROOT/book.adoc
```

### Docker Development

```bash
# Build Docker image and run interactive shell
./docker.sh

# Alternative: use devcontainer in VS Code
# Devcontainer is configured in .devcontainer/devcontainer.json
```

## Architecture

### Content Structure
- **Primary content**: Written in AsciiDoc format in `ru/modules/ROOT/pages/`
- **Navigation**: Defined in `ru/modules/ROOT/nav.adoc` with hierarchical structure
- **Book compilation**: `ru/modules/ROOT/book.adoc` serves as the main entry point for PDF/EPUB generation
- **Multi-format output**: HTML site, PDF book, EPUB, and reduced AsciiDoc

### Build System
This project uses Antora as the primary documentation system:

- **Config**: `antora-playbook.yml`
- **Site title**: "Общие цели" (Common Goals)
- **Published URL**: https://text.sharedgoals.ru
- **Features**: Searchable HTML site with Lunr search extension
- **Language support**: Russian and English search
- **UI**: Custom Antora theme from GitLab

### Content Organization
- **Part 1** (`p1-*`): Introductory chapters about happiness, time, and society
  - Introduction, happiness, call to action, time, unhappiness, country
- **Part 2** (`p2-*`): Practical chapters covering various life aspects
  - Authors, systems, education, local community, digital life, absurd, photos, routine, open source, shared goals, presentation, text creation, death
- **References** (`p3-references.adoc`): Bibliography and sources

### Generation Pipeline
1. Navigation structure (`nav.adoc`) is transformed into book TOC (`generated-toc.adoc`) via sed script
2. Individual AsciiDoc pages are compiled into complete books
3. Multiple output formats generated simultaneously:
   - HTML site via Antora
   - PDF via asciidoctor-pdf with custom theme
   - EPUB via asc-epub3 with custom styles
   - Reduced AsciiDoc via asciidoctor-reducer
4. PDF optimization with asciidoctor-pdf-optimize

## Development Environment

### Docker Setup
- **Base image**: Debian latest
- **Workspace**: `/antora`
- **Pre-installed tools**: 
  - Node.js and npm
  - Ruby and development tools
  - Ghostscript for PDF processing
  - AsciiDoctor suite (PDF, EPUB, reducer, reveal.js)
  - Antora and Lunr extension

### VS Code Integration
- **Devcontainer**: Full development environment in container
- **AsciiDoc support**: Snippets in `.vscode/asciidoc.code-snippets`
- **Launch configurations**: Debugging setup in `.vscode/launch.json`

## Content Guidelines

This is a collaborative text project with specific characteristics:
- **Language**: Russian
- **Format**: Long-form philosophical/practical text
- **Style**: Conversational, personal, with literary references
- **Collaboration**: Uses Git workflow (Fork -> Edit -> Pull Request)
- **Community**: Telegram discussion at https://t.me/bongiozzo_public
- **Repository**: GitHub at https://github.com/bongiozzo/whattodo/
- **Tone**: Inquisitive rather than prescriptive (note the smiley in title)

## Output Formats

The build system generates:
- **HTML site**: Searchable, responsive documentation site at `public/`
- **PDF book**: Print-ready version with custom theme and optimization
- **EPUB**: E-reader compatible format with custom SCSS styling
- **Reduced AsciiDoc**: Flattened single-file version for distribution

## Technical Notes

- **Content versioning**: Uses semantic version "ru" for Russian content
- **Caching**: Antora cache stored in `.cache/antora`
- **Custom attributes**: Extensive AsciiDoc attributes for navigation and formatting
- **Image handling**: Custom image directory structure
- **SEO**: HTML extension style set to "drop" for clean URLs
- **Publisher**: "Общие Цели" (Common Goals)
