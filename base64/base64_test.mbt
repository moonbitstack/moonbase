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
/// The RFC 4648 §10 test vectors — the canonical padding cases.
test "base64 RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "Zg=="),
    ("fo", "Zm8="),
    ("foo", "Zm9v"),
    ("foob", "Zm9vYg=="),
    ("fooba", "Zm9vYmE="),
    ("foobar", "Zm9vYmFy"),
  ]
  for c in cases {
    let (text, b64) = c
    let raw = ascii(text)
    assert_eq(@base64.encode(raw), b64)
    assert_eq(@base64.decode(b64), Some(raw))
  }
}

///|
/// Bytes chosen so index 62/63 appear: standard uses `+` `/`, URL-safe `-` `_`.
test "base64 url-safe alphabet and no padding" {
  let data = bytes([0xfb, 0xff, 0xbf])
  assert_eq(@base64.encode(data), "+/+/")
  assert_eq(@base64.encode_url(data), "-_-_")
  assert_eq(@base64.decode("+/+/"), Some(data))
  assert_eq(@base64.decode_url("-_-_"), Some(data))
  // one-byte tail: standard pads with "==", URL-safe omits padding
  assert_eq(@base64.encode(bytes([0xff])), "/w==")
  assert_eq(@base64.encode_url(bytes([0xff])), "_w")
}

///|
test "base64 decode tolerates missing padding and rejects bad input" {
  assert_eq(@base64.decode("Zm9vYg=="), Some(ascii("foob")))
  assert_eq(@base64.decode("Zm9vYg"), Some(ascii("foob")))
  assert_eq(@base64.decode("Zm9vYmE"), Some(ascii("fooba")))
  assert_eq(@base64.decode("****"), None)
  assert_eq(@base64.decode("Zg=="), Some(ascii("f")))
}
