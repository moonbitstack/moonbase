// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Encode bytes as standard base64 (RFC 4648 §4): the `+/` alphabet, padded
/// with `=` to a multiple of four characters. Round-trips with [`decode`].
pub fn encode(input : Bytes) -> String {
  encode_with(input, std_digits, true)
}

///|
/// Encode bytes as URL-safe base64 (RFC 4648 §5): the `-_` alphabet with no
/// padding, so the result is safe inside URLs and file names. Round-trips with
/// [`decode_url`].
pub fn encode_url(input : Bytes) -> String {
  encode_with(input, url_digits, false)
}

///|
let std_digits : Array[Char] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".to_array()

///|
let url_digits : Array[Char] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".to_array()

///|
fn encode_with(input : Bytes, digits : Array[Char], pad : Bool) -> String {
  let n = input.length()
  let chars : Array[Char] = Array::new()
  let mut i = 0
  while i + 3 <= n {
    let b0 = input[i].to_int()
    let b1 = input[i + 1].to_int()
    let b2 = input[i + 2].to_int()
    chars.push(digits[b0 >> 2])
    chars.push(digits[((b0 & 0x03) << 4) | (b1 >> 4)])
    chars.push(digits[((b1 & 0x0f) << 2) | (b2 >> 6)])
    chars.push(digits[b2 & 0x3f])
    i = i + 3
  }
  let rem = n - i
  if rem == 1 {
    let b0 = input[i].to_int()
    chars.push(digits[b0 >> 2])
    chars.push(digits[(b0 & 0x03) << 4])
    if pad {
      chars.push('=')
      chars.push('=')
    }
  } else if rem == 2 {
    let b0 = input[i].to_int()
    let b1 = input[i + 1].to_int()
    chars.push(digits[b0 >> 2])
    chars.push(digits[((b0 & 0x03) << 4) | (b1 >> 4)])
    chars.push(digits[(b1 & 0x0f) << 2])
    if pad {
      chars.push('=')
    }
  }
  String::from_array(chars)
}

///|
/// Decode a standard base64 string (RFC 4648 §4). Trailing `=` padding is
/// optional. Returns `None` on any character outside the alphabet or an
/// impossible length. Round-trips with [`encode`].
pub fn decode(input : String) -> Bytes? {
  decode_with(input, std_lookup)
}

///|
/// Decode a URL-safe base64 string (RFC 4648 §5, `-_`). Padding is optional.
/// Round-trips with [`encode_url`].
pub fn decode_url(input : String) -> Bytes? {
  decode_with(input, url_lookup)
}

///|
let std_lookup : Array[Int] = build_lookup(
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",
)

///|
let url_lookup : Array[Int] = build_lookup(
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
)

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
  // A group of 4 carries 3 bytes; lengths 2 and 3 carry 1 and 2 bytes. A
  // remainder of 1 character is never producible and so is rejected.
  if n % 4 == 1 {
    return None
  }
  let out : Array[Byte] = Array::new()
  let mut i = 0
  while i < n {
    let take = if n - i >= 4 { 4 } else { n - i }
    let mut acc = 0
    for k in 0..<take {
      let code = cs[i + k].to_int()
      if code < 0 || code >= 128 {
        return None
      }
      let v = lookup[code]
      if v < 0 {
        return None
      }
      acc = (acc << 6) | v
    }
    if take == 4 {
      out.push(((acc >> 16) & 0xff).to_byte())
      out.push(((acc >> 8) & 0xff).to_byte())
      out.push((acc & 0xff).to_byte())
    } else if take == 3 {
      acc = acc >> 2
      out.push(((acc >> 8) & 0xff).to_byte())
      out.push((acc & 0xff).to_byte())
    } else {
      acc = acc >> 4
      out.push((acc & 0xff).to_byte())
    }
    i = i + take
  }
  Some(Bytes::from_array(out))
}
