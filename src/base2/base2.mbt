// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Encode bytes as binary, one bit a character.
///
/// Eight characters per byte, most significant bit first. There is nothing to
/// choose and nothing to pad: `b"\xb5"` is `"10110101"`.
pub fn encode(input : BytesView) -> String {
  @internal.pack(input, 1, digits, false)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView) -> Bytes {
  @internal.pack_bytes(input, 1, digits, false)
}

///|
/// Decode binary back to bytes. Fails at the first character that is not `0` or
/// `1`, or when the length is not a multiple of eight.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  @internal.unpack(input, 1, lookup, false)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  @internal.unpack_bytes(input, 1, lookup, false)
}

///|
/// Decode, skipping anything that is not a bit — the spaces in a hand-written
/// bit string, the newlines in a wrapped one.
pub fn decode_lossy(input : StringView) -> Bytes {
  try @internal.unpack(input, 1, lookup, true) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// A streaming encoder: feed bytes in pieces, get the bits as they are produced.
pub fn sink() -> @moonbase.Sink {
  @moonbase.Sink::new(1, digits, false)
}

///|
/// A streaming decoder.
pub fn source(lossy~ : Bool = false) -> @moonbase.Source {
  @moonbase.Source::new(1, lookup, lossy)
}

///|
let text : String = "01"

///|
let digits : Array[Char] = text.to_array()

///|
let lookup : Array[Int32] = @internal.lookup_of(text)
