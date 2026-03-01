```prompt
---
agent: agent
---

# Changelog Summary in Russian

Generate a structured bulleted summary in Russian of all text changes since a given reference point.

## Input

The user provides one of:
- A **git tag** (e.g. `v1.0`)
- A **commit hash** (e.g. `a3f9c12`)
- A **date** (e.g. `2025-01-01`)

## Step 1 — Get the diff

Run the appropriate git command based on input type:

**Tag or commit hash:**
```bash
git diff <tag_or_hash>..HEAD -- 'text/*.md'
```

**Date:**
```bash
git log --oneline --after="<date>" -- 'text/*.md'
# then use the oldest commit hash from the output:
git diff <oldest_commit>^..HEAD -- 'text/*.md'
```

## Step 2 — Analyse changes

- Focus only on added (`+`) and removed (`-`) lines in `text/*.md` files
- Ignore frontmatter, blank lines, and purely formatting changes
- Group changes by file
- For each changed chunk, identify the nearest heading above it — this will be used as the anchor

## Step 3 — Build anchor links

The site URL is `https://text.sharedgoals.ru/`.

URL mapping rules:

- `text/index.md` → `https://text.sharedgoals.ru/`
- `text/<filename>.md` → `https://text.sharedgoals.ru/<filename>/`

Heading anchors follow MkDocs slug rules:
- lowercase, spaces → hyphens, punctuation removed
- Example: heading `## Общие цели {#shared_goals}` → anchor `#shared_goals`

Link format:
```
[ключевое слово или фраза](https://text.sharedgoals.ru/chapter#anchor)
```

## Step 4 — Output

This summary will be used as a **post for a Telegram channel**, so write it in an engaging, conversational tone suitable for a public audience — not a dry technical log.

Write a **bulleted list in Russian** summarising what changed, grouped by chapter.
Each bullet must contain at least one link pointing to the relevant heading.

Focus on **semantic changes** (new ideas, revised arguments, added examples, removed sections)
— not on wording tweaks or punctuation fixes.

Example output format:
```
- В главе о [цифровых инструментах](https://text.sharedgoals.ru/p2-140-digital#tools) добавлено описание новых подходов к работе с задачами.
- Раздел [о рутине](https://text.sharedgoals.ru/p2-160-routine#practice) переработан: акцент смещён на осознанность вместо продуктивности.
- В [открытом исходном коде](https://text.sharedgoals.ru/p2-170-opensource#contribute) добавлен новый пример участия в проекте.
```
```
