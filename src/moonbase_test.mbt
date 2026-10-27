// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The kernel is a big-integer conversion, so value 15 is one digit `"f"` and
/// not the fixed-width `"0f"` a byte-wise hexadecimal would print.
test "a generic alphabet round-trips" {
  let hexa = @moonbase.Alphabet::of("0123456789abcdef")
  let data = b"\xde\xad\xbe\xef"
  assert_eq(@moonbase.encode(data[:], hexa), "deadbeef")
  assert_eq(@moonbase.decode("deadbeef", hexa), data)
  assert_eq(hexa.base(), 16)
}

///|
test "leading zero bytes become leading zero digits" {
  let hexa = @moonbase.Alphabet::of("0123456789abcdef")
  let data = b"\x00\x00\x0f"
  assert_eq(@moonbase.encode(data[:], hexa), "00f")
  assert_eq(@moonbase.decode("00f", hexa), data)
}

///|
test "an alphabet built at runtime reports why it is wrong" {
  try @moonbase.Alphabet::new("01201") catch {
    failure => assert_eq(failure, Repeated(at=3, char='0'))
  } noraise {
    _ => fail("expected the repeat to be rejected")
  }
  try @moonbase.Alphabet::new("0") catch {
    failure => assert_eq(failure, TooFew(count=1))
  } noraise {
    _ => fail("expected a single digit to be rejected")
  }
  try @moonbase.Alphabet::new("01\u{4e2d}") catch {
    failure => assert_eq(failure, NotAscii(at=2, char='\u{4e2d}'))
  } noraise {
    _ => fail("expected the non-ASCII character to be rejected")
  }
}

///|
test "an alphabet answers what it maps" {
  let a = @moonbase.Alphabet::of("xyz")
  assert_eq(a.char_of(0), 'x')
  assert_eq(a.value_of('z'), Some(2))
  assert_eq(a.value_of('q'), None)
}

///|
test "decoding says which character was wrong and where" {
  let a = @moonbase.Alphabet::of("0123456789abcdef")
  try @moonbase.decode("dead!beef", a) catch {
    failure => assert_eq(failure, Bad(at=4, char='!'))
  } noraise {
    _ => fail("expected the mark to be rejected")
  }
}

///|
test "the lossy face skips what the strict one refuses" {
  let a = @moonbase.Alphabet::of("0123456789abcdef")
  assert_eq(@moonbase.decode_lossy("de ad be ef", a), b"\xde\xad\xbe\xef")
}

///|
test "the integer faces ignore the leading-zero rule" {
  let a = @moonbase.Alphabet::of("0123456789abcdef")
  assert_eq(@moonbase.encode_int(0, a), "0")
  assert_eq(@moonbase.encode_int(255, a), "ff")
  assert_eq(@moonbase.decode_int("ff", a), 255)
}

///|
test "ASCII text and the bytes that spell it convert both ways" {
  assert_eq(@moonbase.ascii("abc"), b"abc")
  assert_eq(@moonbase.text_of(b"abc"[:]), "abc")
}

///|
test "the packer groups the way each encoding's padding says" {
  let digits = "01".to_array()
  assert_eq(@moonbase.pack(b"\xff"[:], 1, digits, false), "11111111")
  assert_eq(@moonbase.pack(b"\x00"[:], 1, digits, false), "00000000")
  let table = @moonbase.lookup_of("01")
  assert_eq(@moonbase.unpack("11111111", 1, table, false), b"\xff")
}
