// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The integer face is pinned against JavaScript's `toString(36)`.
test "base36 integer encoding matches known values" {
  assert_eq(@base36.encode_int(0), "0")
  assert_eq(@base36.encode_int(35), "z")
  assert_eq(@base36.encode_int(36), "10")
  assert_eq(@base36.encode_int(123456789), "21i3v9")
  assert_eq(@base36.decode_int("21i3v9"), 123456789)
  assert_eq(@base36.decode_int("0"), 0)
}

///|
test "the upper-case alphabet spells the same numbers" {
  assert_eq(@base36.encode_int(123456789, kind=Upper), "21I3V9")
  assert_eq(@base36.decode_int("21I3V9", kind=Upper), 123456789)
}

///|
test "byte encoding round-trips and keeps leading zeros" {
  let data = bytes([0x00, 0x01, 0xff])
  let text = @base36.encode(data[:])
  assert_eq(@base36.decode(text), data)
  assert_true(text.length() > 0)
  assert_eq(@base36.decode(@base36.encode(b"moonbase"[:])), b"moonbase")
}

///|
test "an empty number is truncated input, not zero" {
  try @base36.decode_int("") catch {
    failure => assert_eq(failure, Truncated(at=0))
  } noraise {
    _ => fail("expected the empty string to be rejected")
  }
}

///|
test "a character outside the alphabet says which one and where" {
  try @base36.decode_int("xyz!") catch {
    failure => assert_eq(failure, Bad(at=3, char='!'))
  } noraise {
    _ => fail("expected the mark to be rejected")
  }
  try @base36.decode("ABC") catch {
    failure => assert_eq(failure, Bad(at=0, char='A'))
  } noraise {
    _ => fail("expected upper case to be rejected by the lower-case alphabet")
  }
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base36.decode_lossy("21i3 v9"), @base36.decode("21i3v9"))
}
