// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which of the three base85 spellings is in use.
///
/// Ascii85 is Adobe's: it lives inside PostScript and PDF, writes a group of
/// four zero bytes as a single `z`, and lets the last group be short. Z85 is
/// ZeroMQ's (RFC 32): the same five-for-four arithmetic over an alphabet safe to
/// put inside a string literal, but with no shortcuts, so the length must be a
/// multiple of four. `Ipv6` is RFC 1924's: the input is one 128-bit number, not a
/// run of four-byte groups.
pub(all) enum Kind {
  Ascii85
  Z85
  Ipv6
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with Debug::{to_repr}

///|
/// Encode bytes as base85.
///
/// Fails only for the two kinds that know how long their input is: Z85 with a
/// length that is not a multiple of four, because ZeroMQ's frame is four bytes
/// and it defines no short tail; and `Ipv6` with a length that is not sixteen,
/// because RFC 1924 is about addresses. Ascii85 shortens its last group
/// instead, so it encodes whatever it is given.
pub fn encode(
  input : BytesView,
  kind~ : Kind = Ascii85,
) -> String raise @moonbase.Malformed {
  match kind {
    Ipv6 => address_encode(input)
    Z85 => {
      if input.length() % 4 != 0 {
        raise Truncated(at=input.length())
      }
      blocks(input, z85_digits, false)
    }
    Ascii85 => blocks(input, ascii85_digits, true)
  }
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(
  input : BytesView,
  kind~ : Kind = Ascii85,
) -> Bytes raise @moonbase.Malformed {
  @internal.ascii(encode(input, kind~))
}

///|
/// Decode base85 back to bytes.
///
/// Ascii85 accepts `z` for a zero group and a short final group; Z85 requires a
/// length that is a multiple of five; `Ipv6` reads a 128-bit number and always
/// gives back sixteen bytes.
pub fn decode(
  input : StringView,
  kind~ : Kind = Ascii85,
) -> Bytes raise @moonbase.Malformed {
  match kind {
    Ipv6 => address_decode(input)
    Z85 => groups(input, z85_lookup, false)
    Ascii85 => groups(input, ascii85_lookup, true)
  }
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind~ : Kind = Ascii85,
) -> Bytes raise @moonbase.Malformed {
  decode(@internal.text_of(input), kind~)
}

///|
/// Decode, skipping anything outside the alphabet — the newlines Adobe wraps a
/// PostScript stream with, the spaces in a pasted string.
pub fn decode_lossy(input : StringView, kind~ : Kind = Ascii85) -> Bytes {
  let table = match kind {
    Z85 => z85_lookup
    Ipv6 => ipv6_lookup
    Ascii85 => ascii85_lookup
  }
  let kept = StringBuilder()
  for i in 0..<input.length() {
    let code = input[i].to_int()
    if kind == Ascii85 && code == 122 {
      kept.write_char('z')
    } else if code >= 0 && code < 128 && table[code] >= 0 {
      kept.write_char(input[i].unsafe_to_char())
    }
  }
  try decode(kept.to_string(), kind~) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// RFC 1924 puts a whole address in one number, so its digits are the
/// positional encoder's — with the leading-zero rule taken back out, because the
/// all-zero address is `0`, not sixteen zero digits.
fn address_encode(input : BytesView) -> String raise @moonbase.Malformed {
  if input.length() != 16 {
    raise Truncated(at=input.length())
  }
  let mut zeros = 0
  while zeros < 16 && input[zeros].to_int() == 0 {
    zeros = zeros + 1
  }
  if zeros == 16 {
    return ipv6_digits[0].to_string()
  }
  @moonbase.encode(input[zeros:], ipv6_alphabet)
}

///|
/// The reverse, which always gives sixteen bytes: an address has a width even
/// when its number does not. A number too large for 128 bits is a failure at
/// its first digit, not a wrapped address.
fn address_decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  if input.length() == 0 {
    raise Truncated(at=0)
  }
  let raw = @moonbase.decode(input, ipv6_alphabet)
  if raw.length() > 16 {
    raise Bad(at=0, char=input[0].unsafe_to_char())
  }
  let out = Array::make(16, b'\x00')
  let shift = 16 - raw.length()
  for i in 0..<raw.length() {
    out[shift + i] = raw[i]
  }
  Bytes::from_array(out)
}

///|
/// Encode a run of four-byte groups, five characters each.
///
/// `short` decides what a trailing group of fewer than four bytes does: Ascii85
/// writes `n + 1` characters for `n` bytes, Z85 never gets here with one.
fn blocks(input : BytesView, digits : Array[Char], short : Bool) -> String {
  let out = StringBuilder()
  let n = input.length()
  let mut i = 0
  while i + 4 <= n {
    write_group(input, i, 4, digits, out, short)
    i = i + 4
  }
  if i < n {
    write_group(input, i, n - i, digits, out, short)
  }
  out.to_string()
}

///|
/// One group: `length` bytes from `at`, widened with zero bytes to four.
fn write_group(
  input : BytesView,
  at : Int32,
  length : Int32,
  digits : Array[Char],
  out : StringBuilder,
  short : Bool,
) -> Unit {
  let mut value = 0L
  for k in 0..<4 {
    let byte = if k < length { input[at + k].to_int().to_int64() } else { 0L }
    value = (value << 8) | byte
  }
  if short && length == 4 && value == 0L {
    out.write_char('z')
    return
  }
  let chars : Array[Char] = []
  let mut left = value
  for _ in 0..<5 {
    chars.push(digits[(left % 85L).to_int()])
    left = left / 85L
  }
  // Ascii85 writes one character more than it has bytes; a full group is five.
  let want = if length < 4 { length + 1 } else { 5 }
  let mut k = 5
  while k > 5 - want {
    k = k - 1
    out.write_char(chars[k])
  }
}

///|
/// Decode a run of five-character groups, four bytes each.
fn groups(
  input : StringView,
  table : Array[Int32],
  short : Bool,
) -> Bytes raise @moonbase.Malformed {
  let out : Array[Byte] = []
  let n = input.length()
  let mut i = 0
  while i < n {
    if short && input[i].to_int() == 122 {
      out.push(b'\x00')
      out.push(b'\x00')
      out.push(b'\x00')
      out.push(b'\x00')
      i = i + 1
      continue
    }
    let rest = n - i
    let length = if rest >= 5 { 5 } else { rest }
    if length < 5 && (!short || length < 2) {
      raise Truncated(at=i)
    }
    let mut value = 0L
    for k in 0..<5 {
      let code = if k < length { input[i + k].to_int() } else { 117 }
      let digit = if code >= 0 && code < 128 { table[code] } else { -1 }
      if digit < 0 {
        if k < length {
          raise Bad(at=i + k, char=input[i + k].unsafe_to_char())
        }
        // A short group is completed with the largest digit, the way every
        // Ascii85 decoder does it: it makes an overflowing tail impossible to
        // accept silently.
        value = value * 85L + 84L
      } else {
        value = value * 85L + digit.to_int64()
      }
    }
    if value > 0xffffffffL {
      raise Bad(at=i, char=input[i].unsafe_to_char())
    }
    let bytes = if length == 5 { 4 } else { length - 1 }
    for k in 0..<bytes {
      out.push(((value >> ((3 - k) * 8)) & 0xffL).to_int().to_byte())
    }
    i = i + length
  }
  Bytes::from_array(out)
}

///|
/// A streaming encoder: four bytes are written as five characters, so up to
/// three bytes wait for the next chunk. `kind=Ipv6` reads its input as one
/// number and therefore buffers the whole payload.
pub struct Sink {
  priv kind : Kind
  priv pending : Array[Byte]
  priv whole : Array[Byte]
  priv out : StringBuilder
}

///|
/// A sink that takes the payload a chunk at a time, in the given alphabet. A
/// group split across two `write` calls is joined before it becomes five
/// characters.
pub fn Sink::new(kind : Kind) -> Sink {
  { kind, pending: [], whole: [], out: StringBuilder(), }
}

///|
/// Feed the next chunk.
pub fn Sink::write(self : Sink, input : BytesView) -> Unit {
  if self.kind == Ipv6 {
    for i in 0..<input.length() {
      self.whole.push(input[i])
    }
    return
  }
  for i in 0..<input.length() {
    self.pending.push(input[i])
    if self.pending.length() == 4 {
      let digits = match self.kind {
        Z85 => z85_digits
        _ => ascii85_digits
      }
      write_group(
        Bytes::from_array(self.pending)[:],
        0,
        4,
        digits,
        self.out,
        self.kind == Ascii85,
      )
      self.pending.clear()
    }
  }
}

///|
/// Take what has been produced so far and forget it.
pub fn Sink::drain(self : Sink) -> String {
  let text = self.out.to_string()
  self.out.reset()
  text
}

///|
/// Close the sink: write the trailing short group, or, for `Ipv6`, encode the
/// whole payload now that there is one.
pub fn Sink::finish(self : Sink) -> String raise @moonbase.Malformed {
  if self.kind == Ipv6 {
    self.out.write_string(address_encode(Bytes::from_array(self.whole)[:]))
    self.whole.clear()
    return self.out.to_string()
  }
  if self.pending.length() > 0 {
    if self.kind == Z85 {
      raise Truncated(at=self.pending.length())
    }
    write_group(
      Bytes::from_array(self.pending)[:],
      0,
      self.pending.length(),
      ascii85_digits,
      self.out,
      true,
    )
    self.pending.clear()
  }
  self.out.to_string()
}

///|
/// A streaming decoder: five characters are four bytes; a partial group waits.
/// `kind=Ipv6` buffers the whole input, because the number is only known once
/// the last digit has arrived.
pub struct Source {
  priv kind : Kind
  priv pending : Array[Int32]
  priv whole : StringBuilder
  priv mut head : Char
  priv mut seen : Int32
  priv out : Array[Byte]
}

///|
/// A source that takes the string a chunk at a time, in the given alphabet. A
/// group split across two `write` calls is joined before it becomes four bytes.
pub fn Source::new(kind : Kind) -> Source {
  { kind, pending: [], whole: StringBuilder(), head: '!', seen: 0, out: [], }
}

///|
/// Feed the next chunk of text.
pub fn Source::write(
  self : Source,
  input : StringView,
) -> Unit raise @moonbase.Malformed {
  if self.kind == Ipv6 {
    self.whole.write_string(input.to_owned())
    self.seen = self.seen + input.length()
    return
  }
  let table = match self.kind {
    Z85 => z85_lookup
    _ => ascii85_lookup
  }
  for i in 0..<input.length() {
    let at = self.seen
    self.seen = self.seen + 1
    let code = input[i].to_int()
    if self.kind == Ascii85 && code == 122 {
      if self.pending.length() != 0 {
        raise Bad(at~, char='z')
      }
      self.out.push(b'\x00')
      self.out.push(b'\x00')
      self.out.push(b'\x00')
      self.out.push(b'\x00')
      continue
    }
    let digit = if code >= 0 && code < 128 { table[code] } else { -1 }
    if digit < 0 {
      raise Bad(at~, char=input[i].unsafe_to_char())
    }
    if self.pending.length() == 0 {
      self.head = input[i].unsafe_to_char()
    }
    self.pending.push(digit)
    if self.pending.length() == 5 {
      let value = fold_group(self.pending, 5)
      for k in 0..<4 {
        self.out.push(((value >> ((3 - k) * 8)) & 0xffL).to_int().to_byte())
      }
      self.pending.clear()
    }
  }
}

///|
/// Take the bytes decoded so far and forget them.
pub fn Source::drain(self : Source) -> Bytes {
  let bytes = Bytes::from_array(self.out)
  self.out.clear()
  bytes
}

///|
/// Close the source and return every byte that has not been drained.
pub fn Source::finish(self : Source) -> Bytes raise @moonbase.Malformed {
  if self.kind == Ipv6 {
    let text = self.whole.to_string()
    let bytes = address_decode(text)
    self.whole.reset()
    return bytes
  }
  let rest = self.pending.length()
  if rest > 0 {
    if self.kind == Z85 || rest == 1 {
      raise Truncated(at=self.seen)
    }
    let value = fold_group(self.pending, rest)
    if value > 0xffffffffL {
      raise Bad(at=self.seen - rest, char=self.head)
    }
    for k in 0..<(rest - 1) {
      self.out.push(((value >> ((3 - k) * 8)) & 0xffL).to_int().to_byte())
    }
    self.pending.clear()
  }
  let bytes = Bytes::from_array(self.out)
  self.out.clear()
  bytes
}

///|
/// The value of a group of `length` digits, the missing ones taken as 84 — the
/// largest digit, so that a group which cannot fit in its bytes is rejected
/// rather than quietly truncated.
fn fold_group(pending : Array[Int32], length : Int32) -> Int64 {
  let mut value = 0L
  for k in 0..<5 {
    let digit = if k < length { pending[k].to_int64() } else { 84L }
    value = value * 85L + digit
  }
  value
}

///|
/// A streaming encoder of this encoding.
pub fn sink(kind~ : Kind = Ascii85) -> Sink {
  Sink::new(kind)
}

///|
/// A streaming decoder of this encoding.
pub fn source(kind~ : Kind = Ascii85) -> Source {
  Source::new(kind)
}

///|
/// Ascii85's alphabet is every printable character from `!` to `u`, in order;
/// the digits are the character minus 33.
let ascii85_text : String = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstu"

///|
/// ZeroMQ RFC 32's alphabet: the digits, the lower case, the upper case, and
/// then the punctuation it kept after dropping what a shell or a string literal
/// would eat.
let z85_text : String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.-:+=^!/*?&<>()[]{}@%$#"

///|
/// RFC 1924's alphabet, in ascending order, with `"`, `'`, `,`, `.`, `/`, `:`,
/// `[`, `]` and `\` left out so an address survives being quoted or written in a
/// list.
let ipv6_text : String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~"

///|
let ascii85_digits : Array[Char] = ascii85_text.to_array()

///|
let z85_digits : Array[Char] = z85_text.to_array()

///|
let ipv6_digits : Array[Char] = ipv6_text.to_array()

///|
let ipv6_alphabet : @moonbase.Alphabet = @moonbase.Alphabet::of(ipv6_text)

///|
let ascii85_lookup : Array[Int32] = @internal.lookup_of(ascii85_text)

///|
let z85_lookup : Array[Int32] = @internal.lookup_of(z85_text)

///|
let ipv6_lookup : Array[Int32] = @internal.lookup_of(ipv6_text)
