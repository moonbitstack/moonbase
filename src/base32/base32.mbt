// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which alphabet: the ordinary one, the extended-hex one whose characters sort
/// in the same order as the bytes they encode, Crockford's, or z-base-32's.
pub(all) enum Kind {
  Std
  Hex
  Crockford
  Z
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with Debug::{to_repr}

///|
/// Encode bytes as base32 (RFC 4648 §6, or §7 with `kind=Hex`).
///
/// Five bits a character, padded to a multiple of eight unless told otherwise.
/// `kind=Crockford` and `kind=Z` are never padded: neither specification has a
/// padding character, so the `padding` argument has no effect on them.
pub fn encode(
  input : BytesView,
  kind~ : Kind = Std,
  padding~ : Bool = true,
) -> String {
  @internal.pack(input, 5, digits(kind), padding && pads(kind))
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(
  input : BytesView,
  kind~ : Kind = Std,
  padding~ : Bool = true,
) -> Bytes {
  @internal.pack_bytes(input, 5, digits(kind), padding && pads(kind))
}

///|
/// Decode base32. Trailing `=` is optional; a character outside the alphabet or
/// a length that cannot be a whole number of bytes fails, naming where.
///
/// Both cases are accepted whatever `kind` says, and `kind=Crockford` also
/// accepts the letters its specification aliases: `O` reads as zero, `I` and `L`
/// as one.
///
/// `padding` says whether trailing `=` must be there (`true`) or must not
/// (`false`); left out, either is read. `strict` refuses what the default
/// tolerates: an incomplete run of `=`, and spare bits after the last byte that
/// are not zero (RFC 4648 §3.5). Together they accept exactly the one spelling
/// `encode` writes, which is what a format that compares or signs the text needs.
pub fn decode(
  input : StringView,
  kind~ : Kind = Std,
  padding? : Bool,
  strict~ : Bool = false,
) -> Bytes raise @moonbase.Malformed {
  @internal.unpack(input, 5, lookup(kind), false, padding?, strict~)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind~ : Kind = Std,
  padding? : Bool,
  strict~ : Bool = false,
) -> Bytes raise @moonbase.Malformed {
  @internal.unpack_bytes(input, 5, lookup(kind), false, padding?, strict~)
}

///|
/// Decode, skipping anything outside the alphabet — newlines, spaces, the
/// punctuation a wrapped document picks up.
pub fn decode_lossy(input : StringView, kind~ : Kind = Std) -> Bytes {
  try @internal.unpack(input, 5, lookup(kind), true) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// A streaming encoder of the same encoding, for a payload that arrives in
/// pieces. Feeding it chunk by chunk gives the same string as [`encode`].
pub fn sink(kind~ : Kind = Std, padding~ : Bool = true) -> @moonbase.Sink {
  @moonbase.Sink::new(5, digits(kind), padding && pads(kind))
}

///|
/// A streaming decoder of the same encoding.
pub fn source(kind~ : Kind = Std, lossy~ : Bool = false) -> @moonbase.Source {
  @moonbase.Source::new(5, lookup(kind), lossy)
}

///|
/// Whether this kind pads. RFC 4648 §3.2 defines `=` for both of its alphabets;
/// Crockford and z-base-32 write a length instead of a padding character.
fn pads(kind : Kind) -> Bool {
  match kind {
    Std => true
    Hex => true
    Crockford => false
    Z => false
  }
}

///|
fn digits(kind : Kind) -> Array[Char] {
  match kind {
    Std => std_digits
    Hex => hex_digits
    Crockford => crockford_digits
    Z => z_digits
  }
}

///|
fn lookup(kind : Kind) -> Array[Int32] {
  match kind {
    Std => std_lookup
    Hex => hex_lookup
    Crockford => crockford_lookup
    Z => z_lookup
  }
}

///|
let std_text : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

///|
let hex_text : String = "0123456789ABCDEFGHIJKLMNOPQRSTUV"

///|
let crockford_text : String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

///|
let z_text : String = "ybndrfg8ejkmcpqxot1uwisza345h769"

///|
let std_digits : Array[Char] = std_text.to_array()

///|
let hex_digits : Array[Char] = hex_text.to_array()

///|
let crockford_digits : Array[Char] = crockford_text.to_array()

///|
let z_digits : Array[Char] = z_text.to_array()

///|
let std_lookup : Array[Int32] = @internal.lookup_of_both(
  "abcdefghijklmnopqrstuvwxyz234567", std_text,
)

///|
let hex_lookup : Array[Int32] = @internal.lookup_of_both(
  "0123456789abcdefghijklmnopqrstuv", hex_text,
)

///|
/// Crockford's table, with the aliases his specification asks for: `O` for zero,
/// `I` and `L` for one. A reader who confuses them still gets the right number.
let crockford_lookup : Array[Int32] = crockford_table()

///|
let z_lookup : Array[Int32] = @internal.lookup_of_both(
  z_text, "YBNDRFG8EJKMCPQXOT1UWISZA345H769",
)

///|
fn crockford_table() -> Array[Int32] {
  let table = @internal.lookup_of_both(
    "0123456789abcdefghjkmnpqrstvwxyz", crockford_text,
  )
  let aliases = [("O", 0), ("o", 0), ("I", 1), ("i", 1), ("L", 1), ("l", 1)]
  for pair in aliases {
    let (letter, value) = pair
    let code = letter.to_array()[0].to_int()
    table[code] = value
  }
  table
}
