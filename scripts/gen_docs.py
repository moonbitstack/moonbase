#!/usr/bin/env python3
"""Generate the API reference (docs/api.html) for GitHub Pages.

The page is built from two sources, so it can never drift from the code:

  * each package's ``pkg.generated.mbti``  — the authoritative public surface
    (signatures, optional ``kind?`` arguments, ``raise`` clauses, types);
  * the ``///`` doc-comments in the ``.mbt`` sources            — the prose.

Reproducible by construction: package order and item order are fixed, so the
output is byte-stable and ``git diff --exit-code docs/api.html`` stays empty
when the workflow re-runs this script.

Style: the classic Read the Docs layout (dark navigation sidebar, content with
a right-hand "on this page" table of contents), sharing docs/assets/style.css
and docs/assets/site.js with the rest of the site.
"""
from __future__ import annotations

import html
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent / "src"

# package name -> (mbti file, [source files that make up the package], blurb)
PACKAGES = [
    ("moonbase", "pkg.generated.mbti",
     ["moonbase.mbt", "big.mbt", "stream.mbt", "error.mbt"],
     "The positional base-N core, the error types and the streaming engine. Every other package is a table of digits on top of this one."),
    ("base2", "base2/pkg.generated.mbti",
     ["base2/base2.mbt"],
     "One bit a character — the multibase `0` prefix. Eight characters a byte, so no chunk ever waits and no padding exists."),
    ("base8", "base8/pkg.generated.mbti",
     ["base8/base8.mbt"],
     "Three bits a character, eight characters to three bytes — the multibase `7` prefix, which is a bit packing and not an octal of a number."),
    ("base10", "base10/pkg.generated.mbti",
     ["base10/base10.mbt"],
     "Decimal, the multibase `9` prefix: the bytes read as one big-endian integer, so a leading zero byte is a leading `0`."),
    ("base16", "base16/pkg.generated.mbti",
     ["base16/base16.mbt"],
     "RFC 4648 hexadecimal — byte-oriented, two characters per byte, with a colon form for fingerprints."),
    ("base32", "base32/pkg.generated.mbti",
     ["base32/base32.mbt"],
     "RFC 4648 base32 (A-Z2-7) and the extended-hex base32hex (0-9A-V), plus Crockford's human-oriented alphabet and z-base-32."),
    ("base36", "base36/pkg.generated.mbti",
     ["base36/base36.mbt"],
     "Case-insensitive 0-9a-z over the base-N core, with an integer mode."),
    ("base45", "base45/pkg.generated.mbti",
     ["base45/base45.mbt"],
     "RFC 9285: two bytes in three characters from the 45 that a QR code's alphanumeric mode can hold, with no padding at all."),
    ("base58", "base58/pkg.generated.mbti",
     ["base58/base58.mbt"],
     "The Bitcoin, Flickr and Ripple alphabets over the base-N core — 0, O, I and l left out so a string survives being read aloud — and base58check."),
    ("base62", "base62/pkg.generated.mbti",
     ["base62/base62.mbt"],
     "URL-safe 0-9A-Za-z over the base-N core, with an integer mode."),
    ("base64", "base64/pkg.generated.mbti",
     ["base64/base64.mbt"],
     "RFC 4648 standard (+/) and URL-safe (-_) base64."),
    ("base85", "base85/pkg.generated.mbti",
     ["base85/base85.mbt"],
     "Adobe's Ascii85, ZeroMQ's Z85 (RFC 32) and the IPv6 spelling of RFC 1924 — four bytes in five characters, three ways."),
    ("bech32", "bech32/pkg.generated.mbti",
     ["bech32/bech32.mbt"],
     "BIP 173's bech32 and BIP 350's bech32m: a human-readable prefix, five-bit groups, and a BCH checksum that the two variants do not share."),
    ("multibase", "multibase/pkg.generated.mbti",
     ["multibase/multibase.mbt", "multibase/emoji.mbt"],
     "Multiformats' self-identifying encodings: a one-character prefix in front of any of the above, from `0` for base2 to a rocket for base256emoji."),
]

# Derived trait methods are noise in a reference; they carry no doc-comment
# and are never something a caller reaches for. Left out on purpose.
DERIVED_SUFFIXES = ("::equal", "::not_equal", "::to_repr")

KNOWN_TYPES = {
    "Bytes", "BytesView", "String", "StringView", "Int", "Int32", "UInt", "UInt64",
    "Char", "Bool", "Unit", "Array", "Map", "Option", "Result", "Alphabet",
    "Kind", "Malformed", "BadAlphabet", "Repr", "Debug", "Eq",
}


# --------------------------------------------------------------------------
# parsing
# --------------------------------------------------------------------------
def parse_source_doc(path: pathlib.Path) -> dict[str, str]:
    """Return {item-name: prose} for every public item documented by `///`."""
    docs: dict[str, str] = {}
    buffer: list[str] = []
    text = path.read_text(encoding="utf-8")
    for raw in text.splitlines():
        s = raw.strip()
        if s == "///|":
            buffer = []
        elif s.startswith("///"):
            buffer.append(s[3:].strip())
        elif s.startswith("pub ") or s.startswith("pub(all) "):
            name = pub_name(s)
            if name is not None and name not in DERIVED_SUFFIXES:
                docs[name] = " ".join(b for b in buffer if b).strip()
            buffer = []
        else:
            # any non-doc, non-public line ends a pending comment block
            buffer = []
    return docs


def pub_name(line: str) -> str | None:
    """The stable key for a public declaration line, or None to skip it."""
    s = line.strip()
    if s.startswith("pub extend") or s.startswith("pub(all) extend"):
        return None
    m = re.match(r"pub(?:\(all\))?\s+(?:fn|let|struct|enum|suberror)\s+([A-Za-z0-9_]+::[A-Za-z0-9_]+)", s)
    if m:
        return m.group(1)
    m = re.match(r"pub(?:\(all\))?\s+(?:fn|let|struct|enum|suberror)\s+([A-Za-z0-9_]+)", s)
    if m:
        return m.group(1)
    return None


def parse_mbti(path: pathlib.Path) -> list[dict]:
    """Return the public items of a package, in source order."""
    items: list[dict] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    i = 0
    n = len(lines)
    while i < n:
        raw = lines[i]
        s = raw.strip()
        if not (s.startswith("pub ") or s.startswith("pub(all) ")):
            i += 1
            continue
        # collect a possibly multi-line definition (enum/struct/suberror span `}`)
        buf = [s]
        depth = s.count("{") - s.count("}")
        j = i + 1
        while depth > 0 and j < n:
            buf.append(lines[j].strip())
            depth += lines[j].count("{") - lines[j].count("}")
            j += 1
        full = " ".join(buf)
        name = pub_name(s)
        if name is None or name.endswith(DERIVED_SUFFIXES):
            i = j
            continue
        kind = "struct" if "struct" in s else \
            "enum" if "enum" in s else \
            "error" if "suberror" in s else \
            "let" if s.split()[1] == "let" else "fn"
        items.append({
            "name": name,
            "kind": kind,
            "sig": full,
            "variants": extract_variants(buf) if kind in ("enum", "error") else None,
        })
        i = j
    return items


def extract_variants(buf: list[str]) -> list[str]:
    """The constructor lines inside an enum/suberror body."""
    variants: list[str] = []
    inside = False
    for line in buf:
        if not inside:
            if "{" not in line:
                continue
            inside = True
            line = line.split("{", 1)[1].strip()
        if "}" in line:
            line = line.split("}", 1)[0].strip()
            if line:
                variants.append(line)
            break
        line = line.strip()
        if line and not line.startswith("derive"):
            variants.append(line)
    return variants


# --------------------------------------------------------------------------
# rendering helpers
# --------------------------------------------------------------------------
def esc(t: str) -> str:
    return html.escape(t)


def highlight(sig: str) -> str:
    """Syntax-highlight a signature line for the <pre class=sig> blocks."""
    s = esc(sig)
    s = re.sub(r"\b(pub|pub\(all\)|fn|struct|let|enum|suberror)\b", r'<span class="k">\1</span>', s)
    # type names: Capitalised identifiers and known lowercase types
    def ty(m: re.Match) -> str:
        word = m.group(0)
        if word in KNOWN_TYPES or word[0].isupper():
            return '<span class="ty">%s</span>' % word
        return word
    s = re.sub(r"\b[A-Za-z_][A-Za-z0-9_]*\b", ty, s)
    s = s.replace("-&gt;", '<span class="op">-&gt;</span>')
    s = s.replace("?", '<span class="op">?</span>')
    s = s.replace("~", '<span class="op">~</span>')
    return s


def prose(t: str) -> str:
    t = esc(t)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", t)


def item_html(it: dict, doc: str) -> str:
    kind_label = {"fn": "function", "let": "value", "struct": "struct",
                  "enum": "enum", "error": "error"}[it["kind"]]
    if it["kind"] in ("struct", "enum", "error"):
        # fields/constructors are shown separately; keep the head only
        sig = re.sub(r"\s*\{.*$", "", strip_pub(it["sig"])).strip()
    else:
        sig = strip_pub(it["sig"])
    if it["kind"] in ("enum", "error"):
        variants = "".join(
            '<div class="variant"><code>%s</code></div>' % highlight(v)
            for v in it["variants"]
        )
        body = '<div class="variants">%s</div>' % variants
    else:
        body = ""
    doc_html = '<p class="doc">%s</p>' % prose(doc) if doc else ""
    return (
        '<article class="item" id="sym-%s" data-kind="%s">'
        '<span class="kind">%s</span>'
        '<pre class="sig">%s</pre>%s%s'
        '</article>'
    ) % (esc(it["name"]), esc(it["kind"]), esc(kind_label),
         highlight(sig),
         body, doc_html)


def strip_pub(sig: str) -> str:
    return re.sub(r"^pub(?:\(all\))?\s+", "", sig).strip()


# --------------------------------------------------------------------------
# page shell (matches docs/assets/style.css)
# --------------------------------------------------------------------------
SIDE_NAV = "".join(
    '<li><a href="api.html#pkg-%s" class="nav-pkg"><span class="at">@</span>%s</a></li>'
    % (name, name) for name, *_ in PACKAGES
)

TOC = "".join(
    '<li><a href="#pkg-%s">%s</a></li>' % (name, name)
    for name, *_ in PACKAGES
)


def shell(title: str, main_html: str) -> str:
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Lato:wght@400;700&family=Roboto+Slab:wght@500;700&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="assets/style.css">
</head>
<body>
<a class="skip-link" href="#content">Skip to content</a>
<header class="rtd-top">
  <a class="brand" href="index.html">moonbase</a>
  <nav class="top-nav">
    <a href="index.html">Home</a>
    <a href="guide.html">Guide</a>
    <a class="active" href="api.html">API</a>
    <a href="showcase.html">Showcase</a>
    <button class="theme-btn" id="theme-toggle" aria-label="Toggle colour theme" title="Toggle colour theme"><svg class="ic ic-sun" viewBox="0 0 16 16" width="18" height="18" aria-hidden="true"><circle cx="8" cy="8" r="3.35" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M8 .95v1.7M8 13.35v1.7M.95 8h1.7M13.35 8h1.7M3.05 3.05l1.2 1.2M11.75 11.75l1.2 1.2M12.95 3.05l-1.2 1.2M4.25 11.75l-1.2 1.2" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg><svg class="ic ic-moon" viewBox="0 0 16 16" width="18" height="18" aria-hidden="true"><path d="M13.6 10A5.8 5.8 0 0 1 6 2.4a6.1 6.1 0 1 0 7.6 7.6Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/></svg></button>
    <a class="github" href="https://github.com/moonbitstack/moonbase" aria-label="GitHub repository" title="GitHub repository">
      <svg class="ic" viewBox="0 0 16 16" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z"></path></svg>
    </a>
  </nav>
</header>
<div class="rtd-wrap">
  <aside class="rtd-side">
    <p class="side-title">API Reference</p>
    <ul class="side-nav">{SIDE_NAV}</ul>
    <a class="side-github" href="https://github.com/moonbitstack/moonbase">View source on GitHub</a>
  </aside>
  <div class="rtd-content" id="content">
    <nav class="breadcrumb"><a href="index.html">moonbase</a> &raquo; API Reference</nav>
    <main>
      <h1>API Reference</h1>
      <p class="lede">Every public type, function, method and value in moonbase, grouped by
      package. Signatures come from <code>pkg.generated.mbti</code>; the notes come from the
      <code>///</code> doc-comments in the sources.</p>
      {main_html}
      <footer class="rtd-foot">
        moonbase &middot; Apache-2.0 &middot;
        <a href="https://github.com/moonbitstack/moonbase">GitHub</a> &middot;
        <a href="https://mooncakes.io/docs/moonbitstack/moonbase">mooncakes</a>
      </footer>
    </main>
  </div>
  <aside class="rtd-toc">
    <p class="toc-title">On this page</p>
    <ul class="toc-nav">{TOC}</ul>
  </aside>
</div>
<script src="assets/site.js"></script>
</body>
</html>"""


def main() -> None:
    parts: list[str] = []
    for name, mbti_rel, srcs, blurb in PACKAGES:
        mbti_path = ROOT / mbti_rel
        doc_map: dict[str, str] = {}
        for rel in srcs:
            doc_map.update(parse_source_doc(ROOT / rel))
        items = parse_mbti(mbti_path)
        items = sorted(items, key=lambda it: it["name"])
        cards = "".join(item_html(it, doc_map.get(it["name"], "")) for it in items)
        parts.append(
            '<section class="pkg" id="pkg-%s">'
            '<h2><span class="at">@</span>%s</h2>'
            '<p class="pdesc">%s</p>%s'
            '</section>' % (name, name, esc(blurb), cards)
        )
    page = shell("API Reference — moonbase", "\n".join(parts))
    out = ROOT.parent / "docs" / "api.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")
    total = sum(len(parse_mbti(ROOT / m)) for _, m, _, _ in PACKAGES)
    print("wrote %s (%d public items across %d packages)" % (out, total, len(PACKAGES)))


if __name__ == "__main__":
    main()
