#!/usr/bin/env python3
"""Strict YAML frontmatter validator for text/books/*.md.

Contract:
- file starts with `---` line, then a YAML block, closed by a `---` line
- the YAML block must parse with yaml.safe_load into a mapping
- every string value in the mapping must be double-quoted in the source
  line when it contains ':', '#', leading/trailing spaces, or starts with
  a special YAML char; inner double quotes must be escaped
- `title` values must ALWAYS be double-quoted (uniform rule)
- `livelib_book` / `livelib_review` values must be the SHORT canonical form
  https://www.livelib.ru/book/<digits> and
  https://www.livelib.ru/review/<digits>: a slug tail changes with the title
  while the numeric id redirects forever

Usage: python3 scripts/validate_books_frontmatter.py [books_dir]
Exit code 0 = all pass; prints FAIL lines otherwise.
"""
import json
import re
import sys
from pathlib import Path

import yaml

SPECIAL_START = set("!&*?|>%@`{}[]>,\"'")

# frontmatter livelib links must be the short canonical /kind/<digits> form
LINK_KINDS = {"livelib_book": "book", "livelib_review": "review"}
CANONICAL = {k: re.compile(rf"^https://www\.livelib\.ru/{v}/\d+$")
             for k, v in LINK_KINDS.items()}

FAILS = []


def fail(path, msg):
    FAILS.append(f"{path}: {msg}")


def raw_scalar(line: str) -> str | None:
    m = re.match(r"^([A-Za-z_][\w ]*):(?: (.*))?$", line)
    return m.group(2) if m else None


def check_quoting(path, key, raw, must_quote_always):
    if raw is None:
        return
    needs = (
        must_quote_always
        or ":" in raw
        or "#" in raw
        or raw != raw.strip()
        or (raw and raw[0] in SPECIAL_START)
    )
    if not needs:
        return
    if not (raw.startswith('"') and raw.endswith('"') and len(raw) >= 2):
        fail(path, f"{key}: needs double quotes, got {raw!r}")
        return
    inner = raw[1:-1]
    try:
        json.loads(f'"{inner}"')
    except Exception:
        fail(path, f"{key}: invalid quoting/escapes in {raw!r}")


def check_link_form(path, key, value):
    """livelib_book/livelib_review must be https://www.livelib.ru/<kind>/<digits>."""
    if key not in LINK_KINDS or not isinstance(value, str):
        return
    if not CANONICAL[key].match(value):
        fail(path, f"{key}: must be the short canonical form "
                  f"https://www.livelib.ru/{LINK_KINDS[key]}/<digits>, got {value!r}")


def validate_file(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        fail(path, "does not start with '---'")
        return {}
    try:
        end = lines.index("---", 1)
    except ValueError:
        fail(path, "no closing '---'")
        return {}
    block = "\n".join(lines[1:end])
    try:
        data = yaml.safe_load(block)
    except yaml.YAMLError as e:
        fail(path, f"YAML parse error: {str(e).splitlines()[0]}")
        return {}
    if not isinstance(data, dict):
        fail(path, "frontmatter is not a mapping")
        return {}
    for line in lines[1:end]:
        raw = raw_scalar(line)
        if raw is None:
            continue
        key = line.split(":", 1)[0].strip()
        check_quoting(path, key, raw, must_quote_always=(key == "title"))
    for key in LINK_KINDS:
        if key in data:
            check_link_form(path, key, data[key])
    return data


def main(books_dir: str) -> int:
    files = sorted(Path(books_dir).glob("*.md"))
    for p in files:
        validate_file(p)
    if FAILS:
        print(f"FAIL {len(FAILS)} problem(s) in {len(files)} files:")
        for f in FAILS:
            print(" -", f)
        return 1
    print(f"OK {len(files)}/{len(files)} files pass")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "text/books"))
