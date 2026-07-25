// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The standard base62 alphabet: the decimal digits, then the upper-case
/// letters, then the lower-case letters. Every character is URL-safe, which is
/// why base62 is the usual choice for shortened links and opaque public ids.
pub let alphabet : @basex.Alphabet = @basex.Alphabet::new(
  "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
)

///|
/// Encode bytes as a base62 string. Round-trips with [`decode`].
pub fn encode(input : Bytes) -> String {
  @basex.encode(input, alphabet)
}

///|
/// Decode a base62 string back to bytes, or `None` when it holds a character
/// outside the alphabet.
pub fn decode(input : String) -> Bytes? {
  @basex.decode(input, alphabet)
}

///|
/// Encode an unsigned integer as base62 — the compact form a URL shortener
/// gives a numeric id (`123456789` becomes `"8M0kX"`). Zero encodes to `"0"`.
/// Round-trips with [`decode_uint`].
pub fn encode_uint(value : UInt64) -> String {
  if value == 0 {
    return "0"
  }
  let little : Array[Char] = Array::new()
  let mut v = value
  while v > 0 {
    little.push(alphabet.char_of((v % 62).to_int()))
    v = v / 62
  }
  let chars : Array[Char] = Array::new()
  let mut k = little.length() - 1
  while k >= 0 {
    chars.push(little[k])
    k = k - 1
  }
  String::from_array(chars)
}

///|
/// Decode a base62 string produced by [`encode_uint`] back to an unsigned
/// integer. Returns `None` for an empty string or an out-of-alphabet
/// character. Values beyond `UInt64::max_value` wrap, so keep ids within range.
pub fn decode_uint(input : String) -> UInt64? {
  if input.length() == 0 {
    return None
  }
  let mut acc : UInt64 = 0
  for c in input.iter() {
    match alphabet.value_of(c) {
      None => return None
      Some(d) => acc = acc * 62 + d.to_uint64()
    }
  }
  Some(acc)
}
