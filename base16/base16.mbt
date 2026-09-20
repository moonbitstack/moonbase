// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which case the digits are written in. Decoding accepts either whatever this
/// says, since a hexadecimal document written by someone else is as likely to
/// be upper case as lower.
pub(all) enum Kind {
  Lower
  Upper
} derive(Eq, Debug)

///|
/// Encode bytes as hexadecimal (RFC 4648 §8).
///
/// Each byte becomes exactly two characters, so a leading `0x00` stays `"00"`
/// — unlike a big-integer conversion, which drops leading zeros.
pub fn encode(input : BytesView, kind? : Kind = Lower) -> String {
  @moonbase.pack(input, 4, digits(kind), false)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView, kind? : Kind = Lower) -> Bytes {
  @moonbase.pack_bytes(input, 4, digits(kind), false)
}

///|
/// Encode with a colon between every byte, the spelling certificate
/// fingerprints and MAC addresses are written in.
pub fn encode_colons(input : BytesView, kind? : Kind = Lower) -> String {
  let table = digits(kind)
  let out = StringBuilder()
  for i in 0..<input.length() {
    if i > 0 {
      out.write_char(':')
    }
    let byte = input[i].to_int()
    out.write_char(table[byte >> 4])
    out.write_char(table[byte & 0x0f])
  }
  out.to_string()
}

///|
/// Decode hexadecimal, in either case. Fails at the first character that is not
/// a hexadecimal digit, or when the length is odd.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  @moonbase.unpack(input, 4, lookup, false)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  @moonbase.unpack_bytes(input, 4, lookup, false)
}

///|
/// Decode, skipping anything that is not a hexadecimal digit — colons in a
/// fingerprint, spaces in a hex dump, newlines in a dump of a key.
pub fn decode_lossy(input : StringView) -> Bytes {
  try @moonbase.unpack(input, 4, lookup, true) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
fn digits(kind : Kind) -> Array[Char] {
  match kind {
    Lower => lower
    Upper => upper
  }
}

///|
let lower : Array[Char] = "0123456789abcdef".to_array()

///|
let upper : Array[Char] = "0123456789ABCDEF".to_array()

///|
let lookup : Array[Int] = @moonbase.lookup_of_both(
  "0123456789abcdef", "0123456789ABCDEF",
)
