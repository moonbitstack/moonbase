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
  lookup : Array[Int32]
  base : Int32
}

///|
/// Build an [`Alphabet`] from its ordered digit characters, e.g.
/// `Alphabet::new("0123456789abcdef")` for lowercase hexadecimal.
///
/// Fails rather than aborts: an alphabet often comes from configuration, and a
/// library has no business killing the program over a value it was handed.
pub fn Alphabet::new(chars : String) -> Alphabet raise BadAlphabet {
  let digits = chars.to_array()
  let base = digits.length()
  if base < 2 {
    raise TooFew(count=base)
  }
  let lookup = Array::make(128, -1)
  for i in 0..<base {
    let code = digits[i].to_int()
    if code >= 128 {
      raise NotAscii(at=i, char=digits[i])
    }
    if lookup[code] != -1 {
      raise Repeated(at=i, char=digits[i])
    }
    lookup[code] = i
  }
  { digits, lookup, base, }
}

///|
/// An alphabet written as a literal in source, where a mistake is a
/// programming error rather than bad input.
///
/// This is the one place the library still aborts: `new` exists for alphabets
/// that arrive at runtime, and this one for the six that ship with the library
/// and are covered by its tests.
pub fn Alphabet::of(chars : String) -> Alphabet {
  try Alphabet::new(chars) catch {
    failure => abort(spell(failure))
  } noraise {
    alphabet => alphabet
  }
}

///|
/// What went wrong with an alphabet, in words, for the one place that aborts.
fn spell(failure : BadAlphabet) -> String {
  match failure {
    NotAscii(at~, ..) =>
      "moonbase: alphabet character " + at.to_string() + " is not ASCII"
    Repeated(at~, ..) =>
      "moonbase: alphabet character " +
      at.to_string() +
      " repeats an earlier one"
    TooFew(count~) =>
      "moonbase: an alphabet needs two digits, got " + count.to_string()
  }
}

///|
/// The radix of this alphabet — the number of distinct digits.
pub fn Alphabet::base(self : Alphabet) -> Int32 {
  self.base
}

///|
/// The character for digit value `v`, where `0 <= v < base`.
pub fn Alphabet::char_of(self : Alphabet, v : Int32) -> Char {
  self.digits[v]
}

///|
/// The digit value of `c` in this alphabet, or `None` if `c` is not one of its
/// characters.
pub fn Alphabet::value_of(self : Alphabet, c : Char) -> Int32? {
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
/// Encode raw bytes to a string over `alphabet`.
///
/// Leading zero bytes map to leading zero-digit characters; the rest is read as
/// a big-endian integer and rewritten in the target base. Round-trips with
/// [`decode`].
pub fn encode(input : BytesView, alphabet : Alphabet) -> String {
  let n = input.length()
  let base = alphabet.base
  let mut zeros = 0
  while zeros < n && input[zeros].to_int() == 0 {
    zeros = zeros + 1
  }
  // Little-endian digits of the big integer; leading zeros are never stored, so
  // an all-zero payload leaves this empty.
  let out_digits : Array[Int32] = []
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
  let out = StringBuilder()
  for _ in 0..<zeros {
    out.write_char(alphabet.digits[0])
  }
  let mut k = out_digits.length() - 1
  while k >= 0 {
    out.write_char(alphabet.digits[out_digits[k]])
    k = k - 1
  }
  out.to_string()
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView, alphabet : Alphabet) -> Bytes {
  let text = encode(input, alphabet)
  let out = Array::make(text.length(), b'\x00')
  for i in 0..<text.length() {
    out[i] = (text[i].to_int() & 0xff).to_byte()
  }
  Bytes::from_array(out)
}

///|
/// Decode a string over `alphabet` back to the original bytes.
///
/// Fails at the first character outside the alphabet, naming where it was.
/// Round-trips with [`encode`].
pub fn decode(input : StringView, alphabet : Alphabet) -> Bytes raise Malformed {
  read(input, alphabet)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  alphabet : Alphabet,
) -> Bytes raise Malformed {
  let text = StringBuilder()
  for i in 0..<input.length() {
    text.write_char(input[i].to_int().unsafe_to_char())
  }
  read(text.to_string(), alphabet)
}

///|
/// Decode, skipping anything outside the alphabet.
///
/// Never fails, which is what a payload wrapped in newlines or punctuation
/// needs. What it cannot do is tell you the input was wrong.
pub fn decode_lossy(input : StringView, alphabet : Alphabet) -> Bytes {
  let kept = StringBuilder()
  for i in 0..<input.length() {
    let code = input[i].to_int()
    if code >= 0 && code < 128 && alphabet.lookup[code] >= 0 {
      kept.write_char(code.unsafe_to_char())
    }
  }
  // Everything left is in the alphabet, so the reader has nothing to raise.
  try read(kept.to_string(), alphabet) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// Write a whole number in this base, without the leading-zero rule that the
/// byte-oriented faces keep.
pub fn encode_int(value : UInt64, alphabet : Alphabet) -> String {
  let base = alphabet.base.to_uint64()
  if value == 0 {
    return alphabet.digits[0].to_string()
  }
  let digits : Array[Char] = []
  let mut left = value
  while left > 0 {
    digits.push(alphabet.digits[(left % base).to_int()])
    left = left / base
  }
  let out = StringBuilder()
  let mut i = digits.length() - 1
  while i >= 0 {
    out.write_char(digits[i])
    i = i - 1
  }
  out.to_string()
}

///|
/// Read a whole number in this base.
pub fn decode_int(
  input : StringView,
  alphabet : Alphabet,
) -> UInt64 raise Malformed {
  if input.length() == 0 {
    raise Truncated(at=0)
  }
  let base = alphabet.base.to_uint64()
  let mut value = 0UL
  for i in 0..<input.length() {
    let code = input[i].to_int()
    let digit = if code >= 0 && code < 128 { alphabet.lookup[code] } else { -1 }
    if digit < 0 {
      raise Bad(at=i, char=code.unsafe_to_char())
    }
    value = value * base + digit.to_uint64()
  }
  value
}

///|
fn read(input : StringView, alphabet : Alphabet) -> Bytes raise Malformed {
  let base = alphabet.base
  let zero = alphabet.digits[0]
  let mut zeros = 0
  let mut counting = true
  let out_bytes : Array[Int32] = []
  for i in 0..<input.length() {
    let code = input[i].to_int()
    let digit = if code >= 0 && code < 128 { alphabet.lookup[code] } else { -1 }
    if digit < 0 {
      raise Bad(at=i, char=code.unsafe_to_char())
    }
    if counting && code == zero.to_int() {
      zeros = zeros + 1
      continue
    }
    counting = false
    let mut carry = digit
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
  let bytes : Array[Byte] = []
  for _ in 0..<zeros {
    bytes.push(0)
  }
  let mut k = out_bytes.length() - 1
  while k >= 0 {
    bytes.push(out_bytes[k].to_byte())
    k = k - 1
  }
  Bytes::from_array(bytes)
}
