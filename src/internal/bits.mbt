// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The bit packer behind base2, base8, base16, base32 and base64.
///
/// The five differ in one number — how many bits a character carries — and in
/// their alphabets. Writing the packing once means a fix to the padding rules
/// or the error positions lands in all five at once, and it is why each of
/// those packages is a table and five one-line functions.
///
/// On the backends with 128-bit lanes the whole input, when it is long enough,
/// is handed to [`pack_ascii`](#pack_ascii), which does the same arithmetic
/// sixteen characters wide. Everything else falls through to the loop below.
pub fn pack(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> String {
  match pack_ascii(input, bits, digits, pad) {
    Some(text) => text
    None => pack_scalar(input, bits, digits, pad)
  }
}

///|
/// The scalar packer: the definition the vector path is measured against, and
/// the implementation on every backend without lanes.
pub fn pack_scalar(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> String {
  let out = StringBuilder()
  let mut buffer = 0
  let mut held = 0
  let mask = (1 << bits) - 1
  let mut count = 0
  for i in 0..<input.length() {
    buffer = (buffer << 8) | input[i].to_int()
    held = held + 8
    while held >= bits {
      held = held - bits
      out.write_char(digits[(buffer >> held) & mask])
      count = count + 1
    }
    buffer = buffer & ((1 << held) - 1)
  }
  if held > 0 {
    out.write_char(digits[(buffer << (bits - held)) & mask])
    count = count + 1
  }
  if pad {
    let group = group_of(bits)
    while count % group != 0 {
      out.write_char('=')
      count = count + 1
    }
  }
  out.to_string()
}

///|
/// The same packing, as the ASCII bytes it would be written with.
///
/// Wire formats — an HTTP header, a gRPC metadata value — hold bytes, and
/// going through a `String` only to turn it back into bytes costs a pass over
/// the data for nothing.
pub fn pack_bytes(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> Bytes {
  let text = pack(input, bits, digits, pad)
  let out = Array::make(text.length(), b'\x00')
  for i in 0..<text.length() {
    out[i] = (text[i].to_int() & 0xff).to_byte()
  }
  Bytes::from_array(out)
}

///|
/// Unpack characters back into bytes.
///
/// `lossy` decides what an unknown character means: skipped, which is what a
/// PEM body full of newlines needs, or an error naming where it was. `padding`
/// and `strict` are the decoders' own, and do nothing when `lossy` is set.
/// `whitespace` skips exactly the four ASCII blanks and nothing else, so a
/// wrapped body decodes and a typo still fails.
pub fn unpack(
  input : StringView,
  bits : Int32,
  lookup : Array[Int32],
  lossy : Bool,
  padding? : Bool,
  strict~ : Bool = false,
  whitespace~ : Bool = false,
) -> Bytes raise @moonbase.Malformed {
  // One allocation, sized by the widest the input could decode to, instead of a
  // growable array: this loop writes a byte whenever the accumulator fills, and
  // growing for that turned out to be a fifth of what the whole decode cost.
  let out = FixedArray::make(input.length() * bits / 8 + 4, b'\x00')
  // The four-at-a-time path needs an alphabet whose characters all carry six
  // bits, and an input that nothing has to be skipped in.
  let bulk = bits == 6 && !lossy && !whitespace
  let mut written = 0
  let mut buffer = 0
  let mut held = 0
  let mut taken = 0
  let mut pads = 0
  let mut first_pad = -1
  let mut last = -1
  let mut i = 0
  while i < input.length() {
    // Four characters at a time when they are four plain characters of a
    // six-bit alphabet: twenty-four bits become three bytes with no
    // accumulator, no inner loop and no per-character mask. Anything else — a
    // blank, a `=`, a character outside the alphabet, the tail — falls through
    // to the loop below, which is still the only place the rules live. A `=`
    // already passed also stops it: the input has said where it ends, and a
    // character after that is a lie about the length the loop has to rule on.
    if bulk &&
      first_pad < 0 &&
      i + 4 <= input.length() &&
      out.length() - written >= 4 {
      let c0 = input[i].to_int()
      let c1 = input[i + 1].to_int()
      let c2 = input[i + 2].to_int()
      let c3 = input[i + 3].to_int()
      if c0 < 128 && c1 < 128 && c2 < 128 && c3 < 128 {
        let v0 = lookup[c0]
        let v1 = lookup[c1]
        let v2 = lookup[c2]
        let v3 = lookup[c3]
        // A miss is -1, and -1 survives an or, so one check covers all four.
        let all = v0 | v1 | v2 | v3
        if all >= 0 && all < 64 {
          out[written] = ((v0 << 2) | (v1 >> 4)).to_byte()
          out[written + 1] = (((v1 & 15) << 4) | (v2 >> 2)).to_byte()
          out[written + 2] = (((v2 & 3) << 6) | v3).to_byte()
          written = written + 3
          taken = taken + 4
          last = i + 3
          i = i + 4
          continue
        }
      }
    }
    let code = input[i].to_int()
    if whitespace && blank(code) {
      i = i + 1
      continue
    }
    if code == 61 {
      if first_pad < 0 {
        first_pad = i
      }
      pads = pads + 1
      i = i + 1
      continue
    }
    if first_pad >= 0 && !lossy {
      // Padding closes the input: anything after it is a lie about the length.
      raise @moonbase.Padding(at=i)
    }
    let value = if code >= 0 && code < 128 { lookup[code] } else { -1 }
    if value < 0 {
      if lossy {
        i = i + 1
        continue
      }
      raise @moonbase.Bad(at=i, char=code.unsafe_to_char())
    }
    buffer = (buffer << bits) | value
    held = held + bits
    taken = taken + 1
    last = i
    while held >= 8 {
      held = held - 8
      out[written] = ((buffer >> held) & 0xff).to_byte()
      written = written + 1
    }
    buffer = buffer & ((1 << held) - 1)
    i = i + 1
  }
  if taken * bits % 8 >= bits {
    // A whole character is left over that cannot become a byte.
    raise @moonbase.Truncated(at=input.length())
  }
  if lossy {
    return Bytes::from_array(out[:written])
  }
  let group = group_of(bits)
  let want = (group - taken % group) % group
  match padding {
    Some(true) if pads < want => raise @moonbase.Padding(at=input.length())
    Some(true) if pads > want => raise @moonbase.Padding(at=first_pad + want)
    Some(false) if pads > 0 => raise @moonbase.Padding(at=first_pad)
    _ => ()
  }
  if strict {
    if pads > 0 && pads != want {
      raise @moonbase.Padding(at=first_pad)
    }
    // RFC 4648 §3.5: the bits left over after the last whole byte are zero, so
    // that each byte string has one spelling and two spellings never compare
    // equal by accident.
    if buffer != 0 {
      raise @moonbase.Padding(at=last)
    }
  }
  Bytes::from_array(out[:written])
}

///|
/// Unpack from ASCII bytes, for callers who never had a string.
pub fn unpack_bytes(
  input : BytesView,
  bits : Int32,
  lookup : Array[Int32],
  lossy : Bool,
  padding? : Bool,
  strict~ : Bool = false,
  whitespace~ : Bool = false,
) -> Bytes raise @moonbase.Malformed {
  let out = StringBuilder()
  for i in 0..<input.length() {
    out.write_char(input[i].to_int().unsafe_to_char())
  }
  unpack(out.to_string(), bits, lookup, lossy, padding?, strict~, whitespace~)
}

///|
/// The four ASCII blanks a line-wrapped body is folded with: space, tab, line
/// feed, carriage return. Form feed and vertical tab are left out on purpose —
/// nothing writes them, so meeting one is a sign the input is not what it says.
pub fn blank(code : Int32) -> Bool {
  code == 32 || code == 9 || code == 10 || code == 13
}

///|
/// The 128-entry table that turns a character into its digit value.
pub fn lookup_of(chars : String) -> Array[Int32] {
  let table = Array::make(128, -1)
  let digits = chars.to_array()
  for i in 0..<digits.length() {
    let code = digits[i].to_int()
    if code >= 0 && code < 128 {
      table[code] = i
    }
  }
  table
}

///|
/// The same table, accepting either case, for the encodings whose decoders do.
pub fn lookup_of_both(lower : String, upper : String) -> Array[Int32] {
  let table = lookup_of(lower)
  let digits = upper.to_array()
  for i in 0..<digits.length() {
    let code = digits[i].to_int()
    if code >= 0 && code < 128 {
      table[code] = i
    }
  }
  table
}

///|
/// How many characters make a whole number of bytes.
pub fn group_of(bits : Int32) -> Int32 {
  let mut chars = 1
  while chars * bits % 8 != 0 {
    chars = chars + 1
  }
  chars
}
