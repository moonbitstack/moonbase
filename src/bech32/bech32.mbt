// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Which checksum: the one BIP 173 defined, or the one BIP 350 amended it to.
///
/// They are the same code with a different constant folded in at the end, so the
/// two families of strings do not overlap: a string that verifies as one never
/// verifies as the other. A witness version-0 output is bech32, everything from
/// version 1 up is bech32m. A format that has never used bech32 at all — a
/// lightning invoice, say — picks bech32m, because the amendment is the one that
/// does not have the insertion weakness.
pub(all) enum Kind {
  Bech32
  Bech32m
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with Debug::{to_repr}

///|
/// A bech32 string taken apart: the prefix a human reads, and the data a machine
/// reads.
pub(all) struct Decoded {
  /// The human-readable part, lower case.
  hrp : String
  /// The data part, as bytes.
  data : Bytes
} derive(Eq, Debug)

///|
pub extend Decoded with Eq::{equal, not_equal}

///|
pub extend Decoded with Debug::{to_repr}

///|
/// The same, before the five-bit groups have been turned back into bytes.
///
/// This is the layer the specification actually defines: BIP 173 checksums the
/// five-bit groups, and a string whose data is not a whole number of bytes is a
/// perfectly valid bech32 string — `abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw`
/// is one. Turning the groups into bytes is a separate, stricter step that a
/// checksum verifier has no business doing.
pub(all) struct Words {
  /// The human-readable part, lower case.
  hrp : String
  /// The data part, one value 0..31 per character.
  words : Bytes
}

///|
/// Encode bytes as a bech32 string.
///
/// ```moonbit nocheck
/// @bech32.encode("bc", program)        // "bc1q…"
/// @bech32.encode("tb", program, kind=Bech32m)
/// ```
///
/// The bytes are written as five-bit groups, zero-padded to a whole group, which
/// is the same `1`/`2`/`3` to `2`/`4`/`5`/`7`/`8` expansion base32 does — the
/// difference is that bech32 pads nothing back on the way in and puts a checksum
/// on the end instead.
///
/// The prefix is written lower case whatever case it arrives in: a bech32 string
/// is either all lower case or all upper case, never both, and the checksum is
/// computed over the lower-case form.
pub fn encode(
  hrp : StringView,
  input : BytesView,
  kind~ : Kind = Bech32,
) -> String raise @moonbase.Malformed {
  encode_words(hrp, words_of(input), kind~)
}

///|
/// The same encoding, as the ASCII bytes it would be written with.
pub fn encode_bytes(
  hrp : StringView,
  input : BytesView,
  kind~ : Kind = Bech32,
) -> Bytes raise @moonbase.Malformed {
  @internal.ascii(encode(hrp, input, kind~))
}

///|
/// Encode five-bit groups directly, for a format that has words of its own — a
/// segregated witness program carries its version as a group, not as a byte.
pub fn encode_words(
  hrp : StringView,
  words : BytesView,
  kind~ : Kind = Bech32,
) -> String raise @moonbase.Malformed {
  let prefix = check_hrp(hrp)
  let data : Array[Byte] = []
  for i in 0..<words.length() {
    let word = words[i].to_int()
    if word > 31 {
      raise Bad(at=i, char=word.unsafe_to_char())
    }
    data.push(word.to_byte())
  }
  if prefix.length() + 1 + data.length() + 6 > 90 {
    // BIP 173 §"Overall max length" — a 90-character string is the largest the
    // checksum is designed for; past that the guarantees are not the ones it
    // claims.
    raise Bad(at=90, char='1')
  }
  let out = StringBuilder()
  out.write_string(prefix)
  out.write_char('1')
  for byte in data {
    out.write_char(digit(byte.to_int()))
  }
  let sum = create_checksum(prefix, Bytes::from_array(data)[:], kind)
  for byte in sum {
    out.write_char(digit(byte.to_int()))
  }
  out.to_string()
}

///|
/// Decode a bech32 string to the bytes its data part stands for.
///
/// Fails if the checksum does not match, if the data does not fill whole bytes,
/// or if the padding that completes the last byte is not zero.
///
/// A segregated witness address does not fill whole bytes — its first group is a
/// version, not the top of the program — so it fails here with [`Padding`](#Padding)
/// and belongs in [`decode_words`](#decode_words). That is a property of addresses;
/// bech32 itself never promised its data would be bytes.
pub fn decode(
  input : StringView,
  kind~ : Kind = Bech32,
) -> Decoded raise @moonbase.Malformed {
  let parts = decode_words(input, kind~)
  { hrp: parts.hrp, data: bytes_of(parts.words[:]), }
}

///|
/// Decode from ASCII bytes, for callers who never had a string.
pub fn decode_bytes(
  input : BytesView,
  kind~ : Kind = Bech32,
) -> Decoded raise @moonbase.Malformed {
  decode(@internal.text_of(input), kind~)
}

///|
/// Decode, dropping the whitespace a pasted address picks up on the way.
///
/// `None` rather than a failure, because this face is for input whose quality is
/// already in doubt: a caller who wants to know what was wrong should use
/// [`decode`](#decode).
pub fn decode_lossy(input : StringView, kind~ : Kind = Bech32) -> Decoded? {
  let kept = StringBuilder()
  for i in 0..<input.length() {
    let code = input[i].to_int()
    if code != 32 && code != 9 && code != 10 && code != 13 {
      kept.write_char(input[i].unsafe_to_char())
    }
  }
  try decode(kept.to_string(), kind~) catch {
    _ => None
  } noraise {
    decoded => Some(decoded)
  }
}

///|
/// Decode to five-bit groups without turning them into bytes.
///
/// This is the check BIP 173 specifies: length, character range, one case
/// throughout, a separator, at least six checksum characters, and a checksum that
/// matches the constant of `kind`.
pub fn decode_words(
  input : StringView,
  kind~ : Kind = Bech32,
) -> Words raise @moonbase.Malformed {
  let n = input.length()
  if n > 90 {
    raise Bad(at=90, char=input[90].unsafe_to_char())
  }
  // One case only, and the checksum is computed over the lower-case form.
  let mut lower = false
  let mut upper = false
  for i in 0..<n {
    let code = input[i].to_int()
    if code < 33 || code > 126 {
      raise Bad(at=i, char=input[i].unsafe_to_char())
    }
    if code >= 97 && code <= 122 {
      lower = true
    } else if code >= 65 && code <= 90 {
      upper = true
    }
    if lower && upper {
      raise Bad(at=i, char=input[i].unsafe_to_char())
    }
  }
  let text = StringBuilder()
  for i in 0..<n {
    let code = input[i].to_int()
    text.write_char(
      if code >= 65 && code <= 90 {
        (code + 32).unsafe_to_char()
      } else {
        input[i].unsafe_to_char()
      },
    )
  }
  let flat = text.to_string()
  // The separator is the last `1`, so a prefix may contain one.
  let mut sep = -1
  for i in 0..<n {
    if flat[i].to_int() == 49 {
      sep = i
    }
  }
  if sep < 0 {
    raise Truncated(at=n)
  }
  if sep == 0 {
    raise Bad(at=0, char='1')
  }
  if n - sep - 1 < 6 {
    raise Truncated(at=n)
  }
  let hrp = flat[:sep].to_owned()
  let body_len = n - sep - 7
  let body : Array[Byte] = []
  let tail : Array[Byte] = []
  for i in 0..<(n - sep - 1) {
    let code = flat[sep + 1 + i].to_int()
    let value = if code >= 0 && code < 128 { table[code] } else { -1 }
    if value < 0 {
      raise Bad(at=sep + 1 + i, char=input[sep + 1 + i].unsafe_to_char())
    }
    if i < body_len {
      body.push(value.to_byte())
    } else {
      tail.push(value.to_byte())
    }
  }
  let sum = create_checksum(hrp, Bytes::from_array(body)[:], kind)
  for i in 0..<6 {
    if sum[i] != tail[i] {
      // The checksum is the last six characters, and they only make sense as a
      // group: the first of them is where the reader stopped believing.
      raise Checksum(at=sep + 1)
    }
  }
  { hrp, words: Bytes::from_array(body), }
}

///|
/// Eight-bit bytes to five-bit groups, zero-padded, as bech32's data part wants.
pub fn words_of(input : BytesView) -> Bytes {
  let out : Array[Byte] = []
  let mut acc = 0
  let mut held = 0
  for i in 0..<input.length() {
    acc = (acc << 8) | input[i].to_int()
    held = held + 8
    while held >= 5 {
      held = held - 5
      out.push(((acc >> held) & 31).to_byte())
    }
    acc = acc & ((1 << held) - 1)
  }
  if held > 0 {
    out.push(((acc << (5 - held)) & 31).to_byte())
  }
  Bytes::from_array(out)
}

///|
/// Five-bit groups back to bytes, strictly.
///
/// The leftover bits of the last partial byte must be fewer than five and all
/// zero: a decoder that ignores them accepts four different strings for one
/// payload, which is a malleability bug rather than a convenience.
pub fn bytes_of(words : BytesView) -> Bytes raise @moonbase.Malformed {
  let out : Array[Byte] = []
  let mut acc = 0
  let mut held = 0
  for i in 0..<words.length() {
    let word = words[i].to_int()
    if word > 31 {
      raise Bad(at=i, char=word.unsafe_to_char())
    }
    acc = (acc << 5) | word
    held = held + 5
    while held >= 8 {
      held = held - 8
      out.push(((acc >> held) & 0xff).to_byte())
    }
    acc = acc & ((1 << held) - 1)
  }
  if held >= 5 || acc != 0 {
    raise Padding(at=words.length())
  }
  Bytes::from_array(out)
}

///|
/// The constant a string of this kind has to leave in the checksum register.
fn constant_of(kind : Kind) -> Int32 {
  match kind {
    Bech32 => 1
    Bech32m => 0x2bc830a3
  }
}

///|
/// The six checksum characters for `hrp` followed by `data`.
fn create_checksum(
  hrp : StringView,
  data : BytesView,
  kind : Kind,
) -> Array[Byte] {
  let values : Array[Int32] = []
  expand_hrp(hrp, values)
  for i in 0..<data.length() {
    values.push(data[i].to_int())
  }
  for _ in 0..<6 {
    values.push(0)
  }
  let residue = polymod(values) ^ constant_of(kind)
  let out : Array[Byte] = []
  for i in 0..<6 {
    out.push(((residue >> (5 * (5 - i))) & 31).to_byte())
  }
  out
}

///|
/// The prefix, split into its high bits, a zero, and its low bits — BIP 173 §
/// "checksum", which spreads the prefix so a change in either half is a change in
/// at least two positions.
fn expand_hrp(hrp : StringView, out : Array[Int32]) -> Unit {
  for i in 0..<hrp.length() {
    out.push(hrp[i].to_int() >> 5)
  }
  out.push(0)
  for i in 0..<hrp.length() {
    out.push(hrp[i].to_int() & 31)
  }
}

///|
/// The BCH code over GF(32): one step of the shift register per value.
fn polymod(values : Array[Int32]) -> Int32 {
  let mut chk = 1
  for value in values {
    let top = chk >> 25
    chk = ((chk & 0x1ffffff) << 5) ^ value
    for i in 0..<5 {
      if ((top >> i) & 1) == 1 {
        chk = chk ^ generator[i]
      }
    }
  }
  chk
}

///|
/// Check a prefix and return it lower case.
///
/// The character range is BIP 173's: printable US-ASCII, one to eighty-three
/// characters. Below 33 the string could not be written on a line; at 127 it is
/// the character that deletes the one before it.
fn check_hrp(hrp : StringView) -> String raise @moonbase.Malformed {
  if hrp.length() == 0 {
    raise Truncated(at=0)
  }
  if hrp.length() > 83 {
    raise Bad(at=83, char=hrp[83].unsafe_to_char())
  }
  let out = StringBuilder()
  for i in 0..<hrp.length() {
    let code = hrp[i].to_int()
    if code < 33 || code > 126 {
      raise Bad(at=i, char=hrp[i].unsafe_to_char())
    }
    out.write_char(
      if code >= 65 && code <= 90 {
        (code + 32).unsafe_to_char()
      } else {
        hrp[i].unsafe_to_char()
      },
    )
  }
  out.to_string()
}

///|
/// The character for a five-bit value.
fn digit(value : Int32) -> Char {
  charset[value]
}

///|
/// BIP 173's `CHARSET`: the characters chosen so that a misread digit is visible
/// rather than plausible — no `1`, `b`, `i` or `o`.
let charset_text : String = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

///|
let charset : Array[Char] = charset_text.to_array()

///|
let table : Array[Int32] = @internal.lookup_of(charset_text)

///|
/// The generator polynomial, as BIP 173 lists it.
let generator : Array[Int32] = [
  0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3,
]
