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
test "base62 byte encoding round-trips" {
  // 255 = 4*62 + 7, and a leading zero byte renders as the zero digit '0'.
  assert_eq(@base62.encode(bytes([255])), "47")
  assert_eq(@base62.encode(bytes([0, 255])), "047")
  let samples = [
    bytes([]),
    bytes([0]),
    bytes([0, 0, 1]),
    bytes([0xde, 0xad, 0xbe, 0xef]),
    bytes([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]),
  ]
  for s in samples {
    assert_eq(@base62.decode(@base62.encode(s)), Some(s))
  }
}

///|
test "base62 integer encoding matches known values" {
  assert_eq(@base62.encode_uint(0), "0")
  assert_eq(@base62.encode_uint(61), "z")
  assert_eq(@base62.encode_uint(62), "10")
  assert_eq(@base62.encode_uint(3843), "zz")
  assert_eq(@base62.encode_uint(123456789), "8M0kX")
  let numbers : Array[UInt64] = [0, 1, 61, 62, 12345, 123456789, 9999999999]
  for n in numbers {
    assert_eq(@base62.decode_uint(@base62.encode_uint(n)), Some(n))
  }
}

///|
test "base62 decode_uint rejects bad input" {
  assert_eq(@base62.decode_uint(""), None)
  assert_eq(@base62.decode_uint("hello!"), None)
}
