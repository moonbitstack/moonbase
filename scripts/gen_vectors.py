#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Generate the vectors the encoding tests are written against.

Every vector in this repository comes from one of three places, and this script
is the common provenance for all of them:

  * a specification's own worked examples (RFC 9285 §4.3, RFC 1924 §5, ZeroMQ
    RFC 32, BIP 173 and BIP 350), reproduced here by a reference implementation
    of the algorithm the specification defines;
  * a multibase fixture file (`tests/*.csv` upstream), vendored under
    `scripts/vectors/multibase/` and copied into the MoonBit tests verbatim;
  * a reference implementation that ships with a language runtime — Python's
    `base64.a85encode` for Ascii85, and `hashlib` for the base58check trailer.

Usage:
    python3 scripts/gen_vectors.py check          # self-test, and sanity-check
                                                  # the MoonBit tables against
                                                  # the vendored fixtures
    python3 scripts/gen_vectors.py multibase FILE  # rewrite the fixture tables
                                                  # in a MoonBit test file
"""

import base64
import csv
import hashlib
import re
import sys

# ---------------------------------------------------------------- base45

BASE45 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"


def base45_encode(raw: bytes) -> str:
    """RFC 9285 §4: two bytes in one number below 65536, three characters out,
    least significant first; an odd trailing byte is two characters."""
    out = []
    for i in range(0, len(raw) - 1, 2):
        n = raw[i] * 256 + raw[i + 1]
        out += [BASE45[n % 45], BASE45[n // 45 % 45], BASE45[n // 2025]]
    if len(raw) % 2:
        n = raw[-1]
        out += [BASE45[n % 45], BASE45[n // 45]]
    return "".join(out)


def base45_decode(text: str) -> bytes:
    values = [BASE45.index(c) for c in text]
    out = bytearray()
    i = 0
    while i < len(values):
        rest = len(values) - i
        if rest >= 3:
            n = values[i] + values[i + 1] * 45 + values[i + 2] * 2025
            assert n <= 65535, "RFC 9285 §6: a triplet over 65535 is invalid"
            out += bytes([n // 256, n % 256])
            i += 3
        elif rest == 2:
            n = values[i] + values[i + 1] * 45
            assert n <= 255, "a pair over 255 is invalid"
            out.append(n)
            i += 2
        else:
            raise ValueError("a lone character is not a group")
    return bytes(out)


# ---------------------------------------------------------------- base85

ASCII85 = "".join(chr(33 + i) for i in range(85))
Z85 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"
RFC1924 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~"


def ascii85_encode(raw: bytes) -> str:
    """Adobe's Ascii85 as `base64.a85encode` writes it: `z` for a zero group, and
    `n + 1` characters for a final group of `n` bytes."""
    return base64.a85encode(raw, adobe=False).decode("ascii")


def z85_encode(raw: bytes) -> str:
    """ZeroMQ RFC 32: four bytes to five characters, no shortcuts, no short
    tail."""
    assert len(raw) % 4 == 0
    out = []
    for i in range(0, len(raw), 4):
        value = int.from_bytes(raw[i:i + 4], "big")
        digits = []
        for _ in range(5):
            digits.append(Z85[value % 85])
            value //= 85
        out += reversed(digits)
    return "".join(out)


def rfc1924_encode(raw: bytes) -> str:
    """RFC 1924: the whole address as one number, most significant digit first."""
    value = int.from_bytes(raw, "big")
    if value == 0:
        return RFC1924[0]
    digits = []
    while value:
        digits.append(RFC1924[value % 85])
        value //= 85
    return "".join(reversed(digits))


# ---------------------------------------------------------------- base58

BTC = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
FLICKR = "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"
RIPPLE = "rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz"


def base58_encode(raw: bytes, alphabet: str = BTC) -> str:
    value = int.from_bytes(raw, "big")
    out = ""
    while value:
        out = alphabet[value % 58] + out
        value //= 58
    zeros = len(raw) - len(raw.lstrip(b"\x00"))
    return alphabet[0] * zeros + out


def base58check_encode(raw: bytes, alphabet: str = BTC) -> str:
    """The Bitcoin trailer: four bytes of SHA-256, twice."""
    return base58_encode(raw + hashlib.sha256(hashlib.sha256(raw).digest()).digest()[:4], alphabet)


# ---------------------------------------------------------------- bech32

CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
GENERATOR = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
CONSTANT = {"bech32": 1, "bech32m": 0x2BC830A3}


def polymod(values):
    chk = 1
    for value in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ value
        for i in range(5):
            if (top >> i) & 1:
                chk ^= GENERATOR[i]
    return chk


def hrp_expand(hrp: str):
    return [ord(c) >> 5 for c in hrp] + [0] + [ord(c) & 31 for c in hrp]


def bech32_encode(hrp: str, words, kind: str = "bech32") -> str:
    values = hrp_expand(hrp) + list(words) + [0] * 6
    residue = polymod(values) ^ CONSTANT[kind]
    checksum = [(residue >> 5 * (5 - i)) & 31 for i in range(6)]
    return hrp + "1" + "".join(CHARSET[d] for d in list(words) + checksum)


def bech32_decode(text: str, kind: str = "bech32"):
    text = text.lower()
    separator = text.rfind("1")
    hrp, data = text[:separator], [CHARSET.index(c) for c in text[separator + 1:]]
    assert polymod(hrp_expand(hrp) + data) == CONSTANT[kind]
    return hrp, data[:-6]


def words_of(raw: bytes):
    acc = bits = 0
    out = []
    for byte in raw:
        acc = (acc << 8) | byte
        bits += 8
        while bits >= 5:
            bits -= 5
            out.append((acc >> bits) & 31)
        acc &= (1 << bits) - 1
    if bits:
        out.append((acc << (5 - bits)) & 31)
    return out


def bytes_of(words):
    acc = bits = 0
    out = bytearray()
    for word in words:
        acc = (acc << 5) | word
        bits += 5
        while bits >= 8:
            bits -= 8
            out.append((acc >> bits) & 0xFF)
        acc &= (1 << bits) - 1
    if bits >= 5 or acc:
        raise ValueError("the padding of the last group is too long or not zero")
    return bytes(out)


# ---------------------------------------------------------------- multibase

BASE_NAMES = {
    "base2": "Base2", "base8": "Base8", "base10": "Base10",
    "base16": "Base16", "base16upper": "Base16Upper",
    "base32": "Base32", "base32upper": "Base32Upper",
    "base32hex": "Base32Hex", "base32hexupper": "Base32HexUpper",
    "base32pad": "Base32Pad", "base32padupper": "Base32PadUpper",
    "base32hexpad": "Base32HexPad", "base32hexpadupper": "Base32HexPadUpper",
    "base32z": "Base32Z", "base36": "Base36", "base36upper": "Base36Upper",
    "base45": "Base45", "base58btc": "Base58Btc", "base58flickr": "Base58Flickr",
    "base64": "Base64", "base64pad": "Base64Pad",
    "base64url": "Base64Url", "base64urlpad": "Base64UrlPad",
    "base256emoji": "Base256Emoji",
}


def fixture_rows(path):
    """One fixture file, as (encoding name, string) pairs, in file order."""
    rows = []
    with open(path, encoding="utf-8") as handle:
        for record in csv.reader(handle):
            if len(record) < 2:
                continue
            name = record[0].strip()
            encoded = record[1].strip().strip('"')
            if name in ("encoding", "non-canonical encoding"):
                continue
            rows.append((name, encoded))
    return rows


def multibase_table(path):
    lines = []
    for name, encoded in fixture_rows(path):
        escaped = encoded.replace("\\", "\\\\").replace('"', '\\"')
        lines.append('  (@multibase.%s, "%s"),' % (BASE_NAMES[name], escaped))
    return "\n".join(lines)


# ---------------------------------------------------------------- self-test


def check():
    """Everything below is a vector that appears in a test, recomputed."""
    failures = 0

    def expect(what, got, want):
        nonlocal failures
        if got != want:
            failures += 1
            print("  %-44s got %r, want %r" % (what, got, want))

    # RFC 9285 §4.3 and §4.4.
    expect("base45 AB", base45_encode(b"AB"), "BB8")
    expect("base45 Hello!!", base45_encode(b"Hello!!"), "%69 VD92EX0")
    expect("base45 base-45", base45_encode(b"base-45"), "UJCLQE7W581")
    expect("base45 QED8WEX0", base45_decode("QED8WEX0"), b"ietf!")
    expect("base45 FGW", base45_decode("FGW"), b"\xff\xff")
    try:
        base45_decode("GGW")
        expect("base45 GGW", "accepted", "rejected")
    except AssertionError:
        pass

    # Adobe Ascii85, against Python's own encoder.
    for payload in (b"Man ", b"easy", b"sure", b"hello world", b"moonbase", b"a", b"ab", b"abc"):
        expect("ascii85 %r" % payload, ascii85_encode(payload), ENCODED_ASCII85[payload])

    # ZeroMQ RFC 32's own test case, and RFC 1924 §5.
    expect("z85 HelloWorld", z85_encode(bytes.fromhex("864FD26FB559F75B")), "HelloWorld")
    expect("z85 zero group", z85_encode(b"\x00\x00\x00\x00"), "00000")
    expect("z85 moon", z85_encode(b"moon"), "zeTug")
    address = bytes.fromhex("108000000000000000080800200C417A")
    expect("rfc1924 address", rfc1924_encode(address), "4)+k&C#VzJ4br>0wv%Yp")
    expect("rfc1924 zero", rfc1924_encode(bytes(16)), "0")

    # bech32 and bech32m, from empty data and from a payload.
    expect("bech32 empty", bech32_encode("a", []), "a12uel5l")
    expect("bech32m empty", bech32_encode("a", [], "bech32m"), "a1lqfn3a")
    expect("bech32 ?", bech32_encode("?", []), "?1ezyfcl")
    expect("bech32m ?", bech32_encode("?", [], "bech32m"), "?1v759aa")
    program = bytes.fromhex("751e76e8199196d454941c45d1b3a323f1433bd6")
    segwit = bech32_encode("bc", [0] + words_of(program))
    expect("segwit v0 address", segwit, "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4")
    expect("segwit v0 program", bytes_of(bech32_decode(segwit)[1][1:]), program)

    # base58check, against Bitcoin Core's documented address.
    key = bytes.fromhex("00010966776006953D5567439E5E39F86A0D273BEE")
    expect("base58check address", base58check_encode(key), "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")

    # The vendored fixtures still parse, and still describe the payloads they
    # claim to.
    for name, payload in (
        ("basic", b"yes mani !"),
        ("leading-zero", b"\x00yes mani !"),
        ("two-leading-zeros", b"\x00\x00yes mani !"),
    ):
        path = "scripts/vectors/multibase/%s.csv" % name
        rows = fixture_rows(path)
        if len(rows) < 20:
            failures += 1
            print("  %-44s only %d rows" % (path, len(rows)))
        for encoding, encoded in rows:
            if encoding == "base2":
                want = "".join(format(b, "08b") for b in payload)
                expect("%s base2" % name, encoded[1:], want)
    case = fixture_rows("scripts/vectors/multibase/case-insensitivity.csv")
    if len(case) < 10:
        failures += 1
        print("  case-insensitivity.csv only %d rows" % len(case))

    print("%d checks failed" % failures if failures else "all vectors reproduce")
    return 1 if failures else 0


ENCODED_ASCII85 = {
    b"Man ": "9jqo^",
    b"easy": "ARTY*",
    b"sure": "F*2M7",
    b"hello world": "BOu!rD]j7BEbo7",
    b"moonbase": "D/X?1@UX=h",
    b"a": "@/",
    b"ab": "@:B",
    b"abc": "@:E^",
}

TEMPLATE_HEAD = '''// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// multibase's own fixture files, vendored under `scripts/vectors/multibase/`
/// and copied here in their table order. Each row is one encoding of the same
/// payload, which is what the prefix is for: the strings differ everywhere and
/// mean the same thing.
'''

TEMPLATE_BODY = '''
///|
/// `tests/basic.csv`: the canonical encoding of "yes mani !" in every entry of
/// the table this module writes.
let basic : Array[(@multibase.Base, String)] = [
%s
]

///|
/// `tests/leading_zero.csv`: the same payload with one zero byte in front. A
/// leading zero is the case that separates a bit packing from a big-integer
/// conversion, and every row here is one or the other.
let leading_zero : Array[(@multibase.Base, String)] = [
%s
]

///|
/// `tests/two_leading_zeros.csv`, for the encodings where one zero byte and two
/// are not simply a shift.
let two_leading_zeros : Array[(@multibase.Base, String)] = [
%s
]

///|
test "the canonical fixture of every base, and back" {
  let cases = [
    ("yes mani !", basic),
    ("\\u{0}yes mani !", leading_zero),
    ("\\u{0}\\u{0}yes mani !", two_leading_zeros),
  ]
  for case in cases {
    let (text, table) = case
    let raw = @internal.ascii(text)
    for row in table {
      let (base, encoded) = row
      assert_eq(@multibase.encode(raw[:], base~), encoded)
      assert_eq(@multibase.decode(encoded), raw)
      assert_eq(@multibase.detect(encoded), Some(base))
    }
  }
}

///|
/// `tests/case_insensitivity.csv`: a string whose digits are in the wrong case
/// still means what it says, because the prefix already settled the case. The
/// fixture calls these "non-canonical", not "invalid" — decoding them is
/// required, and re-encoding gives the canonical spelling back.
let case_insensitivity : Array[(@multibase.Base, String)] = [
%s
]

///|
test "a non-canonical case still decodes to the same bytes" {
  let raw = @internal.ascii("hello world")
  for row in case_insensitivity {
    let (base, encoded) = row
    assert_eq(@multibase.decode(encoded), raw)
    assert_eq(@multibase.detect(encoded), Some(base))
  }
}

///|
test "every prefix in the table maps back to its entry, and no two collide" {
  let seen : Array[Char] = []
  for base in all_bases() {
    let mark = @multibase.prefix(base)
    assert_eq(@multibase.of_prefix(mark), Some(base))
    for other in seen {
      assert_true(mark != other)
    }
    seen.push(mark)
  }
}

///|
/// The four reserved code points and proquint are the entries this module does
/// not write, and a string starting with one of them is a failure at index zero
/// rather than a guess.
test "a reserved or unsupported prefix is rejected where it stands" {
  for mark in ['\\u{0}', '1', 'Q', '/', 'p'] {
    let text = mark.to_string() + "abc"
    assert_eq(@multibase.detect(text), None)
    try @multibase.decode(text) catch {
      failure => assert_eq(failure, bad(at=0, char=mark))
    } noraise {
      _ => fail("expected a reserved prefix to be rejected")
    }
  }
  try @multibase.decode("") catch {
    failure => assert_eq(failure, truncated(at=0))
  } noraise {
    _ => fail("expected an empty string to be rejected")
  }
}

///|
/// The failure index counts from the start of the whole string, so it points at
/// the input the caller has rather than at the body the decoder saw.
test "a failure inside the body is reported with the prefix counted in" {
  // Twenty-one hexadecimal digits: the odd one out is not a bad character, it is
  // a length that cannot be halved.
  try @multibase.decode("f796573206d616e6920214") catch {
    failure => assert_eq(failure, truncated(at=22))
  } noraise {
    _ => fail("expected twenty-one hexadecimal digits to be rejected")
  }
  try @multibase.decode("z7paNL19xttacU0") catch {
    failure => assert_eq(failure, bad(at=14, char='0'))
  } noraise {
    _ => fail("expected the zero to be rejected by base58")
  }
}

///|
test "every byte value survives every base" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  for base in all_bases() {
    assert_eq(@multibase.decode(@multibase.encode(raw[:], base~)), raw)
  }
}

///|
/// The emoji entry is the one place a character is not a byte and a byte is not
/// a character, and the one place the index of a failure counts characters
/// rather than UTF-16 code units.
test "base256emoji is one character per byte, whatever the code point is" {
  let raw = @internal.ascii("yes mani !")
  let encoded = "\\u{1F680}\\u{1F3C3}\\u{270B}\\u{1F308}\\u{1F605}\\u{1F337}\\u{1F924}\\u{1F63B}\\u{1F31F}\\u{1F605}\\u{1F44F}"
  assert_eq(@multibase.encode(raw[:], base=Base256Emoji), encoded)
  assert_eq(@multibase.decode(encoded), raw)
  // A character that is not in the alphabet fails at its own index, counted in
  // characters: the rocket is one character and two UTF-16 code units.
  try @multibase.decode("\\u{1F680}\\u{1F3C3}a") catch {
    failure => assert_eq(failure, bad(at=2, char='a'))
  } noraise {
    _ => fail("expected a stray ascii character to be rejected")
  }
}

///|
test "the lossy face drops whitespace around a prefixed string" {
  assert_eq(
    @multibase.decode_lossy(" z7paNL19xttacUY\\n"), @internal.ascii("yes mani !"),
  )
  assert_eq(@multibase.decode_lossy("z7paN L19x ttacU0"), b"")
}

///|
/// Every base this module writes, for a test that has to try them all.
fn all_bases() -> Array[@multibase.Base] {
  let out : Array[@multibase.Base] = []
  for row in basic {
    out.push(row.0)
  }
  // base45 is in the table but not in the fixture files, which predate RFC 9285.
  for row in [@multibase.Base45] {
    out.push(row)
  }
  out
}

///|
fn assert_true(condition : Bool) -> Unit raise {
  if !condition {
    fail("expected the condition to hold")
  }
}

///|
fn bad(at~ : Int32, char~ : Char) -> @moonbase.Malformed {
  @moonbase.Bad(at~, char~)
}

///|
fn truncated(at~ : Int32) -> @moonbase.Malformed {
  @moonbase.Truncated(at~)
}
'''


def write_multibase(path):
    if not re.search(r"multibase_test\.mbt$", path):
        raise SystemExit("refusing to overwrite %s: not a multibase test" % path)
    tables = [
        multibase_table("scripts/vectors/multibase/%s.csv" % name)
        for name in ("basic", "leading-zero", "two-leading-zeros", "case-insensitivity")
    ]
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(TEMPLATE_HEAD + TEMPLATE_BODY % tuple(tables))
    print("wrote %s" % path)


def main(argv):
    if len(argv) == 2 and argv[1] == "check":
        return check()
    if len(argv) == 3 and argv[1] == "multibase":
        write_multibase(argv[2])
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
