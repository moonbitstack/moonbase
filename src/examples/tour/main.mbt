// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every face of the library in one page: encode, decode, the bytes variants,
/// the lossy one, streaming, and what a failure tells you.
///
/// `main raise` only because some of the calls below are declared to fail and
/// this page never hands them anything malformed; the last section shows the
/// handling a real program would do.
fn main raise {
  let raw = b"moonbase"

  // The same eight bytes in every encoding, in the order the table lists them.
  println(@base2.encode(raw[:]))
  println(@base8.encode(raw[:]))
  println(@base10.encode(raw[:]))
  println(@base16.encode(raw[:]))
  println(@base32.encode(raw[:]))
  println(@base36.encode(raw[:]))
  println(@base45.encode(raw[:]))
  println(@base58.encode(raw[:]))
  println(@base62.encode(raw[:]))
  println(@base64.encode(raw[:]))
  println(@base85.encode(raw[:]))

  // Two spellings of the same bytes, one padded and one not.
  println(@base64.encode(raw[:], kind=@base64.Url, padding=false))
  println(@base16.encode(raw[:], kind=@base16.Upper))

  // The variants that matter to a person reading the string rather than a
  // machine parsing it: Crockford drops the letters that look like digits, and
  // z-base-32 puts the letters a word needs at the cheap end of the alphabet.
  println(@base32.encode(raw[:], kind=@base32.Crockford))
  println(@base32.encode(raw[:], kind=@base32.Z))
  println(@base58.encode(raw[:], kind=@base58.Ripple))

  // base85 is three encodings that happen to share a width.
  println(@base85.encode(b"\x00\xff\x01\xfe"[:], kind=@base85.Z85))
  println(@base85.encode(b"\x00\x00\x00\x00"[:], kind=@base85.Ascii85))

  // A certificate fingerprint is hexadecimal with colons; the lossy decoder
  // reads it back without being told about them.
  let print = @base16.encode_colons(b"\xab\xcd\xef"[:])
  println(print)
  println(@base16.encode(@base16.decode_lossy(print)[:]))

  // A base58 address keeps its leading zero bytes as leading ones, and a
  // Bitcoin address is that plus four bytes of double SHA-256.
  println(@base58.encode(b"\x00\x00\x01"[:]))
  println(
    @base58.encode_check(
      @base16.decode("00010966776006953D5567439E5E39F86A0D273BEE")[:],
    ),
  )

  // Numbers, where leading zeros have no meaning, and the big ones that do not
  // fit an Int at all.
  println(@base36.encode_int(123456789))
  println(@base62.encode_int(123456789))
  println(
    @moonbase.encode_big(
      @bigint.BigInt::from_int(123456789),
      @moonbase.Alphabet::of("0123456789abcdef"),
    ),
  )

  // Any positional system at all, given its digits. Crockford's base32 leaves
  // out the letters a human confuses with digits.
  let crockford = @moonbase.Alphabet::of("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
  println(@moonbase.encode(raw[:], crockford))

  // A stream hands over what is already decided and keeps the rest, so a split
  // anywhere gives the same answer as one call.
  let sink = @base64.sink()
  sink.write(b"moon"[:])
  sink.write(b"base"[:])
  println(sink.finish())
  let source = @base64.source()
  source.write("bW9vbm")
  println(@base64.encode(source.drain()))
  source.write("Jhc2U=")
  println(@base64.encode(source.finish()))

  // bech32 folds its prefix into the checksum, and the two variants never
  // overlap; multibase writes the encoding's name in front of the string.
  println(@bech32.encode("moonbase", raw[:]))
  println(@multibase.encode(raw[:], base=@multibase.Base58Btc))
  println(@multibase.name(@multibase.detect("zKJfFLz7PRba").unwrap()))

  // A failure says what was wrong and where, rather than just "no".
  try @base64.decode("Zm*vYg==") catch {
    failure =>
      match failure {
        Bad(at~, char~) =>
          println("bad character " + char.to_string() + " at " + at.to_string())
        Truncated(at~) => println("truncated at " + at.to_string())
        Padding(at~) => println("misplaced padding at " + at.to_string())
        Checksum(at~) => println("bad checksum at " + at.to_string())
      }
  } noraise {
    _ => println("decoded")
  }
}
