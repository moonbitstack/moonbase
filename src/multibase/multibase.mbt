// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every encoding in multibase's table that this module can write, named after
/// the table's `encoding` column.
///
/// The spellings that differ only in case are separate entries because the prefix
/// differs: `f` and `F` are both hexadecimal, and a decoder has to know which one
/// it was handed in order to write it back the same way. `base256emoji` is in the
/// table too, even though a character standing for a byte is not a base at all in
/// the bit-packing sense.
pub(all) enum Base {
  Base2
  Base8
  Base10
  Base16
  Base16Upper
  Base32Hex
  Base32HexUpper
  Base32HexPad
  Base32HexPadUpper
  Base32
  Base32Upper
  Base32Pad
  Base32PadUpper
  Base32Z
  Base36
  Base36Upper
  Base45
  Base58Btc
  Base58Flickr
  Base64
  Base64Pad
  Base64Url
  Base64UrlPad
  Base256Emoji
} derive(Eq, Debug)

///|
pub extend Base with Eq::{equal, not_equal}

///|
pub extend Base with Debug::{to_repr}

///|
/// The prefix that identifies `base`, which is the one character a multibase
/// string starts with.
pub fn prefix(base : Base) -> Char {
  match base {
    Base2 => '0'
    Base8 => '7'
    Base10 => '9'
    Base16 => 'f'
    Base16Upper => 'F'
    Base32Hex => 'v'
    Base32HexUpper => 'V'
    Base32HexPad => 't'
    Base32HexPadUpper => 'T'
    Base32 => 'b'
    Base32Upper => 'B'
    Base32Pad => 'c'
    Base32PadUpper => 'C'
    Base32Z => 'h'
    Base36 => 'k'
    Base36Upper => 'K'
    Base45 => 'R'
    Base58Btc => 'z'
    Base58Flickr => 'Z'
    Base64 => 'm'
    Base64Pad => 'M'
    Base64Url => 'u'
    Base64UrlPad => 'U'
    Base256Emoji => '\u{1F680}'
  }
}

///|
/// The name multibase's table gives this encoding, for a message or a table cell.
pub fn name(base : Base) -> String {
  match base {
    Base2 => "base2"
    Base8 => "base8"
    Base10 => "base10"
    Base16 => "base16"
    Base16Upper => "base16upper"
    Base32Hex => "base32hex"
    Base32HexUpper => "base32hexupper"
    Base32HexPad => "base32hexpad"
    Base32HexPadUpper => "base32hexpadupper"
    Base32 => "base32"
    Base32Upper => "base32upper"
    Base32Pad => "base32pad"
    Base32PadUpper => "base32padupper"
    Base32Z => "base32z"
    Base36 => "base36"
    Base36Upper => "base36upper"
    Base45 => "base45"
    Base58Btc => "base58btc"
    Base58Flickr => "base58flickr"
    Base64 => "base64"
    Base64Pad => "base64pad"
    Base64Url => "base64url"
    Base64UrlPad => "base64urlpad"
    Base256Emoji => "base256emoji"
  }
}

///|
/// The encoding a prefix stands for, or `None` if this module does not write it.
///
/// `NUL`, `1`, `Q` and `/` are reserved by the table and are not encodings;
/// `p` is proquint, which is a word encoding rather than a base, and is the one
/// entry left out.
pub fn of_prefix(mark : Char) -> Base? {
  let code = mark.to_int()
  Some(
    match code {
      48 => Base2 // '0'
      55 => Base8 // '7'
      57 => Base10 // '9'
      102 => Base16 // 'f'
      70 => Base16Upper // 'F'
      118 => Base32Hex // 'v'
      86 => Base32HexUpper // 'V'
      116 => Base32HexPad // 't'
      84 => Base32HexPadUpper // 'T'
      98 => Base32 // 'b'
      66 => Base32Upper // 'B'
      99 => Base32Pad // 'c'
      67 => Base32PadUpper // 'C'
      104 => Base32Z // 'h'
      107 => Base36 // 'k'
      75 => Base36Upper // 'K'
      82 => Base45 // 'R'
      122 => Base58Btc // 'z'
      90 => Base58Flickr // 'Z'
      109 => Base64 // 'm'
      77 => Base64Pad // 'M'
      117 => Base64Url // 'u'
      85 => Base64UrlPad // 'U'
      128640 => Base256Emoji // U+1F680
      _ => return None
    },
  )
}

///|
/// Encode bytes with a prefix in front that says which encoding was used.
///
/// ```moonbit nocheck
/// @multibase.encode(b"yes mani !")            // "z7paNL19xttacUY"
/// @multibase.encode(b"yes mani !", base=Base16) // "f796573206d616e692021"
/// ```
pub fn encode(input : BytesView, base~ : Base = Base58Btc) -> String {
  let body = match base {
    Base2 => @base2.encode(input)
    Base8 => @base8.encode(input)
    Base10 => @base10.encode(input)
    Base16 => @base16.encode(input, kind=@base16.Lower)
    Base16Upper => @base16.encode(input, kind=@base16.Upper)
    Base32Hex => @base32.encode(input, kind=@base32.Hex, padding=false)
    Base32HexUpper => @base32.encode(input, kind=@base32.Hex, padding=false)
    Base32HexPad => @base32.encode(input, kind=@base32.Hex, padding=true)
    Base32HexPadUpper => @base32.encode(input, kind=@base32.Hex, padding=true)
    Base32 => @base32.encode(input, kind=@base32.Std, padding=false)
    Base32Upper => @base32.encode(input, kind=@base32.Std, padding=false)
    Base32Pad => @base32.encode(input, kind=@base32.Std, padding=true)
    Base32PadUpper => @base32.encode(input, kind=@base32.Std, padding=true)
    Base32Z => @base32.encode(input, kind=@base32.Z, padding=false)
    Base36 => @base36.encode(input, kind=@base36.Lower)
    Base36Upper => @base36.encode(input, kind=@base36.Upper)
    Base45 => @base45.encode(input)
    Base58Btc => @base58.encode(input, kind=@base58.Bitcoin)
    Base58Flickr => @base58.encode(input, kind=@base58.Flickr)
    Base64 => @base64.encode(input, padding=false)
    Base64Pad => @base64.encode(input, padding=true)
    Base64Url => @base64.encode(input, kind=@base64.Url, padding=false)
    Base64UrlPad => @base64.encode(input, kind=@base64.Url, padding=true)
    Base256Emoji => emoji_encode(input)
  }
  // RFC 4648 spells base32 in capitals; multibase has an entry for each case and
  // writes the lower-case one by default, so the case is settled here rather
  // than in the base32 package.
  let cased = match base {
    Base32Upper | Base32PadUpper | Base32HexUpper | Base32HexPadUpper =>
      upper(body)
    Base32 | Base32Pad | Base32Hex | Base32HexPad => lower(body)
    _ => body
  }
  prefix(base).to_string() + cased
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView, base~ : Base = Base58Btc) -> Bytes {
  @internal.ascii(encode(input, base~))
}

///|
/// Decode a string whose first character says how the rest is encoded.
///
/// The failure positions count from the start of the whole string, prefix
/// included, so an error index can be used to point at the input the caller
/// actually has.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  let chars = input.to_array()
  if chars.length() == 0 {
    raise Truncated(at=0)
  }
  let base = match of_prefix(chars[0]) {
    Some(base) => base
    None => raise Bad(at=0, char=chars[0])
  }
  if base == Base256Emoji {
    return emoji_decode(chars)
  }
  let text = StringBuilder()
  for i in 1..<chars.length() {
    let code = chars[i].to_int()
    if code > 127 {
      raise Bad(at=i, char=chars[i])
    }
    text.write_char(chars[i])
  }
  try decode_body(text.to_string(), base) catch {
    failure => raise shift(failure)
  } noraise {
    bytes => bytes
  }
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  decode(@internal.text_of(input))
}

///|
/// Decode, dropping the whitespace a pasted string picks up on the way.
pub fn decode_lossy(input : StringView) -> Bytes {
  let chars = input.to_array()
  let kept = StringBuilder()
  for i in 0..<chars.length() {
    let code = chars[i].to_int()
    if code != 32 && code != 9 && code != 10 && code != 13 {
      kept.write_char(chars[i])
    }
  }
  try decode(kept.to_string()) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// Which encoding a string claims to be in, without decoding it.
pub fn detect(input : StringView) -> Base? {
  let chars = input.to_array()
  if chars.length() == 0 {
    return None
  }
  of_prefix(chars[0])
}

///|
/// The body of a string, decoded as `base`, with the prefix already removed.
fn decode_body(
  input : StringView,
  base : Base,
) -> Bytes raise @moonbase.Malformed {
  match base {
    Base2 => @base2.decode(input)
    Base8 => @base8.decode(input)
    Base10 => @base10.decode(input)
    Base16 | Base16Upper => @base16.decode(input)
    Base32Hex | Base32HexUpper | Base32HexPad | Base32HexPadUpper =>
      @base32.decode(input, kind=@base32.Hex)
    Base32 | Base32Upper | Base32Pad | Base32PadUpper =>
      @base32.decode(input, kind=@base32.Std)
    Base32Z => @base32.decode(input, kind=@base32.Z)
    // base36 is the one spelling whose decoder is case-sensitive, because its
    // alphabet is a value of its own; multibase's table calls both entries
    // case-insensitive, so the case is settled here.
    Base36 | Base36Upper => @base36.decode(lower(input))
    Base45 => @base45.decode(input)
    Base58Btc => @base58.decode(input, kind=@base58.Bitcoin)
    Base58Flickr => @base58.decode(input, kind=@base58.Flickr)
    Base64 | Base64Pad => @base64.decode(input, kind=@base64.Std)
    Base64Url | Base64UrlPad => @base64.decode(input, kind=@base64.Url)
    Base256Emoji =>
      abort("multibase: base256emoji is decoded character by character")
  }
}

///|
/// One character per byte, which is the whole of base256emoji.
fn emoji_encode(input : BytesView) -> String {
  let out = StringBuilder()
  for i in 0..<input.length() {
    out.write_char(emoji[input[i].to_int()])
  }
  out.to_string()
}

///|
/// The reverse. `chars[0]` is the prefix, so the failure index is already the one
/// it has in the whole string — counted in characters rather than in UTF-16 code
/// units, which differ for every emoji outside the basic plane.
fn emoji_decode(chars : Array[Char]) -> Bytes raise @moonbase.Malformed {
  let out : Array[Byte] = []
  for i in 1..<chars.length() {
    let mut found = -1
    for k in 0..<256 {
      if emoji[k] == chars[i] {
        found = k
      }
    }
    if found < 0 {
      raise Bad(at=i, char=chars[i])
    }
    out.push(found.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// Move a failure found in the body up by one, to count from the prefix.
fn shift(failure : @moonbase.Malformed) -> @moonbase.Malformed {
  match failure {
    Bad(at~, char~) => Bad(at=at + 1, char~)
    Truncated(at~) => Truncated(at=at + 1)
    Padding(at~) => Padding(at=at + 1)
    Checksum(at~) => Checksum(at=at + 1)
  }
}

///|
/// Lower case, for the two base36 entries.
fn lower(input : StringView) -> String {
  let out = StringBuilder()
  for i in 0..<input.length() {
    let code = input[i].to_int()
    out.write_char(
      if code >= 65 && code <= 90 {
        (code + 32).unsafe_to_char()
      } else {
        input[i].unsafe_to_char()
      },
    )
  }
  out.to_string()
}

///|
/// Upper case, for the four base32 entries that are spelled that way.
fn upper(input : StringView) -> String {
  let out = StringBuilder()
  for i in 0..<input.length() {
    let code = input[i].to_int()
    out.write_char(
      if code >= 97 && code <= 122 {
        (code - 32).unsafe_to_char()
      } else {
        input[i].unsafe_to_char()
      },
    )
  }
  out.to_string()
}
