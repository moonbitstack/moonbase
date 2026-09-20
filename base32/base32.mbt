// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which alphabet: the ordinary one, or the extended-hex one whose characters
/// sort in the same order as the bytes they encode.
pub(all) enum Kind {
  Std
  Hex
} derive(Eq, Debug)

///|
/// Encode bytes as base32 (RFC 4648 §6, or §7 with `kind=Hex`).
///
/// Padded to a multiple of eight characters unless told otherwise.
pub fn encode(
  input : BytesView,
  kind? : Kind = Std,
  padding? : Bool = true,
) -> String {
  @moonbase.pack(input, 5, digits(kind), padding)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(
  input : BytesView,
  kind? : Kind = Std,
  padding? : Bool = true,
) -> Bytes {
  @moonbase.pack_bytes(input, 5, digits(kind), padding)
}

///|
/// Decode base32. Trailing `=` is optional; a character outside the alphabet or
/// a length that cannot be a whole number of bytes fails, naming where.
pub fn decode(
  input : StringView,
  kind? : Kind = Std,
) -> Bytes raise @moonbase.Malformed {
  @moonbase.unpack(input, 5, lookup(kind), false)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind? : Kind = Std,
) -> Bytes raise @moonbase.Malformed {
  @moonbase.unpack_bytes(input, 5, lookup(kind), false)
}

///|
/// Decode, skipping anything outside the alphabet — newlines, spaces, the
/// punctuation a wrapped document picks up.
pub fn decode_lossy(input : StringView, kind? : Kind = Std) -> Bytes {
  try @moonbase.unpack(input, 5, lookup(kind), true) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
fn digits(kind : Kind) -> Array[Char] {
  match kind {
    Std => std_digits
    Hex => hex_digits
  }
}

///|
fn lookup(kind : Kind) -> Array[Int] {
  match kind {
    Std => std_lookup
    Hex => hex_lookup
  }
}

///|
let std_text : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

///|
let hex_text : String = "0123456789ABCDEFGHIJKLMNOPQRSTUV"

///|
let std_digits : Array[Char] = std_text.to_array()

///|
let hex_digits : Array[Char] = hex_text.to_array()

///|
let std_lookup : Array[Int] = @moonbase.lookup_of_both(
  "abcdefghijklmnopqrstuvwxyz234567", std_text,
)

///|
let hex_lookup : Array[Int] = @moonbase.lookup_of_both(
  "0123456789abcdefghijklmnopqrstuv", hex_text,
)
