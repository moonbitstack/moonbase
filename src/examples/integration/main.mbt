// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// multibase, and the packages it is assembled from.
///
/// The point of multibase is that a string carries the name of its own encoding,
/// so the reader does not have to be told. This example writes one payload every
/// way the table allows, then reads all of them back without being told which is
/// which.
fn main raise {
  let raw = b"\x00yes mani !"

  // The same bytes, twelve ways. The first character is the encoding; the rest
  // is that encoding's own output.
  let bases = [
    @multibase.Base2,
    @multibase.Base8,
    @multibase.Base10,
    @multibase.Base16,
    @multibase.Base32,
    @multibase.Base36,
    @multibase.Base45,
    @multibase.Base58Btc,
    @multibase.Base58Flickr,
    @multibase.Base64,
    @multibase.Base64Url,
  ]
  for base in bases {
    let text = @multibase.encode(raw[:], base~)
    println(pad(@multibase.name(base), 14) + text)
  }

  // Nothing above said which encoding it used, and nothing below says either:
  // the reader asks the string.
  println("")
  for base in bases {
    let text = @multibase.encode(raw[:], base~)
    let found = @multibase.detect(text).unwrap()
    let back = @multibase.decode(text)
    let ok = back == raw && found == base
    println(
      pad(@multibase.name(base), 14) +
      "reads back as " +
      @multibase.name(found) +
      " " +
      (if ok { "ok" } else { "WRONG" }),
    )
  }

  // The base256emoji entry is the one where a character is not a byte: one
  // character per byte value, and some of them are outside the basic plane.
  println("")
  println(@multibase.encode(b"hi!"[:], base=@multibase.Base256Emoji))

  // Underneath, the encodings are ordinary packages. base58check is what a
  // Bitcoin address is: the payload, then four bytes of double SHA-256, then the
  // whole thing in base58.
  println("")
  let key = @base16.decode("00010966776006953D5567439E5E39F86A0D273BEE")
  println(@base58.encode_check(key[:]))

  // bech32 puts the prefix inside the checksum, so a typo in the prefix is as
  // visible as a typo anywhere else. The prefix says which network an address
  // belongs to, which is why it cannot be dropped.
  //
  // A segregated witness address is a witness version as one five-bit group and
  // then the program, which is why the words are built here rather than passed
  // as bytes: the version is not part of the program.
  let program = @base16.decode("751e76e8199196d454941c45d1b3a323f1433bd6")
  let address = witness(0, program[:])
  for hrp in ["bc", "tb"] {
    println(@bech32.encode_words(hrp, address[:]))
  }
  // bech32m is the same code with a different constant, and the two do not
  // overlap: a version-0 output is bech32, every later version is bech32m. A
  // taproot output is version 1 with a 32-byte program, so it is spelled with
  // the other constant — and the same call with `Bech32` would produce a string
  // no wallet accepts.
  let taproot = @base16.decode(
    "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
  )
  println(
    @bech32.encode_words("bc", witness(1, taproot[:])[:], kind=@bech32.Bech32m),
  )

  // The same address, spelled in upper case, decodes to the same bytes — a
  // bech32 string is one case throughout, and the checksum is over the lower one.
  let upper = upper_of(@bech32.encode_words("bc", address[:]))
  println("")
  println(upper)
  // Read at the words layer: the data part of an address is a version and a
  // program, which is not a whole number of bytes, so `decode` — the byte face —
  // would refuse it. That is a property of addresses, not of bech32.
  let parts = @bech32.decode_words(upper)
  println(
    parts.hrp + " " + @base16.encode(@bech32.bytes_of(parts.words[1:])[:]),
  )
}

///|
/// A witness program, as the groups bech32 carries: the version alone, then the
/// program regrouped from eight bits to five.
fn witness(version : Int32, program : BytesView) -> Bytes {
  let data : Array[Byte] = [version.to_byte()]
  let words = @bech32.words_of(program)
  for i in 0..<words.length() {
    data.push(words[i])
  }
  Bytes::from_array(data)
}

///|
/// Upper case, which is the other legal spelling of a bech32 string.
fn upper_of(text : StringView) -> String {
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

///|
/// Left-align a label so a column of them lines up.
fn pad(text : String, width : Int32) -> String {
  let out = StringBuilder()
  out.write_string(text)
  for _ in 0..<(width - text.length()) {
    out.write_char(' ')
  }
  out.to_string()
}
