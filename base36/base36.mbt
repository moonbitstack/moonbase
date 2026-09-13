// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The base36 alphabet: the decimal digits followed by the lower-case letters.
/// base36 is the densest encoding that stays case-insensitive and purely
/// alphanumeric, which is why it is a common choice for human-facing short ids.
pub let alphabet : @moonbase.Alphabet = @moonbase.Alphabet::new(
  "0123456789abcdefghijklmnopqrstuvwxyz",
)

///|
/// Encode bytes as a base36 string. Round-trips with [`decode`].
pub fn encode(input : Bytes) -> String {
  @moonbase.encode(input, alphabet)
}

///|
/// Decode a base36 string back to bytes, or `None` on a character outside the
/// alphabet. Round-trips with [`encode`].
pub fn decode(input : String) -> Bytes? {
  @moonbase.decode(input, alphabet)
}

///|
/// Encode an unsigned integer as base36 — the same text JavaScript's
/// `n.toString(36)` produces (`123456789` becomes `"21i3v9"`). Zero encodes to
/// `"0"`. Round-trips with [`decode_uint`].
pub fn encode_uint(value : UInt64) -> String {
  if value == 0 {
    return "0"
  }
  let little : Array[Char] = Array::new()
  let mut v = value
  while v > 0 {
    little.push(alphabet.char_of((v % 36).to_int()))
    v = v / 36
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
/// Decode a base36 string produced by [`encode_uint`] back to an unsigned
/// integer. Returns `None` for an empty string or a character outside the
/// alphabet. Values beyond `UInt64::max_value` wrap, so keep ids within range.
pub fn decode_uint(input : String) -> UInt64? {
  if input.length() == 0 {
    return None
  }
  let mut acc : UInt64 = 0
  for c in input.iter() {
    match alphabet.value_of(c) {
      None => return None
      Some(d) => acc = acc * 36 + d.to_uint64()
    }
  }
  Some(acc)
}
