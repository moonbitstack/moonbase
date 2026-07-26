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
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = Array::new()
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The RFC 4648 §10 test vectors; upper case is the spec's canonical spelling.
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
  for c in cases {
    let (text, hexs) = c
    let raw = ascii(text)
    assert_eq(@base16.encode_upper(raw), hexs)
    assert_eq(@base16.decode(hexs), Some(raw))
  }
}

///|
/// Byte orientation is the whole point: a leading zero byte and a zero high
/// nibble both survive, which the big-integer core does not guarantee.
test "base16 is byte-oriented and case-insensitive on decode" {
  assert_eq(@base16.encode(ascii("foobar")), "666f6f626172")
  let z = bytes([0x00, 0x0f, 0xff])
  assert_eq(@base16.encode(z), "000fff")
  assert_eq(@base16.decode("000fff"), Some(z))
  assert_eq(@base16.decode("000FFF"), Some(z))
  assert_eq(@base16.decode("DeAdBeEf"), @base16.decode("deadbeef"))
}

///|
test "base16 decode rejects odd length and non-hex" {
  assert_eq(@base16.decode("abc"), None)
  assert_eq(@base16.decode("zz"), None)
  assert_eq(@base16.decode("6g"), None)
}
