/* ============================================================================
   moonbase documentation — the codec engine
   ----------------------------------------------------------------------------
   A port of the library's encoders, shared by the homepage playground and the
   showcase visualiser. It is checked against the library's own test vectors by
   `scripts/check_docs.py`, so a drift between this file and `src/` fails the
   build instead of quietly lying to a reader.

   Loads as a browser script (window.Moonbase) or as a CommonJS module.
   ========================================================================== */
(function (root) {
  "use strict";

  var ALPHA = {
    base2: "01",
    base8: "01234567",
    base10: "0123456789",
    base16: "0123456789abcdef",
    base16u: "0123456789ABCDEF",
    base32: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
    base32hex: "0123456789ABCDEFGHIJKLMNOPQRSTUV",
    base32z: "ybndrfg8ejkmcpqxot1uwisza345h769",
    base36: "0123456789abcdefghijklmnopqrstuvwxyz",
    base45: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:",
    base58: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz",
    base58flickr: "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ",
    base62: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
    base64: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
    base64url: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
    ascii85: "",           // 33..117, filled in below
    z85: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#",
    ipv6: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~",
    bech32: "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
  };
  var a = "";
  for (var i = 33; i <= 117; i++) a += String.fromCharCode(i);
  ALPHA.ascii85 = a;

  // one character per byte value, the multibase base256emoji table. `Array.from`
  // splits on code points, not UTF-16 units: half a surrogate is not a character.
  var EMOJI = Array.from("\u{1F680}\u{1FA90}\u{2604}\u{1F6F0}\u{1F30C}\u{1F311}\u{1F312}\u{1F313}\u{1F314}\u{1F315}\u{1F316}\u{1F317}\u{1F318}\u{1F30D}\u{1F30F}\u{1F30E}\u{1F409}\u{2600}\u{1F4BB}\u{1F5A5}\u{1F4BE}\u{1F4BF}\u{1F602}\u{2764}\u{1F60D}\u{1F923}\u{1F60A}\u{1F64F}\u{1F495}\u{1F62D}\u{1F618}\u{1F44D}\u{1F605}\u{1F44F}\u{1F601}\u{1F525}\u{1F970}\u{1F494}\u{1F496}\u{1F499}\u{1F622}\u{1F914}\u{1F606}\u{1F644}\u{1F4AA}\u{1F609}\u{263A}\u{1F44C}\u{1F917}\u{1F49C}\u{1F614}\u{1F60E}\u{1F607}\u{1F339}\u{1F926}\u{1F389}\u{1F49E}\u{270C}\u{2728}\u{1F937}\u{1F631}\u{1F60C}\u{1F338}\u{1F64C}\u{1F60B}\u{1F497}\u{1F49A}\u{1F60F}\u{1F49B}\u{1F642}\u{1F493}\u{1F929}\u{1F604}\u{1F600}\u{1F5A4}\u{1F603}\u{1F4AF}\u{1F648}\u{1F447}\u{1F3B6}\u{1F612}\u{1F92D}\u{2763}\u{1F61C}\u{1F48B}\u{1F440}\u{1F62A}\u{1F611}\u{1F4A5}\u{1F64B}\u{1F61E}\u{1F629}\u{1F621}\u{1F92A}\u{1F44A}\u{1F973}\u{1F625}\u{1F924}\u{1F449}\u{1F483}\u{1F633}\u{270B}\u{1F61A}\u{1F61D}\u{1F634}\u{1F31F}\u{1F62C}\u{1F643}\u{1F340}\u{1F337}\u{1F63B}\u{1F613}\u{2B50}\u{2705}\u{1F97A}\u{1F308}\u{1F608}\u{1F918}\u{1F4A6}\u{2714}\u{1F623}\u{1F3C3}\u{1F490}\u{2639}\u{1F38A}\u{1F498}\u{1F620}\u{261D}\u{1F615}\u{1F33A}\u{1F382}\u{1F33B}\u{1F610}\u{1F595}\u{1F49D}\u{1F64A}\u{1F639}\u{1F5E3}\u{1F4AB}\u{1F480}\u{1F451}\u{1F3B5}\u{1F91E}\u{1F61B}\u{1F534}\u{1F624}\u{1F33C}\u{1F62B}\u{26BD}\u{1F919}\u{2615}\u{1F3C6}\u{1F92B}\u{1F448}\u{1F62E}\u{1F646}\u{1F37B}\u{1F343}\u{1F436}\u{1F481}\u{1F632}\u{1F33F}\u{1F9E1}\u{1F381}\u{26A1}\u{1F31E}\u{1F388}\u{274C}\u{270A}\u{1F44B}\u{1F630}\u{1F928}\u{1F636}\u{1F91D}\u{1F6B6}\u{1F4B0}\u{1F353}\u{1F4A2}\u{1F91F}\u{1F641}\u{1F6A8}\u{1F4A8}\u{1F92C}\u{2708}\u{1F380}\u{1F37A}\u{1F913}\u{1F619}\u{1F49F}\u{1F331}\u{1F616}\u{1F476}\u{1F974}\u{25B6}\u{27A1}\u{2753}\u{1F48E}\u{1F4B8}\u{2B07}\u{1F628}\u{1F31A}\u{1F98B}\u{1F637}\u{1F57A}\u{26A0}\u{1F645}\u{1F61F}\u{1F635}\u{1F44E}\u{1F932}\u{1F920}\u{1F927}\u{1F4CC}\u{1F535}\u{1F485}\u{1F9D0}\u{1F43E}\u{1F352}\u{1F617}\u{1F911}\u{1F30A}\u{1F92F}\u{1F437}\u{260E}\u{1F4A7}\u{1F62F}\u{1F486}\u{1F446}\u{1F3A4}\u{1F647}\u{1F351}\u{2744}\u{1F334}\u{1F4A3}\u{1F438}\u{1F48C}\u{1F4CD}\u{1F940}\u{1F922}\u{1F445}\u{1F4A1}\u{1F4A9}\u{1F450}\u{1F4F8}\u{1F47B}\u{1F910}\u{1F92E}\u{1F3BC}\u{1F975}\u{1F6A9}\u{1F34E}\u{1F34A}\u{1F47C}\u{1F48D}\u{1F4E3}\u{1F942}");

  function bytesOf(str) { return new TextEncoder().encode(str); }

  /* ---- bit packing ------------------------------------------------------ */
  // Read the bytes as one bit string and cut it into groups of `bits`. The
  // trailing group is shifted up and zero-filled, which is why the last
  // character of a short payload looks arbitrary until you count the bits.
  function pack(bytes, bits, alphabet, chunk, pad) {
    var mask = (1 << bits) - 1;
    var out = "", buf = 0, held = 0;
    for (var i = 0; i < bytes.length; i++) {
      buf = (buf << 8) | bytes[i];
      held += 8;
      while (held >= bits) {
        held -= bits;
        out += alphabet[(buf >> held) & mask];
      }
      buf &= (1 << held) - 1;
    }
    if (held > 0) out += alphabet[(buf << (bits - held)) & mask];
    if (pad) while (out.length % chunk !== 0) out += "=";
    return out;
  }

  function b16(bytes, upper) { return pack(bytes, 4, upper ? ALPHA.base16u : ALPHA.base16, 2, false); }
  function b32(bytes, hex) { return pack(bytes, 5, hex ? ALPHA.base32hex : ALPHA.base32, 8, true); }
  function b64(bytes, url, pad) { return pack(bytes, 6, url ? ALPHA.base64url : ALPHA.base64, 4, pad !== false); }

  /* ---- repeated division ------------------------------------------------ */
  // The bytes as one big-endian integer, divided by the base until it is zero.
  // A leading zero byte has no meaning in an integer, so the zeros are counted
  // first and written as leading zero digits.
  function baseN(bytes, alphabet) {
    var base = BigInt(alphabet.length);
    var n = 0n;
    for (var i = 0; i < bytes.length; i++) n = (n << 8n) | BigInt(bytes[i]);
    var out = "";
    if (n === 0n) {
      out = alphabet[0];
    } else {
      while (n > 0n) { out = alphabet[Number(n % base)] + out; n /= base; }
    }
    var z = 0;
    for (var j = 0; j < bytes.length; j++) { if (bytes[j] === 0) z++; else break; }
    return alphabet[0].repeat(z) + out;
  }

  /* ---- base45 (RFC 9285) ------------------------------------------------ */
  // Two bytes are a number below 65536; three base-45 digits carry it, least
  // significant first. An odd trailing byte gets two digits. No padding.
  function b45(bytes) {
    var A = ALPHA.base45, out = "";
    var i = 0;
    for (; i + 1 < bytes.length; i += 2) {
      var n = bytes[i] * 256 + bytes[i + 1];
      out += A[n % 45] + A[Math.floor(n / 45) % 45] + A[Math.floor(n / 2025)];
    }
    if (i < bytes.length) out += A[bytes[i] % 45] + A[Math.floor(bytes[i] / 45)];
    return out;
  }

  /* ---- base85, three ways ----------------------------------------------- */
  // Adobe's Ascii85: four bytes to five characters, `z` for a zero group, and a
  // short final group gives `n + 1` characters.
  function a85(bytes) {
    var A = ALPHA.ascii85, out = "";
    for (var i = 0; i < bytes.length; i += 4) {
      var n = 0, len = Math.min(4, bytes.length - i);
      for (var k = 0; k < 4; k++) n = n * 256 + (k < len ? bytes[i + k] : 0);
      if (len === 4 && n === 0) { out += "z"; continue; }
      var digits = "", v = n;
      for (var d = 0; d < 5; d++) { digits = A[v % 85] + digits; v = Math.floor(v / 85); }
      out += len === 4 ? digits : digits.slice(0, len + 1);
    }
    return out;
  }

  // ZeroMQ RFC 32: four bytes to five characters, no shortcut, no short tail.
  function z85(bytes) {
    if (bytes.length % 4 !== 0) throw new Error("z85 needs a multiple of four bytes");
    var A = ALPHA.z85, out = "";
    for (var i = 0; i < bytes.length; i += 4) {
      var v = ((bytes[i] << 24) | (bytes[i + 1] << 16) | (bytes[i + 2] << 8) | bytes[i + 3]) >>> 0;
      var digits = "";
      for (var d = 0; d < 5; d++) { digits = A[v % 85] + digits; v = Math.floor(v / 85); }
      out += digits;
    }
    return out;
  }

  // RFC 1924: the whole address as one number, most significant digit first.
  function ipv6(bytes) {
    var n = 0n;
    for (var i = 0; i < bytes.length; i++) n = (n << 8n) | BigInt(bytes[i]);
    if (n === 0n) return ALPHA.ipv6[0];
    var out = "";
    while (n > 0n) { out = ALPHA.ipv6[Number(n % 85n)] + out; n /= 85n; }
    return out;
  }

  /* ---- base256emoji ----------------------------------------------------- */
  function emoji(bytes) {
    var out = "";
    for (var i = 0; i < bytes.length; i++) out += EMOJI[bytes[i]];
    return out;
  }

  /* ---- bech32 ----------------------------------------------------------- */
  var GENERATOR = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3];

  function polymod(values) {
    var chk = 1;
    for (var i = 0; i < values.length; i++) {
      var top = chk >> 25;
      chk = ((chk & 0x1FFFFFF) << 5) ^ values[i];
      for (var j = 0; j < 5; j++) if ((top >> j) & 1) chk ^= GENERATOR[j];
    }
    return chk >>> 0;
  }

  function wordsOf(bytes) {
    var acc = 0, bits = 0, out = [];
    for (var i = 0; i < bytes.length; i++) {
      acc = (acc << 8) | bytes[i];
      bits += 8;
      while (bits >= 5) { bits -= 5; out.push((acc >> bits) & 31); }
      acc &= (1 << bits) - 1;
    }
    if (bits) out.push((acc << (5 - bits)) & 31);
    return out;
  }

  function bech32(hrp, bytes, variant) {
    var words = wordsOf(bytes);
    var values = [];
    for (var i = 0; i < hrp.length; i++) values.push(hrp.charCodeAt(i) >> 5);
    values.push(0);
    for (var j = 0; j < hrp.length; j++) values.push(hrp.charCodeAt(j) & 31);
    values = values.concat(words, [0, 0, 0, 0, 0, 0]);
    var residue = (polymod(values) ^ (variant === "m" ? 0x2BC830A3 : 1)) >>> 0;
    var data = "";
    for (var k = 0; k < words.length; k++) data += ALPHA.bech32[words[k]];
    for (var c = 0; c < 6; c++) data += ALPHA.bech32[(residue >>> (5 * (5 - c))) & 31];
    return hrp + "1" + data;
  }

  /* ---- multibase -------------------------------------------------------- */
  function lower(s) { return s.toLowerCase(); }
  function upper(s) { return s.toUpperCase(); }
  function padTo(s, n) { while (s.length % n !== 0) s += "="; return s; }

  // The body of each encoding multibase prefixes, without the prefix itself.
  var BODY = {
    base2: function (b) { return pack(b, 1, ALPHA.base2, 0, false); },
    base8: function (b) { return pack(b, 3, ALPHA.base8, 0, false); },
    base10: function (b) { return baseN(b, ALPHA.base10); },
    base16: function (b) { return b16(b, false); },
    base16upper: function (b) { return b16(b, true); },
    base32: function (b) { return lower(pack(b, 5, ALPHA.base32, 8, false)); },
    base32upper: function (b) { return upper(pack(b, 5, ALPHA.base32, 8, false)); },
    base32pad: function (b) { return lower(b32(b, false)); },
    base32padupper: function (b) { return upper(b32(b, false)); },
    base32hex: function (b) { return lower(pack(b, 5, ALPHA.base32hex, 8, false)); },
    base32hexupper: function (b) { return upper(pack(b, 5, ALPHA.base32hex, 8, false)); },
    base32hexpad: function (b) { return lower(b32(b, true)); },
    base32hexpadupper: function (b) { return upper(b32(b, true)); },
    base32z: function (b) { return pack(b, 5, ALPHA.base32z, 8, false); },
    base36: function (b) { return baseN(b, ALPHA.base36); },
    base36upper: function (b) { return upper(baseN(b, ALPHA.base36)); },
    base58btc: function (b) { return baseN(b, ALPHA.base58); },
    base58flickr: function (b) { return baseN(b, ALPHA.base58flickr); },
    base64: function (b) { return b64(b, false, false); },
    base64pad: function (b) { return b64(b, false, true); },
    base64url: function (b) { return b64(b, true, false); },
    base64urlpad: function (b) { return b64(b, true, true); },
    base256emoji: emoji            // the prefix is a rocket, and so is the first digit
  };

  var PREFIX = {
    base2: "0", base8: "7", base10: "9", base16: "f", base16upper: "F",
    base32: "b", base32upper: "B", base32pad: "c", base32padupper: "C",
    base32hex: "v", base32hexupper: "V", base32hexpad: "t", base32hexpadupper: "T",
    base32z: "h", base36: "k", base36upper: "K", base58btc: "z", base58flickr: "Z",
    base64: "m", base64pad: "M", base64url: "u", base64urlpad: "U",
    base256emoji: "\u{1F680}"
  };

  // What each package's own `encode` returns, which is what the showcase shows:
  // RFC 4648's capitals and padding for base32 and base64, and the multibase
  // spellings only where an encoding has no other default.
  var DEFAULT = {
    base2: BODY.base2,
    base8: BODY.base8,
    base10: BODY.base10,
    base16: function (b) { return b16(b, false); },
    base32: function (b) { return b32(b, false); },
    base45: b45,
    base36: function (b) { return baseN(b, ALPHA.base36); },
    base58: function (b) { return baseN(b, ALPHA.base58); },
    base62: function (b) { return baseN(b, ALPHA.base62); },
    base64: function (b) { return b64(b, false, true); },
    base85: a85,
    base256emoji: emoji
  };

  /* ---- the two pages' entry points -------------------------------------- */
  var Moonbase = {
    ALPHA: ALPHA,
    EMOJI: EMOJI,
    bytesOf: bytesOf,
    pack: pack,
    baseN: baseN,
    b16: b16, b32: b32, b64: b64, b45: b45, a85: a85, z85: z85,
    ipv6: ipv6, emoji: emoji, bech32: bech32,
    byName: function (name, bytes) {
      if (name === "base45") return b45(bytes);
      if (!BODY[name]) throw new Error("no codec for " + name);
      return BODY[name](bytes);
    },
    prefix: function (name) { return PREFIX[name]; },
    show: function (name, bytes) {
      if (!DEFAULT[name]) throw new Error("no codec for " + name);
      return DEFAULT[name](bytes);
    },
    // the rows the homepage playground shows
    rows: function (text) {
      var by = bytesOf(text);
      return [
        ["base2", Moonbase.byName("base2", by)],
        ["base8", Moonbase.byName("base8", by)],
        ["base10", Moonbase.byName("base10", by)],
        ["base16", b16(by, false)],
        ["base32", b32(by, false)],
        ["base32 hex", b32(by, true)],
        ["base36", baseN(by, ALPHA.base36)],
        ["base45", b45(by)],
        ["base58", baseN(by, ALPHA.base58)],
        ["base62", baseN(by, ALPHA.base62)],
        ["base64", b64(by, false, true)],
        ["base64 url", b64(by, true, false)],
        ["base85", a85(by)],
        ["base256emoji", emoji(by)]
      ];
    }
  };

  root.Moonbase = Moonbase;
  if (typeof module !== "undefined" && module.exports) module.exports = Moonbase;
})(typeof window !== "undefined" ? window : globalThis);
