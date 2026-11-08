// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A deterministic run of bytes: every value once, then a pseudo-random tail, so
/// the probe covers both the wide lanes and the leftovers the scalar tail sees.
fn probe(n : Int32) -> Bytes {
  let out = Array::make(n, b'\x00')
  let mut state = 123456789U
  for i in 0..<n {
    state = state * 1103515245U + 12345U
    out[i] = (i % 251).to_byte() ^ (state >> 16).reinterpret_as_int().to_byte()
  }
  Bytes::from_array(out)
}

///|
/// The alphabet a package would hand the packer, as a list of characters.
fn alphabet(text : String) -> Array[Char] {
  let out : Array[Char] = []
  for c in text {
    out.push(c)
  }
  out
}

///|
let widths : Array[Int32] = [1, 3, 4, 5, 6]

///|
/// Every alphabet the library actually uses: one run, two runs, five (base64's
/// `+` and `/` are not neighbours), and one with holes that the vector path is
/// expected to refuse.
let alphabets : Array[Array[Char]] = [
  alphabet("01"),
  alphabet("01234567"),
  alphabet("0123456789abcdef"),
  alphabet("0123456789ABCDEF"),
  alphabet("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"),
  alphabet("0123456789ABCDEFGHIJKLMNOPQRSTUV"),
  alphabet("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"),
  alphabet("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"),
  alphabet("0123456789ABCDEFGHJKMNPQRSTVWXYZ"),
]

///|
test "the vector path and the scalar one write the same characters" {
  for bits in widths {
    for digits in alphabets {
      if digits.length() != 1 << bits {
        continue
      }
      for
        n in [
          0, 1, 2, 3, 15, 16, 17, 31, 32, 33, 47, 48, 63, 64, 65, 127, 128, 1000,
        ] {
        let input = probe(n)
        for pad in [true, false] {
          let fast = @internal.pack(input[:], bits, digits, pad)
          let slow = @internal.pack_scalar(input[:], bits, digits, pad)
          assert_eq(fast, slow)
        }
      }
    }
  }
}

///|
test "a block boundary never changes a character" {
  // Sixteen characters of six bits are twelve bytes, so lengths either side of
  // that are where a gather that reads past the block would show up.
  let digits = alphabets[6]
  for n in [11, 12, 13, 23, 24, 25, 35, 36, 37] {
    let input = probe(n)
    assert_eq(
      @internal.pack(input[:], 6, digits, true),
      @internal.pack_scalar(input[:], 6, digits, true),
    )
    assert_eq(
      @internal.pack(input[:], 6, digits, false),
      @internal.pack_scalar(input[:], 6, digits, false),
    )
  }
}
