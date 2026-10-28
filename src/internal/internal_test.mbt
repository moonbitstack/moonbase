// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// These two used to live in the root package's tests, back when the kernel was
/// public. The assertions are the ones that were there; only the prefix on the
/// names changed, because the kernel now lives in `internal`.
test "ASCII text and the bytes that spell it convert both ways" {
  assert_eq(@internal.ascii("abc"), b"abc")
  assert_eq(@internal.text_of(b"abc"[:]), "abc")
}

///|
test "the packer groups the way each encoding's padding says" {
  let digits = "01".to_array()
  assert_eq(@internal.pack(b"\xff"[:], 1, digits, false), "11111111")
  assert_eq(@internal.pack(b"\x00"[:], 1, digits, false), "00000000")
  let table = @internal.lookup_of("01")
  assert_eq(@internal.unpack("11111111", 1, table, false), b"\xff")
}

///|
/// The kernel is what the five faces sit on, so its error indices have to be
/// the ones the faces promise.
test "the packer's failures name the character that broke it" {
  let table = @internal.lookup_of("0123456789abcdef")
  try @internal.unpack("deadbeef!", 4, table, false) catch {
    failure => assert_eq(failure, @moonbase.Bad(at=8, char='!'))
  } noraise {
    _ => fail("expected the mark to be rejected")
  }
}

///|
test "one nibble too many is a truncation, one too few is not" {
  let table = @internal.lookup_of("0123456789abcdef")
  assert_eq(@internal.unpack("abcd", 4, table, false), b"\xab\xcd")
  try @internal.unpack("abcde", 4, table, false) catch {
    failure => assert_eq(failure, @moonbase.Truncated(at=5))
  } noraise {
    _ => fail("expected the odd nibble to be rejected")
  }
}

///|
/// FIPS 180-4's own two examples, and the 56-byte one that crosses the block
/// boundary and so exercises the padding twice.
test "SHA-256 matches the FIPS 180-4 examples" {
  assert_eq(
    @internal.sha256(b""[:]),
    b"\xe3\xb0\xc4\x42\x98\xfc\x1c\x14\x9a\xfb\xf4\xc8\x99\x6f\xb9\x24\x27\xae\x41\xe4\x64\x9b\x93\x4c\xa4\x95\x99\x1b\x78\x52\xb8\x55",
  )
  assert_eq(
    @internal.sha256(b"abc"[:]),
    b"\xba\x78\x16\xbf\x8f\x01\xcf\xea\x41\x41\x40\xde\x5d\xae\x22\x23\xb0\x03\x61\xa3\x96\x17\x7a\x9c\xb4\x10\xff\x61\xf2\x00\x15\xad",
  )
  assert_eq(
    @internal.sha256(
      b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"[:],
    ),
    b"\x24\x8d\x6a\x61\xd2\x06\x38\xb8\xe5\xc0\x26\x93\x0c\x3e\x60\x39\xa3\x3c\xe4\x59\x64\xff\x21\x67\xf6\xec\xed\xd4\x19\xdb\x06\xc1",
  )
}
