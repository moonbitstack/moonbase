// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Encode bytes as standard base32 (RFC 4648 §6): the `A-Z2-7` alphabet, padded
/// with `=` to a multiple of eight characters. Round-trips with [`decode`].
pub fn encode(input : Bytes) -> String {
  encode_with(input, std_digits, true)
}

///|
/// Encode bytes as base32hex (RFC 4648 §7): the extended-hex `0-9A-V` alphabet,
/// which preserves sort order. Padded with `=`. Round-trips with [`decode_hex`].
pub fn encode_hex(input : Bytes) -> String {
  encode_with(input, hex_digits, true)
}

///|
let std_digits : Array[Char] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".to_array()

///|
let hex_digits : Array[Char] = "0123456789ABCDEFGHIJKLMNOPQRSTUV".to_array()

///|
fn encode_with(input : Bytes, digits : Array[Char], pad : Bool) -> String {
  let chars : Array[Char] = Array::new()
  let mut buffer = 0
  let mut bits = 0
  for i in 0..<input.length() {
    buffer = (buffer << 8) | input[i].to_int()
    bits = bits + 8
    while bits >= 5 {
      bits = bits - 5
      chars.push(digits[(buffer >> bits) & 0x1f])
    }
    buffer = buffer & ((1 << bits) - 1)
  }
  if bits > 0 {
    chars.push(digits[(buffer << (5 - bits)) & 0x1f])
  }
  if pad {
    while chars.length() % 8 != 0 {
      chars.push('=')
    }
  }
  String::from_array(chars)
}

///|
/// Decode a standard base32 string (RFC 4648 §6). Trailing `=` padding is
/// optional. Returns `None` on an out-of-alphabet character or an impossible
/// length. Round-trips with [`encode`].
pub fn decode(input : String) -> Bytes? {
  decode_with(input, std_lookup)
}

///|
/// Decode a base32hex string (RFC 4648 §7, `0-9A-V`). Padding is optional.
/// Round-trips with [`encode_hex`].
pub fn decode_hex(input : String) -> Bytes? {
  decode_with(input, hex_lookup)
}

///|
let std_lookup : Array[Int] = build_lookup("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

///|
let hex_lookup : Array[Int] = build_lookup("0123456789ABCDEFGHIJKLMNOPQRSTUV")

///|
fn build_lookup(chars : String) -> Array[Int] {
  let table = Array::make(128, -1)
  let ds = chars.to_array()
  for i in 0..<ds.length() {
    table[ds[i].to_int()] = i
  }
  table
}

///|
fn decode_with(input : String, lookup : Array[Int]) -> Bytes? {
  let cs = input.to_array()
  let mut n = cs.length()
  while n > 0 && cs[n - 1] == '=' {
    n = n - 1
  }
  // A block of eight characters carries five bytes; the only valid tail
  // lengths are 2, 4, 5 and 7 characters (1, 2, 3 and 4 bytes).
  let rem = n % 8
  if rem == 1 || rem == 3 || rem == 6 {
    return None
  }
  let out : Array[Byte] = Array::new()
  let mut buffer = 0
  let mut bits = 0
  for i in 0..<n {
    let code = cs[i].to_int()
    if code < 0 || code >= 128 {
      return None
    }
    let v = lookup[code]
    if v < 0 {
      return None
    }
    buffer = (buffer << 5) | v
    bits = bits + 5
    if bits >= 8 {
      bits = bits - 8
      out.push(((buffer >> bits) & 0xff).to_byte())
      buffer = buffer & ((1 << bits) - 1)
    }
  }
  Some(Bytes::from_array(out))
}
