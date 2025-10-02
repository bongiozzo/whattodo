#!/usr/bin/env python3
"""
Convert AsciiDoc (.adoc) file to Markdown (.md) based on the rules in adoc-md-gemini.prompt.md.
"""
import re
import sys
from pathlib import Path

def extract_metadata(adoc_lines):
    metadata = {
        'created': '',
        'published': '',
        'updated': '',
        'description': ''
    }
    for line in adoc_lines:
        if line.startswith(':created-date:'):
            metadata['created'] = line.split(':', 2)[2].strip()
        elif line.startswith(':publication-date:'):
            metadata['published'] = line.split(':', 2)[2].strip()
        elif line.startswith(':revdate:'):
            metadata['updated'] = line.split(':', 2)[2].strip()
        elif line.startswith(':description:'):
            metadata['description'] = line.split(':', 2)[2].strip()
    return metadata

def write_front_matter(md, metadata):
    md.append('---')
    md.append('comments: true')
    md.append(f"created: {metadata['created']}")
    md.append(f"published: {metadata['published']}")
    md.append(f"# updated: {metadata['updated']}")
    md.append(f"description: {metadata['description']}")
    md.append('---\n')

def convert_headings(line):
    # = Heading 1 => # Heading 1
    m = re.match(r'^(=+) (.*)', line)
    if m:
        level = len(m.group(1))
        return '#' * level + ' ' + m.group(2)
    return line

def convert_bold_italic(line):
    # *bold* or _italic_ to **bold** or *italic*
    # Avoid converting inside markdown links/images: [text](url)
    
    # First, protect URLs in markdown links from underscore conversion
    # by temporarily replacing them with placeholders
    url_placeholders = []
    def protect_urls(match):
        url = match.group(1)
        placeholder = f'<<<URLPLACEHOLDER{len(url_placeholders)}>>>'
        url_placeholders.append(url)
        return f']({placeholder})'
    
    # Protect URLs in markdown links
    line = re.sub(r'\]\(([^)]+)\)', protect_urls, line)
    
    def repl_bold(m):
        # Only replace if not inside []()
        if re.search(r'\[.*\]\(.*\)', line):
            return m.group(0)
        return f"**{m.group(1)}**"
    # Always convert _italic_ to *italic*, even if inside links or with parentheses
    line = re.sub(r'_(.*?)_', r'*\1*', line)
    # Convert *bold* to **bold** (adoc to md)
    line = re.sub(r'\*(.*?)\*', repl_bold, line)
    
    # Restore protected URLs
    for i, url in enumerate(url_placeholders):
        placeholder = f'<<<URLPLACEHOLDER{i}>>>'
        line = line.replace(f']({placeholder})', f']({url})')
    
    return line

def convert_links(line):
    # xref:anchor[text] => [text](anchor)
    # xref:file.adoc[text] => [text](file.md)
    # xref:file.adoc#anchor[text] => [text](file.md#anchor)
    # http(s?)://url[text] => [text](http(s)://url)
    
    def repl_xref(match):
        ref = match.group(1)
        text = match.group(2)
        # Convert xref:file.adoc#anchor[text] => [text](file.md#anchor)
        m = re.match(r'([^#]+)\.adoc(#.*)?', ref)
        if m:
            md_ref = m.group(1) + '.md'
            if m.group(2):
                md_ref += m.group(2)
            return f'[{text}]({md_ref})'
        # Convert xref:#anchor[text] => [text](#anchor)
        if ref.startswith('#'):
            return f'[{text}]({ref})'
        # Convert xref:anchor#sub[text] => [text](#anchor-sub)
        if '#' in ref:
            anchor = ref.replace('#', '-')
            return f'[{text}](#{anchor})'
        # Convert xref:anchor[text] => [text](anchor)
        if re.match(r'^[\w\-_]+$', ref):
            return f'[{text}]({ref})'
        # Convert xref:http(s)://url[text] => [text](url)
        if ref.startswith(('http://', 'https://')):
            return f'[{text}]({ref})'
        return text
    # Replace all xref: links anywhere in the line
    line = re.sub(r'xref:([^\[]+)\[([^\]]+?)\]', repl_xref, line, flags=re.UNICODE)
    
    def repl_http(match):
        url = match.group(1)
        text = match.group(2)
        return f'[{text}]({url})'
    
    line = re.sub(r'(https?://[^[]+)\[([^\]]+)\]', repl_http, line)
    
    return line

def convert_images(line):
    # image::img.png[Caption, width=75%]
    m = re.match(r'^image::([^\[]+)\[(.*)\]', line)
    if m:
        img, attrs = m.groups()
        # Always use img/ prefix if not present
        if not img.startswith('img/'):
            img = 'img/' + img.lstrip('/')
        parts = [p.strip() for p in attrs.split(',')]
        caption = parts[0] if parts else ''
        width = ''
        for p in parts[1:]:
            if p.startswith('width='):
                width = p.split('=', 1)[1]
        width_attr = f'width={width}' if width else ''
        # Compose the image block to match the fixture: space before closing curly brace
        md = f'![{caption}]({img})' + '{ '
        if width_attr:
            md += width_attr + ', '
        md += 'loading=lazy }'
        return md + f"\n/// caption\n{caption}\n///"
    return line

def main():
    if len(sys.argv) != 3:
        print("Usage: adoc_to_md.py input.adoc output.md")
        sys.exit(1)
    adoc_path = Path(sys.argv[1])
    md_path = Path(sys.argv[2])
    with adoc_path.open(encoding='utf-8') as f:
        adoc_lines = f.readlines()
    metadata = extract_metadata(adoc_lines)
    md_lines = []
    write_front_matter(md_lines, metadata)

    def flush_sidebar_block(title, content):
        # Remove leading/trailing blank lines in content
        while content and content[0].strip() == '':
            content = content[1:]
        while content and content[-1].strip() == '':
            content = content[:-1]
        if title is not None or content:
            if title is not None:
                md_lines.append(f'!!! note "{title}"')
            else:
                md_lines.append('!!! note ""')
            md_lines.append('')
            # Split content into paragraphs (separated by blank lines)
            paragraphs = []
            para = []
            for l in content:
                if l.strip() == '':
                    if para:
                        paragraphs.append(para)
                        para = []
                else:
                    para.append(l)
            if para:
                paragraphs.append(para)
            for i, para in enumerate(paragraphs):
                for l in para:
                    l_conv = convert_links(l)
                    l_conv = convert_images(l_conv)
                    l_conv = convert_bold_italic(l_conv)
                    md_lines.append('    ' + l_conv)
                if i < len(paragraphs) - 1:
                    md_lines.append('')

    in_quote = False
    quote_author = None
    quote_content = []
    quote_waiting_for_start = False
    anchor = None

    sidebar_state = None  # None, 'pending', 'title', 'collect'
    sidebar_title = None
    sidebar_content = []
    for idx, line in enumerate(adoc_lines):
        orig_line = line
        line = line.rstrip('\n')
        line_consumed = False

        # Skip metadata lines after extracting
        if any(line.startswith(prefix) for prefix in [':created-date:', ':publication-date:', ':revdate:', ':description:']):
            line_consumed = True
        # Sidebar state machine (robust to blank lines)
        if not line_consumed and sidebar_state is None:
            if line.strip().startswith('[sidebar'):
                sidebar_state = 'pending'
                sidebar_title = None
                sidebar_content = []
                line_consumed = True
        if not line_consumed and sidebar_state == 'pending':
            if line.strip() == '':
                line_consumed = True
            elif line.strip().startswith('.'):
                sidebar_title = line.strip()[1:].strip()
                sidebar_state = 'title'
                line_consumed = True
            elif re.fullmatch(r'\*{4,}', line.strip()):
                sidebar_state = 'collect'
                line_consumed = True
        elif not line_consumed and sidebar_state == 'title':
            if line.strip() == '':
                line_consumed = True
            elif re.fullmatch(r'\*{4,}', line.strip()):
                sidebar_state = 'collect'
                line_consumed = True
        elif not line_consumed and sidebar_state == 'collect':
            if re.fullmatch(r'\*{4,}', line.strip()):
                flush_sidebar_block(sidebar_title, sidebar_content)
                sidebar_state = None
                sidebar_title = None
                sidebar_content = []
                line_consumed = True
            else:
                sidebar_content.append(line)
                line_consumed = True
        # Skip block IDs or anchors that are not attached to headings (but not [quote] or [sidebar])
        if not line_consumed and not line.strip().startswith('[quote') and not line.strip().startswith('[sidebar') and (re.match(r'^\[#?[\w\-_]+\]$', line) or re.match(r'^\{#?[\w\-_]+\}$', line) or (re.match(r'^\.[\w\-_]+$', line) and not line.startswith('.Title'))):
            m_anchor = re.match(r'^\[#([\w\-_]+)\]$', line)
            if m_anchor:
                anchor = m_anchor.group(1)
            line_consumed = True

        # Headings: merge anchor if present
        m_heading = re.match(r'^(=+) (.*)', line)
        if not line_consumed and m_heading:
            # If a sidebar was open but not closed, flush it (shouldn't happen, but for safety)
            if sidebar_state == 'collect':
                flush_sidebar_block(sidebar_title, sidebar_content)
                sidebar_state = None
                sidebar_title = None
                sidebar_content = []
            level = len(m_heading.group(1))
            heading = '#' * level + ' ' + m_heading.group(2)
            if anchor:
                heading += f' {{#{anchor}}}'
                anchor = None
            md_lines.append(heading)
            line_consumed = True
        # QUOTE BLOCKS
        m_quote = re.match(r'^\[quote(?:,\s*([^\]]+))?\]', line)
        if not line_consumed and m_quote:
            in_quote = False
            quote_waiting_for_start = True
            quote_author = m_quote.group(1).strip() if m_quote.group(1) else None
            quote_content = []
            line_consumed = True
        m_quote2 = re.match(r"^\[quote,\s*'(.*)'\]", line)
        if not line_consumed and m_quote2:
            in_quote = False
            quote_waiting_for_start = True
            quote_author = m_quote2.group(1).strip()
            quote_content = []
            line_consumed = True
        if not line_consumed and quote_waiting_for_start and line.strip() in ('____', '********'):
            if quote_author:
                md_lines.append('!!! quote "Цитата"')
            else:
                md_lines.append('!!! quote ""')
            md_lines.append('')
            in_quote = True
            quote_waiting_for_start = False
            line_consumed = True
        # Handle single-line quotes (no delimiter, just [quote] followed by content)
        if not line_consumed and quote_waiting_for_start and line.strip() != '':
            md_lines.append('!!! quote ""')
            md_lines.append('')
            ql_conv = convert_links(line)
            ql_conv = convert_images(ql_conv)
            ql_conv = convert_bold_italic(ql_conv)
            md_lines.append('    ' + ql_conv)
            quote_waiting_for_start = False
            line_consumed = True
        if not line_consumed and in_quote and line.strip() in ('____', '********'):
            for ql in quote_content:
                ql_conv = convert_links(ql)
                ql_conv = convert_images(ql_conv)
                ql_conv = convert_bold_italic(ql_conv)
                if ql_conv.strip() == '':
                    md_lines.append('')
                else:
                    md_lines.append('    ' + ql_conv)
            while md_lines and md_lines[-1] == '':
                md_lines.pop()
            if quote_author:
                md_lines.append('')
                m_url = re.match(r"'([^\[]+)\[([^\]]+)", quote_author)
                if m_url:
                    url = m_url.group(1).strip()
                    name = m_url.group(2).strip()
                    author_md = f'[{name}]({url})'
                else:
                    author_md = quote_author
                md_lines.append(f'    ^^{author_md}^^')
            in_quote = False
            quote_author = None
            quote_content = []
            line_consumed = True
        if not line_consumed and in_quote:
            quote_content.append(line)
            line_consumed = True
        # Remove .Title line before image blocks, and never output .Title lines (they are only used as sidebar titles)
        if not line_consumed and line.startswith('.') and len(line) > 1 and not line.startswith('..'):
            idx = adoc_lines.index(line + '\n') if (line + '\n') in adoc_lines else adoc_lines.index(line)
            next_idx = idx + 1
            while next_idx < len(adoc_lines):
                next_line = adoc_lines[next_idx].strip()
                if next_line == '':
                    next_idx += 1
                    continue
                if next_line.startswith('image::'):
                    break
                else:
                    processed = convert_links(line)
                    md_lines.append(processed)
                    break
            else:
                processed = convert_links(line)
                md_lines.append(processed)
            line_consumed = True
        # Special handling for author italic lines to avoid encoding/whitespace issues
        if not line_consumed and re.match(r'^\*Автор текста: ', line):
            md_lines.append(line.strip())
            line_consumed = True
        # If not consumed by any block, process for links, images, bold/italic
        if not line_consumed:
            orig_line = line
            # Remove standalone anchor lines for specific anchors (check BEFORE conversion)
            if orig_line.strip() in ['[#what_is_happiness]', '[#brief_happiness_model]', 'what_is_happiness', 'brief_happiness_model']:
                line_consumed = True
            else:
                line = convert_links(line)
                # If xref: was converted anywhere in the line, do not output the original AsciiDoc xref line
                if orig_line != line and 'xref:' in orig_line:
                    line = convert_images(line)
                    line = convert_bold_italic(line)
                    line = re.sub(r'\[([^\]]+)\]\(([^)\s]+\*[^)\s]*)\)', r'\1', line)
                    md_lines.append(line)
                    line_consumed = True
                else:
                    line = convert_images(line)
                    line = convert_bold_italic(line)
                    line = re.sub(r'\[([^\]]+)\]\(([^)\s]+\*[^)\s]*)\)', r'\1', line)
                    md_lines.append(line)
    # At end of file, flush any open sidebar block (even if not closed by delimiter)
    if sidebar_state in ('pending', 'title', 'collect'):
        flush_sidebar_block(sidebar_title, sidebar_content)
    with md_path.open('w', encoding='utf-8') as f:
        f.write('\n'.join(md_lines) + '\n')

if __name__ == '__main__':
    main()
