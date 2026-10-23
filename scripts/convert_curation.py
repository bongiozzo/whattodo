#!/usr/bin/env python3
"""One-time conversion: 7 per-concern curation files -> one curation.jsonc.

Run from the whattodo repo root:

    uv run --project ../text-forge python scripts/convert_curation.py

Reads text/books/_curation/*.json, emits text/books/_curation/curation.jsonc with
one entry per livelib edition id and the book title as a // comment above it, for
manual navigation. Titles come from the CURRENT corpus (note frontmatter keyed by
livelib id), so the comment reflects what the note actually says.

What is deliberately NOT migrated (derivable from the source, so it would be
redundant):
  * reference-books title/author — fetched from the livelib search API at build
    time and cached in livelib-export/editions-cache.json;
  * link-mappings url variants of the SAME id — collapsed to one short key;
  * collections title text — the '(омнибус)' marker was decoration; the flag is
    what the build uses. The title survives as the entry's // comment.

Two exceptions are carried because they are NOT derivable:
  * `url` on a books[] entry — a slug-suffixed edition url. The export emits short
    /book/<id> urls only, and these editions are off-shelf, so nothing else holds
    the long form the corpus declares (and livelib-export/ is not tracked).
  * an explicit merge canonical — a fold whose survivor is decided by id, not by
    which entry happens to come first.
"""
import json
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[1]
CUR = REPO / "text" / "books" / "_curation"
BOOKS = REPO / "text" / "books"
EXPORT = REPO / "livelib-export"

# the seven per-concern files this conversion consumes (all must be gone after it)
SOURCE_FILES = ("important.json", "book-overrides.json", "collections.json",
                "author-overrides.json", "link-mappings.json", "work-merges.json",
                "reference-books.json")

ID_RE = re.compile(r"/(?:book|work|review)/(\d+)")


def book_id(url):
    m = re.search(r"/(?:book|work)/(\d+)", url)
    return m.group(1) if m else url


def load(name):
    p = CUR / name
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else None


def corpus_titles():
    """Every livelib id mentioned in a note -> (note slug, frontmatter title)."""
    out = {}
    for note in sorted(BOOKS.glob("*.md")):
        m = re.match(r"---\n(.*?)\n---", note.read_text(encoding="utf-8"), re.S)
        if not m:
            continue
        fm = m.group(1)
        tm = re.search(r'^title:\s*"(.*?)"\s*$', fm, re.M)
        title = tm.group(1) if tm else note.stem
        for m2 in re.finditer(r"https?://www\.livelib\.ru/(?:book|work)/(\d+)", fm):
            out.setdefault(m2.group(1), (note.stem, title))
    return out


def main():
    titles = corpus_titles()
    books = {}

    def entry(bid):
        return books.setdefault(bid, {})

    # --- importance (id -> weight): curation, not in livelib
    for bid, w in (load("important.json") or {}).items():
        entry(bid)["weight"] = w

    # --- book overrides (status / my_mark): livelib shelves lie about these
    for bid, ov in (load("book-overrides.json") or {}).items():
        entry(bid).update({k: v for k, v in ov.items() if k in ("status", "my_mark")})

    # --- collections -> omnibus flag. Kept LIVE (every entry does work): no id
    # carries quotes in this corpus, so the quote-exclusion path never fires, but
    # the flag is what stops a COLLECTION — a compilation, not a work — from being
    # credited with an author. Verified by removal, not by assumption: dropping it
    # changes 8 notes (each gains an `author:` line it must not have).
    for url, text in (load("collections.json") or {}).items():
        bid = book_id(url)
        ent = entry(bid)
        ent["omnibus"] = True
        # title for the // comment: the corpus note if it still exists, else the
        # text the old file carried (an edition that has since left the shelves
        # has no note to read a title from, and an unlabelled id is unreadable)
        title = ((titles.get(bid) or (None, ""))[1]
                 or re.sub(r"\s*\(омнибус\)\s*$", "", text).strip())
        if title:
            ent.setdefault("_comment", title)

    # --- author overrides
    for url, author in (load("author-overrides.json") or {}).items():
        entry(book_id(url))["author"] = author

    # --- link mappings: dedupe url variants of one id, and keep the long form
    # only where the corpus really declares it (as an edition url of a note)
    declared_long = {}
    for note in sorted(BOOKS.glob("*.md")):
        fm = note.read_text(encoding="utf-8")
        for m in re.finditer(r"https?://www\.livelib\.ru/book/(\d+)-[^\"\s)]+", fm):
            declared_long.setdefault(m.group(1), m.group(0))

    links = {}
    for url, slug in (load("link-mappings.json") or {}).items():
        m = re.search(r"/(book|work|review)/(\d+)", url)
        if not m:
            sys.exit(f"STOP: link-mappings key has no id: {url}")
        kind, bid = m.group(1), m.group(2)
        short = f"https://www.livelib.ru/{kind}/{bid}"
        prev = links.get(short)
        if prev is not None and prev != slug:
            sys.exit(f"STOP: {short} maps to two slugs ({prev} / {slug})")
        links[short] = slug
        # a /book/<id>-<slug> key names the edition's long url: carry it on the
        # entry when a note declares that long url
        if kind == "book" and declared_long.get(bid) == url:
            entry(bid)["url"] = url

    # --- work merges -> {removed: canonical}. An entry that names no 'remove'
    # annotates the note named by 'into'; when remove == into (the real corpora
    # case: a hidden sibling edition folded into the note that declares it) the
    # fold is recorded as a no-op self entry, because dropping it would silently
    # resurrect a duplicate note.
    merges, merge_extra, merge_status = {}, {}, {}
    for m in (load("work-merges.json") or []):
        into, remove = m.get("into"), m.get("remove")
        key = remove or into
        if not key:
            sys.exit(f"STOP: work-merges entry names neither remove nor into: {m}")
        # an explicit canonical, or a self-fold when the entry folds into itself
        merges[key] = into or key
        if m.get("extra"):
            merge_extra[key] = m["extra"]
            eid = book_id(m["extra"])
            if declared_long.get(eid) == m["extra"]:
                entry(eid)["url"] = m["extra"]
        if m.get("status"):
            merge_status[key] = m["status"]

    # --- reference books: title/author are NOT stored (fetched from the API)
    notes_by_id = declared_note_urls()
    texts_by_id = text_link_urls()
    refs = {}
    ref_titles = {}
    for b in (load("reference-books.json") or []):
        bid = book_id(b["book_url"])
        ent = {}
        # the // title of such an entry is the note's own frontmatter title: the
        # file no longer stores a title, so the comment is the only place a human
        # reading it can see what the id is
        ref_titles[bid] = (titles.get(bid) or (None, b.get("title") or ""))[1]
        # A long edition url is carried ONLY when the corpus really depends on it:
        # some text links that id in its slug-suffixed form while the id itself
        # lives in no note, so the validator can only match the url if a note
        # declares it. Whether that is the case is read off the corpus, not
        # guessed — an id whose texts all use the short form gets `"id": {}`.
        long_url = b.get("book_url") or ""
        if f"/{bid}-" in long_url and long_url_is_load_bearing(
                bid, long_url, notes_by_id, texts_by_id):
            ent["url"] = long_url
        refs[bid] = ent

    external = load("external-links.json") or []

    # this script consumes the old files and destroys them: refuse to write when
    # they are absent, because an empty curation.jsonc would silently replace a
    # good one and the corpus would lose its curation on the next build
    if not any((CUR / n).exists() for n in SOURCE_FILES):
        sys.exit("STOP: no source files in " + str(CUR) +
                 " — conversion already ran; not overwriting curation.jsonc")
    if not books and not refs and not links:
        sys.exit("STOP: sources produced no curation at all; refusing to write an empty file")

    # titles lookup: id -> title string, from notes first, then from whatever the
    # old files said (ids no longer in the corpus have no note to read from)
    title_lookup = {k: v[1] for k, v in titles.items() if v[1]}
    title_lookup.update({k: v for k, v in ref_titles.items() if v})
    text = render(books, merges, merge_extra, merge_status, links, external, refs,
                  title_lookup)
    out = CUR / "curation.jsonc"
    out.write_text(text, encoding="utf-8")
    print(f"wrote {out} ({len(text)} bytes)")
    print(f"  books={len(books)} merges={len(merges)} links={len(links)} "
          f"external={len(external)} reference-books={len(refs)}")


_IN_EXPORT = None
_TEXT_LINKS = None
_NOTE_IDS = None


def text_links():
    """(kind, id) -> the urls texts actually use, across text/*.md."""
    global _TEXT_LINKS
    if _TEXT_LINKS is None:
        _TEXT_LINKS = {}
        for ch in sorted((REPO / "text").glob("*.md")):
            for m in re.finditer(r"https?://www\.livelib\.ru/(book|work|review|quote)/(\d+)[^)\s\"']*",
                                ch.read_text(encoding="utf-8")):
                _TEXT_LINKS.setdefault((m.group(1), m.group(2)), set()).add(m.group(0))
    return _TEXT_LINKS


def note_ids():
    """Every livelib id already declared by some note frontmatter."""
    global _NOTE_IDS
    if _NOTE_IDS is None:
        _NOTE_IDS = set()
        for note in sorted(BOOKS.glob("*.md")):
            fm = note.read_text(encoding="utf-8")
            for m in re.finditer(r"livelib\.ru/(?:book|work|review|quote)/(\d+)", fm):
                _NOTE_IDS.add(m.group(1))
    return _NOTE_IDS


def declared_note_urls():
    """Every livelib /book/ url a note declares, id -> {urls}."""
    out = {}
    for note in sorted(BOOKS.glob("*.md")):
        fm = note.read_text(encoding="utf-8")
        for m in re.finditer(r"https?://www\.livelib\.ru/book/(\d+)([^\"\s)]*)", fm):
            out.setdefault(m.group(1), set()).add(m.group(0))
    return out


def text_link_urls():
    """Every livelib /book|work/ url a text links, id -> {urls as written}."""
    out = {}
    for ch in sorted((REPO / "text").glob("*.md")):
        for m in re.finditer(r"https?://www\.livelib\.ru/(?:book|work)/(\d+)([^)\s\"']*)",
                             ch.read_text(encoding="utf-8")):
            out.setdefault(m.group(1), set()).add(m.group(0))
    return out


def long_url_is_load_bearing(bid, long_url, notes_by_id, texts_by_id):
    """True only when the corpus genuinely depends on this exact long url.

    A note is written with whatever url the record that created it carries; the
    export gives short /book/<id> urls. So a reference book whose long form is
    ALSO the form a text links, and which owns its note alone, has to keep the
    long url in curation — otherwise the note's declared url and the text's link
    disagree. Where a note is already anchored by another edition (the id shows
    up on a shelf under a different url), or no text uses the long form, the
    short form is enough and the long url would change no byte.
    """
    if long_url not in texts_by_id.get(bid, set()):
        return False
    declared = notes_by_id.get(bid, set())
    if not declared:
        return False
    # load-bearing only when the note declares exactly this long url and no short
    # form of the same id is already established by a shelf record
    return declared == {long_url} and f"https://www.livelib.ru/book/{bid}" not in declared


_IN_EXPORT = None
_TEXT_LINKS = None
_NOTE_IDS = None


def text_links():
    """(kind, id) -> the urls texts actually use, across text/*.md."""
    global _TEXT_LINKS
    if _TEXT_LINKS is None:
        _TEXT_LINKS = {}
        for ch in sorted((REPO / "text").glob("*.md")):
            for m in re.finditer(r"https?://www\.livelib\.ru/(book|work|review|quote)/(\d+)[^)\s\"']*",
                                ch.read_text(encoding="utf-8")):
                _TEXT_LINKS.setdefault((m.group(1), m.group(2)), set()).add(m.group(0))
    return _TEXT_LINKS


def note_ids():
    """Every livelib id already declared by some note frontmatter."""
    global _NOTE_IDS
    if _NOTE_IDS is None:
        _NOTE_IDS = set()
        for note in sorted(BOOKS.glob("*.md")):
            fm = note.read_text(encoding="utf-8")
            for m in re.finditer(r"livelib\.ru/(?:book|work|review|quote)/(\d+)", fm):
                _NOTE_IDS.add(m.group(1))
    return _NOTE_IDS


def _needs_long_url(bid, links, long_url):
    """True only when the long url is load-bearing for the corpus.

    The long form is written into a note's `livelib_editions:`/`livelib_book:`
    line, so carrying it is only worth its bytes if some text depends on that
    exact string being declared. It is, when BOTH hold:
      * a text links this id in the slug-suffixed form, AND
      * the id resolves by itself in no note (otherwise the id->short mapping in
        the build's link_map already accounts for it).
    Measured on this corpus: 2 of 7 reference books meet the test; the other 5
    would carry a `url` that changes no byte of the output, so they stay
    `"<id>": {}`.
    """
    if f"https://www.livelib.ru/book/{bid}" in links:
        return False
    for (kind, cid), urls in text_links().items():
        if cid == bid and long_url in urls:
            return True
    return False


def _in_export(bid):
    global _IN_EXPORT
    if _IN_EXPORT is None:
        p = EXPORT / "livelib-books.json"
        _IN_EXPORT = {book_id(b["book_url"]) for b in json.loads(p.read_text(encoding="utf-8"))} \
            if p.exists() else set()
    return bid in _IN_EXPORT


FIELD_ORDER = ("omnibus", "weight", "status", "my_mark", "author", "url")


def render(books, merges, merge_extra, merge_status, links, external, refs, titles):
    lines = [
        "// Curation for text/books — one entry per livelib edition id.",
        "// JSONC: // and /* */ comments are stripped by load_curation() before parse.",
        "//",
        "// books            — per-edition curation: omnibus?, weight?, status?,",
        "//                    my_mark?, author?, url? (long edition url the export",
        "//                    cannot supply). The // line above each entry is that",
        "//                    edition's title, for reading the file by eye.",
        "// merges          — {removed note slug: canonical note slug or id}.",
        "// links           — {livelib url: note slug} for urls that resolve by id",
        "//                    in no note.",
        "// external        — livelib urls that are not books (old quote pages).",
        "// reference-books — {edition id: {}} ; title/author come from the livelib",
        "//                    search API at build time (cached, offline-repeatable).",
        "{",
    ]
    lines.append('  "books": {')
    ids = sorted(books)
    for i, bid in enumerate(ids):
        ent = books[bid]
        title = ent.pop("_comment", None) or (titles.get(bid) or "")
        if title:
            # the frontmatter value is JSON-quoted; decode it, then re-encode and
            # shave the outer quotes so the comment shows the title as written
            # (a title carrying «» or \" survives the round trip unchanged)
            try:
                plain = json.loads(f'"{title}"')
            except json.JSONDecodeError:
                plain = title
            safe = json.dumps(plain, ensure_ascii=False)[1:-1]
            lines.append(f"    // {safe}")
        parts = []
        for k in FIELD_ORDER:
            if k not in ent:
                continue
            v = ent[k]
            parts.append(f'"{k}": ' + (json.dumps(v, ensure_ascii=False)
                                      if isinstance(v, str) else json.dumps(v)))
        comma = "," if i < len(ids) - 1 else ""
        if not parts:
            continue
        lines.append(f"    {json.dumps(bid)}: {{{', '.join(parts)}}}{comma}")
    lines.append("  },")

    def simple(section, data, comma=True, title_of=None):
        out = [f'  "{section}": ' + ("{" if isinstance(data, dict) else "[")]
        items = list(data.items()) if isinstance(data, dict) else list(data)
        for j, it in enumerate(items):
            tail = "," if j < len(items) - 1 else ""
            if isinstance(data, dict):
                k, v = it
                if title_of:
                    label = title_of(k)
                    if label:
                        out.append(f"    // {json.dumps(label, ensure_ascii=False)[1:-1]}")
                yield_line = f"    {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}{tail}"
            else:
                yield_line = f"    {json.dumps(it, ensure_ascii=False)}{tail}"
            out.append(yield_line)
        out.append("  }" if isinstance(data, dict) else "  ]")
        if comma:
            out[-1] += ","
        return out

    lines += simple("merges", merges)
    lines += simple("merge-extra", merge_extra) if merge_extra else []
    lines += simple("merge-status", merge_status) if merge_status else []
    lines += simple("links", links)
    lines += simple("external", external)
    lines += simple("reference-books", refs, comma=False,
                    title_of=lambda k: (titles.get(k) or ""))
    lines.append("}")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    main()
