// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The alphabet this encoding pins.
pub let alphabet : @moonbase.Alphabet = @moonbase.Alphabet::of(
  "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz",
)

///|
/// Encode bytes. Leading zero bytes become leading zero digits; the rest is
/// read as one big-endian integer and rewritten in this base.
pub fn encode(input : BytesView) -> String {
  @moonbase.encode(input, alphabet)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView) -> Bytes {
  @moonbase.encode_bytes(input, alphabet)
}

///|
/// Decode back to bytes. Fails at the first character outside the alphabet,
/// naming where it was.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode(input, alphabet)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode_bytes(input, alphabet)
}

///|
/// Decode, skipping anything outside the alphabet.
pub fn decode_lossy(input : StringView) -> Bytes {
  @moonbase.decode_lossy(input, alphabet)
}

///|
/// Write a whole number in this base. Unlike the byte faces, this one has no
/// leading-zero rule: a number has no leading zeros to preserve.
pub fn encode_int(value : UInt64) -> String {
  @moonbase.encode_int(value, alphabet)
}

///|
/// Read a whole number in this base.
pub fn decode_int(input : StringView) -> UInt64 raise @moonbase.Malformed {
  @moonbase.decode_int(input, alphabet)
}
