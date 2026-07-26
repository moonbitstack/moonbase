// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn ascii(s : String) -> Bytes {
  let out : Array[Byte] = Array::new()
  for c in s {
    out.push(c.to_int().to_byte())
  }
  Bytes::from_array(out)
}

///|
/// RFC 4648 §10 base32 test vectors.
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
  for c in cases {
    let (text, b32) = c
    let raw = ascii(text)
    assert_eq(@base32.encode(raw), b32)
    assert_eq(@base32.decode(b32), Some(raw))
  }
}

///|
/// RFC 4648 §10 base32hex test vectors.
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
  for c in cases {
    let (text, b32) = c
    let raw = ascii(text)
    assert_eq(@base32.encode_hex(raw), b32)
    assert_eq(@base32.decode_hex(b32), Some(raw))
  }
}

///|
test "base32 tolerates missing padding and rejects bad input" {
  assert_eq(@base32.decode("MZXW6YTBOI"), Some(ascii("foobar")))
  assert_eq(@base32.decode("MZXW6YTB1"), None) // '1' is not a base32 digit
  assert_eq(@base32.decode("MZX"), None) // 3 chars is an impossible length
}
