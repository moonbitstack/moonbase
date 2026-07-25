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
test "basex generic alphabet round-trips" {
  let hexa = @basex.Alphabet::new("0123456789abcdef")
  assert_eq(hexa.base(), 16)
  let data = bytes([0xde, 0xad, 0xbe, 0xef])
  assert_eq(@basex.encode(data, hexa), "deadbeef")
  assert_eq(@basex.decode("deadbeef", hexa), Some(data))
}

///|
test "basex preserves leading zero bytes as the zero digit" {
  let hexa = @basex.Alphabet::new("0123456789abcdef")
  assert_eq(@basex.encode(bytes([0x00, 0x0f]), hexa), "0f")
  assert_eq(@basex.decode("0f", hexa), Some(bytes([0x00, 0x0f])))
  assert_eq(@basex.encode(bytes([0x00, 0x00]), hexa), "00")
  assert_eq(@basex.encode(bytes([]), hexa), "")
  assert_eq(@basex.decode("", hexa), Some(bytes([])))
}

///|
test "basex decode rejects foreign characters" {
  let hexa = @basex.Alphabet::new("0123456789abcdef")
  assert_eq(@basex.decode("dead beef", hexa), None)
  assert_eq(@basex.decode("xyz", hexa), None)
}
