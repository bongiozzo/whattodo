---
mode: agent
description: This prompt is used to convert AsciiDoc content to Markdown format.
---

# Copilot Prompts

## Convert AsciiDoc to Markdown

### AsciiDoc to Markdown Conversion Logic

1. **Copy the source file to a new Markdown file.**

    - Copy the specified .adoc file to the text/ru folder with a .md extension.

2. **Start the new file with a Front Matter block.**

    - Start with Front Matter block at the top of the .md file with exactly this content:
        ---
        comments: true
        created: [take from source .adoc]
        published: [take from source .adoc]
        # updated: [take from source .adoc]
        description: [take from source .adoc]
        ---
    - Do not add extra lines inside the Front Matter block.
    - Ensure all required metadata is present and formatted for Markdown.

3. **Process the file incrementally, updating and saving after each element type:**
    - **External links:**
        - Find all external links in `[text](url)` format.
        - Refine and replace as needed for Markdown compatibility.
        - Save the file after updating links.
    - **xref links:**
        - Find all `xref:` links.
        - Update targets to the correct Markdown file or anchor.
        - Save after each batch of updates.
    - **Headings:**
        - Convert all headings to Markdown format.
        - Place `{#anchor}` on the same line as the heading.
        - Save after heading updates.
    - **Images:**
        - Convert all images to Markdown format, preserving attributes (e.g., width).
        - Add `{ loading=lazy }` to each image.
        - Add a `/// caption` block after each image, as in the example.
        - Save after image updates.
    - **Quote blocks:**
        - Convert all quote blocks to the required Markdown format, as shown in the example.
        - Convert '[quote]' blocks to '!!! quote "Цитата"' as shown in the example.
        - Always include the author line after the quote, formatted as '^^[Author](url)^^' if a URL is present, or '^^Author^^' if not.
        - Use 4 spaces for indentation inside the quote block.
        - Save after quote updates.

    - **Sidebar blocks:**
        - Convert all sidebar blocks to the required Markdown format, as shown in the example.
        - Convert '[sidebar]' to '!!! note "Title"' as shown in the example.
        - Use 4 spaces for indentation inside the sidebar block.
        - If the sidebar has no title, use '!!! note ""'.
        - Save after sidebar updates.

4. **Update all italic and bold formatting to Markdown syntax.**
    - Replace AsciiDoc formatting with Markdown (`*italic*`, `**bold**`).
    - Convert _italic_ to *italic*, *bold* to **bold**, monospace to backticks, etc.
    - Save after formatting updates.

5. **Repeat the find, refine, replace, and save process for each element type, ensuring granular, incremental updates and version safety.**

6. **Review the final file for completeness and consistency.**

    Do not update final partials/time.adoc at the end.
---

*Follow this logic for reliable, step-by-step AsciiDoc to Markdown conversion with incremental, safe updates.*

### IMPORTANT NOTES

**Do not omit, skip, or reposition any text content. Every line and block must be preserved and converted.**

#### Special Blocks

If a block or macro is not recognized, leave it for later review.

## Examples

### [quote] example

[quote, 'https://url[Author]']
____
Citation text
____

Use format:

!!! quote "Цитата"

    Citation text
  
    ^^[Author](https://url)^^

### [sidebar] example:

[sidebar]
.Title
****
Content
****

Use format:

!!! note "Title"

    Content  

### image example:

.Caption
image::image.png[Caption, width=75%]

Use format:

![Caption](img/image.jpg){ width="75%", loading=lazy }
/// caption
Caption
///

