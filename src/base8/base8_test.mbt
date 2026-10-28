// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// multibase's fixtures for `base8`, whose `7` prefix is not an octal digit. Ten
/// bytes are 27 characters, not 26⅔: the last group is shifted up and
/// zero-filled, and there is no padding character in this encoding at all.
test "base8 matches the multibase fixtures" {
  let cases = [
    ("yes mani !", "362625631006654133464440102"),
    ("\u{0}yes mani !", "000745453462015530267151100204"),
    ("\u{0}\u{0}yes mani !", "00000171312714403326055632220041"),
    ("", ""),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = @internal.ascii(text)
    assert_eq(@base8.encode(raw[:]), encoded)
    assert_eq(@base8.decode(encoded), raw)
  }
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base8.decode(@base8.encode(raw[:])), raw)
}

///|
test "three bytes are eight characters" {
  assert_eq(@base8.encode(b"\x00\x00\x00"[:]), "00000000")
  assert_eq(@base8.encode(b"\x00"[:]), "000")
  assert_eq(@base8.decode("000"), b"\x00")
  assert_eq(@base8.decode("00000000"), b"\x00\x00\x00")
}

///|
test "a length that cannot be whole bytes is a truncation" {
  try @base8.decode("0000") catch {
    failure => assert_eq(failure, @moonbase.Truncated(at=4))
  } noraise {
    _ => fail("expected four octal digits to be rejected")
  }
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base8.decode_lossy("000 000"), b"\x00\x00")
  assert_eq(@base8.decode_lossy("00000009"), b"")
}

///|
/// Three bits a character, so up to two bits wait between chunks, and eight
/// characters are three bytes — a split at an offset that is not a multiple of
/// eight is the case that matters.
test "the streaming faces agree with the one-shot ones at any split" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  let want = @base8.encode(raw[:])
  for cut in [0, 1, 2, 3, 7, 129, 255, 256] {
    let sink = @base8.sink()
    sink.write(raw[:cut])
    sink.write(raw[cut:])
    assert_eq(sink.finish(), want)
    let source = @base8.source()
    try source.write(want[:cut]) catch {
      _ => fail("a split inside valid octal should never fail")
    } noraise {
      _ => ()
    }
    let tail = try {
      source.write(want[cut:])
      source.finish()
    } catch {
      _ => fail("a split inside valid octal should never fail")
    } noraise {
      bytes => bytes
    }
    assert_eq(tail, raw)
  }
}

///|
test "a hand-written sink and source round trip a fixed payload" {
  let sink = @base8.sink()
  sink.write(b"\x00\xff"[:])
  sink.write(b"\x01"[:])
  assert_eq(sink.finish(), @base8.encode(b"\x00\xff\x01"[:]))
  let text = @base8.encode(b"\x00\xff\x01"[:])
  let source = @base8.source()
  // Three characters are nine bits: one byte and one bit left over.
  try source.write(text[:3]) catch {
    _ => fail("a partial group is legal")
  } noraise {
    _ => ()
  }
  try source.write(text[3:]) catch {
    _ => fail("the whole string is valid")
  } noraise {
    _ => ()
  }
  assert_eq(source.finish(), b"\x00\xff\x01")
}
