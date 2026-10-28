// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Encode bytes as octal, three bits a character.
///
/// Three bytes make eight characters, so the tail of a payload that is not a
/// multiple of three is shifted up and filled with zero bits — 11 bytes become
/// 30 characters, not 29⅓. There is no padding character: nothing in base8 needs
/// one, because the length alone says where the tail starts.
pub fn encode(input : BytesView) -> String {
  @internal.pack(input, 3, digits, false)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView) -> Bytes {
  @internal.pack_bytes(input, 3, digits, false)
}

///|
/// Decode octal back to bytes. Fails at the first character outside `0`–`7`, or
/// when the length cannot be a whole number of bytes.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  @internal.unpack(input, 3, lookup, false)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  @internal.unpack_bytes(input, 3, lookup, false)
}

///|
/// Decode, skipping anything outside the alphabet — `chmod`-style punctuation,
/// spaces between groups.
pub fn decode_lossy(input : StringView) -> Bytes {
  try @internal.unpack(input, 3, lookup, true) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// A streaming encoder: feed bytes in pieces, get the digits as they are
/// produced.
pub fn sink() -> @moonbase.Sink {
  @moonbase.Sink::new(3, digits, false)
}

///|
/// A streaming decoder.
pub fn source(lossy~ : Bool = false) -> @moonbase.Source {
  @moonbase.Source::new(3, lookup, lossy)
}

///|
let text : String = "01234567"

///|
let digits : Array[Char] = text.to_array()

///|
let lookup : Array[Int32] = @internal.lookup_of(text)
