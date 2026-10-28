// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Encode bytes as base45 (RFC 9285 §4).
///
/// Two bytes are one number below 65536 and are written as three digits in base
/// 45, least significant first. An odd trailing byte is written as two digits,
/// because base45 has no padding character to reach for.
pub fn encode(input : BytesView) -> String {
  let out = StringBuilder()
  let mut i = 0
  while i + 1 < input.length() {
    let n = input[i].to_int() * 256 + input[i + 1].to_int()
    out.write_char(digits[n % 45])
    out.write_char(digits[n / 45 % 45])
    out.write_char(digits[n / 2025])
    i = i + 2
  }
  if i < input.length() {
    let n = input[i].to_int()
    out.write_char(digits[n % 45])
    out.write_char(digits[n / 45])
  }
  out.to_string()
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(input : BytesView) -> Bytes {
  @internal.ascii(encode(input))
}

///|
/// Decode base45 back to bytes.
///
/// Fails at a character outside the alphabet, at a length that ends one
/// character short of a group, and at a three-digit group that is larger than
/// 65535 — RFC 9285 §6 requires that last one, because `GGW` would otherwise
/// decode to a number that does not fit in the two bytes it claims.
pub fn decode(input : StringView) -> Bytes raise @moonbase.Malformed {
  let out : Array[Byte] = []
  let n = input.length()
  let mut i = 0
  while i < n {
    let rest = n - i
    if rest >= 3 {
      let value = read_digit(input, i) +
        read_digit(input, i + 1) * 45 +
        read_digit(input, i + 2) * 2025
      if value > 65535 {
        raise Bad(at=i, char=input[i].unsafe_to_char())
      }
      out.push((value / 256).to_byte())
      out.push((value % 256).to_byte())
      i = i + 3
    } else if rest == 2 {
      let value = read_digit(input, i) + read_digit(input, i + 1) * 45
      if value > 255 {
        raise Bad(at=i, char=input[i].unsafe_to_char())
      }
      out.push(value.to_byte())
      i = i + 2
    } else {
      raise Truncated(at=i)
    }
  }
  Bytes::from_array(out)
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(input : BytesView) -> Bytes raise @moonbase.Malformed {
  decode(@internal.text_of(input))
}

///|
/// Decode, skipping anything outside the alphabet — the line breaks a QR payload
/// picks up when it is pasted.
pub fn decode_lossy(input : StringView) -> Bytes {
  let kept = StringBuilder()
  for i in 0..<input.length() {
    let code = input[i].to_int()
    if code >= 0 && code < 128 && lookup[code] >= 0 {
      kept.write_char(input[i].unsafe_to_char())
    }
  }
  try decode(kept.to_string()) catch {
    _ => b""
  } noraise {
    bytes => bytes
  }
}

///|
/// The digit value of the character at `at`, or a failure naming where.
fn read_digit(
  input : StringView,
  at : Int32,
) -> Int32 raise @moonbase.Malformed {
  let code = input[at].to_int()
  let value = if code >= 0 && code < 128 { lookup[code] } else { -1 }
  if value < 0 {
    raise Bad(at~, char=input[at].unsafe_to_char())
  }
  value
}

///|
/// A streaming encoder: bytes go in two at a time, three characters come out.
///
/// A chunk may end on an odd byte; that byte waits for the next chunk rather
/// than being encoded early, so the output is the same as feeding the whole
/// payload at once.
pub struct Sink {
  priv mut odd : Int32
  priv out : StringBuilder
}

///|
/// A sink that takes the payload a chunk at a time. A pair split across two
/// `write` calls is joined before it becomes three characters, which is the
/// whole reason the type exists.
pub fn Sink::new() -> Sink {
  { odd: -1, out: StringBuilder(), }
}

///|
/// Feed the next chunk.
pub fn Sink::write(self : Sink, input : BytesView) -> Unit {
  let mut i = 0
  if self.odd >= 0 && input.length() > 0 {
    let n = self.odd * 256 + input[0].to_int()
    self.out.write_char(digits[n % 45])
    self.out.write_char(digits[n / 45 % 45])
    self.out.write_char(digits[n / 2025])
    self.odd = -1
    i = 1
  }
  while i + 1 < input.length() {
    let n = input[i].to_int() * 256 + input[i + 1].to_int()
    self.out.write_char(digits[n % 45])
    self.out.write_char(digits[n / 45 % 45])
    self.out.write_char(digits[n / 2025])
    i = i + 2
  }
  if i < input.length() {
    self.odd = input[i].to_int()
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
/// Close the sink: write the odd trailing byte as two digits, if there is one.
pub fn Sink::finish(self : Sink) -> String {
  if self.odd >= 0 {
    self.out.write_char(digits[self.odd % 45])
    self.out.write_char(digits[self.odd / 45])
    self.odd = -1
  }
  self.out.to_string()
}

///|
/// A streaming decoder: characters go in, bytes come out.
///
/// Three characters are one group, so up to two wait for the next chunk. The
/// index in a failure is the one it has in the whole input, not in the chunk.
pub struct Source {
  priv pending : Array[Int32]
  priv mut start : Int32
  priv mut head : Char
  priv mut seen : Int32
  priv out : Array[Byte]
}

///|
/// A source that takes the string a chunk at a time. A triplet split across two
/// `write` calls is joined before it becomes two bytes, and a failure names the
/// index in the whole input rather than in the chunk.
pub fn Source::new() -> Source {
  { pending: [], start: 0, head: '0', seen: 0, out: [], }
}

///|
/// Feed the next chunk.
pub fn Source::write(
  self : Source,
  input : StringView,
) -> Unit raise @moonbase.Malformed {
  for i in 0..<input.length() {
    let at = self.seen
    self.seen = self.seen + 1
    let code = input[i].to_int()
    let value = if code >= 0 && code < 128 { lookup[code] } else { -1 }
    if value < 0 {
      raise Bad(at~, char=input[i].unsafe_to_char())
    }
    if self.pending.length() == 0 {
      self.start = at
      self.head = input[i].unsafe_to_char()
    }
    self.pending.push(value)
    if self.pending.length() == 3 {
      let n = self.pending[0] + self.pending[1] * 45 + self.pending[2] * 2025
      if n > 65535 {
        raise Bad(at=self.start, char=self.head)
      }
      self.out.push((n / 256).to_byte())
      self.out.push((n % 256).to_byte())
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
///
/// Two characters left over are one byte; one character left over is a failure,
/// the same [`Truncated`](#Truncated) the one-shot decoder raises.
pub fn Source::finish(self : Source) -> Bytes raise @moonbase.Malformed {
  let rest = self.pending.length()
  if rest == 1 {
    raise Truncated(at=self.start)
  }
  if rest == 2 {
    let n = self.pending[0] + self.pending[1] * 45
    if n > 255 {
      raise Bad(at=self.start, char=self.head)
    }
    self.out.push(n.to_byte())
    self.pending.clear()
  }
  let bytes = Bytes::from_array(self.out)
  self.out.clear()
  bytes
}

///|
/// A streaming encoder of this encoding.
pub fn sink() -> Sink {
  Sink::new()
}

///|
/// A streaming decoder of this encoding.
pub fn source() -> Source {
  Source::new()
}

///|
/// Table 1 of RFC 9285 §4.2: the digits, the capitals, then the punctuation a QR
/// code's alphanumeric mode also allows. Space is a digit here, which is why
/// `%69 VD92EX0` is a well-formed encoding of `Hello!!`.
let text : String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

///|
let digits : Array[Char] = text.to_array()

///|
let lookup : Array[Int32] = @internal.lookup_of(text)
