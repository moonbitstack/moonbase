// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// multibase's fixtures for `base10` — the `9` in front of each is the multibase
/// prefix, not a digit. A leading zero byte is a leading `0`, which is the one
/// thing a decimal spelling of a big integer can keep.
test "base10 matches the multibase fixtures" {
  let cases = [
    ("yes mani !", "573277761329450583662625"),
    ("\u{0}yes mani !", "0573277761329450583662625"),
    ("\u{0}\u{0}yes mani !", "00573277761329450583662625"),
    ("", ""),
  ]
  for case in cases {
    let (text, encoded) = case
    assert_eq(@base10.encode(@internal.ascii(text)[:]), encoded)
    assert_eq(@base10.decode(encoded), @internal.ascii(text))
  }
}

///|
test "every byte value survives the round trip" {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push(i.to_byte())
  }
  let raw = Bytes::from_array(all)
  assert_eq(@base10.decode(@base10.encode(raw[:])), raw)
}

///|
test "the integer faces ignore the leading-zero rule" {
  assert_eq(@base10.encode_int(0), "0")
  assert_eq(@base10.encode_int(123456789), "123456789")
  assert_eq(@base10.decode_int("123456789"), 123456789)
}

///|
/// A number wider than a `UInt64` — the reason the big faces exist. 2^80 is
/// 1208925819614629174706176.
test "the big faces go past sixty-four bits" {
  let wide = "1208925819614629174706176"
  assert_eq(@base10.encode_big(@base10.decode_big(wide)), wide)
  assert_eq(@base10.encode_big(@base10.decode_big("0")), "0")
  assert_eq(@base10.encode(@base10.decode_big(wide).to_octets()), wide)
}

///|
test "a character outside the digits says which one and where" {
  try @base10.decode("129a") catch {
    failure => assert_eq(failure, @moonbase.Bad(at=3, char='a'))
  } noraise {
    _ => fail("expected the letter to be rejected")
  }
}
