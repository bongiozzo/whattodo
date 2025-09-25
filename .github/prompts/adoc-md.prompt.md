---
mode: agent
description: This prompt is used to convert AsciiDoc content to Markdown format.
---

# Copilot Prompts

## Convert AsciiDoc to Markdown

### Copy file

Do not create the .md file from scratch.
Copy the specified .adoc file to the text/ru folder with a .md extension.
Do not try to convert whole file at once.
Do not bother about lint errors, we will fix them later.
Do not include final partials/time.adoc at the end.

### Convert AsciiDoc to Markdown

**All AsciiDoc content, including comments, callouts, and custom blocks, must be preserved and converted to the closest Markdown equivalent. Do not omit, skip, or reposition any text content. Every line and block must be preserved and converted.**

#### Front Matter

Start with Front Matter block at the top of the .md file with:
---
comments: true
created: Fill from adoc
published: Fill from adoc
# updated: Fill from adoc
description: Fill from adoc
---
Do not add extra lines inside the Front Matter block.

#### Headings

Convert every '=' heading to '#' for h1, '##' for h2, '###' for h3, etc.
Always add '{#anchor}' after the heading if an anchor is present in the AsciiDoc (inline or block) in the same line.
The h1 heading after Front Matter must match the AsciiDoc title.

Read the copied file section by section, convert it and save .md file in several steps to be sure all headings and content are in correct order.

#### Links

Convert all 'xref:' and 'https://' links to Markdown '[]()' format.

#### Quotes

Convert '[quote]' blocks to '!!! quote "Цитата"' as shown in the example.
Always include the author line after the quote, formatted as '^^[Author](url)^^' if a URL is present, or '^^Author^^' if not.
Use 4 spaces for indentation inside the quote block.

#### Sidebars and Admonitions

Convert '[sidebar]' to '!!! note "Title"' as shown in the example.
Use 4 spaces for indentation inside the sidebar block.
If the sidebar has no title, use '!!! note ""'.

#### Images

Convert 'image::' to '![]()' with attributes as shown in the example.
Always add a '/// caption ... ///' block after the image, even if the caption is empty.

#### Inline Formatting

Convert _italic_ to *italic*, *bold* to **bold**, monospace to backticks, etc.

#### Anchors

Convert all inline anchors ('[[anchor]]', '[#anchor]') to '{#anchor}' in Markdown, placed in the same line as the heading or text they refer to.

#### Special Blocks

If a block or macro is not recognized, preserve it as a Markdown code block and add a comment for manual review.

#### Preservation

All AsciiDoc content, including comments, callouts, and custom blocks, must be preserved and converted to the closest Markdown equivalent.

## Examples

### [quote] like this:

[quote, 'https://url[Author]']
____
Citation text
____

Use format:

!!! quote "Цитата"

    Citation text
  
    ^^[Author](https://url)^^

### For [sidebar] like this:

[sidebar]
.Title
****
Content
****

Use format:

!!! note "Title"

    Content  

### For images like this:

.Caption
image::image.png[Caption, width=75%]

Use format:

![Caption](img/image.jpg){ width="75%", loading=lazy }
/// caption
Caption
///

## Reference

For reference in uncertain cases you can check already converted .md files and their corresponding .adoc source