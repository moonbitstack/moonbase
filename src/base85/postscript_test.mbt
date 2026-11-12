// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A PostScript stream is the shape this encoding actually arrives in: the
/// writer puts `<~` in front of the body, `~>` behind it, and breaks the lines
/// wherever they got long. Adobe's filter says the line breaks belong to the
/// writer, so a decoder reads through the markers and the blanks rather than
/// refusing a body that a real program wrote.
test "a postscript body is read with its markers and its line breaks" {
  assert_eq(@base85.decode("<~9jqo^~>"), b"Man ")
  assert_eq(@base85.decode("<~9jqo^\nARTY*~>"), b"Man easy")
  assert_eq(@base85.decode("<~9jqo^\r\n\tARTY*~>"), b"Man easy")
  assert_eq(@base85.decode("<~9jqo^ ARTY*~>"), b"Man easy")
  assert_eq(@base85.decode("<~~>"), b"")
  // The markers are a frame, not characters: an opening one with no closing one
  // is a body that stopped early, and the index is the end of the input.
  try @base85.decode("<~9jqo^~") catch {
    failure => assert_eq(failure, Truncated(at=8))
  } noraise {
    _ => fail("expected an unclosed marker to be a truncation")
  }
  // Without the opening marker `~>` is not a marker, it is a character outside
  // the alphabet, blamed where it stands.
  try @base85.decode("9jqo^~>") catch {
    failure => assert_eq(failure, Bad(at=5, char='~'))
  } noraise {
    _ => fail("expected a stray closing marker to be rejected")
  }
}

///|
/// The index a failure names counts the markers and the blanks the caller has, so
/// it can be used to point at the input that was handed in.
test "a failure inside a framed body is blamed at the caller's index" {
  try @base85.decode("<~9jz~>") catch {
    failure => assert_eq(failure, Bad(at=4, char='z'))
  } noraise {
    _ => fail("expected a z inside a group to be rejected")
  }
  // Five `u` digits carry more than four bytes can hold; the group starts at
  // index seven once the markers are counted.
  try @base85.decode("<~9jqo^uuuuu~>") catch {
    failure => assert_eq(failure, Bad(at=7, char='u'))
  } noraise {
    _ => fail("expected an overflowing group to be rejected")
  }
}

///|
/// `y` is the other abbreviation PostScript defines: thirty-two zero bytes, which
/// would otherwise be eight `z`s. Neither `z` nor `y` can stand inside a group,
/// because both stand for whole groups.
test "y is the thirty-two zero bytes postscript abbreviates" {
  assert_eq(@base85.decode("y"), Bytes::make(32, b'\x00'))
  assert_eq(@base85.decode("<~y~>"), Bytes::make(32, b'\x00'))
  assert_eq(@base85.decode("yy"), Bytes::make(64, b'\x00'))
  let want : Array[Byte] = []
  for byte in @internal.ascii("Man ") {
    want.push(byte)
  }
  for _ in 0..<32 {
    want.push(b'\x00')
  }
  assert_eq(@base85.decode("9jqo^y"), Bytes::from_array(want))
  try @base85.decode("9jy") catch {
    failure => assert_eq(failure, Bad(at=2, char='y'))
  } noraise {
    _ => fail("expected a y inside a group to be rejected")
  }
}

///|
/// Z85 has no abbreviations: `y` is a digit of its alphabet like any other, and
/// the whitespace that Ascii85 ignores is a character it does not hold.
test "z85 keeps y as a digit and takes no blanks" {
  assert_eq(@base85.decode("00000", kind=Z85), b"\x00\x00\x00\x00")
  assert_eq(@base85.encode(b"\x00\x00\x00\x01"[:], kind=Z85), "00001")
  // `y` is one of Z85's eighty-five digits, so it is worth a value here and
  // carries no abbreviation.
  assert_eq(@base85.decode("y0000", kind=Z85), b"\x69\xc9\x9f\x82")
  try @base85.decode("BOu! rDZ", kind=Z85) catch {
    failure => assert_eq(failure, Bad(at=4, char=' '))
  } noraise {
    _ => fail("expected a blank to be rejected by z85")
  }
}

///|
/// The lossy face reads the same bodies: a pasted stream loses its markers here
/// too, and a character that is not part of the encoding is dropped rather than
/// blamed.
test "the lossy face reads a framed body as well" {
  assert_eq(@base85.decode_lossy("<~9jqo^\nARTY*~>"), b"Man easy")
  assert_eq(@base85.decode_lossy("<~{9jqo^}~>"), b"Man ")
  assert_eq(@base85.decode_lossy("y"), Bytes::make(32, b'\x00'))
}

///|
/// A source reads the body, and the body is where the whitespace and the `y`
/// live; the markers are the one thing it refuses, because `~>` is only a marker
/// if the input ends there.
test "a source skips the blanks and reads y" {
  let source = @base85.source()
  source.write("9jqo^\n")
  source.write("ARTY*")
  assert_eq(source.finish(), b"Man easy")
  let zeros = @base85.source()
  zeros.write("y")
  assert_eq(zeros.finish(), Bytes::make(32, b'\x00'))
  // The group and the abbreviation may fall in different chunks: the source
  // keeps the group it has and reads the next character when it arrives.
  let split = @base85.source()
  split.write("9jqo")
  split.write("^")
  assert_eq(split.drain(), b"Man ")
  split.write("y")
  assert_eq(split.finish(), Bytes::make(32, b'\x00'))
  let inside = @base85.source()
  try inside.write("9jy") catch {
    failure => assert_eq(failure, Bad(at=2, char='y'))
  } noraise {
    _ => fail("expected a y inside a group to be rejected")
  }
}
