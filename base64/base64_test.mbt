// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
fn ascii(s : String) -> Bytes {
  @moonbase.ascii(s)
}

///|
fn bytes(values : Array[Int]) -> Bytes {
  let out : Array[Byte] = []
  for v in values {
    out.push(v.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// The RFC 4648 §10 vectors, which are the canonical padding cases.
test "base64 RFC 4648 vectors round-trip" {
  let cases = [
    ("", ""),
    ("f", "Zg=="),
    ("fo", "Zm8="),
    ("foo", "Zm9v"),
    ("foob", "Zm9vYg=="),
    ("fooba", "Zm9vYmE="),
    ("foobar", "Zm9vYmFy"),
  ]
  for case in cases {
    let (text, encoded) = case
    let raw = ascii(text)
    assert_eq(@base64.encode(raw[:]), encoded)
    assert_eq(@base64.decode(encoded), raw)
  }
}

///|
test "encoding without padding leaves the tail off" {
  assert_eq(@base64.encode(ascii("f")[:], padding=false), "Zg")
  assert_eq(@base64.encode(ascii("fo")[:], padding=false), "Zm8")
  assert_eq(@base64.encode(ascii("foo")[:], padding=false), "Zm9v")
}

///|
test "the two alphabets differ in exactly two characters" {
  let data = bytes([0xfb, 0xff, 0xbf])
  assert_eq(@base64.encode(data[:]), "+/+/")
  assert_eq(@base64.encode(data[:], kind=Url, padding=false), "-_-_")
  assert_eq(@base64.decode("+/+/"), data)
  assert_eq(@base64.decode("-_-_", kind=Url), data)
  assert_eq(@base64.encode(bytes([0xff])[:]), "/w==")
  assert_eq(@base64.encode(bytes([0xff])[:], kind=Url, padding=false), "_w")
}

///|
test "input whose spelling is unknown decodes either way" {
  let data = bytes([0xfb, 0xff, 0xbf])
  assert_eq(@base64.decode_any("+/+/"), data)
  assert_eq(@base64.decode_any("-_-_"), data)
}

///|
test "padding is optional on the way in" {
  assert_eq(@base64.decode("Zm9vYg=="), ascii("foob"))
  assert_eq(@base64.decode("Zm9vYg"), ascii("foob"))
  assert_eq(@base64.decode("Zm9vYmE"), ascii("fooba"))
  assert_eq(@base64.decode("Zg=="), ascii("f"))
}

///|
test "a character outside the alphabet says which one and where" {
  try @base64.decode("Zm*vYg==") catch {
    failure => assert_eq(failure, Bad(at=2, char='*'))
  } noraise {
    _ => fail("expected the star to be rejected")
  }
}

///|
test "a length that cannot be a whole number of bytes is truncated input" {
  try @base64.decode("Zm9vY") catch {
    failure => assert_eq(failure, Truncated(at=5))
  } noraise {
    _ => fail("expected five characters to be rejected")
  }
}

///|
test "characters after the padding are a lie about the length" {
  try @base64.decode("Zg==Zg==") catch {
    failure => assert_eq(failure, Padding(at=4))
  } noraise {
    _ => fail("expected the second group to be rejected")
  }
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base64.decode_lossy("Zm9v\nYmFy\n"), ascii("foobar"))
  assert_eq(@base64.decode_lossy("Zm9v YmFy"), ascii("foobar"))
  assert_eq(@base64.decode_lossy("****"), b"")
}

///|
test "the bytes faces agree with the string faces" {
  let raw = ascii("foobar")
  assert_eq(@base64.encode_bytes(raw[:]), ascii("Zm9vYmFy"))
  assert_eq(@base64.decode_bytes(ascii("Zm9vYmFy")[:]), raw)
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base64.decode(@base64.encode(raw[:])), raw)
  assert_eq(@base64.decode(@base64.encode(raw[:], padding=false)), raw)
}
