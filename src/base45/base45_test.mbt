// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// RFC 9285 §4.3 and §4.4, the four worked examples, verbatim. The middle one
/// is the interesting one: its encoding contains a space, because space is a
/// digit in this alphabet.
test "base45 matches the RFC 9285 examples" {
  let cases = [
    ("AB", "BB8"),
    ("Hello!!", "%69 VD92EX0"),
    ("base-45", "UJCLQE7W581"),
  ]
  for c in cases {
    let (text, encoded) = c
    let raw = @internal.ascii(text)
    assert_eq(@base45.encode(raw[:]), encoded)
    assert_eq(@base45.decode(encoded), raw)
  }
  // §4.4 decodes in the other direction, from a string to `ietf!`.
  assert_eq(@base45.decode("QED8WEX0"), @internal.ascii("ietf!"))
}

///|
/// The two shapes a group can have: two bytes are three characters, one byte is
/// two. There is no padding character, so the length alone says which.
test "an odd trailing byte is two characters, not three" {
  assert_eq(@base45.encode(b"A"[:]), "K1")
  assert_eq(@base45.decode("K1"), b"A")
  assert_eq(@base45.encode(b"AB"[:]), "BB8")
  assert_eq(@base45.encode(b"ABC"[:]), "BB8M1")
  assert_eq(@base45.decode("BB8M1"), b"ABC")
}

///|
/// RFC 9285 §6 names the case: `GGW` is 65536, which does not fit in the two
/// bytes a three-character group claims, and a decoder MUST reject it rather
/// than silently wrap.
test "a triplet past 65535 is rejected" {
  assert_eq(@base45.decode("FGW"), b"\xff\xff")
  try @base45.decode("GGW") catch {
    failure => assert_eq(failure, Bad(at=0, char='G'))
  } noraise {
    _ => fail("expected a triplet over 65535 to be rejected")
  }
}

///|
test "a length that ends mid-group, or a bad character, is named where it is" {
  try @base45.decode("BB8B") catch {
    failure => assert_eq(failure, Truncated(at=3))
  } noraise {
    _ => fail("expected one leftover character to be rejected")
  }
  try @base45.decode("BB8b0") catch {
    failure => assert_eq(failure, Bad(at=3, char='b'))
  } noraise {
    _ => fail("expected a lowercase letter to be rejected")
  }
  // A two-character group that overflows its single byte: 45 * 5 + 45 = 270.
  try @base45.decode("::") catch {
    failure => assert_eq(failure, Bad(at=0, char=':'))
  } noraise {
    _ => fail("expected a two-character group over 255 to be rejected")
  }
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base45.decode(@base45.encode(raw[:])), raw)
}

///|
test "the lossy face skips the line break a pasted QR payload picks up" {
  assert_eq(@base45.decode_lossy("%69 VD92EX0\r\n"), @internal.ascii("Hello!!"))
  assert_eq(@base45.decode_lossy("%69_VD92EX0"), b"")
}

///|
/// Feeding a payload in two pieces must give the same string as feeding it in
/// one, including when the split lands between the two bytes of a group.
test "the streaming faces agree with the one-shot ones" {
  let payloads = [
    b""[:],
    b"A"[:],
    b"AB"[:],
    b"Hello!!"[:],
    b"base-45"[:],
    b"\xff\xff\xff"[:],
  ]
  for payload in payloads {
    let want = @base45.encode(payload)
    for cut in 0..<(payload.length() + 1) {
      let sink = @base45.sink()
      sink.write(payload[:cut])
      sink.write(payload[cut:])
      assert_eq(sink.finish(), want)
    }
    // And the same for every one-character split of the text.
    for cut in 0..<(want.length() + 1) {
      let source = @base45.source()
      try source.write(want[:cut]) catch {
        _ => fail("the first half should never fail on valid text")
      } noraise {
        _ => ()
      }
      let tail = try {
        source.write(want[cut:])
        source.finish()
      } catch {
        _ => fail("the second half should never fail on valid text")
      } noraise {
        bytes => bytes
      }
      assert_eq(tail, payload.to_owned())
    }
  }
}

///|
test "a failure in the second chunk names an index in the whole input" {
  let source = @base45.source()
  try source.write("%69 ") catch {
    _ => fail("the first chunk is valid")
  } noraise {
    _ => ()
  }
  try source.write("VD92EX0b") catch {
    failure => assert_eq(failure, Bad(at=11, char='b'))
  } noraise {
    _ => fail("expected the bad character to be named")
  }
}

///|
test "a drained sink keeps its half-finished group" {
  let sink = @base45.sink()
  sink.write(b"AB"[:])
  assert_eq(sink.drain(), "BB8")
  sink.write(b"C"[:])
  assert_eq(sink.finish(), "M1")
}
