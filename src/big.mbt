// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Write a whole number of any size in this base.
///
/// [`encode_int`](#encode_int) stops at a `UInt64`, which is where most ids
/// stop too — but a hash, a committee size or a Snowflake-style identifier is
/// wider than that, and a positional encoding has no reason to be. Like
/// `encode_int` this keeps no leading zeros: a number has none to keep.
///
/// A sign is not part of any alphabet here, so a negative value is encoded as
/// its magnitude. Ask with `value.compare_int(0)` first if the sign can vary.
pub fn encode_big(value : @bigint.BigInt, alphabet : Alphabet) -> String {
  let radix = alphabet.base
  let mut left = if value.compare_int(0) < 0 { -value } else { value }
  if left.is_zero() {
    return alphabet.digits[0].to_string()
  }
  let step = @bigint.BigInt::from_int(radix)
  let digits : Array[Char] = []
  while !left.is_zero() {
    digits.push(alphabet.digits[left.mod(step).to_int()])
    left = left.div(step)
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
/// Read a whole number of any size in this base.
///
/// Fails at the first character outside the alphabet, naming where it was, the
/// same way [`decode_int`](#decode_int) does.
pub fn decode_big(
  input : StringView,
  alphabet : Alphabet,
) -> @bigint.BigInt raise Malformed {
  if input.length() == 0 {
    raise Truncated(at=0)
  }
  let radix = @bigint.BigInt::from_int(alphabet.base)
  let mut value = @bigint.BigInt::from_int(0)
  for i in 0..<input.length() {
    let code = input[i].to_int()
    let digit = if code >= 0 && code < 128 { alphabet.lookup[code] } else { -1 }
    if digit < 0 {
      raise Bad(at=i, char=code.unsafe_to_char())
    }
    value = value * radix + @bigint.BigInt::from_int(digit)
  }
  value
}
