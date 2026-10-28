// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

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
    let raw = @base16.decode_lossy(h)
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
  assert_eq(@base58.encode_bytes(raw[:]), @internal.ascii(text))
  assert_eq(@base58.decode_bytes(@internal.ascii(text)[:]), raw)
}

///|
test "the lossy face skips what the strict one refuses" {
  assert_eq(@base58.decode_lossy("2cFup jhnEs"), @base58.decode("2cFupjhnEs"))
}

///|
/// The Flickr and Ripple alphabets, from multibase's fixtures (`base58flickr`
/// is the `Z` prefix) and from ripple-lib's own encoder for the Ripple one.
test "the other two alphabets spell the same bytes differently" {
  let flickr = [
    ("yes mani !", "7Pznk19XTTzBtx"),
    ("hello world", "rTu1dk6cWsRYjYu"),
    ("moonbase", "jiEfkZ7oqAz"),
  ]
  for case in flickr {
    let (text, encoded) = case
    let raw = @internal.ascii(text)
    assert_eq(@base58.encode(raw[:], kind=Flickr), encoded)
    assert_eq(@base58.decode(encoded, kind=Flickr), raw)
  }
  let ripple = [("hello world", "StVrDLaUATiyKyV"), ("moonbase", "KJCELzfPRb2")]
  for case in ripple {
    let (text, encoded) = case
    let raw = @internal.ascii(text)
    assert_eq(@base58.encode(raw[:], kind=Ripple), encoded)
    assert_eq(@base58.decode(encoded, kind=Ripple), raw)
  }
  assert_eq(@base58.encode(b"\x00\x00\x01"[:], kind=Ripple), "rrp")
}

///|
test "a string from one alphabet is not a string from another" {
  let raw = @internal.ascii("moonbase")
  assert_eq(@base58.encode(raw[:], kind=Bitcoin), "KJfFLz7PRba")
  assert_eq(@base58.encode(raw[:], kind=Flickr), "jiEfkZ7oqAz")
  assert_eq(@base58.encode(raw[:], kind=Ripple), "KJCELzfPRb2")
  assert_true(
    @base58.decode("KJfFLz7PRba", kind=Flickr) !=
    @base58.decode("KJfFLz7PRba", kind=Bitcoin),
  )
}

///|
/// The address from the Bitcoin book's §4.4 example: a version byte and a
/// hash160, a SHA-256 trailer, base58.
test "base58check writes a bitcoin address" {
  let hash160 = @base16.decode_lossy(
    "00010966776006953D5567439E5E39F86A0D273BEE",
  )
  let address = @base58.encode_check(hash160[:])
  assert_eq(address, "16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvM")
  assert_eq(@base58.decode_check(address), hash160)
}

///|
test "base58check refuses a typo in the checksum" {
  // One character changed, still inside the alphabet: only the trailer can
  // catch this.
  try @base58.decode_check("16UwLL9Risc3QfPqBUvKofHmBQ7wMtjvN") catch {
    failure => assert_eq(failure, @moonbase.Checksum(at=21))
  } noraise {
    _ => fail("expected the tampered address to be rejected")
  }
}

///|
test "base58check needs four bytes before it can check anything" {
  try @base58.decode_check("2g") catch {
    failure => assert_eq(failure, @moonbase.Truncated(at=2))
  } noraise {
    _ => fail("expected the short input to be rejected")
  }
}
