/* ============================================================================
   moonbase documentation — shared behaviour
   - theme toggle (light / dark, remembered)
   - copy-to-clipboard buttons
   - scroll-spy for the right-hand "On this page" TOC and the sidebar
   - wide-glyph wrapping so trailing comments stay aligned in code blocks
   - the homepage playground and the showcase visualiser. Both encode through
     `assets/engine.js`, which is moonbase built to JavaScript; nothing in this
     file knows what a base45 digit is.
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
      copy(text, btn);
    });
  });

  function copy(text, btn) {
    var label = btn.textContent;
    var done = function () {
      btn.textContent = "copied";
      btn.classList.add("ok");
      setTimeout(function () { btn.textContent = label; btn.classList.remove("ok"); }, 1100);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () {});
    } else {
      var ta = document.createElement("textarea");
      ta.value = text; document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy"); done(); } catch (e) {}
      document.body.removeChild(ta);
    }
  }

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

  if (!window.moonbaseEngine) return;
  window.moonbaseEngine.then(demos, function (failure) {
    document.querySelectorAll("#pg-rows, #viz-out").forEach(function (el) {
      el.textContent = "The moonbase engine did not load: " + failure.message;
    });
  });

  function demos(M) {

    function hex2(n) { return (n < 16 ? "0" : "") + n.toString(16); }

    function bitString(bytes) {
      var out = "";
      for (var i = 0; i < bytes.length; i++) {
        out += ("00000000" + bytes[i].toString(2)).slice(-8);
      }
      return out;
    }

    function byteRow(bytes) {
      var cells = [];
      for (var i = 0; i < bytes.length; i++) {
        var b = bytes[i];
        var ch = b >= 32 && b < 127 ? String.fromCharCode(b) : "\u00b7";
        cells.push('<span class="byte"><span class="ch">' + ch + "</span>" + hex2(b) + "</span>");
      }
      return '<div class="bytes">' + cells.join("") + "</div>";
    }

    function chars(text) {
      // `Array.from` iterates code points: splitting on UTF-16 units would cut an
      // emoji in half, and base256emoji's whole alphabet is emoji.
      return '<div class="chars">' + Array.from(text).map(function (c) {
        return '<span class="ch">' + c + "</span>";
      }).join("") + "</div>";
    }

    function step(title, body) {
      return '<div class="viz-step"><div class="t">' + title + "</div>" + body + "</div>";
    }

    /* ---- homepage playground -------------------------------------------- */
    var input = document.getElementById("pg-in");
    if (input) {
      var rows = document.getElementById("pg-rows");
      var render = function () {
        if (!rows) return;
        rows.innerHTML = "";
        M.rows(input.value).forEach(function (row) {
          var line = document.createElement("div");
          line.className = "pg-row";
          var lbl = document.createElement("span");
          lbl.className = "lbl";
          lbl.textContent = row[0];
          var val = document.createElement("span");
          val.className = "val";
          val.textContent = row[1];
          var btn = document.createElement("button");
          btn.className = "copy";
          btn.textContent = "copy";
          btn.addEventListener("click", function () { copy(row[1], btn); });
          line.appendChild(lbl);
          line.appendChild(val);
          line.appendChild(btn);
          rows.appendChild(line);
        });
      };
      input.addEventListener("input", render);
      render();
    }

    /* ========================================================================
       Showcase visualiser
       ====================================================================== */
    var vizInput = document.getElementById("viz-text");
    var vizEnc = document.getElementById("viz-enc");
    var vizOut = document.getElementById("viz-out");

    // How each encoding gets from bytes to characters, which is the only thing
    // this page is about.
    var HOW = {
      base2: { mode: "pack", width: 1 },
      base8: { mode: "pack", width: 3 },
      base16: { mode: "pack", width: 4 },
      base32: { mode: "pack", width: 5 },
      base64: { mode: "pack", width: 6 },
      base45: { mode: "group", size: 2, base: 45, digits: 3, first: "last" },
      base85: { mode: "group", size: 4, base: 85, digits: 5, first: "first" },
      base10: { mode: "divide" },
      base36: { mode: "divide" },
      base58: { mode: "divide" },
      base62: { mode: "divide" },
      base256emoji: { mode: "substitute" },
      bech32: { mode: "checksum" }
    };

    function packing(bytes, how, text) {
      var bits = bitString(bytes);
      var grouped = "";
      for (var i = 0; i < bits.length; i += how.width) {
        grouped += '<span class="grp">' + bits.slice(i, i + how.width).padEnd(how.width, "0") + "</span> ";
      }
      return step("2 \u00b7 group the bits by " + how.width, '<div class="bits">' + grouped + "</div>") +
        step("3 \u00b7 each group is one digit (a short group is shifted up and zero-filled)", chars(text));
    }

    function grouping(bytes, how, text) {
      var rowsHtml = "";
      var at = 0;
      for (; at + how.size <= bytes.length; at += how.size) {
        var value = 0;
        var raw = [];
        for (var k = 0; k < how.size; k++) {
          value = value * 256 + bytes[at + k];
          raw.push(hex2(bytes[at + k]));
        }
        rowsHtml += "<tr><td>" + raw.join(" ") + "</td><td>" + value + "</td></tr>";
      }
      var tail = "";
      if (at < bytes.length) {
        var rest = bytes.slice(at);
        var short = 0;
        for (var j = 0; j < rest.length; j++) short = short * 256 + rest[j];
        tail = "<tr><td>" + Array.prototype.map.call(rest, hex2).join(" ") + "</td><td>" +
          short + " (a short tail)</td></tr>";
      }
      return step(
        "2 \u00b7 every " + how.size + " bytes are one number",
        "<table><thead><tr><th>bytes</th><th>value</th></tr></thead><tbody>" +
          rowsHtml + tail + "</tbody></table>"
      ) + step(
        "3 \u00b7 the number in base " + how.base + ", " + how.digits + " digits, " +
          (how.first === "last" ? "least significant first" : "most significant first"),
        chars(text)
      );
    }

    function dividing(bytes, text, kind) {
      var alpha = M.ALPHA[kind];
      var base = alpha.length;
      var n = 0n;
      for (var i = 0; i < bytes.length; i++) n = (n << 8n) | BigInt(bytes[i]);
      var digits = [];
      var work = n;
      if (work === 0n) {
        digits.push('<tr><td>0</td><td>' + alpha[0] + "</td></tr>");
      } else {
        while (work > 0n) {
          digits.push("<tr><td>" + work.toString() + "</td><td>" + alpha[Number(work % BigInt(base))] + "</td></tr>");
          work = work / BigInt(base);
        }
      }
      var zeros = 0;
      for (var p = 0; p < bytes.length; p++) { if (bytes[p] === 0) zeros++; else break; }
      var zeroNote = zeros > 0
        ? "<div class=\"t\">leading zero bytes become leading \"" + alpha[0] + "\" digits (" + zeros + ")</div>"
        : "";
      return step("2 \u00b7 the bytes are one big integer",
        '<div class="result" style="border-left-color:var(--accent)">' + n.toString() + "</div>") +
        step("3 \u00b7 divide by " + base + ", the remainder is the next digit (right to left)" + zeroNote,
          "<table><thead><tr><th>value</th><th>digit</th></tr></thead><tbody>" +
            digits.reverse().join("") + "</tbody></table>") +
        step("4 \u00b7 read the digits back to front", chars(text));
    }

    function substituting(bytes, text) {
      var cells = [];
      var glyphs = Array.from(text);
      for (var i = 0; i < bytes.length; i++) {
        cells.push('<span class="byte"><span class="ch">' + glyphs[i] + "</span>" + hex2(bytes[i]) + "</span>");
      }
      return step("2 \u00b7 one character per byte value, looked up in a 256-entry table",
        '<div class="bytes">' + cells.join("") + "</div>" +
        '<div class="t">' + bytes.length + " bytes, " + glyphs.length +
        " characters \u2014 no bit packing, no padding, no length rule</div>") +
        step("3 \u00b7 the result", chars(text));
    }

    function checksum(bytes, text, hrp) {
      var words = [];
      var acc = 0, bits = 0;
      for (var i = 0; i < bytes.length; i++) {
        acc = (acc << 8) | bytes[i];
        bits += 8;
        while (bits >= 5) { bits -= 5; words.push((acc >> bits) & 31); }
        acc &= (1 << bits) - 1;
      }
      if (bits) words.push((acc << (5 - bits)) & 31);
      var body = words.map(function (w) { return M.ALPHA.bech32[w]; }).join("");
      var sum = text.slice(text.length - 6);
      return step("2 \u00b7 the payload regrouped from 8 bits to 5",
        '<div class="bits">' + words.map(function (w) {
          return '<span class="grp">' + ("00000" + w.toString(2)).slice(-5) + "</span>";
        }).join(" ") + "</div>") +
        step("3 \u00b7 the prefix, the data, and six checksum characters",
          '<div class="result" style="border-left-color:var(--accent)">' +
          hrp + "<b>1</b>" + body + "<b>" + sum + "</b></div>" +
          '<div class="t">the checksum is a BCH code over the prefix and every data group \u2014 ' +
          "a typo anywhere, including in the prefix, lands here</div>") +
        step("4 \u00b7 the result", chars(text));
    }

    function visualize() {
      if (!vizInput || !vizEnc || !vizOut) return;
      var text = vizInput.value;
      var kind = vizEnc.value;
      var bytes = M.bytesOf(text);
      var how = HOW[kind] || HOW.base16;
      var hrp = "moonbase";

      var out = step("1 \u00b7 input bytes (UTF-8)", byteRow(bytes));
      var result;
      try {
        result = kind === "bech32" ? M.bech32(hrp, text) : M.show(kind, text);
      } catch (failure) {
        // The library refuses this input, so the page must not pretend otherwise.
        vizOut.innerHTML = out + '<div class="t">' + failure.message + "</div>";
        return;
      }
      if (kind === "bech32") {
        out += checksum(bytes, result, hrp);
      } else if (how.mode === "pack") {
        out += packing(bytes, how, result);
      } else if (how.mode === "group") {
        out += grouping(bytes, how, result);
      } else if (how.mode === "divide") {
        out += dividing(bytes, result, kind);
      } else {
        out += substituting(bytes, result);
      }
      vizOut.innerHTML = out + '<div class="result">' + result + "</div>";
    }

    if (vizInput && vizEnc && vizOut) {
      vizInput.addEventListener("input", visualize);
      vizEnc.addEventListener("change", visualize);
      visualize();
    }
  }
})();
