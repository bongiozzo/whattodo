# Convert AsciiDoc to Markdown

## AsciiDoc to Markdown Conversion Logic

1. **Start the new file with a Front Matter block.**

    - Start with Front Matter block at the top of the .md file with exactly this content:
        ---
        comments: true
        created: [take from source .adoc]
        published: [take from source .adoc]
        # updated: [take from source .adoc]
        description: [take from source .adoc]
        ---
    - Ensure all required metadata is present and formatted for Markdown.

2. **Process the file incrementally to save consistency:**
    - **External links:**
        - Find and replace all external links in `[text](http(s?)://)` format.
    - **xref links:**
        - Find all `xref:` links.
        - Update targets to the correct Markdown file or anchor.
    - **Headings:**
        - Convert all headings to Markdown format.
        - Place `{#anchor}` on the same line as the heading.
    - **Images:**
        - Convert all images to Markdown format, preserving attributes (e.g., width).
        - Add `{ loading=lazy }` to each image.
        - Add a `/// caption` block after each image, as in the example.
    - **Quote blocks:**
        - Convert all quote blocks to the required Markdown format, as shown in the example.
        - Convert '[quote]' blocks to '!!! quote "Цитата"' as shown in the example.
        - Always include the author line after the quote, formatted as '^^[Author](url)^^' if a URL is present, or '^^Author^^' if not.
        - Use 4 spaces for indentation inside the quote block.

    - **Sidebar blocks:**
        - Convert all sidebar blocks to the required Markdown format, as shown in the example.
        - Convert '[sidebar]' to '!!! note "Title"' as shown in the example.
        - Use 4 spaces for indentation inside the sidebar block.
        - If the sidebar has no title, use '!!! note ""'.

4. **Update all italic and bold and other formatting to Markdown syntax.**
    - Replace AsciiDoc formatting with Markdown (`*italic*`, `**bold**`) - be sure not to modify urls in link formatting.
    - For numbered lists use 1. 1. 1. format.
    - For verse blocks use > at the start of each line and double space at the end of each line.

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
...

...
...
____

Use format:

!!! quote "Цитата"

    ...

    ...
    ...
  
    ^^[Author](https://url)^^

### [sidebar] example:

[sidebar]
.Title
****
...

...
...
****

Use format:

!!! note "Title"

    ...

    ...
    ...

### image example:

.Caption
image::image.png[Caption, width=75%]

Use format:

![Caption text](img/image.jpg){ width="75%", loading=lazy }
/// caption
Caption text
///

