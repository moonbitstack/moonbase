// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// `B85` is RFC 1924's alphabet read the way a binary patch is written: four
/// bytes to five characters, no `z`, and a last group of `n` bytes spelled as
/// `n + 1` characters.
test "b85 matches the text a binary patch carries" {
  let cases = [
    ("", ""),
    ("a", "VE"),
    ("ab", "VPX"),
    ("abc", "VPaz"),
    ("abcd", "VPa!s"),
    ("hello", "Xk~0{Zv"),
    ("hello world", "Xk~0{Zy<MXa%^M"),
    ("moonbase", "ZEtUGVqtS-"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = @internal.ascii(text)
    assert_eq(@base85.encode(raw[:], kind=B85), encoded)
    assert_eq(@base85.decode(encoded, kind=B85), raw)
  }
}

///|
/// The alphabet is RFC 1924's, but the encoding is not the address one: a group
/// of four zero bytes is five zero digits here, and sixteen bytes are twenty
/// characters rather than one number.
test "b85 shares the rfc 1924 alphabet and not its arithmetic" {
  assert_eq(@base85.encode(b"\x00\x00\x00\x00"[:], kind=B85), "00000")
  assert_eq(@base85.decode("00000", kind=B85), b"\x00\x00\x00\x00")
  assert_eq(@base85.encode(b"\x00\x01\x02\x03"[:], kind=B85), "009C6")
  let address = @base16.decode("108000000000000000080800200c417a")
  assert_eq(@base85.encode(address[:], kind=B85).length(), 20)
  assert_eq(@base85.encode(address[:], kind=Ipv6), "4)+k&C#VzJ4br>0wv%Yp")
}

///|
/// A group is five characters, so a length that is not a multiple of five is
/// truncated input — except for the short last group, which is the whole reason
/// the encoding is usable on a payload whose length is not a multiple of four.
test "a short last group is read as the bytes it stands for" {
  assert_eq(@base85.decode("VE", kind=B85), b"a")
  assert_eq(@base85.decode("VPX", kind=B85), b"ab")
  assert_eq(@base85.decode("VPaz", kind=B85), b"abc")
  assert_eq(@base85.decode("VPa!s", kind=B85), b"abcd")
  // One character cannot stand for a group of zero bytes.
  try @base85.decode("V", kind=B85) catch {
    failure => assert_eq(failure, Truncated(at=0))
  } noraise {
    _ => fail("expected a lone character to be rejected")
  }
  try @base85.decode("VPa!sV", kind=B85) catch {
    failure => assert_eq(failure, Truncated(at=5))
  } noraise {
    _ => fail("expected a lone character after a group to be rejected")
  }
}

///|
test "every byte value survives the b85 round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base85.decode(@base85.encode(raw[:], kind=B85), kind=B85), raw)
}

///|
/// The streaming faces have to hold the same group boundary: a sink writes the
/// short group only when it is closed, and a source cannot decide the last group
/// before it is closed either.
test "the b85 streaming faces agree with the one-shot ones" {
  let payloads = [
    b""[:],
    b"a"[:],
    b"ab"[:],
    b"abc"[:],
    b"abcd"[:],
    b"moonbase"[:],
    b"\x00\x00\x00\x00\x00"[:],
  ]
  for payload in payloads {
    let want = @base85.encode(payload, kind=B85)
    for cut in 0..<(payload.length() + 1) {
      let sink = @base85.sink(kind=B85)
      sink.write(payload[:cut])
      sink.write(payload[cut:])
      assert_eq(sink.finish(), want)
    }
    for cut in 0..<(want.length() + 1) {
      let source = @base85.source(kind=B85)
      let tail = try {
        source.write(want[:cut])
        source.write(want[cut:])
        source.finish()
      } catch {
        _ => fail("a split inside a valid string should never fail")
      } noraise {
        bytes => bytes
      }
      assert_eq(tail, payload.to_owned())
    }
  }
}
