// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The integer faces, which are the ones a 64-bit integer cannot hold.
///
/// 2^128-1 is the interesting value: it is 39 decimal digits, 32 hexadecimal
/// ones, and 16 bytes, so a mistake in any of the three shows up as a length.
test "a number wider than a machine word round-trips" {
  let ten = @moonbase.Alphabet::of("0123456789")
  let hex = @moonbase.Alphabet::of("0123456789abcdef")
  let decimal = "340282366920938463463374607431768211455"
  let value = @moonbase.decode_big(decimal, ten)
  assert_eq(@moonbase.encode_big(value, ten), decimal)
  assert_eq(
    @moonbase.encode_big(value, hex),
    "ffffffffffffffffffffffffffffffff",
  )
  // And the same value through the byte faces, which is where the width shows up
  // as sixteen bytes rather than as a number.
  let bytes = @moonbase.decode(@moonbase.encode_big(value, hex), hex)
  assert_eq(bytes.length(), 16)
  assert_eq(@moonbase.encode(bytes[:], hex), "ffffffffffffffffffffffffffffffff")
}

///|
test "a small number says the same thing as the 64-bit face" {
  let hex = @moonbase.Alphabet::of("0123456789abcdef")
  let ten = @moonbase.Alphabet::of("0123456789")
  // `Int` is signed, so the largest 64-bit value is reached through its decimal
  // spelling rather than through `from_int`, which would wrap to -1.
  let cases = [
    (0UL, "0"),
    (1UL, "1"),
    (15UL, "15"),
    (255UL, "255"),
    (4096UL, "4096"),
    (18446744073709551615UL, "18446744073709551615"),
  ]
  for case in cases {
    let (value, decimal) = case
    let big = @moonbase.decode_big(decimal, ten)
    assert_eq(@moonbase.encode_big(big, hex), @moonbase.encode_int(value, hex))
    assert_eq(@moonbase.encode_big(big, ten), decimal)
  }
  assert_eq(
    @moonbase.encode_big(@bigint.BigInt::from_int(255), hex),
    @moonbase.encode_int(255UL, hex),
  )
}

///|
/// A number has no sign, so a negative value is written as its magnitude — the
/// same choice the byte faces make, for the same reason: no alphabet here has a
/// minus sign.
test "a negative value is written as its magnitude" {
  let ten = @moonbase.Alphabet::of("0123456789")
  let value = @bigint.BigInt::from_int(-1234)
  assert_eq(@moonbase.encode_big(value, ten), "1234")
}

///|
test "the reader says which character was wrong and where" {
  let ten = @moonbase.Alphabet::of("0123456789")
  try @moonbase.decode_big("12a4", ten) catch {
    failure => assert_eq(failure, Bad(at=2, char='a'))
  } noraise {
    _ => fail("expected the letter to be rejected")
  }
  try @moonbase.decode_big("", ten) catch {
    failure => assert_eq(failure, Truncated(at=0))
  } noraise {
    _ => fail("expected an empty number to be rejected")
  }
}
