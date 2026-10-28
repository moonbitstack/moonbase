// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The strings BIP 173 §"Test vectors" calls valid bech32.
///
/// They are checked at the five-bit layer, which is the layer the specification
/// defines: three of these seven are not a whole number of bytes, and a checksum
/// verifier has no business insisting that they be.
let bech32_valid : Array[String] = [
  "A12UEL5L", "a12uel5l", "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs",
  "abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw", "11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j",
  "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", "?1ezyfcl",
]

///|
/// The strings BIP 350 §"Test vectors for Bech32m" calls valid bech32m. No string
/// is valid under both codes, which is why this list doubles as invalid bech32.
let bech32m_valid : Array[String] = [
  "A1LQFN3A", "a1lqfn3a", "an83characterlonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11sg7hg6",
  "abcdef1l7aum6echk45nj3s0wdvt2fg8x9yrzpqzd3ryx", "11llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllludsr8",
  "split1checkupstagehandshakeupstreamerranterredcaperredlc445v", "?1v759aa",
]

///|
test "every string BIP 173 lists as valid bech32 checks out" {
  for text in bech32_valid {
    let parts = @bech32.decode_words(text, kind=@bech32.Bech32)
    // Re-encoding the words must give the string back, in lower case.
    assert_eq(
      @bech32.encode_words(parts.hrp, parts.words[:], kind=@bech32.Bech32),
      lower(text),
    )
  }
}

///|
test "every string BIP 350 lists as valid bech32m checks out" {
  for text in bech32m_valid {
    let parts = @bech32.decode_words(text, kind=@bech32.Bech32m)
    assert_eq(
      @bech32.encode_words(parts.hrp, parts.words[:], kind=@bech32.Bech32m),
      lower(text),
    )
  }
}

///|
/// BIP 350: "No string can be simultaneously valid Bech32 and Bech32m". Each
/// list is therefore the other's invalid set, and the failure is the checksum —
/// the two codes differ in one constant and nothing else.
test "each variant rejects the other's strings, at the checksum" {
  for text in bech32_valid {
    try @bech32.decode_words(text, kind=@bech32.Bech32m) catch {
      failure => assert_eq(failure, Checksum(at=separator(text) + 1))
    } noraise {
      _ => fail("a bech32 string must not decode as bech32m")
    }
  }
  for text in bech32m_valid {
    try @bech32.decode_words(text, kind=@bech32.Bech32) catch {
      failure => assert_eq(failure, Checksum(at=separator(text) + 1))
    } noraise {
      _ => fail("a bech32m string must not decode as bech32")
    }
  }
}

///|
/// BIP 173 §"The following string are not valid Bech32", with the reason each one
/// gives. The index in every failure is the one the specification's own reference
/// implementation would report.
test "BIP 173's invalid bech32 strings fail for the reason it gives" {
  let cases : Array[(String, @moonbase.Malformed)] = [
    ("\u{20}1nwldj5", Bad(at=0, char=' ')), // HRP character out of range
    ("\u{7f}1axkwrx", Bad(at=0, char='\u{7f}')), // HRP character out of range
    ("\u{80}1eym55h", Bad(at=0, char='\u{80}')), // HRP character out of range
    (
      "an84characterslonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1569pvx",
      Bad(at=90, char='x'),
    ), // overall max length exceeded
    ("pzry9x0s0muk", Truncated(at=12)), // no separator character
    ("1pzry9x0s0muk", Bad(at=0, char='1')), // empty HRP
    ("x1b4n0q5v", Bad(at=2, char='b')), // invalid data character
    ("li1dgmt3", Truncated(at=8)), // too short checksum
    ("de1lg7wt\u{ff}", Bad(at=8, char='\u{ff}')), // invalid character in checksum
    ("A1G7SGD8", Checksum(at=2)), // checksum over the upper-case HRP
    ("10a06t8", Bad(at=0, char='1')), // empty HRP
    ("1qzzfhee", Bad(at=0, char='1')), // empty HRP
  ]
  for case in cases {
    let (text, want) = case
    try @bech32.decode_words(text, kind=@bech32.Bech32) catch {
      failure => assert_eq(failure, want)
    } noraise {
      _ => fail("expected the string to be rejected")
    }
  }
}

///|
test "BIP 350's invalid bech32m strings fail for the reason it gives" {
  let cases : Array[(String, @moonbase.Malformed)] = [
    ("\u{20}1xj0phk", Bad(at=0, char=' ')),
    ("\u{7f}1g6xzxy", Bad(at=0, char='\u{7f}')),
    ("\u{80}1vctc34", Bad(at=0, char='\u{80}')),
    (
      "an84characterslonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11d6pts4",
      Bad(at=90, char='4'),
    ),
    ("qyrz8wqd2c9m", Truncated(at=12)),
    ("1qyrz8wqd2c9m", Bad(at=0, char='1')),
    ("y1b0jsk6g", Bad(at=2, char='b')),
    ("lt1igcx5c0", Bad(at=3, char='i')),
    ("in1muywd", Truncated(at=8)),
    ("mm1crxm3i", Bad(at=8, char='i')),
    ("au1s5cgom", Bad(at=7, char='o')),
    ("M1VUXWEZ", Checksum(at=2)),
    ("16plkw9", Bad(at=0, char='1')),
    ("1p2gdwpf", Bad(at=0, char='1')),
  ]
  for case in cases {
    let (text, want) = case
    try @bech32.decode_words(text, kind=@bech32.Bech32m) catch {
      failure => assert_eq(failure, want)
    } noraise {
      _ => fail("expected the string to be rejected")
    }
  }
}

///|
/// The case rule, which is the one part of BIP 173 a reader is most likely to get
/// wrong: a string is all lower case or all upper case, the checksum is computed
/// over the lower-case form, and a mixture is refused at the first character that
/// breaks it.
test "one case throughout, and the checksum over the lower-case form" {
  for text in bech32_valid {
    let upper = to_upper(text)
    let from_lower = @bech32.decode_words(text, kind=@bech32.Bech32)
    let from_upper = @bech32.decode_words(upper, kind=@bech32.Bech32)
    assert_eq(from_lower.hrp, from_upper.hrp)
    assert_eq(from_lower.words, from_upper.words)
    // Whatever case it came in, the encoder writes it back in lower case.
    assert_eq(
      @bech32.encode_words(from_upper.hrp, from_upper.words[:]),
      lower(text),
    )
  }
  // "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7" is BIP 173's
  // mixed-case vector; the offending character is the capital L.
  try
    @bech32.decode_words(
      "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7",
    )
  catch {
    failure => assert_eq(failure, Bad(at=58, char='L'))
  } noraise {
    _ => fail("expected a mixed-case string to be rejected")
  }
}

///|
/// BIP 173 and BIP 350 give the scriptPubKey each valid address stands for. The
/// witness version is a five-bit word of its own, so the address is checked the
/// way its own specification reads it: the first word is the version, the rest
/// are the program.
test "the valid segregated witness addresses give back their scripts" {
  let cases = [
    (
      "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4",
      @bech32.Bech32,
      0,
      "751e76e8199196d454941c45d1b3a323f1433bd6",
    ),
    (
      "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7",
      @bech32.Bech32,
      0,
      "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262",
    ),
    ("BC1SW50QGDZ25J", @bech32.Bech32m, 16, "751e"),
    (
      "bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs",
      @bech32.Bech32m,
      2,
      "751e76e8199196d454941c45d1b3a323",
    ),
    (
      "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y",
      @bech32.Bech32m,
      1,
      "751e76e8199196d454941c45d1b3a323f1433bd6751e76e8199196d454941c45d1b3a323f1433bd6",
    ),
    (
      "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0",
      @bech32.Bech32m,
      1,
      "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
    ),
    (
      "tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c",
      @bech32.Bech32m,
      1,
      "000000c4a5cad46221b2a187905e5266362b99d5e91c6ce24d165dab93e86433",
    ),
  ]
  for case in cases {
    let (address, kind, version, program) = case
    let parts = @bech32.decode_words(address, kind~)
    assert_eq(parts.words[0].to_int(), version)
    let bytes = @bech32.bytes_of(parts.words[1:])
    assert_eq(@base16.encode(bytes[:]), program)
    // And back the other way: version in front of the words of the program.
    let rebuilt = @bech32.encode_words(parts.hrp, parts.words, kind~)
    assert_eq(rebuilt, lower(address))
  }
}

///|
/// Two rules BIP 173 states that this layer does enforce, because they are
/// properties of the five-bit groups rather than of a witness program: the
/// padding that completes the last byte must be fewer than five bits and must be
/// zero. Without that, one program has four spellings.
test "the padding of the last group must be short and zero" {
  // BIP 173's "zero padding of more than 4 bits": the program is 33 groups,
  // which is 165 bits — five of them cannot become a byte and must not be left
  // over. The failure names the group the reader stopped at, which is counted
  // from the start of the data part, including the witness version.
  let words = @bech32.decode_words("bc1zw508d6qejxtdg4y5r3zarvaryvqyzf3du").words
  try @bech32.bytes_of(words[1:]) catch {
    failure => assert_eq(failure, Padding(at=27))
  } noraise {
    _ => fail("expected more than four bits of padding to be rejected")
  }
  // BIP 173's "non-zero padding in 8-to-5 conversion": the leftover bits are
  // fewer than five but not zero, which would give one program four spellings.
  let words = @bech32.decode_words(
      "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3pjxtptv",
    ).words
  try @bech32.bytes_of(words[1:]) catch {
    failure => assert_eq(failure, Padding(at=52))
  } noraise {
    _ => fail("expected non-zero padding to be rejected")
  }
}

///|
test "the byte faces round-trip, and agree with the word faces" {
  let payloads = [
    b""[:],
    b"\x00"[:],
    b"\xff"[:],
    b"moonbase"[:],
    b"\x00\x01\x02\x03\x04\x05\x06\x07"[:],
  ]
  for payload in payloads {
    for kind in [@bech32.Bech32, @bech32.Bech32m] {
      let text = @bech32.encode("moon", payload, kind~)
      assert_eq(text[:4], "moon")
      let back = @bech32.decode(text, kind~)
      assert_eq(back.hrp, "moon")
      assert_eq(back.data, payload.to_owned())
      // The five-bit layer must agree with the byte layer.
      let words = @bech32.decode_words(text, kind~)
      assert_eq(words.words, @bech32.words_of(payload))
      assert_eq(@bech32.bytes_of(words.words[:]), payload.to_owned())
    }
  }
  // An empty payload is a valid address with an empty data part: BIP 173's own
  // "a12uel5l" is one.
  assert_eq(@bech32.encode("a", b""[:]), "a12uel5l")
}

///|
/// The prefix rules: one to eighty-three printable characters, written back in
/// lower case, and a string no longer than ninety.
test "the prefix is checked and normalised" {
  assert_eq(@bech32.encode("BC", b"\x00"[:]), @bech32.encode("bc", b"\x00"[:]))
  // A prefix may contain a `1`; the separator is the last one.
  let text = @bech32.encode("a1b", b"\x07"[:])
  assert_eq(@bech32.decode(text).hrp, "a1b")
  try @bech32.encode("", b""[:]) catch {
    failure => assert_eq(failure, Truncated(at=0))
  } noraise {
    _ => fail("expected an empty prefix to be rejected")
  }
  try @bech32.encode("pad ", b""[:]) catch {
    failure => assert_eq(failure, Bad(at=3, char=' '))
  } noraise {
    _ => fail("expected a space in the prefix to be rejected")
  }
  // Eighty-three characters of prefix plus a separator and six of checksum is
  // exactly the ninety the checksum is designed for.
  let long = repeat("a", 83)
  assert_eq(@bech32.encode(long, b""[:]).length(), 90)
  try @bech32.encode(repeat("a", 84), b""[:]) catch {
    _ => ()
  } noraise {
    _ => fail("expected an eighty-four character prefix to be rejected")
  }
}

///|
test "the lossy face drops whitespace and says nothing else" {
  let text = @bech32.encode("bc", b"\x01\x02"[:])
  let wrapped = " " + text + "\r\n"
  assert_eq(@bech32.decode_lossy(wrapped).unwrap().data, b"\x01\x02")
  assert_eq(@bech32.decode_lossy("bc1notanaddress"), None)
}

///|
/// The index of the separator, counted from the left, for a string whose prefix
/// contains no `1`.
fn separator(text : StringView) -> Int32 {
  let mut last = 0
  for i in 0..<text.length() {
    if text[i].to_int() == 49 {
      last = i
    }
  }
  last
}

///|
fn repeat(text : String, times : Int32) -> String {
  let out = StringBuilder()
  for _ in 0..<times {
    out.write_string(text)
  }
  out.to_string()
}

///|
fn lower(text : StringView) -> String {
  let out = StringBuilder()
  for i in 0..<text.length() {
    let code = text[i].to_int()
    out.write_char(
      if code >= 65 && code <= 90 {
        (code + 32).unsafe_to_char()
      } else {
        text[i].unsafe_to_char()
      },
    )
  }
  out.to_string()
}

///|
fn to_upper(text : StringView) -> String {
  let out = StringBuilder()
  for i in 0..<text.length() {
    let code = text[i].to_int()
    out.write_char(
      if code >= 97 && code <= 122 {
        (code - 32).unsafe_to_char()
      } else {
        text[i].unsafe_to_char()
      },
    )
  }
  out.to_string()
}
