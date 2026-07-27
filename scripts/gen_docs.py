#!/usr/bin/env python3
"""Generate a self-contained, styled API-reference site (docs/index.html) for
gh-pages from the package sources' `///` doc comments. Reproducible: reads the
.mbt files, so the docs never drift from the code."""
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
    items, doc = [], []
    for raw in path.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if s == "///|":
            doc = []
        elif s.startswith("///"):
            doc.append(s[3:].strip())
        elif s.startswith("pub "):
            sig = re.sub(r"\s*\{.*$", "", s[4:]).rstrip()
            kind = ("struct" if sig.startswith("struct") else "fn" if sig.startswith("fn")
                    else "let" if sig.startswith("let") else "item")
            items.append((kind, sig, " ".join(doc).strip()))
            doc = []
        elif s == "":
            pass
        else:
            doc = []
    return items


TYPES = {"Bytes", "String", "Int", "Char", "Bool", "Array", "Map", "UInt64", "Alphabet", "Unit"}


def tint(sig):
    s = html.escape(sig)
    s = re.sub(r"\b(fn|struct|let)\b", r'<span class="k">\1</span>', s)
    s = re.sub(r"\b([A-Z][A-Za-z0-9_]*)\b", r'<span class="ty">\1</span>', s)
    s = s.replace("-&gt;", '<span class="op">-&gt;</span>').replace("?", '<span class="op">?</span>')
    return s


def prose(t):
    t = html.escape(t)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", t)


CSS = r"""
:root{
  --bg:#fbfbfd; --panel:#ffffff; --panel-2:#f6f7fb; --ink:#14181f;
  --muted:#5b6675; --line:#e8ebf1; --accent:#6d5efc; --accent-soft:#efecff; --out:#0ca678;
  --code-bg:#f4f5f9; --shadow:0 1px 2px rgba(20,24,31,.04),0 8px 24px -12px rgba(20,24,31,.10);
}
@media (prefers-color-scheme:dark){:root{
  --bg:#0b0e14; --panel:#131722; --panel-2:#0f131c; --ink:#e9edf6; --muted:#96a1b5;
  --line:#212736; --accent:#9d8bff; --accent-soft:#1c1b3a; --out:#2dd4a7;
  --code-bg:#161b26; --shadow:0 1px 2px rgba(0,0,0,.3),0 12px 30px -14px rgba(0,0,0,.5);
}}
:root[data-theme=light]{--bg:#fbfbfd;--panel:#fff;--panel-2:#f6f7fb;--ink:#14181f;--muted:#5b6675;--line:#e8ebf1;--accent:#6d5efc;--accent-soft:#efecff;--out:#0ca678;--code-bg:#f4f5f9;--shadow:0 1px 2px rgba(20,24,31,.04),0 8px 24px -12px rgba(20,24,31,.10)}
:root[data-theme=dark]{--bg:#0b0e14;--panel:#131722;--panel-2:#0f131c;--ink:#e9edf6;--muted:#96a1b5;--line:#212736;--accent:#9d8bff;--accent-soft:#1c1b3a;--out:#2dd4a7;--code-bg:#161b26;--shadow:0 1px 2px rgba(0,0,0,.3),0 12px 30px -14px rgba(0,0,0,.5)}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
@media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}*{animation:none!important;transition:none!important}}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"IBM Plex Sans",system-ui,-apple-system,Segoe UI,Roboto,sans-serif;
  font-size:15.5px;line-height:1.6;-webkit-font-smoothing:antialiased}
code,pre,.mono{font-family:"IBM Plex Mono",ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
a{color:var(--accent);text-decoration:none}
a:hover{text-decoration:underline}
.layout{display:grid;grid-template-columns:264px minmax(0,1fr);max-width:1180px;margin:0 auto}

/* sidebar */
.sidebar{position:sticky;top:0;align-self:start;height:100vh;overflow-y:auto;
  border-right:1px solid var(--line);padding:1.6rem 1.1rem 2rem;background:var(--panel-2)}
.brand{display:flex;align-items:center;gap:.55rem;font-family:"IBM Plex Mono";font-weight:600;
  font-size:1.35rem;letter-spacing:-.01em;color:var(--ink);margin-bottom:.15rem}
.brand .dot{width:11px;height:11px;border-radius:50%;background:var(--accent);box-shadow:0 0 0 4px var(--accent-soft)}
.brand-sub{color:var(--muted);font-size:.8rem;margin:0 0 1.3rem;padding-left:.15rem}
.side-nav{display:flex;flex-direction:column;gap:.1rem}
.side-nav a{color:var(--muted);font-size:.9rem;padding:.32rem .6rem;border-radius:8px;
  font-family:"IBM Plex Mono";display:flex;align-items:center;gap:.4rem;border-left:2px solid transparent}
.side-nav a .at{color:var(--accent);opacity:.6}
.side-nav a:hover{background:var(--accent-soft);color:var(--ink);text-decoration:none}
.side-nav a.active{color:var(--ink);background:var(--accent-soft);border-left-color:var(--accent);font-weight:500}
.side-nav a.active .at{opacity:1}
.side-foot{margin-top:1.6rem;padding-top:1.1rem;border-top:1px solid var(--line);display:flex;flex-wrap:wrap;gap:.4rem}
.side-foot img{height:20px;display:block}
.theme-btn{margin-top:1rem;background:none;border:1px solid var(--line);color:var(--muted);
  border-radius:8px;padding:.35rem .6rem;font:inherit;font-size:.82rem;cursor:pointer;width:100%}
.theme-btn:hover{border-color:var(--accent);color:var(--ink)}

/* main */
main{padding:2.6rem 2.4rem 5rem;min-width:0}
.hero h1{font-family:"IBM Plex Mono";font-weight:600;font-size:2.9rem;letter-spacing:-.02em;margin:0}
.hero .tag{color:var(--muted);font-size:1.12rem;max-width:60ch;margin:.5rem 0 1.1rem;text-wrap:balance}
.badges{display:flex;flex-wrap:wrap;gap:.45rem;margin:0 0 1.4rem}
.badges img{height:21px;display:block}
.install{display:flex;align-items:center;gap:.6rem;background:var(--panel);border:1px solid var(--line);
  border-radius:12px;padding:.65rem 1rem;box-shadow:var(--shadow);max-width:420px}
.install .prompt{color:var(--out);user-select:none;font-weight:600}
.install code{flex:1;font-size:.95rem}
.copy{background:none;border:1px solid var(--line);border-radius:7px;color:var(--muted);
  cursor:pointer;font:inherit;font-size:.72rem;padding:.2rem .5rem}
.copy:hover{border-color:var(--accent);color:var(--accent)}
.copy.ok{color:var(--out);border-color:var(--out)}

/* playground */
.pg{margin:2.2rem 0 .5rem;background:
   radial-gradient(120% 130% at 100% 0%, var(--accent-soft) 0%, transparent 55%), var(--panel);
  border:1px solid var(--line);border-radius:16px;padding:1.3rem 1.4rem;box-shadow:var(--shadow)}
.pg h2{margin:0 0 .1rem;font-size:1.06rem;display:flex;align-items:center;gap:.5rem}
.pg h2 .spark{color:var(--accent)}
.pg .hint{color:var(--muted);font-size:.86rem;margin:0 0 .9rem}
.pg input{width:100%;font-family:"IBM Plex Mono";font-size:1rem;color:var(--ink);
  background:var(--code-bg);border:1px solid var(--line);border-radius:10px;padding:.7rem .9rem;outline:none}
.pg input:focus{border-color:var(--accent);box-shadow:0 0 0 3px var(--accent-soft)}
.pg-rows{margin-top:.9rem;display:grid;gap:.35rem}
.pg-row{display:grid;grid-template-columns:84px 1fr auto;align-items:center;gap:.7rem;
  padding:.4rem .6rem;border-radius:9px}
.pg-row:hover{background:var(--panel-2)}
.pg-row .lbl{font-family:"IBM Plex Mono";font-size:.8rem;color:var(--accent);font-weight:500}
.pg-row .val{font-family:"IBM Plex Mono";font-size:.9rem;color:var(--out);overflow-x:auto;white-space:nowrap;
  scrollbar-width:thin}
.pg-row .val::-webkit-scrollbar{height:5px}

/* sections + cards */
section.pkg{scroll-margin-top:1.2rem;padding-top:2.4rem;margin-top:2rem;border-top:1px solid var(--line)}
section.pkg > h2{font-family:"IBM Plex Mono";font-size:1.55rem;margin:0 0 .15rem;letter-spacing:-.01em}
section.pkg > h2 .at{color:var(--accent)}
.pdesc{color:var(--muted);margin:.15rem 0 1.2rem;max-width:70ch}
.item{background:var(--panel);border:1px solid var(--line);border-radius:13px;
  padding:1rem 1.2rem;margin:.85rem 0;box-shadow:var(--shadow);transition:border-color .15s,transform .15s}
.item:hover{border-color:color-mix(in oklab,var(--accent) 40%,var(--line))}
.kind{display:inline-block;font-size:.66rem;font-weight:600;text-transform:uppercase;letter-spacing:.08em;
  border-radius:6px;padding:.1rem .45rem;margin-bottom:.55rem;
  color:var(--accent);background:var(--accent-soft);border:1px solid color-mix(in oklab,var(--accent) 26%,transparent)}
.item[data-k=struct] .kind{--c:#8b5cf6}.item[data-k=fn] .kind{--c:#0ca678}.item[data-k=let] .kind{--c:#2563eb}
.item .kind{color:var(--c,var(--accent));background:color-mix(in oklab,var(--c,var(--accent)) 13%,transparent);
  border-color:color-mix(in oklab,var(--c,var(--accent)) 30%,transparent)}
.sig{font-size:.98rem;margin:0 0 .55rem;overflow-x:auto;white-space:pre;color:var(--ink);padding-bottom:.15rem}
.sig .k{color:#8b5cf6;font-weight:500}.sig .ty{color:var(--accent)}.sig .op{color:var(--muted)}
@media (prefers-color-scheme:dark){.sig .k{color:#b794ff}}
.doc{margin:0;color:var(--ink);max-width:74ch}
.doc code{background:var(--code-bg);padding:.06rem .35rem;border-radius:5px;font-size:.9em;color:var(--accent)}
footer{margin-top:3rem;padding-top:1.3rem;border-top:1px solid var(--line);color:var(--muted);font-size:.9rem}

@media (max-width:820px){
  .layout{grid-template-columns:1fr}
  .sidebar{position:static;height:auto;border-right:none;border-bottom:1px solid var(--line)}
  .side-nav{flex-flow:row wrap}.side-nav a{border-left:none}.side-nav a.active{border-left:none}
  main{padding:1.8rem 1.2rem 4rem}.hero h1{font-size:2.2rem}
  .pg-row{grid-template-columns:70px 1fr auto}
}
"""

# JS: codecs (mirror the library exactly) + playground + scroll-spy + copy + theme
JS = r"""
const ALPHA={base58:"123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz",
  base62:"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
  base36:"0123456789abcdefghijklmnopqrstuvwxyz"};
const B32="ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
function bytesOf(s){return new TextEncoder().encode(s);}
function baseN(bytes,alpha){ // big-integer core; leading zero bytes -> zero digit
  const base=BigInt(alpha.length); let n=0n; for(const b of bytes)n=(n<<8n)|BigInt(b);
  let out=""; while(n>0n){out=alpha[Number(n%base)]+out;n=n/base;}
  let z=0; for(const b of bytes){if(b===0)z++;else break;}
  return alpha[0].repeat(z)+out;
}
function b16(bytes){return[...bytes].map(b=>b.toString(16).padStart(2,"0")).join("");}
function b64(bytes){let s="";for(const b of bytes)s+=String.fromCharCode(b);return btoa(s);}
function b32e(bytes){let out="",buf=0,bits=0;for(const b of bytes){buf=(buf<<8)|b;bits+=8;
  while(bits>=5){bits-=5;out+=B32[(buf>>bits)&31];}buf&=(1<<bits)-1;}
  if(bits>0)out+=B32[(buf<<(5-bits))&31];while(out.length%8)out+="=";return out;}
const CODECS=[["base16",b16],["base32",b32e],["base36",s=>baseN(s,ALPHA.base36)],
  ["base58",s=>baseN(s,ALPHA.base58)],["base62",s=>baseN(s,ALPHA.base62)],["base64",b64]];
function render(){const by=bytesOf(document.getElementById("pg-in").value);
  CODECS.forEach(([name,fn])=>{const el=document.getElementById("pg-"+name);if(el)el.textContent=fn(by);});}
document.addEventListener("DOMContentLoaded",()=>{
  const inp=document.getElementById("pg-in"); if(inp){inp.addEventListener("input",render);render();}
  // copy buttons
  document.querySelectorAll("[data-copy]").forEach(btn=>btn.addEventListener("click",()=>{
    navigator.clipboard.writeText(btn.getAttribute("data-copy")).then(()=>{
      const t=btn.textContent;btn.textContent="copied";btn.classList.add("ok");
      setTimeout(()=>{btn.textContent=t;btn.classList.remove("ok");},1100);});}));
  // scroll-spy
  const links=[...document.querySelectorAll(".side-nav a")];
  const map=Object.fromEntries(links.map(a=>[a.getAttribute("href").slice(1),a]));
  const spy=new IntersectionObserver(es=>{es.forEach(e=>{if(e.isIntersecting){
    links.forEach(a=>a.classList.remove("active"));const a=map[e.target.id];if(a)a.classList.add("active");}});},
    {rootMargin:"-10% 0px -80% 0px"});
  document.querySelectorAll("section.pkg").forEach(s=>spy.observe(s));
  // theme toggle
  const tb=document.getElementById("theme");if(tb)tb.addEventListener("click",()=>{
    const cur=document.documentElement.getAttribute("data-theme")
      ||(matchMedia("(prefers-color-scheme:dark)").matches?"dark":"light");
    document.documentElement.setAttribute("data-theme",cur==="dark"?"light":"dark");});
});
"""


def esc(t):
    return html.escape(t)


def main():
    HEAD = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>basex — MoonBit API</title>'
            '<link rel="preconnect" href="https://fonts.googleapis.com">'
            '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
            '<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&'
            'family=IBM+Plex+Sans:wght@400;500;600&display=swap" rel="stylesheet">'
            '<style>' + CSS + '</style></head><body>')

    side = ['<aside class="sidebar"><div class="brand"><span class="dot"></span>basex</div>'
            '<p class="brand-sub">MoonBit API reference</p><nav class="side-nav">']
    side += ['<a href="#%s"><span class="at">@</span>%s</a>' % (n, n) for n, _, _ in PKGS]
    side += ['</nav>'
             '<button class="theme-btn" id="theme">◐ toggle theme</button>'
             '<div class="side-foot">'
             '<a href="https://github.com/Lfan-ke/basex-moonbit/actions"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Lfan-ke/basex-moonbit/ci.yml?branch=master&label=CI&logo=github"></a>'
             '<a href="https://mooncakes.io/docs/Lfan-ke/basex"><img alt="mooncakes" src="https://img.shields.io/badge/mooncakes-Lfan--ke%2Fbasex-1f6feb"></a>'
             '</div></aside>']

    pg_rows = "".join('<div class="pg-row"><span class="lbl">%s</span>'
                      '<span class="val" id="pg-%s"></span></div>' % (n, n)
                      for n in ["base16", "base32", "base36", "base58", "base62", "base64"])
    hero = ('<main><header class="hero"><h1>basex</h1>'
            '<p class="tag">base16 · base32 · base36 · base58 · base62 · base64 for MoonBit — the RFC 4648 '
            'byte codecs plus a generic base-N core behind base36/base58/base62.</p>'
            '<div class="badges">'
            '<a href="https://github.com/Lfan-ke/basex-moonbit/actions"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/Lfan-ke/basex-moonbit/ci.yml?branch=master&label=CI&logo=github"></a>'
            '<img alt="tests" src="https://img.shields.io/badge/tests-20%20passing-0ca678">'
            '<a href="https://github.com/Lfan-ke/basex-moonbit"><img alt="GitHub" src="https://img.shields.io/badge/GitHub-source-24292f?logo=github"></a>'
            '<img alt="license" src="https://img.shields.io/badge/license-Apache--2.0-6d5efc"></div>'
            '<div class="install"><span class="prompt">$</span><code>moon add Lfan-ke/basex</code>'
            '<button class="copy" data-copy="moon add Lfan-ke/basex">copy</button></div>'
            '<div class="pg"><h2><span class="spark">✦</span> Try it live</h2>'
            '<p class="hint">Type anything — encoded in the browser with the exact algorithms this library ships.</p>'
            '<input id="pg-in" value="Hello, MoonBit!" spellcheck="false" aria-label="text to encode">'
            '<div class="pg-rows">' + pg_rows + '</div></div></header>')

    body = [HEAD, '<div class="layout">'] + side + [hero]
    for name, rel, desc in PKGS:
        body.append('<section class="pkg" id="%s"><h2><span class="at">@</span>%s</h2>'
                    '<p class="pdesc">%s</p>' % (name, name, esc(desc)))
        for kind, sig, doc in parse(ROOT / rel):
            body.append('<div class="item" data-k="%s"><span class="kind">%s</span>'
                        '<pre class="sig">%s</pre>%s</div>'
                        % (kind, kind, tint(sig), ('<p class="doc">%s</p>' % prose(doc)) if doc else ''))
        body.append('</section>')
    body.append('<footer>Generated from source <code>///</code> doc-comments · '
                '<a href="https://mooncakes.io/docs/Lfan-ke/basex">mooncakes</a> · '
                '<a href="https://github.com/Lfan-ke/basex-moonbit">GitHub</a> · Apache-2.0 © Leo Cheng</footer>')
    body.append('</main></div><script>' + JS + '</script></body></html>')

    out = ROOT / "docs" / "index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text("\n".join(body), encoding="utf-8")
    total = sum(len(parse(ROOT / rel)) for _, rel, _ in PKGS)
    print("wrote %s (%d public items across %d packages)" % (out, total, len(PKGS)))


if __name__ == "__main__":
    main()
