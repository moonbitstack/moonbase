// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn ascii(s : String) -> Bytes {
  @moonbase.ascii(s)
}

///|
/// The RFC 4648 §10 vectors for the ordinary alphabet.
test "base32 RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "MY======"),
    ("fo", "MZXQ===="),
    ("foo", "MZXW6==="),
    ("foob", "MZXW6YQ="),
    ("fooba", "MZXW6YTB"),
    ("foobar", "MZXW6YTBOI======"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base32.encode(raw[:]), encoded)
    assert_eq(@base32.decode(encoded), raw)
  }
}

///|
/// The RFC 4648 §10 vectors for the extended-hex alphabet.
test "base32hex RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "CO======"),
    ("fo", "CPNG===="),
    ("foo", "CPNMU==="),
    ("foob", "CPNMUOG="),
    ("fooba", "CPNMUOJ1"),
    ("foobar", "CPNMUOJ1E8======"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base32.encode(raw[:], kind=Hex), encoded)
    assert_eq(@base32.decode(encoded, kind=Hex), raw)
  }
}

///|
test "the extended-hex alphabet keeps byte order" {
  let low = @base32.encode(b"\x00\x00"[:], kind=Hex, padding=false)
  let high = @base32.encode(b"\xff\xff"[:], kind=Hex, padding=false)
  assert_true(low < high)
}

///|
test "encoding without padding leaves the tail off" {
  assert_eq(@base32.encode(ascii("f")[:], padding=false), "MY")
  assert_eq(@base32.encode(ascii("foobar")[:], padding=false), "MZXW6YTBOI")
}

///|
test "padding is optional on the way in, and either case decodes" {
  assert_eq(@base32.decode("MZXW6YTBOI"), ascii("foobar"))
  assert_eq(@base32.decode("mzxw6ytboi"), ascii("foobar"))
}

///|
test "a character outside the alphabet says which one and where" {
  try @base32.decode("MZ1W6===") catch {
    failure => assert_eq(failure, Bad(at=2, char='1'))
  } noraise {
    _ => fail("expected the one to be rejected")
  }
}

///|
test "a length that cannot be a whole number of bytes is truncated input" {
  try @base32.decode("MZX") catch {
    failure => assert_eq(failure, Truncated(at=3))
  } noraise {
    _ => fail("expected three characters to be rejected")
  }
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base32.decode_lossy("MZXW\n6YTB\nOI"), ascii("foobar"))
  assert_eq(@base32.decode_lossy("!!!!"), b"")
}

///|
test "the bytes faces agree with the string faces" {
  let raw = ascii("foobar")
  assert_eq(@base32.encode_bytes(raw[:]), ascii("MZXW6YTBOI======"))
  assert_eq(@base32.decode_bytes(ascii("MZXW6YTBOI")[:]), raw)
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base32.decode(@base32.encode(raw[:])), raw)
  assert_eq(@base32.decode(@base32.encode(raw[:], kind=Hex), kind=Hex), raw)
}
