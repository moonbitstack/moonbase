// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Parse a hex string into bytes so the test cases can quote the canonical
/// Bitcoin vectors verbatim.
fn hex(s : String) -> Bytes {
  let cs = s.to_array()
  let out : Array[Byte] = Array::new()
  let mut i = 0
  while i < cs.length() {
    out.push((hex_val(cs[i]) * 16 + hex_val(cs[i + 1])).to_byte())
    i = i + 2
  }
  Bytes::from_array(out)
}

///|
fn hex_val(c : Char) -> Int {
  let x = c.to_int()
  if x >= '0'.to_int() && x <= '9'.to_int() {
    x - '0'.to_int()
  } else if x >= 'a'.to_int() && x <= 'f'.to_int() {
    x - 'a'.to_int() + 10
  } else {
    x - 'A'.to_int() + 10
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
    assert_eq(@base58.encode(raw), want)
    assert_eq(@base58.decode(want), Some(raw))
  }
}

///|
test "base58 rejects characters outside the alphabet" {
  // 0, O, I and l are deliberately absent from base58.
  assert_eq(@base58.decode("0"), None)
  assert_eq(@base58.decode("O"), None)
  assert_eq(@base58.decode("abcI"), None)
}
