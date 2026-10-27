// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every face of the library in one page: encode, decode, the bytes variants,
/// the lossy one, and what a failure tells you.
fn main {
  let raw = b"moonbase"

  // Two spellings of the same bytes, one padded and one not.
  println(@base64.encode(raw[:]))
  println(@base64.encode(raw[:], kind=Url, padding=false))
  println(@base32.encode(raw[:]))
  println(@base16.encode(raw[:]))

  // A certificate fingerprint is hexadecimal with colons; the lossy decoder
  // reads it back without being told about them.
  let print = @base16.encode_colons(b"\xab\xcd\xef"[:])
  println(print)
  println(@base16.encode(@base16.decode_lossy(print)[:]))

  // A base58 address keeps its leading zero bytes as leading ones.
  println(@base58.encode(b"\x00\x00\x01"[:]))

  // Numbers, where leading zeros have no meaning.
  println(@base36.encode_int(123456789))
  println(@base62.encode_int(123456789))

  // Any positional system at all, given its digits. Crockford's base32 leaves
  // out the letters a human confuses with digits.
  let crockford = @moonbase.Alphabet::of("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
  println(@moonbase.encode(raw[:], crockford))

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
