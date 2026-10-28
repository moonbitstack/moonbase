// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The alphabet this encoding pins: the ten digits, in order.
pub let alphabet : @moonbase.Alphabet = @moonbase.Alphabet::of("0123456789")

///|
/// Encode bytes as decimal. The payload is read as one big-endian integer, so a
/// leading zero byte becomes a leading `0` and `b"\x00\x00\x01"` is `"0001"`.
pub fn encode(input : BytesView) -> String {
  @moonbase.encode(input, alphabet)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView) -> Bytes {
  @moonbase.encode_bytes(input, alphabet)
}

///|
/// Decode decimal back to bytes. Fails at the first character that is not a
/// digit, naming where it was.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode(input, alphabet)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode_bytes(input, alphabet)
}

///|
/// Decode, skipping anything that is not a digit — the separators in a written
/// out number.
pub fn decode_lossy(input : StringView) -> Bytes {
  @moonbase.decode_lossy(input, alphabet)
}

///|
/// Write a whole number in decimal. Unlike the byte faces this has no
/// leading-zero rule, because a number has no leading zeros to keep.
pub fn encode_int(value : UInt64) -> String {
  @moonbase.encode_int(value, alphabet)
}

///|
/// Read a whole number in decimal.
pub fn decode_int(input : StringView) -> UInt64 raise @moonbase.Malformed {
  @moonbase.decode_int(input, alphabet)
}

///|
/// Write a whole number of any size in decimal.
pub fn encode_big(value : @bigint.BigInt) -> String {
  @moonbase.encode_big(value, alphabet)
}

///|
/// Read a whole number of any size in decimal.
pub fn decode_big(
  input : StringView,
) -> @bigint.BigInt raise @moonbase.Malformed {
  @moonbase.decode_big(input, alphabet)
}
