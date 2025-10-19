#!/usr/bin/env python3
"""
Combine MkDocs Markdown files into a single document.

This script:
1. Reads mkdocs.yml configuration
2. Combines all .md files from docs_dir into a single Markdown file
3. Generates a Table of Contents following the nav: section structure
4. Fixes internal links: (filename.md#anchor) -> (#filename-md-anchor)
"""

import yaml
import os
import re
from pathlib import Path
from typing import List, Dict, Any, Tuple


def load_config(config_path: str = "mkdocs.yml") -> Dict[str, Any]:
    """
    Load and parse MkDocs configuration file.
    
    Args:
        config_path: Path to mkdocs.yml relative to script location
        
    Returns:
        Dictionary containing parsed YAML configuration
        
    Raises:
        FileNotFoundError: If config file doesn't exist
        yaml.YAMLError: If config file is invalid YAML
    """
    # Resolve path relative to script location
    script_dir = Path(__file__).parent
    config_file = script_dir / config_path
    
    if not config_file.exists():
        raise FileNotFoundError(f"Config file not found: {config_file}")
    
    # Read and parse YAML file (using BaseLoader to avoid Python object instantiation)
    with open(config_file, 'r', encoding='utf-8') as f:
        # Try safe_load first, fall back to BaseLoader if it fails
        try:
            f.seek(0)
            config = yaml.safe_load(f)
        except yaml.constructor.ConstructorError:
            f.seek(0)
            # Use custom loader that skips unknown tags
            class SkipUnknownLoader(yaml.SafeLoader):
                pass
            
            def skip_unknown(loader, tag_suffix, node):
                return None
            
            SkipUnknownLoader.add_multi_constructor('!python', skip_unknown)
            SkipUnknownLoader.add_multi_constructor('tag:yaml.org,2002:python/', skip_unknown)
            
            config = yaml.load(f, Loader=SkipUnknownLoader)
    
    # Validate required fields
    if 'docs_dir' not in config:
        raise ValueError("Config must contain 'docs_dir' field")
    if 'nav' not in config:
        raise ValueError("Config must contain 'nav' field")
    
    return config


def extract_nav_items(nav_config: List[Any], level: int = 0) -> List[Tuple[str, str, int]]:
    """
    Extract navigation items from mkdocs nav configuration.
    
    Args:
        nav_config: List of navigation items from mkdocs.yml
        level: Current nesting level for hierarchy
        
    Returns:
        List of tuples (title, filepath, level) for each item
        
    Example:
        Input: [{'Section': ['file1.md', 'file2.md']}]
        Output: [('Section', '', 0), ('file1.md', 'file1.md', 1), ('file2.md', 'file2.md', 1)]
    """
    items = []
    
    for item in nav_config:
        if isinstance(item, str):
            # Simple file entry
            if item.endswith('.md'):
                # Extract title from filename
                title = item.replace('.md', '').replace('-', ' ').title()
                items.append((title, item, level))
        elif isinstance(item, dict):
            # Section with nested items
            for section_title, section_items in item.items():
                # Check if this is an external link
                if isinstance(section_items, str) and '://' in section_items:
                    # Skip external links
                    continue
                
                # Add section header
                items.append((section_title, '', level))
                
                # Recursively process nested items
                if isinstance(section_items, list):
                    items.extend(extract_nav_items(section_items, level + 1))
    
    return items


def generate_toc(nav_items: List[Tuple[str, str, int]]) -> str:
    """
    Generate Table of Contents in Markdown format.
    
    Args:
        nav_items: List of (title, filepath, level) tuples from navigation
        
    Returns:
        Markdown-formatted TOC string
        
    Logic:
        - Section headers become TOC headers (##, ###, etc.)
        - Files become links to their anchors in combined document
        - Anchor format: #filename-md (without extension dots)
    """
    toc_lines = ["# Содержание\n"]
    
    for title, filepath, level in nav_items:
        indent = "  " * level  # Indentation for nested items
        
        if filepath:
            # This is a file entry - create anchor link
            anchor = filepath.replace('.md', '-md').replace('.', '-')
            toc_lines.append(f"{indent}- [{title}](#{anchor})")
        else:
            # This is a section header
            heading_level = "#" * (level + 2)  # Start from ## for sections
            toc_lines.append(f"\n{heading_level} {title}\n")
    
    return "\n".join(toc_lines) + "\n"


def read_markdown_file(filepath: Path) -> str:
    """
    Read markdown file content.
    
    Args:
        filepath: Path to markdown file
        
    Returns:
        File content as string
        
    Raises:
        FileNotFoundError: If file doesn't exist
        UnicodeDecodeError: If file encoding is not UTF-8
    """
    if not filepath.exists():
        raise FileNotFoundError(f"Markdown file not found: {filepath}")
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError as e:
        raise UnicodeDecodeError(
            e.encoding, e.object, e.start, e.end,
            f"Failed to decode {filepath} as UTF-8"
        )


def fix_internal_links(content: str, current_file: str) -> str:
    """
    Fix internal links in markdown content for combined document.
    
    Args:
        content: Markdown content with links
        current_file: Name of current file (for relative link resolution)
        
    Returns:
        Content with fixed links
        
    Link transformation logic:
        - [text](filename.md) -> [text](#filename-md)
        - [text](filename.md#anchor) -> [text](#filename-md-anchor)
        - [text](#anchor) -> [text](#current-file-anchor)
        - External links (http://, https://) remain unchanged
        - Image links (![...]) remain unchanged
    """
    def replace_link(match):
        # Extract link components
        is_image = match.group(1) == '!'
        text = match.group(2)
        url = match.group(3)
        
        # Skip image links
        if is_image:
            return match.group(0)
        
        # Skip external links
        if url.startswith(('http://', 'https://', '//', 'mailto:')):
            return match.group(0)
        
        # Handle internal links
        if '#' in url:
            # Link with anchor
            if url.startswith('#'):
                # Anchor-only link in current file
                filename_base = current_file.replace('.md', '-md')
                new_url = f"#{filename_base}-{url[1:]}"
            else:
                # Link to another file with anchor
                file_part, anchor_part = url.split('#', 1)
                if file_part.endswith('.md'):
                    file_base = file_part.replace('.md', '-md').replace('.', '-')
                    new_url = f"#{file_base}-{anchor_part}"
                else:
                    new_url = url
        else:
            # Link without anchor
            if url.endswith('.md'):
                file_base = url.replace('.md', '-md').replace('.', '-')
                new_url = f"#{file_base}"
            else:
                # Not a markdown file, keep as is
                new_url = url
        
        return f"[{text}]({new_url})"
    
    # Regex to match markdown links: [text](url) or ![text](url)
    pattern = r'(!?)\[([^\]]+)\]\(([^)]+)\)'
    return re.sub(pattern, replace_link, content)


def add_file_anchor(filename: str) -> str:
    """
    Generate anchor for a file in combined document.
    
    Args:
        filename: Original filename (e.g., 'p1-010-happiness.md')
        
    Returns:
        Anchor string (e.g., '# p1-010-happiness-md {#p1-010-happiness-md}')
        
    Logic:
        - Remove .md extension
        - Add -md suffix
        - Create level 1 heading with anchor
    """
    # Strip .md extension and replace dots with hyphens
    base_name = filename.replace('.md', '').replace('.', '-')
    
    # Add -md suffix for anchor
    anchor_id = f"{base_name}-md"
    
    # Format as markdown heading with explicit anchor
    return f"\n\n---\n\n# {base_name} {{#{anchor_id}}}\n\n"


def combine_files(docs_dir: Path, nav_items: List[Tuple[str, str, int]]) -> str:
    """
    Combine all markdown files into single document.
    
    Args:
        docs_dir: Base directory containing markdown files
        nav_items: List of (title, filepath, level) tuples from navigation
        
    Returns:
        Combined markdown content
        
    Logic:
        - Iterate through nav_items in order
        - For each file:
          - Add file anchor heading
          - Read file content
          - Fix internal links
          - Add content to combined output
        - Separate files with horizontal rules or page breaks
    """
    combined_content = []
    
    for title, filepath, level in nav_items:
        # Skip section headers (no filepath)
        if not filepath:
            continue
        
        # Construct full file path
        file_path = docs_dir / filepath
        
        if not file_path.exists():
            print(f"Warning: File not found: {file_path}")
            continue
        
        print(f"Processing: {filepath}")
        
        # Add file anchor
        combined_content.append(add_file_anchor(filepath))
        
        # Read file content
        try:
            content = read_markdown_file(file_path)
            
            # Fix internal links
            fixed_content = fix_internal_links(content, filepath)
            
            # Add to combined output
            combined_content.append(fixed_content)
            
        except Exception as e:
            print(f"Error processing {filepath}: {e}")
            continue
    
    return "\n".join(combined_content)


def main():
    """
    Main entry point for the script.
    
    Workflow:
        1. Load mkdocs.yml configuration
        2. Extract navigation structure
        3. Generate Table of Contents
        4. Combine all files with fixed links
        5. Write output to combined.md
    """
    try:
        # Load config from mkdocs.yml (parent directory)
        print("Loading configuration...")
        config = load_config("../mkdocs.yml")
        
        # Extract docs_dir and nav sections
        docs_dir = Path(__file__).parent.parent / config['docs_dir']
        nav_config = config['nav']
        
        print(f"Documents directory: {docs_dir}")
        
        # Extract navigation items
        print("Extracting navigation structure...")
        nav_items = extract_nav_items(nav_config)
        
        # Generate TOC
        print("Generating Table of Contents...")
        toc = generate_toc(nav_items)
        
        # Combine all files
        print("Combining markdown files...")
        combined_content = combine_files(docs_dir, nav_items)
        
        # Prepare output
        output_content = toc + "\n\n" + combined_content
        
        # Write output file
        output_file = Path(__file__).parent.parent / "combined.md"
        print(f"Writing output to: {output_file}")
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output_content)
        
        print(f"\n✓ Successfully created combined document: {output_file}")
        print(f"  Total files processed: {sum(1 for _, fp, _ in nav_items if fp)}")
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)


if __name__ == "__main__":
    main()
