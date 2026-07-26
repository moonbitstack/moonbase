// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = Array::new()
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// Integer mode matches JavaScript's `Number.prototype.toString(36)`.
test "base36 integer encoding matches known values" {
  assert_eq(@base36.encode_uint(0), "0")
  assert_eq(@base36.encode_uint(35), "z")
  assert_eq(@base36.encode_uint(36), "10")
  assert_eq(@base36.encode_uint(123456789), "21i3v9")
  let numbers : Array[UInt64] = [0, 1, 35, 36, 12345, 123456789, 9999999999]
  for n in numbers {
    assert_eq(@base36.decode_uint(@base36.encode_uint(n)), Some(n))
  }
}

///|
test "base36 byte encoding round-trips" {
  let samples = [
    bytes([]),
    bytes([0]),
    bytes([0, 0, 1]),
    bytes([0xde, 0xad, 0xbe, 0xef]),
  ]
  for s in samples {
    assert_eq(@base36.decode(@base36.encode(s)), Some(s))
  }
}

///|
test "base36 decode rejects bad input" {
  assert_eq(@base36.decode_uint(""), None)
  assert_eq(@base36.decode_uint("xyz!"), None)
  // upper case is outside the lower-case base36 alphabet
  assert_eq(@base36.decode("ABC"), None)
}
