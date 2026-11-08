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

///|
/// Whether a vector path exists to take. It exists for one backend only, which
/// is why the test asks rather than assumes.
#cfg(target="wasm")
fn has_vector_path() -> Bool {
  true
}

///|
#cfg(not(target="wasm"))
fn has_vector_path() -> Bool {
  false
}

///|
/// Every alphabet the library ships, and the run structure each one has. The
/// shape a spelling takes decides how cheaply it is named, and a spelling that
/// quietly stops qualifying would still encode correctly — it would only get
/// slower, which no other test here would notice.
test "every shipped alphabet takes the vector path" {
  let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  let cases : Array[(String, Int32, String)] = [
    ("base2", 1, "01"),
    ("base8", 3, "01234567"),
    ("base16 lower", 4, "0123456789abcdef"),
    ("base16 upper", 4, "0123456789ABCDEF"),
    ("base32 standard", 5, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"),
    ("base32 hexadecimal", 5, "0123456789ABCDEFGHIJKLMNOPQRSTUV"),
    ("base32 Crockford", 5, "0123456789ABCDEFGHJKMNPQRSTVWXYZ"),
    ("base32 z-base-32", 5, "ybndrfg8ejkmcpqxot1uwisza345h769"),
    ("base64 standard", 6, letters + "+/"),
    ("base64 url", 6, letters + "-_"),
  ]
  let input = probe(4096)
  for entry in cases {
    let (name, bits, text) = entry
    let digits = alphabet(text)
    let fast = @internal.pack_ascii(input[:], bits, digits, true)
    let scalar = @internal.pack_scalar(input[:], bits, digits, true)
    // z-base-32 has twenty-seven runs, none of them in a tail a sixteen-entry
    // table could address, so it is the one spelling with no vector path.
    let expected = has_vector_path() && name != "base32 z-base-32"
    match fast {
      Some(encoded) => {
        assert_true(expected)
        assert_eq(encoded, scalar)
      }
      None => assert_false(expected)
    }
  }
}
