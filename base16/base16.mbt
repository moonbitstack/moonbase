// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Encode bytes as lower-case hexadecimal (RFC 4648 §8). Each byte becomes
/// exactly two characters, so a leading `0x00` is kept as `"00"` — unlike a
/// big-integer base conversion, which drops leading zeros. Round-trips with
/// [`decode`].
pub fn encode(input : Bytes) -> String {
  encode_with(input, lower)
}

///|
/// Encode bytes as upper-case hexadecimal — the canonical spelling in RFC 4648.
/// Round-trips with [`decode`], which accepts either case.
pub fn encode_upper(input : Bytes) -> String {
  encode_with(input, upper)
}

///|
let lower : Array[Char] = "0123456789abcdef".to_array()

///|
let upper : Array[Char] = "0123456789ABCDEF".to_array()

///|
fn encode_with(input : Bytes, digits : Array[Char]) -> String {
  let chars : Array[Char] = Array::new()
  for i in 0..<input.length() {
    let b = input[i].to_int()
    chars.push(digits[b >> 4])
    chars.push(digits[b & 0x0f])
  }
  String::from_array(chars)
}

///|
/// Decode a hexadecimal string back to bytes. Upper- and lower-case digits are
/// both accepted. Returns `None` when the length is odd or a character is not a
/// hex digit, so it doubles as validation. Round-trips with [`encode`].
pub fn decode(input : String) -> Bytes? {
  let cs = input.to_array()
  let n = cs.length()
  if n % 2 != 0 {
    return None
  }
  let out : Array[Byte] = Array::new()
  let mut i = 0
  while i < n {
    let hi = value_of(cs[i])
    let lo = value_of(cs[i + 1])
    if hi < 0 || lo < 0 {
      return None
    }
    out.push((hi * 16 + lo).to_byte())
    i = i + 2
  }
  Some(Bytes::from_array(out))
}

///|
fn value_of(c : Char) -> Int {
  let x = c.to_int()
  if x >= '0'.to_int() && x <= '9'.to_int() {
    x - '0'.to_int()
  } else if x >= 'a'.to_int() && x <= 'f'.to_int() {
    x - 'a'.to_int() + 10
  } else if x >= 'A'.to_int() && x <= 'F'.to_int() {
    x - 'A'.to_int() + 10
  } else {
    -1
  }
}
