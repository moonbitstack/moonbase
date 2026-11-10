// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The decoder reads a six-bit alphabet sixteen characters at a time. The tests here
// compare it with the character loop it falls back to, at the lengths and the
// positions where the two could disagree.

///|
/// The character at `index`, replaced by `bad`.
fn with_char(text : String, index : Int32, bad : Char) -> String {
  let out = StringBuilder()
  let mut at = 0
  for c in text {
    out.write_char(if at == index { bad } else { c })
    at = at + 1
  }
  out.to_string()
}

///|
/// The index the decoder blamed, or -1 when it accepted the text, or -2 when it
/// failed for another reason.
fn blamed(text : String, lookup : Array[Int32], wide : Bool) -> Int32 {
  try {
    if wide {
      ignore(@internal.unpack(text[:], 6, lookup, false))
    } else {
      ignore(@internal.unpack_scalar(text[:], 6, lookup, false))
    }
    -1
  } catch {
    @moonbase.Bad(at~, char~) => {
      ignore(char)
      at
    }
    @moonbase.Padding(at~) => at
    _ => -2
  }
}

///|
/// A round of bytes that is exactly `characters` characters long once encoded
/// without padding.
fn round_of(characters : Int32) -> Bytes {
  probe(characters * 6 / 8)
}

///|
/// The two six-bit alphabets the library ships, as a package would hand them on.
let six_bit_alphabets : Array[String] = [
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
]

///|
/// The wide decoder and the character loop must agree byte for byte, and both
/// must agree with the input the text was made from. 128 characters is where the
/// wide path starts and sixteen is its window, so the lengths here straddle both.
test "the wide decoder agrees with the character loop" {
  let lengths : Array[Int32] = [
    96, 120, 126, 127, 128, 129, 130, 143, 144, 145, 191, 192, 193, 255, 256, 257,
    767, 768, 769,
  ]
  for text in six_bit_alphabets {
    let digits = alphabet(text)
    let lookup = @internal.lookup_of(text)
    for n in lengths {
      let input = probe(n)
      for pad in [true, false] {
        let encoded = @internal.pack(input[:], 6, digits, pad)
        assert_eq(@internal.unpack(encoded[:], 6, lookup, false), input)
        assert_eq(
          @internal.unpack(encoded[:], 6, lookup, false),
          @internal.unpack_scalar(encoded[:], 6, lookup, false),
        )
      }
    }
  }
}

///|
/// A spelling that quietly stops qualifying still decodes correctly — it only
/// gets slower, which no other test would notice. This is the decode side of
/// "every shipped alphabet takes the vector path".
test "the wide decoder takes every window a six-bit alphabet allows" {
  for text in six_bit_alphabets {
    let digits = alphabet(text)
    let lookup = @internal.lookup_of(text)
    // 1024 characters of a six-bit alphabet: 768 bytes, no padding at the end.
    let encoded = @internal.pack(round_of(1024)[:], 6, digits, false)
    let out = FixedArray::make(1024 * 6 / 8 + 4, b'\x00')
    let (consumed, written) = @internal.unpack_ascii(encoded[:], lookup, out)
    let expected = if has_vector_path() { 1024 } else { 0 }
    assert_eq(consumed, expected)
    assert_eq(written, expected * 6 / 8)
  }
  // An alphabet that reads either case has two spellings of every value, and one
  // that skips letters has holes in a class: neither is taken.
  for text in ["0123456789abcdefABCDEF", "0123456789ABCDEFGHJKMNPQRSTVWXYZ"] {
    let lookup = @internal.lookup_of(text)
    let out = FixedArray::make(1024, b'\x00')
    let (consumed, _) = @internal.unpack_ascii(
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"[:],
      lookup,
      out,
    )
    assert_eq(consumed, 0)
  }
}

///|
/// Whether a character of the wide decoder's window is refused, the position it is
/// refused at must be the one the character loop names — the wide path stops at
/// the window it could not take, and the loop picks up from there.
test "a character outside the alphabet is blamed at its own index" {
  for text in six_bit_alphabets {
    let digits = alphabet(text)
    let lookup = @internal.lookup_of(text)
    let encoded = @internal.pack(round_of(1024)[:], 6, digits, false)
    // The first and last character of the first windows, both sides of a window
    // boundary, somewhere in the middle, and the far end.
    for index in [0, 15, 16, 17, 31, 32, 63, 400, 1007, 1008, 1023] {
      let broken = with_char(encoded, index, '*')
      assert_eq(blamed(broken, lookup, true), index)
      assert_eq(blamed(broken, lookup, false), index)
    }
    // A character that is not ASCII at all narrows to 255 and must be refused
    // just as precisely.
    for index in [0, 16, 400, 1023] {
      let broken = with_char(encoded, index, '密')
      assert_eq(blamed(broken, lookup, true), index)
      assert_eq(blamed(broken, lookup, false), index)
    }
  }
}

///|
/// Padding is not a character of the alphabet, so the wide path stops before the
/// group that holds it and the character loop decides the rest — including where
/// a `=` that arrives too early is blamed.
test "padding stops the wide path and keeps the rules" {
  let text = six_bit_alphabets[0]
  let digits = alphabet(text)
  let lookup = @internal.lookup_of(text)
  // 1023 characters: three bytes short of a whole window, so the last group is
  // the two characters and the `=` that a one-byte input leaves.
  for bytes in [767, 768, 769] {
    let input = probe(bytes)
    let encoded = @internal.pack(input[:], 6, digits, true)
    assert_eq(@internal.unpack(encoded[:], 6, lookup, false), input)
    assert_eq(
      @internal.unpack(encoded[:], 6, lookup, false),
      @internal.unpack_scalar(encoded[:], 6, lookup, false),
    )
  }
  // A `=` in the middle is refused at the character after it, in both paths.
  let encoded = @internal.pack(round_of(1024)[:], 6, digits, false)
  for index in [16, 400, 1008] {
    let broken = with_char(encoded, index, '=')
    let wide = try {
      ignore(@internal.unpack(broken[:], 6, lookup, false))
      -1
    } catch {
      @moonbase.Padding(at~) => at
      _ => -2
    }
    assert_eq(wide, index + 1)
    assert_eq(blamed(broken, lookup, false), index + 1)
  }
}

///|
/// `decode_any` reads either spelling, which makes its lookup table two
/// characters to a value; there is no single spelling to name a value by, so the
/// character loop keeps it. It must still read what the wide path reads.
test "an alphabet with two spellings keeps the character loop" {
  let text = six_bit_alphabets[0]
  let digits = alphabet(text)
  let lookup = @internal.lookup_of_both(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
  )
  let input = probe(768)
  let mixed = @internal.pack(input[:], 6, digits, false)
  // The URL spelling of the same bytes reads the same through either alphabet.
  let url = @internal.pack(input[:], 6, alphabet(six_bit_alphabets[1]), false)
  assert_eq(@internal.unpack(mixed[:], 6, lookup, false), input)
  assert_eq(@internal.unpack(url[:], 6, lookup, false), input)
  let out = FixedArray::make(1024 * 6 / 8 + 4, b'\x00')
  let (consumed, _) = @internal.unpack_ascii(mixed[:], lookup, out)
  assert_eq(consumed, 0)
}
