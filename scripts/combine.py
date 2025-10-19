#!/usr/bin/env python3
"""
Combine MkDocs Markdown files into a single document for pandoc processing.

Key improvements:
1. Adjusts heading levels based on nav hierarchy
2. Converts PyMdown syntax to pandoc-compatible markdown
3. Better link fixing for combined document
4. Removes frontmatter that causes pandoc issues

TODO make args for:
- input mkdocs.yml path
- output combined.md path if not specified, than don't combine

Make conversion tests.

TODO copy following values from mkdocs.yml to combined.md frontmatter:

---
title:
- type: main
  text: My Book
- type: subtitle
  text: An investigation of metadata
creator:
- role: author
  text: John Smith
- role: editor
  text: Sarah Jones
identifier:
- scheme: DOI
  text: doi:10.234234.234/33
publisher:  My Press
rights: © 2007 John Smith, CC BY-NC

"""

import yaml
import os
import re
from pathlib import Path
from typing import List, Dict, Any, Tuple


def load_config(config_path: str = "mkdocs.yml") -> Dict[str, Any]:
    """Load and parse MkDocs configuration file."""
    script_dir = Path(__file__).parent
    config_file = script_dir / config_path
    
    if not config_file.exists():
        raise FileNotFoundError(f"Config file not found: {config_file}")
    
    with open(config_file, 'r', encoding='utf-8') as f:
        try:
            f.seek(0)
            config = yaml.safe_load(f)
        except yaml.constructor.ConstructorError:
            f.seek(0)
            class SkipUnknownLoader(yaml.SafeLoader):
                pass
            
            def skip_unknown(loader, tag_suffix, node):
                return None
            
            SkipUnknownLoader.add_multi_constructor('!python', skip_unknown)
            SkipUnknownLoader.add_multi_constructor('tag:yaml.org,2002:python/', skip_unknown)
            
            config = yaml.load(f, Loader=SkipUnknownLoader)
    
    if 'docs_dir' not in config:
        raise ValueError("Config must contain 'docs_dir' field")
    if 'nav' not in config:
        raise ValueError("Config must contain 'nav' field")
    
    return config


def extract_nav_items(nav_config: List[Any], level: int = 0) -> List[Tuple[str, str, int]]:
    """Extract navigation items with proper hierarchy levels."""
    items = []
    
    for item in nav_config:
        if isinstance(item, str):
            if item.endswith('.md'):
                # Title will be extracted from file later, use empty string as placeholder
                items.append(('', item, level))
        elif isinstance(item, dict):
            for section_title, section_items in item.items():
                if isinstance(section_items, str) and '://' in section_items:
                    # External link - add as item with URL
                    items.append((section_title, section_items, level))
                    continue
                
                # Add section header
                items.append((section_title, '', level))
                
                # Process nested items at level+1
                if isinstance(section_items, list):
                    items.extend(extract_nav_items(section_items, level + 1))
    
    return items


def convert_pymdown_to_pandoc(content: str) -> str:
    """
    Convert PyMdown Extensions syntax to pandoc-compatible markdown.
    
    Conversions:
    1. Image captions: ![](url)\n/// caption\ntext\n/// -> ![caption](url)
    2. Admonitions: !!! type "title" -> ::: {.type}\n**title**\n
    3. Superscript: ^^text^^ -> ^text^
    4. Subscript: ~~text~~ -> ~text~
    """
    
    # Convert image captions
    # Pattern: ![alt](url){ attrs }\n/// caption\ncaption text\n///
    def replace_caption(match):
        img_line = match.group(1)
        caption_text = match.group(2).strip()
        
        # Extract alt, url, and attributes from image
        img_match = re.search(r'!\[([^\]]*)\]\(([^)]+)\)(?:\{([^}]+)\})?', img_line)
        if img_match:
            alt = img_match.group(1)
            url = img_match.group(2)
            attrs = img_match.group(3) or ''
            
            # Keep original alt text, use caption as title
            # If no alt text, use caption for both
            final_alt = alt if alt else caption_text
            
            # Convert MkDocs-style attributes to Pandoc format
            # Remove 'loading=lazy' and other non-pandoc attributes
            attrs_cleaned = ''
            if attrs:
                # Keep only width, height, and other pandoc-supported attributes
                # Remove quotes from attribute values for pandoc
                attrs_cleaned = re.sub(r'loading\s*=\s*\w+', '', attrs)
                attrs_cleaned = re.sub(r'["\']', '', attrs_cleaned)
                attrs_cleaned = re.sub(r',\s*', ' ', attrs_cleaned)
                attrs_cleaned = attrs_cleaned.strip()
            
            # Build the result: ![alt](url "caption"){attrs}
            if attrs_cleaned:
                return f'![{final_alt}]({url} "{caption_text}"){{{attrs_cleaned}}}'
            else:
                return f'![{final_alt}]({url} "{caption_text}")'
        return match.group(0)
    
    content = re.sub(
        r'(!\[.*?\]\([^)]+\)(?:\{[^}]*\})?)\s*\n///\s*caption\s*\n(.*?)\n///',
        replace_caption,
        content,
        flags=re.DOTALL
    )
    
    # Convert admonitions: !!! type "title" -> pandoc div with class
    def replace_admonition(match):
        adm_type = match.group(1)
        title = match.group(2) or adm_type.title()
        adm_content = match.group(3)
        
        # Dedent content
        lines = adm_content.split('\n')
        dedented = '\n'.join(line[4:] if line.startswith('    ') else line for line in lines)
        
        return f'::: {{{adm_type}}}\n**{title}**\n\n{dedented}\n:::'
    
    content = re.sub(
        r'!!!\s+(\w+)\s*(?:"([^"]*)")?\s*\n((?:    .*\n?)*)',
        replace_admonition,
        content
    )
    
    # Convert superscript: ^^text^^ -> ^text^
    content = re.sub(r'\^\^([^\^]+)\^\^', r'^\1^', content)
    
    # Convert subscript: ~~text~~ (only if not strikethrough)
    # This is tricky - skip if it looks like strikethrough (has spaces)
    content = re.sub(r'~~([^~\s]+)~~', r'~\1~', content)
    
    return content


def remove_frontmatter(content: str) -> str:
    """Remove YAML frontmatter from markdown content."""
    if content.startswith('---\n'):
        # Find end of frontmatter
        end_match = re.search(r'\n---\n', content[4:])
        if end_match:
            return content[end_match.end() + 4:]
    return content


def fix_internal_links(content: str, current_file: str) -> str:
    """
    Fix internal links for combined document.
    
    Transformations:
    - [text](file.md) -> [text](#file-md)
    - [text](file.md#anchor) -> [text](#file-md-anchor)
    - [text](#anchor) -> [text](#current-file-anchor)
    """
    def replace_link(match):
        is_image = match.group(1) == '!'
        text = match.group(2)
        url = match.group(3)
        
        # Skip image links and external links
        if is_image or url.startswith(('http://', 'https://', '//', 'mailto:')):
            return match.group(0)
        
        # Handle internal links
        if '#' in url:
            if url.startswith('#'):
                # Anchor in current file
                filename_base = current_file.replace('.md', '-md').replace('/', '-')
                new_url = f"#{filename_base}{url}"
            else:
                # Link to another file with anchor
                file_part, anchor_part = url.split('#', 1)
                if file_part.endswith('.md'):
                    file_base = file_part.replace('.md', '-md').replace('/', '-')
                    new_url = f"#{file_base}-{anchor_part}"
                else:
                    new_url = url
        else:
            # Link without anchor
            if url.endswith('.md'):
                file_base = url.replace('.md', '-md').replace('/', '-')
                new_url = f"#{file_base}"
            else:
                new_url = url
        
        return f"[{text}]({new_url})"
    
    pattern = r'(!?)\[([^\]]+)\]\(([^)]+)\)'
    return re.sub(pattern, replace_link, content)


def adjust_heading_levels(content: str, base_level: int) -> str:
    """
    Adjust markdown heading levels based on nav hierarchy.
    
    Args:
        content: Markdown content with headings
        base_level: Base level for this content (0 = no adjustment, 1 = add one level, etc.)
    
    Returns:
        Content with adjusted heading levels
    """
    if base_level <= 0:
        return content
    
    def replace_heading(match):
        hashes = match.group(1)
        title = match.group(2)
        anchor = match.group(3) or ''
        
        # Increase heading level
        new_level = len(hashes) + base_level
        # Cap at h6
        new_level = min(new_level, 6)
        new_hashes = '#' * new_level
        
        return f"{new_hashes} {title}{anchor}"
    
    # Match headings with optional {#anchor}
    pattern = r'^(#{1,6})\s+(.+?)(\s*\{#[^}]+\})?$'
    return re.sub(pattern, replace_heading, content, flags=re.MULTILINE)


def extract_first_heading(content: str) -> str:
    """Extract the first heading from markdown content."""
    # Remove frontmatter first
    content_no_frontmatter = remove_frontmatter(content)
    
    # Find first heading (any level)
    match = re.search(r'^#{1,6}\s+(.+?)(?:\s*\{#[^}]+\})?$', content_no_frontmatter, re.MULTILINE)
    if match:
        return match.group(1).strip()
    
    # Fallback to empty string if no heading found
    return ''


def read_markdown_file(filepath: Path) -> str:
    """Read markdown file content."""
    if not filepath.exists():
        raise FileNotFoundError(f"Markdown file not found: {filepath}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()


def combine_files(docs_dir: Path, nav_items: List[Tuple[str, str, int]]) -> str:
    """
    Combine all markdown files into single document.
    
    Process:
    1. Add section headers from nav
    2. For each file:
       - Remove frontmatter
       - Extract title from first heading
       - Convert PyMdown syntax
       - Adjust heading levels
       - Fix internal links
       - Add to output
    """
    combined_content = []
    
    for title, filepath, level in nav_items:
        # External links (contain ://)
        if filepath and '://' in filepath:
            # Add external link as markdown link in the TOC
            section_level = level + 1  # Start from h1
            section_hashes = '#' * section_level
            combined_content.append(f"\n\n{section_hashes} [{title}]({filepath})\n\n")
            continue
        
        # Section headers (no filepath)
        if not filepath:
            # Add section as heading at appropriate level
            section_level = level + 1  # Start from h1
            section_hashes = '#' * section_level
            combined_content.append(f"\n\n{section_hashes} {title}\n\n")
            continue
        
        # File content
        file_path = docs_dir / filepath
        
        if not file_path.exists():
            print(f"Warning: File not found: {file_path}")
            continue
        
        print(f"Processing: {filepath} (level {level})")
        
        try:
            # Read content
            content = read_markdown_file(file_path)
            
            # Extract title from first heading
            extracted_title = extract_first_heading(content)
            if not extracted_title:
                # Fallback to filename-based title
                extracted_title = filepath.replace('.md', '').replace('-', ' ').title()
            
            print(f"  Title: {extracted_title}")
            
            # Remove frontmatter
            content = remove_frontmatter(content)
            
            # Convert PyMdown syntax
            content = convert_pymdown_to_pandoc(content)
            
            # Adjust heading levels based on nav hierarchy
            # Don't adjust for level 0 (top-level files)
            content = adjust_heading_levels(content, level)
            
            # Fix internal links
            content = fix_internal_links(content, filepath)
            
            # Add anchor for this file
            anchor_id = filepath.replace('.md', '-md').replace('/', '-')
            
            # Add to output with section separator
            combined_content.append(f"\n\n---\n\n# {extracted_title} {{#{anchor_id}}}\n\n{content}")
            
        except Exception as e:
            print(f"Error processing {filepath}: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    return "\n".join(combined_content)


def main():
    """Main entry point."""
    try:
        print("Loading configuration...")
        config = load_config("../mkdocs.yml")
        
        docs_dir = Path(__file__).parent.parent / config['docs_dir']
        nav_config = config['nav']
        
        print(f"Documents directory: {docs_dir}")
        
        print("Extracting navigation structure...")
        nav_items = extract_nav_items(nav_config)
        
        print("Combining markdown files...")
        combined_content = combine_files(docs_dir, nav_items)
        
        # Add document header
        header = f"""---
title: {config.get('site_name', 'Combined Document')}
lang: ru
---

"""
        
        output_content = header + combined_content
        
        output_file = Path(__file__).parent.parent / "combined.md"
        print(f"Writing output to: {output_file}")
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output_content)
        
        print(f"\n✓ Successfully created combined document: {output_file}")
        print(f"  Total files processed: {sum(1 for _, fp, _ in nav_items if fp)}")
        print(f"\nNext step: Run pandoc to generate epub:")
        print(f"  pandoc combined.md -o book.epub --toc --toc-depth=3")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)


if __name__ == "__main__":
    main()