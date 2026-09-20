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
/// Hand-computed values: base62 has no RFC, so the vectors are worked out from
/// the alphabet itself and pinned here.
test "base62 integer encoding matches known values" {
  assert_eq(@base62.encode_int(0), "0")
  assert_eq(@base62.encode_int(61), "z")
  assert_eq(@base62.encode_int(62), "10")
  assert_eq(@base62.encode_int(3843), "zz")
  assert_eq(@base62.encode_int(123456789), "8M0kX")
  assert_eq(@base62.decode_int("8M0kX"), 123456789)
}

///|
test "byte encoding round-trips and keeps leading zeros" {
  assert_eq(@base62.encode(bytes([255])[:]), "47")
  assert_eq(@base62.encode(bytes([0, 255])[:]), "047")
  assert_eq(@base62.decode("047"), bytes([0, 255]))
  assert_eq(@base62.decode(@base62.encode(b"moonbase"[:])), b"moonbase")
}

///|
test "bad input says what and where" {
  try @base62.decode_int("") catch {
    failure => assert_eq(failure, Truncated(at=0))
  } noraise {
    _ => fail("expected the empty string to be rejected")
  }
  try @base62.decode_int("hello!") catch {
    failure => assert_eq(failure, Bad(at=5, char='!'))
  } noraise {
    _ => fail("expected the mark to be rejected")
  }
}
