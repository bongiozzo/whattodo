#!/usr/bin/env python3
"""
MkDocs Markdown Combiner - Two Mode Tool

Mode 1: mkdocs.yml mode
  python3 mkdocs-combine.py mkdocs.yml
  - Extracts navigation hierarchy from mkdocs.yml
  - Reads files one by one from specified chapters
  - Preserves YAML frontmatter from first chapter (for EPUB metadata)
  - Shifts headings according to nav level
  - Fixes internal links
  - Outputs to stdout

Mode 2: Single file mode
  python3 mkdocs-combine.py input.md --level 1
  - Reads input.md file
  - Shifts headings by specified level
  - Fixes internal links
  - Outputs to stdout

Usage:
  # Mode 1: Process mkdocs.yml
  python3 mkdocs-combine.py mkdocs.yml > combined.md

  # Mode 2: Process single file with heading adjustment
  python3 mkdocs-combine.py chapter.md --level 1 > output.md
"""

import sys
import argparse
import yaml
import re
from pathlib import Path
from typing import List, Dict, Any, Tuple

def load_yaml_config(config_path: str) -> Dict[str, Any]:
    """Load MkDocs YAML configuration with graceful error handling."""
    config_file = Path(config_path)
    
    if not config_file.exists():
        raise FileNotFoundError(f"Config file not found: {config_file}")
    
    with open(config_file, 'r', encoding='utf-8') as f:
        try:
            config = yaml.safe_load(f)
        except yaml.constructor.ConstructorError:
            # Handle Python object tags
            f.seek(0)
            class SkipUnknownLoader(yaml.SafeLoader):
                pass
            
            def skip_unknown(loader, tag_suffix, node):
                return None
            
            SkipUnknownLoader.add_multi_constructor('!python', skip_unknown)
            SkipUnknownLoader.add_multi_constructor('tag:yaml.org,2002:python/', skip_unknown)
            
            config = yaml.load(f, Loader=SkipUnknownLoader)
    
    return config


def extract_nav_items(nav_config: List[Any], level: int = 0) -> List[Tuple[str, str, int]]:
    """
    Extract navigation items with hierarchy levels.
    
    Returns list of tuples: (title, filepath, level)
    - level 0: top-level chapters
    - level 1+: nested sections
    """
    items = []
    
    for item in nav_config:
        if isinstance(item, str):
            if item.endswith('.md'):
                items.append(('', item, level))
        elif isinstance(item, dict):
            for section_title, section_items in item.items():
                if isinstance(section_items, str) and '://' in section_items:
                    # External link
                    items.append((section_title, section_items, level))
                    continue
                
                # Section header
                items.append((section_title, '', level))
                
                # Nested items
                if isinstance(section_items, list):
                    items.extend(extract_nav_items(section_items, level + 1))
    
    return items


def extract_frontmatter(content: str) -> Dict[str, Any]:
    """Extract YAML frontmatter as dictionary."""
    if not content.startswith('---\n'):
        return {}
    
    end_match = re.search(r'\n---\n', content[4:])
    if not end_match:
        return {}
    
    frontmatter_text = content[4:end_match.start() + 4]
    
    try:
        frontmatter = yaml.safe_load(frontmatter_text)
        return frontmatter if isinstance(frontmatter, dict) else {}
    except:
        return {}


def remove_frontmatter(content: str) -> str:
    """Remove YAML frontmatter from markdown."""
    if content.startswith('---\n'):
        end_match = re.search(r'\n---\n', content[4:])
        if end_match:
            return content[end_match.end() + 4:]
    return content


def format_dates_from_frontmatter(frontmatter: Dict[str, Any]) -> str:
    """Format dates from frontmatter as italic text."""
    dates = []
    if frontmatter.get('created'):
        dates.append(f"Создано: {frontmatter['created']}")
    if frontmatter.get('published'):
        dates.append(f"Опубликовано: {frontmatter['published']}")
    if frontmatter.get('updated'):
        dates.append(f"Обновлено: {frontmatter['updated']}")
    if dates:
        # Ensure blank lines so Pandoc treats markers and content as separate blocks
        # This helps the Lua filter detect opening/content/closing correctly.
        return f"/// chapter-dates\n{' '.join(dates)}\n///"
    return ""


def adjust_heading_levels(content: str, level: int) -> Tuple[str, list]:
    """
    Shift markdown heading levels by specified amount.
    Returns (new_content, headings) where headings is a list of (pos, anchor or None)
    """
    headings = []
    def replace_heading(match):
        hashes = match.group(1)
        title = match.group(2)
        anchor = match.group(3) or ''
        current_level = len(hashes)
        new_level = max(1, min(current_level + level, 6))
        new_hashes = '#' * new_level
        # Extract anchor name if present
        anchor_name = None
        if anchor:
            m = re.match(r'\s*\{#([^}]+)\}', anchor)
            if m:
                anchor_name = m.group(1)
        headings.append((match.start(), anchor_name))
        return f"{new_hashes} {title}{anchor}"
    pattern = r'^(#{1,6})\s+(.+?)(\s*\{#[^}]+\})?$'
    new_content = re.sub(pattern, replace_heading, content, flags=re.MULTILINE)
    return new_content, headings


def add_anchor_to_first_h1(content: str, anchor_id: str) -> str:
    """
    Add anchor to the first h1 heading if it doesn't have one already.
    
    Transforms:
    - # Heading -> # Heading {#anchor-id}
    - # Heading {#existing} -> # Heading {#existing} (unchanged if has anchor)
    """
    # Find the first h1 heading
    match = re.search(r'^(# [^\n]*?)(\s*\{#[^}]+\})?\n', content, re.MULTILINE)
    if match:
        heading = match.group(1)
        existing_anchor = match.group(2)
        
        # If no anchor, add one
        if not existing_anchor:
            new_heading = f"{heading} {{{anchor_id}}}\n"
            return content[:match.start()] + new_heading + content[match.end():]
    
    return content


def fix_internal_links(content: str, current_file: str) -> str:
    """
    Fix internal markdown links for combined documents.
    
    Transformations:
    - [text](file.md) -> [text](#file-md)
    - [text](file.md#anchor) -> [text](#anchor)
    - [text](#anchor) -> [text](#anchor) (unchanged)
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
                # Anchor-only link (unchanged)
                new_url = url
            else:
                # File with anchor: file.md#anchor -> #anchor
                file_part, anchor_part = url.split('#', 1)
                # Just use the anchor part, ignore the file
                new_url = f"#{anchor_part}"
        else:
            # File without anchor: file.md -> #file-md
            if url.endswith('.md'):
                file_base = url.replace('.md', '-md').replace('/', '-')
                new_url = f"#{file_base}"
            else:
                new_url = url
        
        return f"[{text}]({new_url})"
    
    pattern = r'(!?)\[([^\]]+)\]\(([^)]+)\)'
    return re.sub(pattern, replace_link, content)


def extract_first_heading(content: str) -> str:
    """Extract first heading from markdown content."""
    content_clean = remove_frontmatter(content)
    match = re.search(r'^#{1,6}\s+(.+?)(?:\s*\{#[^}]+\})?$', content_clean, re.MULTILINE)
    return match.group(1).strip() if match else ''


def replace_details_with_source_link(content: str, site_url: str, filepath: str, headings: list) -> str:
    """
    Replace content inside /// details blocks with source link.
    
    Transforms:
        /// details | Title
        <content>
        ///
    
    Into:
        /// details | Title
        <source_link>
        ///
    
    Uses headings array to find nearest anchor above each block.
    """
    # Pattern: capture opening line with optional title, then any content until closing ///
    # Group 1: optional title part after 'details' (e.g., ' | Исходник')
    # Group 2: inner content (to be replaced)
    details_pattern = r'^///\s*details([^\n]*)\n+(.*?)\n+///'

    # Keep filename normalized for URL building
    filename_without_md = filepath.replace('.md', '').replace('\\', '/')

    def find_nearest_anchor_above(pos):
        anchor = None
        for hpos, hanchor in headings:
            if hpos < pos and hanchor:
                anchor = hanchor
            elif hpos >= pos:
                break
        return anchor

    def replace_details(match):
        title_part = match.group(1)  # Includes everything after 'details' on first line
        match_pos = match.start()
        anchor = find_nearest_anchor_above(match_pos)
        if anchor:
            source_link = f"{site_url.rstrip('/')}/{filename_without_md}#{anchor}"
        else:
            source_link = f"{site_url.rstrip('/')}/{filename_without_md}"
        # Preserve delimiters and title, replace inner content with the link only
        return f"/// details{title_part}\n\n<{source_link}>\n\n///"

    # Apply details-block replacement (DOTALL so '.' matches newlines)
    return re.sub(details_pattern, replace_details, content, flags=re.MULTILINE | re.DOTALL)


def mode_mkdocs(config_path: str) -> str:
    """
    Mode 1: Process mkdocs.yml configuration.
    
    - Extracts nav hierarchy
    - Reads files one by one
    - Shifts headings according to level
    - Fixes links
    - Returns combined content
    """
    config = load_yaml_config(config_path)
    
    if 'docs_dir' not in config:
        raise ValueError("Config missing 'docs_dir'")
    if 'nav' not in config:
        raise ValueError("Config missing 'nav'")
    if 'site_url' not in config:
        raise ValueError("Config missing 'site_url'")
    
    config_dir = Path(config_path).parent
    docs_dir = config_dir / config['docs_dir']
    
    if not docs_dir.exists():
        raise FileNotFoundError(f"Docs directory not found: {docs_dir}")
    
    nav_items = extract_nav_items(config['nav'])
    combined = []
    first_content = True
    epub_frontmatter = None  # Store EPUB-formatted frontmatter
    
    for title, filepath, level in nav_items:
        # External links
        if filepath and '://' in filepath:
            level_hashes = '#' * (level + 1)
            combined.append(f"\n{level_hashes} [{title}]({filepath})\n")
            continue
        
        # Section headers (no filepath)
        if not filepath:
            level_hashes = '#' * (level + 1)
            combined.append(f"\n{level_hashes} {title}\n\n")
            continue
        
        # File content
        file_path = docs_dir / filepath
        if not file_path.exists():
            print(f"[WARN] File not found: {file_path}", file=sys.stderr)
            continue
        
        print(f"[INFO] Processing: {filepath} (level {level})", file=sys.stderr)
        
        try:
            content = file_path.read_text(encoding='utf-8')
            
            # Extract frontmatter for dates and metadata
            frontmatter = extract_frontmatter(content)
            
            # Extract dates for display at end of section
            dates_text = format_dates_from_frontmatter(frontmatter)
            
            # Extract title from first heading
            title_from_file = extract_first_heading(content)
            if not title_from_file:
                title_from_file = filepath.replace('.md', '').replace('-', ' ').title()
            
            print(f"[INFO]   Title: {title_from_file}", file=sys.stderr)
            
            # Calculate anchor ID for the file
            anchor_id = f"#{filepath.replace('.md', '-md').replace('/', '-')}"
            
            # Process content
            content = remove_frontmatter(content)
            content = content.lstrip('\n')  # Remove leading blank lines after frontmatter
            
            content = add_anchor_to_first_h1(content, anchor_id)  # Add anchor to original h1
            content, headings = adjust_heading_levels(content, level)
            content = replace_details_with_source_link(content, config['site_url'], filepath, headings)
            content = fix_internal_links(content, filepath)
            
            # Combine with dates
            # First content section has no leading newline; subsequent ones do
            if first_content:
                output_section = content
                first_content = False
            else:
                output_section = f"\n{content}"
            
            # Add dates at the end if present
            if dates_text:
                output_section += f"\n{dates_text}\n"
            
            combined.append(output_section)
            
        except Exception as e:
            print(f"[ERROR] Processing {filepath}: {e}", file=sys.stderr)
            continue
    
    # Prepend EPUB frontmatter if available
    result = ''.join(combined)
    if epub_frontmatter:
        result = f"{epub_frontmatter}\n\n{result}"
    
    return result


def mode_single_file(input_file: str, level: int) -> str:
    """
    Mode 2: Process single markdown file.
    
    - Reads input.md
    - Shifts headings by specified level
    - Fixes internal links
    - Returns processed content
    """
    file_path = Path(input_file)
    
    if not file_path.exists():
        raise FileNotFoundError(f"Input file not found: {file_path}")
    
    print(f"[INFO] Processing: {input_file} (level shift: {level})", file=sys.stderr)
    
    content = file_path.read_text(encoding='utf-8')
    
    # Extract title for logging
    title_from_file = extract_first_heading(content)
    print(f"[INFO]   Title: {title_from_file}", file=sys.stderr)
    
    # Process content
    content = remove_frontmatter(content)
    content = adjust_heading_levels(content, level)
    content = fix_internal_links(content, input_file)
    
    return content


def main():
    """Main entry point with argument parsing."""
    parser = argparse.ArgumentParser(
        description='MkDocs Markdown Combiner - Two mode tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    # Required: input file
    parser.add_argument(
        'input',
        help='Input file: either mkdocs.yml or a markdown file'
    )
    
    # Optional: level for single file mode
    parser.add_argument(
        '--level',
        type=int,
        default=0,
        help='Heading level shift for single file mode (default: 0)'
    )
    
    args = parser.parse_args()
    
    try:
        # Determine mode based on input file
        if args.input.endswith('.yml') or args.input.endswith('.yaml'):
            # Mode 1: mkdocs.yml
            print(f"[INFO] Mode 1: Processing mkdocs.yml", file=sys.stderr)
            output = mode_mkdocs(args.input)
        else:
            # Mode 2: Single markdown file
            print(f"[INFO] Mode 2: Processing single file with level shift {args.level}", file=sys.stderr)
            output = mode_single_file(args.input, args.level)
        
        # Output to stdout
        print(output, end='')
        print(f"[INFO] Complete", file=sys.stderr)
        
    except Exception as e:
        print(f"[ERROR] {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
