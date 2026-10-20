#!/usr/bin/env python3
"""p3_migrate.py — перенос важности из text/p3-references.md в frontmatter книг.

Одновременная (one-time) миграция: библиография text/p3-references.md была
источником того, какие книги важны и в каком порядке. Теперь важность живёт в
frontmatter заметок книги:

    important: true
    weight: <номер строки-маркера>     # 1 = первая строка библиографии

Тезис и отображаемое имя НЕ переносятся: тезис — это заголовок собственного
отзыва книги на LiveLib (свежий экспорт livelib-reviews-api.json), имя —
заголовок самой заметки. Файл text/p3-references.md этот скрипт НЕ меняет.

Usage:
    uv run python scripts/p3_migrate.py [--repo .] [--references PATH]
        [--export PATH] [--apply]

Без --apply — только отчёт (dry-run).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

BULLET = re.compile(r"^- (?P<body>.*\S)\s*$")
LINK = re.compile(r"\[(?P<name>[^\]]*)\]\((https?://(?:www\.)?livelib\.ru/(?P<kind>book|work|review)/(?P<id>\d+)[^)]*)\)")
WORK_ID_TO_SLUG = {
    # /work/<id> -> slug заметки: только те work-id, которых нет в frontmatter
    # (ссылка библиографии ведёт на страницу сочинения, а заметка — на издание)
    "1008288064": "andreev-model-kolichestvennoy-otsenki-urovnya-schastya",
    "1001474484": "vayl-rodnaya-rech",
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def load_json(path: Path, default):
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def load_mappings(repo: Path) -> dict:
    """_curation/link-mappings.json: livelib URL -> slug заметки."""
    return load_json(repo / "text" / "books" / "_curation" / "link-mappings.json", {})


def parse_lines(md: str, mappings: dict | None = None) -> list[dict]:
    """Строки-маркеры библиографии: тезис + упорядоченные ссылки (weight = номер)."""
    mapped = {}
    for url, slug in (mappings or {}).items():
        m = re.match(r"https?://(?:www\.)?livelib\.ru/(book|work|review)/(\d+)", url)
        if m:
            mapped[(m.group(1), m.group(2))] = slug
    lines = []
    for line in md.splitlines():
        m = BULLET.match(line)
        if not m:
            continue
        body = m.group("body")
        links = []
        for lm in LINK.finditer(body):
            kind, rid = lm.group("kind"), lm.group("id")
            links.append({
                "name": lm.group("name"),
                "url": f"https://www.livelib.ru/{kind}/{rid}",
                "kind": kind,
                "book_id": "" if kind == "review" else rid,
                "review_id": rid if kind == "review" else "",
                "slug": mapped.get((kind, rid), ""),
            })
        if not links:
            continue
        lines.append({"thesis": body.split(":", 1)[0].strip("- "),
                     "weight": len(lines) + 1, "links": links, "raw": line})
    return lines


def note_index(books_dir: Path) -> tuple[dict, dict]:
    """(book_id -> [slug], review_id -> [slug]) по frontmatter всех заметок."""
    books, reviews = {}, {}
    for note in sorted(Path(books_dir).glob("*.md")):
        m = re.match(r"---\n(.*?)\n---", read(note), re.S)
        if not m:
            continue
        fm = m.group(1)
        for u in re.findall(r'"?(https?://www\.livelib\.ru/(?:book|work)/\d+[^"\n]*)"?', fm):
            books.setdefault(re.search(r"/(?:book|work)/(\d+)", u).group(1), []).append(note.stem)
        mr = re.search(r'livelib_review:\s*"?https://www\.livelib\.ru/review/(\d+)', fm)
        if mr:
            reviews.setdefault(mr.group(1), []).append(note.stem)
    return books, reviews


def resolve(link: dict, books_dir: Path) -> str | None:
    """Ссылка строки -> slug заметки: mapping, затем review/, затем book/work id.

    Ссылки вида /review/<id> разрешаются ПО ID ОТЗЫВА: отзыв принадлежит
    определённому изданию, поэтому такой id надёжнее — он находит заметку даже
    когда ссылка ведёт на сборник/другое издание. Вещественные ссылки
    (/book/, /work/) разрешаются по id издания, work-lias — по таблице.
    """
    if link.get("slug"):
        return link["slug"]
    books, reviews = note_index(Path(books_dir))
    if link["review_id"] and link["review_id"] in reviews:
        return reviews[link["review_id"]][0]
    if link["book_id"] and link["book_id"] in books:
        return books[link["book_id"]][0]
    # id ссылки не живёт ни в одной заметке: единственный честный способ
    # связать /work/<id> с заметкой — явная таблица (её отсутствие = не разрешено)
    if link["kind"] == "work":
        for candidate in (link["book_id"], link["review_id"]):
            if candidate in WORK_ID_TO_SLUG:
                return WORK_ID_TO_SLUG[candidate]
    return None


def review_titles(export_path: Path) -> dict:
    """review_id -> title из livelib-reviews-api.json (pустые заголовки -> '')."""
    out = {}
    for r in load_json(export_path, []):
        out[str(r.get("id"))] = (r.get("title") or "").strip()
    return out


def frontmatter_of(text: str) -> str | None:
    m = re.match(r"---\n(.*?)\n---", text, re.S)
    return m.group(1) if m else None


def set_fields(fm: str, fields: dict) -> str:
    """Установить/обновить скалярные поля frontmatter, не трогая остальное."""
    lines = fm.split("\n")
    for key, value in fields.items():
        pattern = re.compile(rf"^{key}:.*$")
        for i, line in enumerate(lines):
            if pattern.match(line):
                if line == f"{key}: {value}":
                    break
                lines[i] = f"{key}: {value}"
                break
        else:
            lines.append(f"{key}: {value}")
    return "\n".join(lines)


def migrate(repo: Path, *, references: Path | None = None, export: Path | None = None,
           apply: bool = True) -> dict:
    """Извлечь важность из библиографии и (при apply) дописать её в заметки."""
    repo = Path(repo)
    references = references or repo / "text" / "p3-references.md"
    export = export or repo.parent / "shag" / "livelib-export" / "livelib-reviews-api.json"
    books_dir = repo / "text" / "books"
    lines = parse_lines(read(references), load_mappings(repo))
    titles = review_titles(export)

    report: dict = {"lines": {}, "unresolved": [], "no_thesis": [],
                    "written": [], "pending": [], "files": {}}
    wanted: dict[str, int] = {}  # slug -> min weight (1 = первая строка)

    for line in lines:
        weight = line["weight"]
        matched = []
        for link in line["links"]:
            slug = resolve(link, books_dir)
            if slug is None:
                report["unresolved"].append({"weight": weight, "url": link["url"],
                                            "name": link["name"]})
                continue
            matched.append(slug)
            wanted[slug] = min(wanted.get(slug, weight), weight)
        report["lines"][weight] = matched

    for slug, weight in sorted(wanted.items()):
        note = books_dir / f"{slug}.md"
        text = read(note)
        fm = frontmatter_of(text)
        if fm is None:
            report["unresolved"].append({"weight": weight, "url": None, "name": slug,
                                        "reason": "no-frontmatter"})
            continue
        new_fm = set_fields(fm, {"important": "true", "weight": str(weight)})
        if new_fm != fm:
            report["pending"].append(f"{slug}.md")
            report["files"][f"{slug}.md"] = text.replace(fm, new_fm, 1)
            if apply:
                note.write_text(report["files"][f"{slug}.md"], encoding="utf-8")
                report["written"].append(f"{slug}.md")

        # review whose thesis could serve this line: prefer the review the
        # bibliographic line actually links to, else the note's own review
        linked = {l["review_id"] for l in line_of(wanted, lines, slug) if l["review_id"]}
        own = re.findall(r'"?https://www\.livelib\.ru/review/(\d+)', fm)
        review_id = next((r for r in own if r in linked), None) or (own[0] if own else None)
        if not titles.get(review_id or ""):
            report["no_thesis"].append({
                "slug": slug, "weight": weight,
                # 'untitled-review': review is in the export but carries no title;
                # 'no-titled-review': no review of this book in the export at all
                "reason": "untitled-review" if review_id in titles else "no-titled-review",
                "review_id": review_id,
                "book_id": (re.search(r'livelib_book:\s*"?https://www\.livelib\.ru/(?:book|work)/(\d+)',
                                    fm) or [None, None])[1],
            })
    return report


def line_of(wanted: dict, lines: list, slug: str) -> list:
    """Links of the bibliographic line(s) that matched this slug."""
    weight = wanted[slug]
    return [l for line in lines if line["weight"] == weight for l in line["links"]]


def print_report(report: dict, *, apply: bool) -> None:
    mode = "APPLY" if apply else "DRY-RUN"
    print(f"== p3 migration ({mode}) ==")
    print(f"\nСтроки библиографии -> книги ({len(report['lines'])}):")
    for weight in sorted(report["lines"]):
        slugs = report["lines"][weight]
        print(f"  {weight:>2}: {', '.join(slugs) if slugs else '— (ничего не разрешено)'}")
    if report["no_thesis"]:
        print(f"\nКниги без тезиса в LiveLib ({len(report['no_thesis'])}) — нуждается в человеке:")
        for w in report["no_thesis"]:
            hint = ("отзыв без заголовка" if w["reason"] == "untitled-review"
                    else "у книги нет собственного отзыва")
            print(f"  weight {w['weight']:>2} {w['slug']} ({hint}; "
                  f"review={w['review_id'] or '-'}, book={w['book_id'] or '-'})")
    if report["unresolved"]:
        print(f"\nНеразрешённые ссылки ({len(report['unresolved'])}) — строка не тронута:")
        for u in report["unresolved"]:
            print(f"  weight {u['weight']:>2} {u['url']} ({u['name']})")
    names = report["written"] if apply else report["pending"]
    print(f"\nFrontmatter изменён{' (записано)' if apply else ' (dry-run, не записано)'}: "
          f"{len(names)}")
    for name in names:
        print(f"  {name}")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--repo", default=".", help="путь к репозиторию whattodo")
    ap.add_argument("--references", default=None, help="путь к p3-references.md")
    ap.add_argument("--export", default=None, help="путь к livelib-reviews-api.json")
    ap.add_argument("--apply", action="store_true", help="записать изменения (по умолчанию dry-run)")
    ap.add_argument("--json", action="store_true", help="отчёт как JSON")
    args = ap.parse_args(argv)
    repo = Path(args.repo).resolve()
    report = migrate(
        repo,
        references=Path(args.references) if args.references else None,
        export=Path(args.export) if args.export else None,
        apply=args.apply,
    )
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=1))
    else:
        print_report(report, apply=args.apply)
    return 0


if __name__ == "__main__":
    sys.exit(main())
