// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// multibase's own fixture files, vendored under `scripts/vectors/multibase/`
/// and copied here in their table order. Each row is one encoding of the same
/// payload, which is what the prefix is for: the strings differ everywhere and
/// mean the same thing.

///|
/// `tests/basic.csv`: the canonical encoding of "yes mani !" in every entry of
/// the table this module writes.
let basic : Array[(@multibase.Base, String)] = [
  (
    @multibase.Base2,
    "001111001011001010111001100100000011011010110000101101110011010010010000000100001",
  ),
  (@multibase.Base8, "7362625631006654133464440102"),
  (@multibase.Base10, "9573277761329450583662625"),
  (@multibase.Base16, "f796573206d616e692021"),
  (@multibase.Base16Upper, "F796573206D616E692021"),
  (@multibase.Base32, "bpfsxgidnmfxgsibb"),
  (@multibase.Base32Upper, "BPFSXGIDNMFXGSIBB"),
  (@multibase.Base32Hex, "vf5in683dc5n6i811"),
  (@multibase.Base32HexUpper, "VF5IN683DC5N6I811"),
  (@multibase.Base32Pad, "cpfsxgidnmfxgsibb"),
  (@multibase.Base32PadUpper, "CPFSXGIDNMFXGSIBB"),
  (@multibase.Base32HexPad, "tf5in683dc5n6i811"),
  (@multibase.Base32HexPadUpper, "TF5IN683DC5N6I811"),
  (@multibase.Base32Z, "hxf1zgedpcfzg1ebb"),
  (@multibase.Base36, "k2lcpzo5yikidynfl"),
  (@multibase.Base36Upper, "K2LCPZO5YIKIDYNFL"),
  (@multibase.Base58Flickr, "Z7Pznk19XTTzBtx"),
  (@multibase.Base58Btc, "z7paNL19xttacUY"),
  (@multibase.Base64, "meWVzIG1hbmkgIQ"),
  (@multibase.Base64Pad, "MeWVzIG1hbmkgIQ=="),
  (@multibase.Base64Url, "ueWVzIG1hbmkgIQ"),
  (@multibase.Base64UrlPad, "UeWVzIG1hbmkgIQ=="),
  (@multibase.Base256Emoji, "🚀🏃✋🌈😅🌷🤤😻🌟😅👏"),
]

///|
/// `tests/leading_zero.csv`: the same payload with one zero byte in front. A
/// leading zero is the case that separates a bit packing from a big-integer
/// conversion, and every row here is one or the other.
let leading_zero : Array[(@multibase.Base, String)] = [
  (
    @multibase.Base2,
    "00000000001111001011001010111001100100000011011010110000101101110011010010010000000100001",
  ),
  (@multibase.Base8, "7000745453462015530267151100204"),
  (@multibase.Base10, "90573277761329450583662625"),
  (@multibase.Base16, "f00796573206d616e692021"),
  (@multibase.Base16Upper, "F00796573206D616E692021"),
  (@multibase.Base32, "bab4wk4zanvqw42jaee"),
  (@multibase.Base32Upper, "BAB4WK4ZANVQW42JAEE"),
  (@multibase.Base32Hex, "v01smasp0dlgmsq9044"),
  (@multibase.Base32HexUpper, "V01SMASP0DLGMSQ9044"),
  (@multibase.Base32Pad, "cab4wk4zanvqw42jaee======"),
  (@multibase.Base32PadUpper, "CAB4WK4ZANVQW42JAEE======"),
  (@multibase.Base32HexPad, "t01smasp0dlgmsq9044======"),
  (@multibase.Base32HexPadUpper, "T01SMASP0DLGMSQ9044======"),
  (@multibase.Base32Z, "hybhskh3ypiosh4jyrr"),
  (@multibase.Base36, "k02lcpzo5yikidynfl"),
  (@multibase.Base36Upper, "K02LCPZO5YIKIDYNFL"),
  (@multibase.Base58Flickr, "Z17Pznk19XTTzBtx"),
  (@multibase.Base58Btc, "z17paNL19xttacUY"),
  (@multibase.Base64, "mAHllcyBtYW5pICE"),
  (@multibase.Base64Pad, "MAHllcyBtYW5pICE="),
  (@multibase.Base64Url, "uAHllcyBtYW5pICE"),
  (@multibase.Base64UrlPad, "UAHllcyBtYW5pICE="),
  (@multibase.Base256Emoji, "🚀🚀🏃✋🌈😅🌷🤤😻🌟😅👏"),
]

///|
/// `tests/two_leading_zeros.csv`, for the encodings where one zero byte and two
/// are not simply a shift.
let two_leading_zeros : Array[(@multibase.Base, String)] = [
  (
    @multibase.Base2,
    "0000000000000000001111001011001010111001100100000011011010110000101101110011010010010000000100001",
  ),
  (@multibase.Base8, "700000171312714403326055632220041"),
  (@multibase.Base10, "900573277761329450583662625"),
  (@multibase.Base16, "f0000796573206d616e692021"),
  (@multibase.Base16Upper, "F0000796573206D616E692021"),
  (@multibase.Base32, "baaahszltebwwc3tjeaqq"),
  (@multibase.Base32Upper, "BAAAHSZLTEBWWC3TJEAQQ"),
  (@multibase.Base32Hex, "v0007ipbj41mm2rj940gg"),
  (@multibase.Base32HexUpper, "V0007IPBJ41MM2RJ940GG"),
  (@multibase.Base32Pad, "caaahszltebwwc3tjeaqq===="),
  (@multibase.Base32PadUpper, "CAAAHSZLTEBWWC3TJEAQQ===="),
  (@multibase.Base32HexPad, "t0007ipbj41mm2rj940gg===="),
  (@multibase.Base32HexPadUpper, "T0007IPBJ41MM2RJ940GG===="),
  (@multibase.Base32Z, "hyyy813murbssn5ujryoo"),
  (@multibase.Base36, "k002lcpzo5yikidynfl"),
  (@multibase.Base36Upper, "K002LCPZO5YIKIDYNFL"),
  (@multibase.Base58Flickr, "Z117Pznk19XTTzBtx"),
  (@multibase.Base58Btc, "z117paNL19xttacUY"),
  (@multibase.Base64, "mAAB5ZXMgbWFuaSAh"),
  (@multibase.Base64Pad, "MAAB5ZXMgbWFuaSAh"),
  (@multibase.Base64Url, "uAAB5ZXMgbWFuaSAh"),
  (@multibase.Base64UrlPad, "UAAB5ZXMgbWFuaSAh"),
  (
    @multibase.Base256Emoji,
    "🚀🚀🚀🏃✋🌈😅🌷🤤😻🌟😅👏",
  ),
]

///|
test "the canonical fixture of every base, and back" {
  let cases = [
    ("yes mani !", basic),
    ("\u{0}yes mani !", leading_zero),
    ("\u{0}\u{0}yes mani !", two_leading_zeros),
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
  (@multibase.Base16, "f68656c6c6f20776F726C64"),
  (@multibase.Base16Upper, "F68656c6c6f20776F726C64"),
  (@multibase.Base32, "bnbswy3dpeB3W64TMMQ"),
  (@multibase.Base32Upper, "Bnbswy3dpeB3W64TMMQ"),
  (@multibase.Base32Hex, "vd1imor3f41RMUSJCCG"),
  (@multibase.Base32HexUpper, "Vd1imor3f41RMUSJCCG"),
  (@multibase.Base32Pad, "cnbswy3dpeB3W64TMMQ======"),
  (@multibase.Base32PadUpper, "Cnbswy3dpeB3W64TMMQ======"),
  (@multibase.Base32HexPad, "td1imor3f41RMUSJCCG======"),
  (@multibase.Base32HexPadUpper, "Td1imor3f41RMUSJCCG======"),
  (@multibase.Base36, "kfUvrsIvVnfRbjWaJo"),
  (@multibase.Base36Upper, "KfUVrSIVVnFRbJWAJo"),
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
  for mark in ['\u{0}', '1', 'Q', '/', 'p'] {
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
  let encoded = "\u{1F680}\u{1F3C3}\u{270B}\u{1F308}\u{1F605}\u{1F337}\u{1F924}\u{1F63B}\u{1F31F}\u{1F605}\u{1F44F}"
  assert_eq(@multibase.encode(raw[:], base=Base256Emoji), encoded)
  assert_eq(@multibase.decode(encoded), raw)
  // A character that is not in the alphabet fails at its own index, counted in
  // characters: the rocket is one character and two UTF-16 code units.
  try @multibase.decode("\u{1F680}\u{1F3C3}a") catch {
    failure => assert_eq(failure, bad(at=2, char='a'))
  } noraise {
    _ => fail("expected a stray ascii character to be rejected")
  }
}

///|
test "the lossy face drops whitespace around a prefixed string" {
  assert_eq(
    @multibase.decode_lossy(" z7paNL19xttacUY\n"),
    @internal.ascii("yes mani !"),
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
