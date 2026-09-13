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
/// A custom hexadecimal alphabet exercises the generic core directly. Note the
/// big-integer semantics: value 15 is one digit `"f"`, not the fixed-width
/// `"0f"` that byte-wise hex would print.
test "moonbase generic alphabet round-trips" {
  let hexa = @moonbase.Alphabet::new("0123456789abcdef")
  assert_eq(hexa.base(), 16)
  let data = bytes([0xde, 0xad, 0xbe, 0xef])
  assert_eq(@moonbase.encode(data, hexa), "deadbeef")
  assert_eq(@moonbase.decode("deadbeef", hexa), Some(data))
}

///|
test "moonbase preserves leading zero bytes as the zero digit" {
  let hexa = @moonbase.Alphabet::new("0123456789abcdef")
  assert_eq(@moonbase.encode(bytes([0x00, 0x0f]), hexa), "0f")
  assert_eq(@moonbase.decode("0f", hexa), Some(bytes([0x00, 0x0f])))
  assert_eq(@moonbase.encode(bytes([0x00, 0x00]), hexa), "00")
  assert_eq(@moonbase.encode(bytes([]), hexa), "")
  assert_eq(@moonbase.decode("", hexa), Some(bytes([])))
}

///|
test "moonbase decode rejects foreign characters" {
  let hexa = @moonbase.Alphabet::new("0123456789abcdef")
  assert_eq(@moonbase.decode("dead beef", hexa), None)
  assert_eq(@moonbase.decode("xyz", hexa), None)
}
