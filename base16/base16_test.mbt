// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn ascii(s : String) -> Bytes {
  @moonbase.ascii(s)
}

///|
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The RFC 4648 §10 vectors, in the upper case the RFC writes them in.
test "base16 RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "66"),
    ("fo", "666F"),
    ("foo", "666F6F"),
    ("foob", "666F6F62"),
    ("fooba", "666F6F6261"),
    ("foobar", "666F6F626172"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base16.encode(raw[:], kind=Upper), encoded)
    assert_eq(@base16.decode(encoded), raw)
  }
}

///|
test "hexadecimal is byte-aligned, so leading zeros survive" {
  let z = bytes([0x00, 0x0f, 0xff])
  assert_eq(@base16.encode(z[:]), "000fff")
  assert_eq(@base16.decode("000fff"), z)
}

///|
test "either case decodes, and both spell the same bytes" {
  assert_eq(@base16.encode(ascii("foobar")[:]), "666f6f626172")
  assert_eq(@base16.decode("666f6f626172"), ascii("foobar"))
  assert_eq(@base16.decode("666F6F626172"), ascii("foobar"))
  assert_eq(@base16.decode("666f6F626172"), ascii("foobar"))
}

///|
test "a fingerprint is written with colons and read back through them" {
  let raw = bytes([0xab, 0xcd, 0xef])
  assert_eq(@base16.encode_colons(raw[:]), "ab:cd:ef")
  assert_eq(@base16.encode_colons(raw[:], kind=Upper), "AB:CD:EF")
  assert_eq(@base16.decode_lossy("AB:CD:EF"), raw)
  assert_eq(@base16.decode_lossy("ab cd ef"), raw)
}

///|
test "an odd number of digits is truncated input" {
  try @base16.decode("abc") catch {
    failure => assert_eq(failure, Truncated(at=3))
  } noraise {
    _ => fail("expected three digits to be rejected")
  }
}

///|
test "a character that is not a digit says which one and where" {
  try @base16.decode("ab:cd") catch {
    failure => assert_eq(failure, Bad(at=2, char=':'))
  } noraise {
    _ => fail("expected the colon to be rejected")
  }
}

///|
test "the bytes faces agree with the string faces" {
  let raw = ascii("foobar")
  assert_eq(@base16.encode_bytes(raw[:]), ascii("666f6f626172"))
  assert_eq(@base16.decode_bytes(ascii("666f6f626172")[:]), raw)
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base16.decode(@base16.encode(raw[:])), raw)
  assert_eq(@base16.decode(@base16.encode(raw[:], kind=Upper)), raw)
}
