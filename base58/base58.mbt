// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The base58 alphabet used by Bitcoin and IPFS. It leaves out the four
/// characters that are easy to confuse by eye — `0` (zero), `O`, `I`, and `l`
/// — so an encoded string survives being read aloud or copied by hand.
pub let alphabet : @moonbase.Alphabet = @moonbase.Alphabet::new(
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz",
)

///|
/// Encode bytes as a base58 string. Round-trips with [`decode`].
pub fn encode(input : Bytes) -> String {
  @moonbase.encode(input, alphabet)
}

///|
/// Decode a base58 string back to bytes, or `None` when it holds a character
/// outside the alphabet.
pub fn decode(input : String) -> Bytes? {
  @moonbase.decode(input, alphabet)
}
