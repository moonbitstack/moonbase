// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// No Sink or Source here, on purpose: the payload is read as one big-endian
// integer, so the first digit of the answer depends on the last byte of the
// input and nothing could be emitted before the whole payload had arrived.
// `encode_big` / `decode_big` take a value whole; the reasoning is in
// `stream.mbt`. base58check is one hash of the whole payload, so it cannot be
// fed in pieces either.

///|
/// Which of the three base58 alphabets is in use.
///
/// All three leave out the characters a reader confuses — no `0`, `O`, `I` or
/// `l` — but they put the rest in a different order, so a string from one is
/// not a string from another. Bitcoin's came first; Flickr reordered it to keep
/// upper case out of the way of a URL; Ripple put the characters it uses most
/// where the digits go.
pub(all) enum Kind {
  Bitcoin
  Flickr
  Ripple
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with Debug::{to_repr}

///|
/// The Bitcoin alphabet, which is also the one multibase calls `base58btc`.
pub let alphabet : @moonbase.Alphabet = @moonbase.Alphabet::of(
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz",
)

///|
/// The Flickr alphabet, which multibase calls `base58flickr`.
pub let alphabet_flickr : @moonbase.Alphabet = @moonbase.Alphabet::of(
  "123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ",
)

///|
/// The Ripple alphabet.
pub let alphabet_ripple : @moonbase.Alphabet = @moonbase.Alphabet::of(
  "rpshnaf39wBUDNEGHJKLM4PQRST7VWXYZ2bcdeCg65jkm8oFqi1tuvAxyz",
)

///|
fn pick(kind : Kind) -> @moonbase.Alphabet {
  match kind {
    Bitcoin => alphabet
    Flickr => alphabet_flickr
    Ripple => alphabet_ripple
  }
}

///|
/// Encode bytes. Leading zero bytes become leading zero digits; the rest is
/// read as one big-endian integer and rewritten in this base.
pub fn encode(input : BytesView, kind~ : Kind = Bitcoin) -> String {
  @moonbase.encode(input, pick(kind))
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView, kind~ : Kind = Bitcoin) -> Bytes {
  @moonbase.encode_bytes(input, pick(kind))
}

///|
/// Decode back to bytes. Fails at the first character outside the alphabet,
/// naming where it was.
pub fn decode(
  input : StringView,
  kind~ : Kind = Bitcoin,
) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode(input, pick(kind))
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind~ : Kind = Bitcoin,
) -> Bytes raise @moonbase.Malformed {
  @moonbase.decode_bytes(input, pick(kind))
}

///|
/// Decode, skipping anything outside the alphabet.
pub fn decode_lossy(input : StringView, kind~ : Kind = Bitcoin) -> Bytes {
  @moonbase.decode_lossy(input, pick(kind))
}

///|
/// Write a whole number in this base. Unlike the byte faces, this one has no
/// leading-zero rule: a number has no leading zeros to preserve.
pub fn encode_int(value : UInt64, kind~ : Kind = Bitcoin) -> String {
  @moonbase.encode_int(value, pick(kind))
}

///|
/// Read a whole number in this base.
pub fn decode_int(
  input : StringView,
  kind~ : Kind = Bitcoin,
) -> UInt64 raise @moonbase.Malformed {
  @moonbase.decode_int(input, pick(kind))
}

///|
/// Write a whole number of any size in this base.
pub fn encode_big(value : @bigint.BigInt, kind~ : Kind = Bitcoin) -> String {
  @moonbase.encode_big(value, pick(kind))
}

///|
/// Read a whole number of any size in this base.
pub fn decode_big(
  input : StringView,
  kind~ : Kind = Bitcoin,
) -> @bigint.BigInt raise @moonbase.Malformed {
  @moonbase.decode_big(input, pick(kind))
}

///|
/// Encode with a checksum: the payload, then the first four bytes of
/// `SHA-256(SHA-256(payload))`, all in base58.
///
/// This is what a Bitcoin address is (§4.5 of the Bitcoin book): the checksum is
/// there so that a typo in a 34-character address is caught before it becomes a
/// payment to nowhere. It is not a signature — anyone can produce a valid one.
pub fn encode_check(input : BytesView, kind~ : Kind = Bitcoin) -> String {
  let sum = checksum(input)
  let all = Array::make(input.length() + 4, b'\x00')
  for i in 0..<input.length() {
    all[i] = input[i]
  }
  for i in 0..<4 {
    all[input.length() + i] = sum[i]
  }
  @moonbase.encode(Bytes::from_array(all)[:], pick(kind))
}

///|
/// Decode the same form, checking the four-byte checksum on the way out.
///
/// A checksum that does not match raises [`Checksum`](#Checksum) at the index
/// the payload ends at — the whole string is a candidate for the error, and that
/// is where the disagreement starts. Anything shorter than four bytes cannot
/// carry a checksum at all and is [`Truncated`](#Truncated).
pub fn decode_check(
  input : StringView,
  kind~ : Kind = Bitcoin,
) -> Bytes raise @moonbase.Malformed {
  let all = @moonbase.decode(input, pick(kind))
  let n = all.length()
  if n < 4 {
    raise Truncated(at=input.length())
  }
  let payload = all[:n - 4].to_owned()
  let sum = checksum(payload[:])
  for i in 0..<4 {
    if all[n - 4 + i] != sum[i] {
      raise Checksum(at=n - 4)
    }
  }
  payload
}

///|
/// The four check bytes for a payload.
fn checksum(payload : BytesView) -> Bytes {
  let first = @internal.sha256(payload)
  let second = @internal.sha256(first[:])
  second[:4].to_owned()
}
