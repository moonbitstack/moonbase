// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// An ordered set of digit characters defining a positional numeral system.
/// The character at index `i` is the digit of value `i`, so the first
/// character is always the zero digit. Build one with [`Alphabet::new`] and
/// hand it to [`encode`] / [`decode`]; the `base58` and `base62` packages are
/// thin wrappers that pin a specific alphabet.
pub struct Alphabet {
  digits : Array[Char]
  lookup : Array[Int]
  base : Int
}

///|
/// Build an [`Alphabet`] from its ordered digit characters, e.g.
/// `Alphabet::new("0123456789abcdef")` for lowercase hexadecimal. Aborts when
/// a character repeats or is not ASCII, since either makes the mapping
/// ambiguous.
pub fn Alphabet::new(chars : String) -> Alphabet {
  let digits = chars.to_array()
  let base = digits.length()
  let lookup = Array::make(128, -1)
  for i in 0..<base {
    let code = digits[i].to_int()
    if code >= 128 {
      abort("basex: alphabet characters must be ASCII")
    }
    if lookup[code] != -1 {
      abort("basex: duplicate alphabet character")
    }
    lookup[code] = i
  }
  { digits, lookup, base }
}

///|
/// The radix of this alphabet — the number of distinct digits.
pub fn Alphabet::base(self : Alphabet) -> Int {
  self.base
}

///|
/// The character for digit value `v`, where `0 <= v < base`.
pub fn Alphabet::char_of(self : Alphabet, v : Int) -> Char {
  self.digits[v]
}

///|
/// The digit value of `c` in this alphabet, or `None` if `c` is not one of its
/// characters.
pub fn Alphabet::value_of(self : Alphabet, c : Char) -> Int? {
  let code = c.to_int()
  if code < 0 || code >= 128 {
    return None
  }
  let v = self.lookup[code]
  if v < 0 {
    None
  } else {
    Some(v)
  }
}

///|
/// Encode raw bytes to a string over `alphabet`. Leading zero bytes map to
/// leading zero-digit characters; the rest is read as a big-endian integer and
/// rewritten in the target base. Round-trips with [`decode`].
pub fn encode(input : Bytes, alphabet : Alphabet) -> String {
  let n = input.length()
  let base = alphabet.base
  let mut zeros = 0
  while zeros < n && input[zeros].to_int() == 0 {
    zeros = zeros + 1
  }
  // Little-endian digits of the big integer; leading (most significant) zeros
  // are never stored, so an all-zero payload leaves this empty.
  let out_digits : Array[Int] = Array::new()
  for i in 0..<n {
    let mut carry = input[i].to_int()
    for j in 0..<out_digits.length() {
      carry = carry + out_digits[j] * 256
      out_digits[j] = carry % base
      carry = carry / base
    }
    while carry > 0 {
      out_digits.push(carry % base)
      carry = carry / base
    }
  }
  let chars : Array[Char] = Array::new()
  for _ in 0..<zeros {
    chars.push(alphabet.digits[0])
  }
  let mut k = out_digits.length() - 1
  while k >= 0 {
    chars.push(alphabet.digits[out_digits[k]])
    k = k - 1
  }
  String::from_array(chars)
}

///|
/// Decode a string over `alphabet` back to the original bytes. Returns `None`
/// if `input` holds any character outside `alphabet`. Round-trips with
/// [`encode`].
pub fn decode(input : String, alphabet : Alphabet) -> Bytes? {
  let chars = input.to_array()
  let n = chars.length()
  let base = alphabet.base
  let zero_char = alphabet.digits[0]
  let mut zeros = 0
  while zeros < n && chars[zeros] == zero_char {
    zeros = zeros + 1
  }
  let out_bytes : Array[Int] = Array::new()
  for i in 0..<n {
    let code = chars[i].to_int()
    if code >= 128 {
      return None
    }
    let d = alphabet.lookup[code]
    if d < 0 {
      return None
    }
    let mut carry = d
    for j in 0..<out_bytes.length() {
      carry = carry + out_bytes[j] * base
      out_bytes[j] = carry % 256
      carry = carry / 256
    }
    while carry > 0 {
      out_bytes.push(carry % 256)
      carry = carry / 256
    }
  }
  let bytes : Array[Byte] = Array::new()
  for _ in 0..<zeros {
    bytes.push(0)
  }
  let mut k = out_bytes.length() - 1
  while k >= 0 {
    bytes.push(out_bytes[k].to_byte())
    k = k - 1
  }
  Some(Bytes::from_array(bytes))
}
