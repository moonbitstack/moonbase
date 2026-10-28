// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which alphabet: the ordinary one, or the URL-safe one that trades `+/` for
/// `-_` so the result survives a query string and a file name.
pub(all) enum Kind {
  Std
  Url
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with Debug::{to_repr}

///|
/// Encode bytes as base64 (RFC 4648 §4, or §5 with `kind=Url`).
///
/// A JWT wants `kind=Url, padding=false`; an HTTP Basic credential wants the
/// defaults.
pub fn encode(
  input : BytesView,
  kind~ : Kind = Std,
  padding~ : Bool = true,
) -> String {
  @internal.pack(input, 6, digits(kind), padding)
}

///|
/// The same encoding, as the ASCII bytes it would be written with — what an
/// HTTP header or a gRPC metadata value actually holds.
pub fn encode_bytes(
  input : BytesView,
  kind~ : Kind = Std,
  padding~ : Bool = true,
) -> Bytes {
  @internal.pack_bytes(input, 6, digits(kind), padding)
}

///|
/// Decode base64. Trailing `=` is optional; a character outside the alphabet or
/// an impossible length fails, naming where.
pub fn decode(
  input : StringView,
  kind~ : Kind = Std,
) -> Bytes raise @moonbase.Malformed {
  @internal.unpack(input, 6, lookup(kind), false)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind~ : Kind = Std,
) -> Bytes raise @moonbase.Malformed {
  @internal.unpack_bytes(input, 6, lookup(kind), false)
}

///|
/// Decode, skipping anything outside the alphabet — the newlines in a PEM body,
/// the whitespace in a pasted token.
pub fn decode_lossy(input : StringView, kind~ : Kind = Std) -> Bytes {
  try @internal.unpack(input, 6, lookup(kind), true) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// Decode either alphabet at once, for input whose spelling is not known in
/// advance: `-_` and `+/` are accepted together, since no encoding uses both.
pub fn decode_any(input : StringView) -> Bytes raise @moonbase.Malformed {
  @internal.unpack(input, 6, any_lookup, false)
}

///|
/// A streaming encoder: three bytes are four characters, so up to two bytes
/// wait for the next chunk and the total is the same at any chunking.
pub fn sink(kind~ : Kind = Std, padding~ : Bool = true) -> @moonbase.Sink {
  @moonbase.Sink::new(6, digits(kind), padding)
}

///|
/// A streaming decoder. Up to three characters wait for the next chunk; a
/// failure names the index in the whole input, not in the chunk.
pub fn source(kind~ : Kind = Std, lossy~ : Bool = false) -> @moonbase.Source {
  @moonbase.Source::new(6, lookup(kind), lossy)
}

///|
fn digits(kind : Kind) -> Array[Char] {
  match kind {
    Std => std_digits
    Url => url_digits
  }
}

///|
fn lookup(kind : Kind) -> Array[Int32] {
  match kind {
    Std => std_lookup
    Url => url_lookup
  }
}

///|
let letters : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

///|
let std_text : String = letters + "+/"

///|
let url_text : String = letters + "-_"

///|
let std_digits : Array[Char] = std_text.to_array()

///|
let url_digits : Array[Char] = url_text.to_array()

///|
let std_lookup : Array[Int32] = @internal.lookup_of(std_text)

///|
let url_lookup : Array[Int32] = @internal.lookup_of(url_text)

///|
let any_lookup : Array[Int32] = @internal.lookup_of_both(std_text, url_text)
