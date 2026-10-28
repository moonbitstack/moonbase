// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A streaming encoder: bytes go in a chunk at a time, text comes out as it is
/// produced.
///
/// The one-shot [`encode`] needs the whole payload before it starts, which is
/// fine for a token and wrong for a file or a socket. A `Sink` carries the
/// half-finished character between chunks, so feeding `b"foo"` then `b"bar"`
/// gives the same string as feeding `b"foobar"` — the tests check that against
/// random splits, not just the obvious one.
///
/// ```moonbit nocheck
/// let sink = @base64.sink()
/// sink.write(b"foo"[:])
/// sink.write(b"bar"[:])
/// sink.finish()               // "Zm9vYmFy"
/// ```
///
/// This is the bit-packing engine, so it serves base16, base32 and base64. The
/// positional encodings (base36, base58, base62, base10) have no streaming face
/// at all: their first digit depends on the last byte, so nothing can be
/// written until everything has been read.
pub struct Sink {
  priv digits : Array[Char]
  priv bits : Int32
  priv pad : Bool
  priv mut buffer : Int32
  priv mut held : Int32
  priv mut count : Int32
  priv out : StringBuilder
}

///|
/// A sink that emits one character per `bits` bits, drawn from `digits`.
///
/// `padding` fills the last group with `=`, the way RFC 4648 does; the
/// encodings that do not pad pass `false`.
pub fn Sink::new(bits : Int32, digits : Array[Char], padding : Bool) -> Sink {
  {
    digits,
    bits,
    pad: padding,
    buffer: 0,
    held: 0,
    count: 0,
    out: StringBuilder(),
  }
}

///|
/// Feed the next chunk. Nothing is emitted until there are enough bits for a
/// whole character, so a chunk may produce no output at all.
pub fn Sink::write(self : Sink, input : BytesView) -> Unit {
  let mask = (1 << self.bits) - 1
  for i in 0..<input.length() {
    self.buffer = (self.buffer << 8) | input[i].to_int()
    self.held = self.held + 8
    while self.held >= self.bits {
      self.held = self.held - self.bits
      self.out.write_char(self.digits[(self.buffer >> self.held) & mask])
      self.count = self.count + 1
    }
    self.buffer = self.buffer & ((1 << self.held) - 1)
  }
}

///|
/// Take what has been produced so far and forget it, for a caller writing to a
/// socket who does not want to hold the whole output in memory.
///
/// The half-finished character stays behind, so the next [`write`](#write)
/// picks up where this one stopped.
pub fn Sink::drain(self : Sink) -> String {
  let text = self.out.to_string()
  self.out.reset()
  text
}

///|
/// Close the sink: flush the trailing bits, add the padding, and return
/// everything that has not been drained yet.
///
/// The trailing partial group is shifted up and filled with zero bits, exactly
/// as the one-shot encoder does it. Writing after this call is a mistake with
/// no defined result.
pub fn Sink::finish(self : Sink) -> String {
  if self.held > 0 {
    let mask = (1 << self.bits) - 1
    self.out.write_char(
      self.digits[(self.buffer << (self.bits - self.held)) & mask],
    )
    self.count = self.count + 1
    self.held = 0
    self.buffer = 0
  }
  if self.pad {
    let group = chars_per_group(self.bits)
    while self.count % group != 0 {
      self.out.write_char('=')
      self.count = self.count + 1
    }
  }
  self.out.to_string()
}

///|
/// A streaming decoder: text goes in a chunk at a time, bytes come out.
///
/// The mirror of [`Sink`]. A character may straddle two chunks, so the decoder
/// keeps the bits it cannot yet turn into a byte; and because it remembers how
/// many characters it has seen, a failure found in the third chunk still names
/// the index it would have had if the whole input had arrived at once.
pub struct Source {
  priv lookup : Array[Int32]
  priv bits : Int32
  priv lossy : Bool
  priv mut buffer : Int32
  priv mut held : Int32
  priv mut taken : Int32
  priv mut seen : Int32
  priv mut padding : Bool
  priv out : Array[Byte]
}

///|
/// A source that reads one character per `bits` bits out of `lookup`.
///
/// `lossy` skips anything outside the alphabet instead of failing, the way
/// [`decode_lossy`](#decode_lossy) does.
pub fn Source::new(bits : Int32, lookup : Array[Int32], lossy : Bool) -> Source {
  {
    lookup,
    bits,
    lossy,
    buffer: 0,
    held: 0,
    taken: 0,
    seen: 0,
    padding: false,
    out: [],
  }
}

///|
/// Feed the next chunk of text. Fails at the first character that is not in the
/// alphabet, naming the index it has in the whole input rather than in the
/// chunk.
pub fn Source::write(self : Source, input : StringView) -> Unit raise Malformed {
  for i in 0..<input.length() {
    let code = input[i].to_int()
    let at = self.seen
    self.seen = self.seen + 1
    if code == 61 {
      self.padding = true
      continue
    }
    if self.padding && !self.lossy {
      raise Padding(at~)
    }
    let value = if code >= 0 && code < 128 { self.lookup[code] } else { -1 }
    if value < 0 {
      if self.lossy {
        continue
      }
      raise Bad(at~, char=code.unsafe_to_char())
    }
    self.buffer = (self.buffer << self.bits) | value
    self.held = self.held + self.bits
    self.taken = self.taken + 1
    while self.held >= 8 {
      self.held = self.held - 8
      self.out.push(((self.buffer >> self.held) & 0xff).to_byte())
    }
    self.buffer = self.buffer & ((1 << self.held) - 1)
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
/// Fails if the input ends in the middle of a group — a whole character that
/// cannot become a byte — with the same [`Truncated`](#Truncated) the one-shot
/// decoder raises.
pub fn Source::finish(self : Source) -> Bytes raise Malformed {
  if self.taken * self.bits % 8 >= self.bits {
    raise Truncated(at=self.seen)
  }
  let bytes = Bytes::from_array(self.out)
  self.out.clear()
  bytes
}

///|
/// How many characters make a whole number of bytes.
fn chars_per_group(bits : Int32) -> Int32 {
  let mut chars = 1
  while chars * bits % 8 != 0 {
    chars = chars + 1
  }
  chars
}
