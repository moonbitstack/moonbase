#!/usr/bin/env python3
"""Generate a self-contained API-reference index.html for gh-pages from the
package sources' `///` doc comments. Reproducible: reads the .mbt files, so the
docs never drift from the code."""
import re, html, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
PKGS = [
    ("basex", "basex.mbt", "Generic positional base-N core. base36/base58/base62 pin an alphabet onto it."),
    ("base16", "base16/base16.mbt", "RFC 4648 hexadecimal — byte-oriented (two chars per byte)."),
    ("base32", "base32/base32.mbt", "RFC 4648 base32 (A-Z2-7) and base32hex (0-9A-V)."),
    ("base36", "base36/base36.mbt", "Dense case-insensitive 0-9a-z over the base-N core, with an integer mode."),
    ("base58", "base58/base58.mbt", "The Bitcoin / IPFS alphabet over the base-N core."),
    ("base62", "base62/base62.mbt", "URL-safe 0-9A-Za-z over the base-N core, with an integer mode."),
    ("base64", "base64/base64.mbt", "RFC 4648 standard (+/) and URL-safe (-_) base64."),
]

def parse(path):
    """Yield (kind, signature, doc_html) for each public item."""
    items, doc = [], []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        s = line.strip()
        if s == "///|":
            doc = []
        elif s.startswith("///"):
            doc.append(s[3:].strip())
        elif s.startswith("pub "):
            sig = s[4:]
            sig = re.sub(r"\s*\{.*$", "", sig).rstrip()
            kind = ("struct" if sig.startswith("struct")
                    else "fn" if sig.startswith("fn")
                    else "let" if sig.startswith("let") else "item")
            text = " ".join(doc).strip()
            items.append((kind, sig, text))
            doc = []
        elif s == "":
            pass
        else:
            doc = []
    return items

CSS = """
:root{--bg:#fbfcfe;--fg:#1a2230;--muted:#5b6b82;--card:#ffffff;--line:#e6ebf2;
--accent:#7c5cff;--code-bg:#f3f5f9;--kind:#0a7c5a;--sig:#243049}
@media (prefers-color-scheme:dark){:root{--bg:#0f131a;--fg:#e7edf6;--muted:#98a6bd;
--card:#161c26;--line:#242c39;--accent:#a892ff;--code-bg:#1b222e;--kind:#4fd6a6;--sig:#d6deea}}
*{box-sizing:border-box}html{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,system-ui,sans-serif;
line-height:1.55;color:var(--fg);background:var(--bg)}body{margin:0}
code,pre{font-family:"SFMono-Regular",ui-monospace,Menlo,Consolas,monospace}
.wrap{max-width:920px;margin:0 auto;padding:2.6rem 1.3rem 4rem}
header h1{font-size:2.2rem;margin:0 0 .3rem;letter-spacing:-.02em}
.tag{color:var(--muted);font-size:1.05rem;margin:0 0 1.2rem}
.badges a{display:inline-block;margin:0 .4rem .4rem 0}
.install{background:var(--code-bg);border:1px solid var(--line);border-radius:10px;padding:.7rem 1rem;margin:1.2rem 0 2rem}
.install code{font-size:.95rem}
nav.toc{display:flex;flex-wrap:wrap;gap:.5rem;margin:0 0 2rem}
nav.toc a{text-decoration:none;color:var(--accent);border:1px solid var(--line);border-radius:999px;padding:.25rem .8rem;font-size:.9rem}
section.pkg{border-top:1px solid var(--line);padding-top:1.6rem;margin-top:2rem}
section.pkg h2{font-size:1.5rem;margin:0 0 .2rem}
section.pkg h2 .at{color:var(--accent)}
.pdesc{color:var(--muted);margin:.1rem 0 1.2rem}
.item{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:1rem 1.15rem;margin:.9rem 0;overflow-x:auto}
.item .kind{display:inline-block;font-size:.72rem;font-weight:600;text-transform:uppercase;letter-spacing:.06em;color:var(--kind);margin-bottom:.35rem}
.item pre{margin:0 0 .55rem;color:var(--sig);font-size:.98rem;white-space:pre-wrap;word-break:break-word}
.item p{margin:0;color:var(--fg)}
.item p code{background:var(--code-bg);padding:.05rem .3rem;border-radius:5px;font-size:.9em}
footer{color:var(--muted);font-size:.9rem;border-top:1px solid var(--line);margin-top:3rem;padding-top:1.2rem}
a{color:var(--accent)}
"""

def esc(t):
    t = html.escape(t)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", t)

def main():
    parts = [f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>basex — MoonBit API</title><style>{CSS}</style></head><body><div class="wrap">
<header><h1>basex</h1>
<p class="tag">base16 / base58 / base62 / base64 encoding for MoonBit — RFC 4648 hex &amp; base64, plus a generic base-N core.</p>
<div class="badges">
<a href="https://github.com/Lfan-ke/basex-moonbit">GitHub</a> ·
<a href="https://mooncakes.io/docs/Lfan-ke/basex">mooncakes</a> ·
<span>Apache-2.0 © Leo Cheng</span></div>
<div class="install"><code>moon add Lfan-ke/basex</code></div></header>
<nav class="toc">"""]
    parts += [f'<a href="#{n}">@{n}</a>' for n, _, _ in PKGS]
    parts.append("</nav>")
    for name, rel, desc in PKGS:
        items = parse(ROOT / rel)
        parts.append(f'<section class="pkg" id="{name}"><h2><span class="at">@</span>{name}</h2><p class="pdesc">{esc(desc)}</p>')
        for kind, sig, doc in items:
            parts.append('<div class="item"><span class="kind">'+kind+'</span>'
                         f'<pre>{html.escape(sig)}</pre>'
                         + (f'<p>{esc(doc)}</p>' if doc else '') + '</div>')
        parts.append("</section>")
    parts.append('<footer>API reference generated from source doc-comments. '
                 'Full package + interactive docs on <a href="https://mooncakes.io/docs/Lfan-ke/basex">mooncakes.io</a>. '
                 '<a href="https://github.com/Lfan-ke/basex-moonbit">Source on GitHub</a>.</footer>')
    parts.append("</div></body></html>")
    out = ROOT / "docs" / "index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(parts), encoding="utf-8")
    total = sum(len(parse(ROOT / rel)) for _, rel, _ in PKGS)
    print(f"wrote {out} ({total} public items across {len(PKGS)} packages)")

if __name__ == "__main__":
    main()
