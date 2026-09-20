// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which case the digits are written in.
pub(all) enum Kind {
  Lower
  Upper
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with Debug::{to_repr}

///|
/// The lower-case alphabet, which is the one everything defaults to.
pub let alphabet : @moonbase.Alphabet = @moonbase.Alphabet::of(
  "0123456789abcdefghijklmnopqrstuvwxyz",
)

///|
/// The upper-case alphabet.
pub let alphabet_upper : @moonbase.Alphabet = @moonbase.Alphabet::of(
  "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
)

///|
fn pick(kind : Kind) -> @moonbase.Alphabet {
  match kind {
    Lower => alphabet
    Upper => alphabet_upper
  }
}

///|
/// Encode bytes. Leading zero bytes become leading zero digits; the rest is
/// read as one big-endian integer and rewritten in this base.
pub fn encode(input : BytesView, kind? : Kind = Lower) -> String {
  @moonbase.encode(input, pick(kind))
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView, kind? : Kind = Lower) -> Bytes {
  @moonbase.encode_bytes(input, pick(kind))
}

///|
/// Decode back to bytes. Fails at the first character outside the alphabet,
/// naming where it was.
pub fn decode(
  input : StringView,
  kind? : Kind = Lower,
) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode(input, pick(kind))
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind? : Kind = Lower,
) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode_bytes(input, pick(kind))
}

///|
/// Decode, skipping anything outside the alphabet.
pub fn decode_lossy(input : StringView, kind? : Kind = Lower) -> Bytes {
  @moonbase.decode_lossy(input, pick(kind))
}

///|
/// Write a whole number in this base. Unlike the byte faces, this one has no
/// leading-zero rule: a number has no leading zeros to preserve.
pub fn encode_int(value : UInt64, kind? : Kind = Lower) -> String {
  @moonbase.encode_int(value, pick(kind))
}

///|
/// Read a whole number in this base.
pub fn decode_int(
  input : StringView,
  kind? : Kind = Lower,
) -> UInt64 raise @moonbase.Malformed {
  @moonbase.decode_int(input, pick(kind))
}
