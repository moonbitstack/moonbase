// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// multibase's fixtures for `base2` — the `0` in front is the multibase prefix,
/// not a bit. A bit string keeps a leading zero byte, because it is a packing
/// and not a number.
test "base2 matches the multibase fixtures" {
  let cases = [
    (
      "yes mani !", "01111001011001010111001100100000011011010110000101101110011010010010000000100001",
    ),
    (
      "\u{0}yes mani !", "0000000001111001011001010111001100100000011011010110000101101110011010010010000000100001",
    ),
    (
      "\u{0}\u{0}yes mani !", "000000000000000001111001011001010111001100100000011011010110000101101110011010010010000000100001",
    ),
    ("", ""),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = @internal.ascii(text)
    assert_eq(@base2.encode(raw[:]), encoded)
    assert_eq(@base2.decode(encoded), raw)
  }
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base2.decode(@base2.encode(raw[:])), raw)
}

///|
test "eight characters are one byte, and anything else is not" {
  try @base2.decode("101") catch {
    failure => assert_eq(failure, @moonbase.Truncated(at=3))
  } noraise {
    _ => fail("expected three bits to be rejected")
  }
  try @base2.decode("1011010x") catch {
    failure => assert_eq(failure, @moonbase.Bad(at=7, char='x'))
  } noraise {
    _ => fail("expected the letter to be rejected")
  }
}

///|
test "the bytes and lossy faces agree with the string one" {
  let raw = b"\xb5\x00"
  assert_eq(@base2.encode_bytes(raw[:]), @internal.ascii("1011010100000000"))
  assert_eq(@base2.decode_bytes(@internal.ascii("1011010100000000")[:]), raw)
  assert_eq(@base2.decode_lossy("1011 0101 0000 0000"), raw)
}

///|
/// One bit a character, so nothing ever waits between chunks — but a decoder that
/// forgets the bits it already has still fails a split, which is what this checks.
test "the streaming faces agree with the one-shot ones at any split" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  let want = @base2.encode(raw[:])
  for cut in [0, 1, 2, 3, 5, 127, 255, 256] {
    let sink = @base2.sink()
    sink.write(raw[:cut])
    sink.write(raw[cut:])
    assert_eq(sink.finish(), want)
    let source = @base2.source()
    try source.write(want[:cut]) catch {
      _ => fail("a split inside valid bits should never fail")
    } noraise {
      _ => ()
    }
    let tail = try {
      source.write(want[cut:])
      source.finish()
    } catch {
      _ => fail("a split inside valid bits should never fail")
    } noraise {
      bytes => bytes
    }
    assert_eq(tail, raw)
  }
}

///|
test "a streaming failure names the index in the whole input" {
  let source = @base2.source()
  try source.write("1010") catch {
    _ => fail("the first chunk is valid")
  } noraise {
    _ => ()
  }
  try source.write("01010x") catch {
    failure => assert_eq(failure, @moonbase.Bad(at=9, char='x'))
  } noraise {
    _ => fail("expected the x to be named at its own index")
  }
}
