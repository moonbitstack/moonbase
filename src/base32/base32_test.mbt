// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn ascii(s : String) -> Bytes {
  @internal.ascii(s)
}

///|
/// The RFC 4648 §10 vectors for the ordinary alphabet.
test "base32 RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "MY======"),
    ("fo", "MZXQ===="),
    ("foo", "MZXW6==="),
    ("foob", "MZXW6YQ="),
    ("fooba", "MZXW6YTB"),
    ("foobar", "MZXW6YTBOI======"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base32.encode(raw[:]), encoded)
    assert_eq(@base32.decode(encoded), raw)
  }
}

///|
/// The RFC 4648 §10 vectors for the extended-hex alphabet.
test "base32hex RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "CO======"),
    ("fo", "CPNG===="),
    ("foo", "CPNMU==="),
    ("foob", "CPNMUOG="),
    ("fooba", "CPNMUOJ1"),
    ("foobar", "CPNMUOJ1E8======"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base32.encode(raw[:], kind=Hex), encoded)
    assert_eq(@base32.decode(encoded, kind=Hex), raw)
  }
}

///|
test "the extended-hex alphabet keeps byte order" {
  let low = @base32.encode(b"\x00\x00"[:], kind=Hex, padding=false)
  let high = @base32.encode(b"\xff\xff"[:], kind=Hex, padding=false)
  assert_true(low < high)
}

///|
test "encoding without padding leaves the tail off" {
  assert_eq(@base32.encode(ascii("f")[:], padding=false), "MY")
  assert_eq(@base32.encode(ascii("foobar")[:], padding=false), "MZXW6YTBOI")
}

///|
test "padding is optional on the way in, and either case decodes" {
  assert_eq(@base32.decode("MZXW6YTBOI"), ascii("foobar"))
  assert_eq(@base32.decode("mzxw6ytboi"), ascii("foobar"))
}

///|
test "a character outside the alphabet says which one and where" {
  try @base32.decode("MZ1W6===") catch {
    failure => assert_eq(failure, Bad(at=2, char='1'))
  } noraise {
    _ => fail("expected the one to be rejected")
  }
}

///|
test "a length that cannot be a whole number of bytes is truncated input" {
  try @base32.decode("MZX") catch {
    failure => assert_eq(failure, Truncated(at=3))
  } noraise {
    _ => fail("expected three characters to be rejected")
  }
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base32.decode_lossy("MZXW\n6YTB\nOI"), ascii("foobar"))
  assert_eq(@base32.decode_lossy("!!!!"), b"")
}

///|
test "the bytes faces agree with the string faces" {
  let raw = ascii("foobar")
  assert_eq(@base32.encode_bytes(raw[:]), ascii("MZXW6YTBOI======"))
  assert_eq(@base32.decode_bytes(ascii("MZXW6YTBOI")[:]), raw)
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base32.decode(@base32.encode(raw[:])), raw)
  assert_eq(@base32.decode(@base32.encode(raw[:], kind=Hex), kind=Hex), raw)
}

///|
/// Crockford's alphabet (https://www.crockford.com/base32.html) is the same five
/// bits with the ambiguous letters taken out, so the vectors below were produced
/// by the packing rule its specification gives.
test "crockford's alphabet packs the same five bits" {
  let cases = [
    ("", ""),
    ("f", "CR"),
    ("moonbase", "DNQPYVK2C5SPA"),
    ("yes mani !", "F5JQ683DC5Q6J811"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base32.encode(raw[:], kind=Crockford), encoded)
    assert_eq(@base32.decode(encoded, kind=Crockford), raw)
  }
  let zeros = b"\x00\x00\x01"
  assert_eq(@base32.encode(zeros[:], kind=Crockford), "00002")
  assert_eq(@base32.decode("00002", kind=Crockford), zeros)
}

///|
/// `O` for zero, `I` and `L` for one: the specification's aliases, so that a
/// string read off a screen and typed back in still decodes.
test "crockford's aliases read as the digits they look like" {
  assert_eq(@base32.decode("OOOO2", kind=Crockford), b"\x00\x00\x01")
  assert_eq(@base32.decode("II", kind=Crockford), b"\x08")
  assert_eq(@base32.decode("lL", kind=Crockford), b"\x08")
  assert_eq(
    @base32.decode("o0", kind=Crockford),
    @base32.decode("00", kind=Crockford),
  )
}

///|
/// Neither Crockford nor z-base-32 has a padding character, so asking for
/// padding must not append one.
test "crockford and z never pad" {
  assert_eq(@base32.encode(ascii("f")[:], kind=Crockford), "CR")
  assert_eq(@base32.encode(ascii("f")[:], kind=Z), "ca")
  assert_eq(@base32.encode(ascii("f")[:], kind=Std), "MY======")
}

///|
/// The z-base-32 vectors are multibase's own fixtures for `base32z`, which is
/// the reference implementation of the same alphabet.
test "z-base-32 matches the multibase fixtures" {
  let cases = [
    ("yes mani !", "xf1zgedpcfzg1ebb"),
    ("hello world", "pb1sa5dxrb5s6hucco"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base32.encode(raw[:], kind=Z), encoded)
    assert_eq(@base32.decode(encoded, kind=Z), raw)
  }
  assert_eq(@base32.encode(b"\x00\x00\x01"[:], kind=Z), "yyyyn")
}

///|
/// Every kind has to survive the bytes it cannot see, and every kind reads back
/// what it wrote.
test "all four alphabets round-trip every byte value" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  for kind in [@base32.Std, @base32.Hex, @base32.Crockford, @base32.Z] {
    assert_eq(@base32.decode(@base32.encode(raw[:], kind~), kind~), raw)
  }
}

///|
/// Five bits a character, so up to four bits wait between chunks. A split at an
/// offset that is not a multiple of five is the case that catches a decoder which
/// forgets the bits it could not use yet.
test "the streaming faces agree with the one-shot ones at any split" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  for kind in [@base32.Std, @base32.Hex, @base32.Crockford, @base32.Z] {
    let want = @base32.encode(raw[:], kind~, padding=false)
    for cut in [0, 1, 2, 3, 7, 131, 255, 256] {
      let sink = @base32.sink(kind~, padding=false)
      sink.write(raw[:cut])
      sink.write(raw[cut:])
      assert_eq(sink.finish(), want)
      let source = @base32.source(kind~)
      try source.write(want[:cut]) catch {
        _ => fail("a split inside valid base32 should never fail")
      } noraise {
        _ => ()
      }
      let tail = try {
        source.write(want[cut:])
        source.finish()
      } catch {
        _ => fail("a split inside valid base32 should never fail")
      } noraise {
        bytes => bytes
      }
      assert_eq(tail, raw)
    }
  }
}
