"""Tests for scripts/p3_migrate.py: p3-references.md -> importance in book frontmatter.

The migration extracts ONLY importance from the curated bibliography:
`important: true` + `weight: <bullet number>` written into the frontmatter of
the book notes a line's URLs resolve to. Thesis and display names are NOT
copied — they live in LiveLib now (thesis = title of the book's own review).

Tests run against a miniature of the real repository layout.
"""

import json
import re
import sys
import subprocess
import textwrap
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts" / "p3_migrate.py"

sys.path.insert(0, str(SCRIPT.parent))
import p3_migrate  # noqa: E402


BOOK_A = """---
title: "Книга А"
author: Автор А
tags:
  - book
my_mark: 5
status: read
livelib_book: "https://www.livelib.ru/book/1000000001"
livelib_review: "https://www.livelib.ru/review/111"
---

> Цитата А ^quote_1

— [LiveLib](https://www.livelib.ru/quote/45716146)
"""

BOOK_B = """---
title: "Книга Б"
tags:
  - book
status: none
livelib_book: "https://www.livelib.ru/book/1000000002"
---

> Цитата Б ^quote_1

— [LiveLib](https://www.livelib.ru/quote/45716147)
"""

# Book with a review that carries NO title in the export: thesis cannot come
# from LiveLib, the human has to look at it.
BOOK_C = """---
title: "Книга В"
tags:
  - book
status: read
livelib_book: "https://www.livelib.ru/book/1000000003"
livelib_review: "https://www.livelib.ru/review/333"
---
"""

REVIEWS = [
    {"id": 111, "title": "Тезис А", "url": "/review/111-kniga-a",
     "art_edition": {"id": 1000000001, "url": "/book/1000000001"}},
    {"id": 222, "title": None, "url": "/review/222-kniga-b",
     "art_edition": {"id": 1000000002, "url": "/book/1000000002"}},
    {"id": 333, "title": None, "url": "/review/333-kniga-v",
     "art_edition": {"id": 1000000003, "url": "/book/1000000003"}},
]

REFERENCES = """---
comments: true
created: 18.06.2023
---

# Книги как фундамент

В тексте были использованы книги:

- Тезис А: [Книга А сокращённо](https://www.livelib.ru/review/111-kniga-a)
- Общий тезис: [Книга Б](https://www.livelib.ru/review/222), [Книга В](https://www.livelib.ru/book/1000000003)
- Тезис Г: [Призрак](https://www.livelib.ru/review/9999999)
"""


@pytest.fixture
def repo(tmp_path):
    """Miniature of the whattodo repo: text/books/ + _curation + export."""
    books = tmp_path / "text" / "books"
    books.mkdir(parents=True)
    (books / "kniga-a.md").write_text(BOOK_A, encoding="utf-8")
    (books / "kniga-b.md").write_text(BOOK_B, encoding="utf-8")
    (books / "kniga-v.md").write_text(BOOK_C, encoding="utf-8")
    cur = books / "_curation"
    cur.mkdir()
    (cur / "link-mappings.json").write_text(json.dumps(
        {"https://www.livelib.ru/review/222": "kniga-b"}, ensure_ascii=False), encoding="utf-8")
    (tmp_path / "text" / "p3-references.md").write_text(REFERENCES, encoding="utf-8")
    export = tmp_path / "export"
    export.mkdir()
    (export / "livelib-reviews-api.json").write_text(
        json.dumps(REVIEWS, ensure_ascii=False), encoding="utf-8")
    return tmp_path


def fm_of(repo, slug):
    text = (repo / "text" / "books" / f"{slug}.md").read_text(encoding="utf-8")
    return re.match(r"---\n(.*?)\n---", text, re.S).group(1)


class TestResolve:
    def test_review_id_resolves_via_frontmatter_review(self, repo):
        links = p3_migrate.parse_lines(REFERENCES, p3_migrate.load_mappings(repo))
        got = {l["review_id"] or l["book_id"]: p3_migrate.resolve(l, repo / "text" / "books")
               for ln in links for l in ln["links"]}
        assert got["111"] == "kniga-a"

    def test_review_id_resolves_via_link_mapping(self, repo):
        """222 is not in any note frontmatter — link-mappings.json points to the slug."""
        links = p3_migrate.parse_lines(REFERENCES, p3_migrate.load_mappings(repo))
        link = [l for ln in links for l in ln["links"] if l["review_id"] == "222"][0]
        assert p3_migrate.resolve(link, repo / "text" / "books") == "kniga-b"

    def test_book_id_resolves_via_frontmatter_book(self, repo):
        links = p3_migrate.parse_lines(REFERENCES, p3_migrate.load_mappings(repo))
        link = [l for ln in links for l in ln["links"] if l["book_id"] == "1000000003"][0]
        assert p3_migrate.resolve(link, repo / "text" / "books") == "kniga-v"

    def test_work_url_resolves_to_work_note(self, repo):
        """A /work/<id> link with no id in any note: WORK_ID_TO_SLUG table maps it."""
        links = p3_migrate.parse_lines(
            "- Тезис В: [Вайль](https://www.livelib.ru/work/1001474484-rodnaya-rech)\n")
        assert p3_migrate.resolve(links[0]["links"][0], repo / "text" / "books") == "vayl-rodnaya-rech"

    def test_unknown_id_does_not_resolve(self, repo):
        links = p3_migrate.parse_lines(REFERENCES, p3_migrate.load_mappings(repo))
        link = [l for ln in links for l in ln["links"] if l["review_id"] == "9999999"][0]
        assert p3_migrate.resolve(link, repo / "text" / "books") is None


class TestMigration:
    def run(self, repo, apply=True, export=None):
        # the miniature repo keeps its export next to text/; the real repo keeps
        # it outside, so tests pass the path explicitly when they say so
        export = export or (repo / "export" / "livelib-reviews-api.json")
        return p3_migrate.migrate(repo, apply=apply, export=export)

    def test_writes_only_important_and_weight(self, repo):
        self.run(repo)
        fm = fm_of(repo, "kniga-a")
        assert "important: true" in fm
        assert "weight: 1" in fm
        # nothing else is added: no thesis, no display name
        assert "Тезис" not in fm
        assert "сокращ" not in fm
        assert re.search(r"^thesis:|^name:|^display", fm, re.M) is None

    def test_weight_is_the_bullet_number(self, repo):
        self.run(repo)
        assert "weight: 1" in fm_of(repo, "kniga-a")
        assert "weight: 2" in fm_of(repo, "kniga-b")
        assert "weight: 2" in fm_of(repo, "kniga-v")

    def test_existing_frontmatter_is_preserved(self, repo):
        self.run(repo)
        fm = fm_of(repo, "kniga-a")
        assert 'title: "Книга А"' in fm
        assert "my_mark: 5" in fm
        assert 'livelib_review: "https://www.livelib.ru/review/111"' in fm

    def test_body_is_untouched(self, repo):
        before = (repo / "text" / "books" / "kniga-a.md").read_text(encoding="utf-8")
        after = self.run(repo)["files"]["kniga-a.md"]
        assert before.split("---\n")[2] == after.split("---\n")[2]

    def test_report_lists_matched_books_per_line(self, repo):
        report = self.run(repo)
        assert report["lines"][1] == ["kniga-a"]
        assert report["lines"][2] == ["kniga-b", "kniga-v"]

    def test_report_lists_unresolved_urls(self, repo):
        """Unresolved: the line is left alone and nothing is written for it."""
        report = self.run(repo)
        urls = [u["url"] for u in report["unresolved"]]
        assert "https://www.livelib.ru/review/9999999" in urls
        assert 9999999 not in [int(x) for x in re.findall(
            r"weight: (\d+)", (repo / "text" / "books" / "kniga-a.md").read_text(encoding="utf-8"))]

    def test_report_lists_books_without_a_titled_review(self, repo):
        """A book whose /work/ or /book/ link has no titled review in LiveLib."""
        report = self.run(repo)
        assert {"slug": "kniga-b", "reason": "no-titled-review"} in [
            {k: v for k, v in w.items() if k in ("slug", "reason")} for w in report["no_thesis"]]

    def test_untitled_review_is_reported(self, repo):
        report = self.run(repo, export=repo / "export" / "livelib-reviews-api.json")
        reasons = {w["slug"]: w["reason"] for w in report["no_thesis"]}
        assert reasons.get("kniga-v") == "untitled-review"

    def test_dry_run_writes_nothing(self, repo):
        before = (repo / "text" / "books" / "kniga-a.md").read_text(encoding="utf-8")
        report = self.run(repo, apply=False)
        assert (repo / "text" / "books" / "kniga-a.md").read_text(encoding="utf-8") == before
        # pending changes are reported, but nothing was written to disk
        assert sorted(report["pending"]) == ["kniga-a.md", "kniga-b.md", "kniga-v.md"]
        assert report["written"] == []

    def test_written_files_reported(self, repo):
        report = self.run(repo)
        assert sorted(report["written"]) == ["kniga-a.md", "kniga-b.md", "kniga-v.md"]

    def test_p3_references_file_is_never_modified(self, repo):
        before = (repo / "text" / "p3-references.md").read_text(encoding="utf-8")
        self.run(repo)
        assert (repo / "text" / "p3-references.md").read_text(encoding="utf-8") == before

    def test_idempotent(self, repo):
        self.run(repo)
        first = (repo / "text" / "books" / "kniga-a.md").read_text(encoding="utf-8")
        report = self.run(repo)
        assert (repo / "text" / "books" / "kniga-a.md").read_text(encoding="utf-8") == first
        assert report["written"] == []

    def test_cli_runs(self, repo):
        out = subprocess.run(
            [sys.executable, str(SCRIPT), "--repo", str(repo), "--apply"],
            capture_output=True, text=True, check=True)
        assert "kniga-a" in out.stdout
        assert "important: true" in fm_of(repo, "kniga-a")