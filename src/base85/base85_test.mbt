// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The worked example every Ascii85 description opens with: `Man ` is one
/// four-byte group and comes out as five characters, and `easy` follows it.
test "ascii85 matches the text from every Ascii85 description" {
  let cases = [
    ("Man ", "9jqo^"),
    ("easy", "ARTY*"),
    ("sure", "F*2M7"),
    ("hello world", "BOu!rD]j7BEbo7"),
    ("moonbase", "D/X?1@UX=h"),
  ]
  for c in cases {
    let (text, encoded) = c
    let raw = @internal.ascii(text)
    assert_eq(@base85.encode(raw[:]), encoded)
    assert_eq(@base85.decode(encoded), raw)
  }
}

///|
/// Ascii85 collapses a whole group of zero bytes to `z`, which is the one place
/// the output is shorter than five characters a group.
test "a zero group is a single z" {
  assert_eq(@base85.encode(b"\x00\x00\x00\x00"[:]), "z")
  assert_eq(@base85.decode("z"), b"\x00\x00\x00\x00")
  assert_eq(@base85.encode(b"\x00\x00\x00\x00\x00x"[:]), "z!-e")
  assert_eq(@base85.decode("z!-e"), b"\x00\x00\x00\x00\x00x")
  // `z` only stands for a group of four, so it cannot appear inside one.
  try @base85.decode("9jz") catch {
    failure => assert_eq(failure, Bad(at=2, char='z'))
  } noraise {
    _ => fail("expected a z inside a group to be rejected")
  }
}

///|
/// ZeroMQ RFC 32's test case: the eight bytes of the Z85 key are `HelloWorld`.
test "z85 matches RFC 32's test case" {
  let key = b"\x86\x4f\xd2\x6f\xb5\x59\xf7\x5b"
  assert_eq(@base85.encode(key[:], kind=Z85), "HelloWorld")
  assert_eq(@base85.decode("HelloWorld", kind=Z85), key)
  assert_eq(@base85.encode(b"\x00\x00\x00\x00"[:], kind=Z85), "00000")
  assert_eq(@base85.encode(@internal.ascii("moon")[:], kind=Z85), "zeTug")
  assert_eq(@base85.decode("f!$Kw", kind=Z85), @internal.ascii("1234"))
}

///|
/// Z85 has no short group and no `z`: its frame is four bytes and nothing else
/// is defined, so a length that does not fill one cannot be written or read.
test "z85 refuses a length that is not four bytes" {
  try @base85.encode(@internal.ascii("moonbas")[:], kind=Z85) catch {
    failure => assert_eq(failure, Truncated(at=7))
  } noraise {
    _ => fail("expected a payload of eight bytes to be rejected")
  }
  try @base85.decode("HelloWorld1", kind=Z85) catch {
    failure => assert_eq(failure, Truncated(at=10))
  } noraise {
    _ => fail("expected eleven characters to be rejected")
  }
}

///|
/// RFC 1924 §5: the address `1080:0:0:0:8:800:200C:417A`, read as one 128-bit
/// number, in the alphabet that leaves out the characters a quote or a list
/// would eat.
test "the IPv6 spelling matches RFC 1924" {
  let address = b"\x10\x80\x00\x00\x00\x00\x00\x00\x00\x08\x08\x00\x20\x0c\x41\x7a"
  assert_eq(@base85.encode(address[:], kind=Ipv6), "4)+k&C#VzJ4br>0wv%Yp")
  assert_eq(@base85.decode("4)+k&C#VzJ4br>0wv%Yp", kind=Ipv6), address)
  // A number has no leading zeros, which is why the all-zero address is one
  // character and not twenty.
  assert_eq(@base85.encode(Bytes::make(16, b'\x00')[:], kind=Ipv6), "0")
  assert_eq(@base85.decode("0", kind=Ipv6), Bytes::make(16, b'\x00'))
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base85.decode(@base85.encode(raw[:])), raw)
  assert_eq(@base85.decode(@base85.encode(raw[:], kind=Z85), kind=Z85), raw)
}

///|
test "an address is sixteen bytes in and sixteen bytes out" {
  let cases = [
    "00000000000000000000000000000000", "00000000000000000000000000000001", "ffffffffffffffffffffffffffffffff",
    "20010db8000000000000000000000001",
  ]
  for h in cases {
    let raw = @base16.decode(h)
    assert_eq(@base85.decode(@base85.encode(raw[:], kind=Ipv6), kind=Ipv6), raw)
  }
  // A number has no leading zeros, so the shortest possible address is `0`.
  assert_eq(
    @base85.encode(
      @base16.decode("00000000000000000000000000000000")[:],
      kind=Ipv6,
    ),
    "0",
  )
  // Fifteen bytes is not an address, and neither is seventeen.
  try @base85.encode(Bytes::make(15, b'\x00')[:], kind=Ipv6) catch {
    failure => assert_eq(failure, Truncated(at=15))
  } noraise {
    _ => fail("expected a fifteen-byte payload to be rejected")
  }
  // Twenty digits of base85 is more than 128 bits.
  try @base85.decode("4)+k&C#VzJ4br>0wv%Yp!", kind=Ipv6) catch {
    _ => ()
  } noraise {
    _ => fail("expected a number over 128 bits to be rejected")
  }
}

///|
/// A short final group is `n + 1` characters for `n` bytes, and a decoder has
/// to fill the missing digits with the largest one — otherwise a group that
/// overflows its bytes would decode to a value that silently wrapped.
test "a short group decodes to one byte fewer than its length" {
  assert_eq(@base85.encode(b"a"[:]), "@/")
  assert_eq(@base85.decode("@/"), b"a")
  assert_eq(@base85.encode(b"ab"[:]), "@:B")
  assert_eq(@base85.decode("@:B"), b"ab")
  assert_eq(@base85.encode(b"abc"[:]), "@:E^")
  assert_eq(@base85.decode("@:E^"), b"abc")
  // Five digits is 85^5 values, more than four bytes can hold.
  try @base85.decode("uuuuu") catch {
    failure => assert_eq(failure, Bad(at=0, char='u'))
  } noraise {
    _ => fail("expected an overflowing group to be rejected")
  }
}

///|
test "the lossy face skips the line breaks a PostScript stream wraps with" {
  let wrapped = @internal.ascii("Man ")[:]
  assert_eq(@base85.decode_lossy("9jqo^\nARTY*"), b"Man easy")
  assert_eq(@base85.decode_lossy("9jqo^_ARTY*"), b"")
  assert_eq(@base85.encode(wrapped), "9jqo^")
}

///|
/// The streaming encoder must hold back the bytes of an unfinished group, so
/// that a chunk boundary falling inside one changes nothing.
test "the streaming faces agree with the one-shot ones" {
  let payloads = [
    b""[:],
    b"a"[:],
    b"ab"[:],
    b"abc"[:],
    b"Man "[:],
    b"hello world"[:],
    b"\x00\x00\x00\x00"[:],
    b"\x00\x00\x00\x00\x00"[:],
  ]
  for payload in payloads {
    let want = @base85.encode(payload)
    for cut in 0..<(payload.length() + 1) {
      let sink = @base85.sink()
      sink.write(payload[:cut])
      sink.write(payload[cut:])
      assert_eq(sink.finish(), want)
    }
    for cut in 0..<(want.length() + 1) {
      let source = @base85.source()
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

///|
/// Z85's streaming face refuses the same lengths its one-shot face does, and
/// only when it is closed — a partial group is legal until the input ends.
test "a z85 sink fails when it is closed on a partial group" {
  let sink = @base85.sink(kind=Z85)
  sink.write(b"moon"[:])
  assert_eq(sink.drain(), "zeTug")
  sink.write(b"ba"[:])
  try sink.finish() catch {
    failure => assert_eq(failure, Truncated(at=2))
  } noraise {
    _ => fail("expected two leftover bytes to be rejected")
  }
}
