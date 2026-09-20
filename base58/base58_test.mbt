// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Parse a hex string into bytes so the test cases can quote the canonical
/// Bitcoin vectors verbatim.
fn hex(s : String) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  while i + 1 < s.length() {
    out.push((digit(s[i].to_int()) * 16 + digit(s[i + 1].to_int())).to_byte())
    i = i + 2
  }
  Bytes::from_array(out)
}

///|
fn digit(code : Int) -> Int {
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 97 + 10
  } else {
    code - 65 + 10
  }
}

///|
/// The canonical vectors from Bitcoin Core's `base58_encode_decode.json`.
test "base58 canonical vectors round-trip" {
  let cases = [
    ("", ""),
    ("61", "2g"),
    ("626262", "a3gV"),
    ("636363", "aPEr"),
    ("73696d706c792061206c6f6e6720737472696e67", "2cFupjhnEsSn59qHXstmK2ffpLv2"),
    (
      "00eb15231dfceb60925886b67d065299925915aeb172c06647", "1NS17iag9jJgTHD1VXjvLCEnZuQ3rJDE9L",
    ),
    ("516b6fcd0f", "ABnLTmg"),
    ("bf4f89001e670274dd", "3SEo3LWLoPntC"),
    ("572e4794", "3EFU7m"),
    ("ecac89cad93923c02321", "EJDM8drfXA6uyA"),
    ("10c8511e", "Rt5zm"),
    ("00000000000000000000", "1111111111"),
  ]
  for c in cases {
    let (h, want) = c
    let raw = hex(h)
    assert_eq(@base58.encode(raw[:]), want)
    assert_eq(@base58.decode(want), raw)
  }
}

///|
test "base58 rejects characters outside the alphabet" {
  // 0, O, I and l are deliberately absent from base58.
  try @base58.decode("0") catch {
    _ => ()
  } noraise {
    _ => fail("expected the bad input to be rejected")
  }
  try @base58.decode("O") catch {
    _ => ()
  } noraise {
    _ => fail("expected the bad input to be rejected")
  }
  try @base58.decode("abcI") catch {
    _ => ()
  } noraise {
    _ => fail("expected the bad input to be rejected")
  }
}

///|
test "a character outside the alphabet says which one and where" {
  try @base58.decode("3EFU7m0") catch {
    failure => assert_eq(failure, Bad(at=6, char='0'))
  } noraise {
    _ => fail("expected the zero to be rejected")
  }
}

///|
test "leading zero bytes are leading ones, however many there are" {
  let data = b"\x00\x00\x00\x01"
  let text = @base58.encode(data[:])
  assert_eq(text, "1112")
  assert_eq(@base58.decode(text), data)
}

///|
test "the integer face has no leading-zero rule" {
  assert_eq(@base58.encode_int(0), "1")
  assert_eq(@base58.encode_int(57), "z")
  assert_eq(@base58.encode_int(58), "21")
  assert_eq(@base58.decode_int("21"), 58)
}

///|
test "the bytes faces agree with the string faces" {
  let raw = b"moonbase"
  let text = @base58.encode(raw[:])
  assert_eq(@base58.encode_bytes(raw[:]), @moonbase.ascii(text))
  assert_eq(@base58.decode_bytes(@moonbase.ascii(text)[:]), raw)
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base58.decode_lossy("2cFup jhnEs"), @base58.decode("2cFupjhnEs"))
}
