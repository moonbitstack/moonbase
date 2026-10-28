// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// A string of ASCII, as the bytes it is written with.
pub fn ascii(text : String) -> Bytes {
  let out = Array::make(text.length(), b'\x00')
  for i in 0..<text.length() {
    out[i] = (text[i].to_int() & 0xff).to_byte()
  }
  Bytes::from_array(out)
}

///|
/// ASCII bytes, as the string they spell.
pub fn text_of(input : BytesView) -> String {
  let out = StringBuilder()
  for i in 0..<input.length() {
    out.write_char(input[i].to_int().unsafe_to_char())
  }
  out.to_string()
}
