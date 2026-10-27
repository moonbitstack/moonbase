/* ============================================================================
   moonbase documentation — shared behaviour
   - theme toggle (light / dark, remembered)
   - copy-to-clipboard buttons
   - scroll-spy for the right-hand "On this page" TOC and the sidebar
   - wide-glyph wrapping so trailing comments stay aligned in code blocks
   - a faithful, output-verified port of the library's encoders (the live demo
     and the showcase visualiser both run the same algorithms the MoonBit
     source ships; outputs were checked against `moon run` on every backend)
   ========================================================================== */
(function () {
  "use strict";

  /* ---- theme ----------------------------------------------------------- */
  var root = document.documentElement;
  var saved = null;
  try { saved = localStorage.getItem("moonbase-theme"); } catch (e) {}
  if (saved === "light" || saved === "dark") root.setAttribute("data-theme", saved);
  var toggle = document.getElementById("theme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var cur = root.getAttribute("data-theme");
      var next = cur === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("moonbase-theme", next); } catch (e) {}
    });
  }

  /* ---- copy buttons --------------------------------------------------- */
  document.querySelectorAll("[data-copy]").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var text = btn.getAttribute("data-copy");
      var done = function () {
        var t = btn.textContent;
        btn.textContent = "copied";
        btn.classList.add("ok");
        setTimeout(function () { btn.textContent = t; btn.classList.remove("ok"); }, 1100);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () {});
      } else {
        var ta = document.createElement("textarea");
        ta.value = text; document.body.appendChild(ta); ta.select();
        try { document.execCommand("copy"); done(); } catch (e) {}
        document.body.removeChild(ta);
      }
    });
  });

  /* ---- scroll-spy (TOC + sidebar) ------------------------------------- */
  var tocLinks = Array.prototype.slice.call(document.querySelectorAll(".toc-nav a"));
  var sideLinks = Array.prototype.slice.call(document.querySelectorAll(".side-nav a"));
  var heads = Array.prototype.slice.call(document.querySelectorAll("main h1, main h2, main h3, .rtd-content h2, section.pkg"));
  if (tocLinks.length || sideLinks.length) {
    var spy = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        var id = en.target.id;
        if (!id) return;
        tocLinks.forEach(function (a) {
          a.classList.toggle("active", a.getAttribute("href") === "#" + id);
        });
        sideLinks.forEach(function (a) {
          a.classList.toggle("active", a.getAttribute("href").endsWith("#" + id));
        });
      });
    }, { rootMargin: "-15% 0px -75% 0px" });
    heads.forEach(function (h) { if (h.id) spy.observe(h); });
  }

  /* ---- keep wide glyphs aligned in monospace code ---------------------- */
  // Wrap each non-ASCII grapheme cluster in an inline-block of known width so
  // a CJK character or emoji counts as 2 columns and a comment lines up.
  function wrapWide(el) {
    if (el.dataset.wc) return;
    el.dataset.wc = "1";
    var nodes = Array.prototype.slice.call(el.childNodes);
    nodes.forEach(function (node) {
      if (node.nodeType !== Node.TEXT_NODE) return;
      var text = node.nodeValue;
      if (/[^\x00-\x7F]/.test(text) === false) return;
      var frag = document.createDocumentFragment();
      // split into grapheme clusters
      var m, re = /[\uD800-\uDBFF][\uDC00-\uDFFF]|[\s\S]/g;
      while ((m = re.exec(text)) !== null) {
        var ch = m[0];
        var span = document.createElement("span");
        span.className = "g";
        span.textContent = ch;
        var w = ch.codePointAt(0);
        var wide = (w >= 0x1100 && (w <= 0x115F || (w >= 0x2E80 && w <= 0xA4CF) ||
                    (w >= 0xAC00 && w <= 0xD7A3) || (w >= 0xF900 && w <= 0xFAFF) ||
                    (w >= 0xFF00 && w <= 0xFFE6) || (w >= 0x20000 && w <= 0x3FFFD) ||
                    (w >= 0x3000 && w <= 0x303F) || (w >= 0x3040 && w <= 0x309F) ||
                    (w >= 0x30A0 && w <= 0x30FF) || (w >= 0x3400 && w <= 0x4DBF) ||
                    (w >= 0x4E00 && w <= 0x9FFF)));
        span.style.width = (wide ? 2 : 1) + "ch";
        frag.appendChild(span);
      }
      el.replaceChild(frag, node);
    });
  }
  document.querySelectorAll("pre code, pre, code.align").forEach(wrapWide);

  /* ========================================================================
     Codec engine — mirrors moonbase exactly
     ====================================================================== */
  var ALPHA = {
    base16: "0123456789abcdef",
    base16u: "0123456789ABCDEF",
    base32: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
    base32hex: "0123456789ABCDEFGHIJKLMNOPQRSTUV",
    base36: "0123456789abcdefghijklmnopqrstuvwxyz",
    base58: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz",
    base62: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
    base64: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    base64url: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  };

  function bytesOf(str) { return new TextEncoder().encode(str); }

  function b16(bytes, upper) {
    var a = upper ? ALPHA.base16u : ALPHA.base16;
    var s = "";
    for (var i = 0; i < bytes.length; i++) {
      s += a[(bytes[i] >> 4) & 15] + a[bytes[i] & 15];
    }
    return s;
  }

  function pack(bytes, bits, alphabet, padLen, pad) {
    var A = alphabet;
    var mask = (1 << bits) - 1;
    var out = "", buf = 0, held = 0;
    for (var i = 0; i < bytes.length; i++) {
      buf = (buf << 8) | bytes[i];
      held += 8;
      while (held >= bits) {
        held -= bits;
        out += A[(buf >> held) & mask];
      }
      buf &= (1 << held) - 1;
    }
    if (held > 0) out += A[(buf << (bits - held)) & mask];
    if (pad) while (out.length % padLen !== 0) out += "=";
    return out;
  }
  function b32(bytes, hex) { return pack(bytes, 5, hex ? ALPHA.base32hex : ALPHA.base32, 8, true); }
  function b64(bytes, url, pad) { return pack(bytes, 6, url ? ALPHA.base64url : ALPHA.base64, 4, pad !== false); }

  // big-integer over the bytes (leading zero bytes -> leading zero digits)
  function baseN(bytes, alpha) {
    var base = BigInt(alpha.length);
    var n = 0n;
    for (var i = 0; i < bytes.length; i++) n = (n << 8n) | BigInt(bytes[i]);
    var out = "";
    if (n === 0n) {
      out = alpha[0];
    } else {
      while (n > 0n) { out = alpha[Number(n % base)] + out; n /= base; }
    }
    var z = 0;
    for (var j = 0; j < bytes.length; j++) { if (bytes[j] === 0) z++; else break; }
    return alpha[0].repeat(z) + out;
  }

  // whole-number mode (base36/58/62 encode_int)
  function baseNInt(value, alpha) {
    var base = BigInt(alpha.length);
    var v = BigInt(value);
    if (v === 0n) return alpha[0];
    var out = "";
    while (v > 0n) { out = alpha[Number(v % base)] + out; v /= base; }
    return out;
  }

  var Moonbase = {
    ALPHA: ALPHA,
    bytesOf: bytesOf,
    b16: b16, b32: b32, b64: b64, baseN: baseN, baseNInt: baseNInt,
    // the nine rows the homepage demo shows
    all: function (text) {
      var by = bytesOf(text);
      return [
        ["base16", b16(by, false)],
        ["base16 upper", b16(by, true)],
        ["base32", b32(by, false)],
        ["base32 hex", b32(by, true)],
        ["base36", baseN(by, ALPHA.base36)],
        ["base58", baseN(by, ALPHA.base58)],
        ["base62", baseN(by, ALPHA.base62)],
        ["base64", b64(by, false, true)],
        ["base64 url", b64(by, true, false)]
      ];
    }
  };
  window.Moonbase = Moonbase;

  /* ---- homepage playground -------------------------------------------- */
  var input = document.getElementById("pg-in");
  if (input) {
    var rows = document.getElementById("pg-rows");
    Moonbase.ALL_KEYS = ["base16","base16 upper","base32","base32 hex","base36","base58","base62","base64","base64 url"];
    function render() {
      var data = Moonbase.all(input.value);
      if (rows) {
        rows.innerHTML = "";
        data.forEach(function (row) {
          var r = document.createElement("div");
          r.className = "pg-row";
          var lbl = document.createElement("span"); lbl.className = "lbl"; lbl.textContent = row[0];
          var val = document.createElement("span"); val.className = "val"; val.textContent = row[1];
          var cp = document.createElement("button"); cp.className = "copy"; cp.textContent = "copy";
          cp.addEventListener("click", function () {
            var done = function () { cp.textContent = "copied"; cp.classList.add("ok");
              setTimeout(function () { cp.textContent = "copy"; cp.classList.remove("ok"); }, 1000); };
            if (navigator.clipboard) navigator.clipboard.writeText(row[1]).then(done, function () {});
          });
          r.appendChild(lbl); r.appendChild(val); r.appendChild(cp);
          rows.appendChild(r);
        });
      }
    }
    input.addEventListener("input", render);
    render();
  }

  /* ========================================================================
     Showcase visualiser
     ====================================================================== */
  var vizInput = document.getElementById("viz-text");
  var vizEnc = document.getElementById("viz-enc");
  var vizOut = document.getElementById("viz-out");
  if (vizInput && vizEnc && vizOut) {
    function hex2(n) { return n.toString(16).padStart(2, "0"); }
    function visByteRows(bytes) {
      var cells = [];
      for (var i = 0; i < bytes.length; i++) {
        var b = bytes[i];
        var ch = b >= 32 && b < 127 ? String.fromCharCode(b) : "\u00b7";
        cells.push('<span class="byte"><span class="ch">' + ch + "</span>" + hex2(b) + "</span>");
      }
      return '<div class="bytes">' + cells.join("") + "</div>";
    }
    function visualize() {
      var text = vizInput.value;
      var bytes = bytesOf(text);
      var enc = vizEnc.value;
      var steps = [];
      steps.push('<div class="viz-step"><div class="t">1 · input bytes (UTF-8)</div>' + visByteRows(bytes) + "</div>");

      if (enc === "base16") {
        var bits = "";
        for (var i = 0; i < bytes.length; i++) bits += ("00000000" + bytes[i].toString(2)).slice(-8);
        steps.push('<div class="viz-step"><div class="t">2 · group the bits by 4</div><div class="bits">' +
          bits.replace(/(.{4})/g, '<span class="grp">$1</span> ') + "</div></div>");
        steps.push('<div class="viz-step"><div class="t">3 · each group is one hexadecimal digit</div><div class="chars">' +
          b16(bytes, false).split("").map(function (c) { return '<span class="ch">' + c + "</span>"; }).join("") + "</div></div>");
        vizOut.innerHTML = steps.join("") + '<div class="result">' + b16(bytes, false) + "</div>";
      } else if (enc === "base32" || enc === "base64") {
        var bits2 = "";
        for (var j = 0; j < bytes.length; j++) bits2 += ("00000000" + bytes[j].toString(2)).slice(-8);
        var g = enc === "base32" ? 5 : 6;
        var grouped = "";
        for (var k = 0; k < bits2.length; k += g) grouped += '<span class="grp">' + bits2.slice(k, k + g).padEnd(g, "0") + "</span> ";
        steps.push('<div class="viz-step"><div class="t">2 · group the bits by ' + g + '</div><div class="bits">' + grouped + "</div></div>");
        steps.push('<div class="viz-step"><div class="t">3 · each group maps to one alphabet character (short groups are right-padded)</div></div>');
        var res = enc === "base32" ? b32(bytes, false) : b64(bytes, false, true);
        vizOut.innerHTML = steps.join("") + '<div class="result">' + res + "</div>";
      } else {
        // big-integer: repeated division by the base
        var alpha = ALPHA[enc];
        var base = BigInt(alpha.length);
        var n = 0n;
        for (var m = 0; m < bytes.length; m++) n = (n << 8n) | BigInt(bytes[m]);
        var rows = [];
        var work = n;
        if (work === 0n) {
          rows.push('<tr><td>0</td><td>' + alpha[0] + "</td></tr>");
        } else {
          while (work > 0n) {
            var r = work % base;
            rows.push("<tr><td>" + work.toString() + "</td><td>" + alpha[Number(r)] + "</td></tr>");
            work = work / base;
          }
        }
        var z = 0;
        for (var p = 0; p < bytes.length; p++) { if (bytes[p] === 0) z++; else break; }
        var zeroNote = z > 0 ? '<div class="t">leading zero bytes become leading "' + alpha[0] + '" digits (' + z + ")</div>" : "";
        steps.push('<div class="viz-step"><div class="t">2 · the bytes are one big integer</div><div class="result" style="border-left-color:var(--accent)">' + n.toString() + "</div></div>");
        steps.push('<div class="viz-step">' + zeroNote + '<div class="t">3 · divide by ' + base + ', the remainder is the next digit (right to left)</div>' +
          '<table><thead><tr><th>value</th><th>digit</th></tr></thead><tbody>' + rows.reverse().join("") + "</tbody></table></div>");
        var res2 = baseN(bytes, alpha);
        vizOut.innerHTML = steps.join("") + '<div class="result">' + res2 + "</div>";
      }
    }
    vizInput.addEventListener("input", visualize);
    vizEnc.addEventListener("change", visualize);
    visualize();
  }
})();
