// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The bit packer behind base16, base32 and base64.
///
/// The three differ in one number — how many bits a character carries — and in
/// their alphabets. Writing the packing once means a fix to the padding rules
/// or the error positions lands in all three at once, and it is why each of
/// those packages is a table and five one-line functions.
pub fn pack(
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
pub fn unpack(
  input : StringView,
  bits : Int32,
  lookup : Array[Int32],
  lossy : Bool,
  padding? : Bool,
  strict~ : Bool = false,
) -> Bytes raise @moonbase.Malformed {
  let out : Array[Byte] = []
  let mut buffer = 0
  let mut held = 0
  let mut taken = 0
  let mut pads = 0
  let mut first_pad = -1
  let mut last = -1
  for i in 0..<input.length() {
    let code = input[i].to_int()
    if code == 61 {
      if first_pad < 0 {
        first_pad = i
      }
      pads = pads + 1
      continue
    }
    if first_pad >= 0 && !lossy {
      // Padding closes the input: anything after it is a lie about the length.
      raise @moonbase.Padding(at=i)
    }
    let value = if code >= 0 && code < 128 { lookup[code] } else { -1 }
    if value < 0 {
      if lossy {
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
      out.push(((buffer >> held) & 0xff).to_byte())
    }
    buffer = buffer & ((1 << held) - 1)
  }
  if taken * bits % 8 >= bits {
    // A whole character is left over that cannot become a byte.
    raise @moonbase.Truncated(at=input.length())
  }
  if lossy {
    return Bytes::from_array(out)
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
  Bytes::from_array(out)
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
) -> Bytes raise @moonbase.Malformed {
  let out = StringBuilder()
  for i in 0..<input.length() {
    out.write_char(input[i].to_int().unsafe_to_char())
  }
  unpack(out.to_string(), bits, lookup, lossy, padding?, strict~)
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
