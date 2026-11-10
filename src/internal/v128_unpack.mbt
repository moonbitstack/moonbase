// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// How a six-bit alphabet reads a character back into its value, worked out once
/// per call from the lookup table.
///
/// The high nibble of an ASCII character is a hash onto sixteen classes, and
/// inside one class every character of the alphabet differs from its value by the
/// same constant — so reading a character back is one table lookup and one
/// subtraction. The characters of a class are also contiguous, which is what
/// makes one unsigned compare enough to tell a character of the alphabet from
/// anything else that happened to land in the same class.
#cfg(target="wasm")
priv struct Sextets {
  /// What to subtract, per class.
  offset : V128
  /// The first character of the class.
  first : V128
  /// How many characters the class holds.
  span : V128
  /// A character whose high nibble puts it in a class it does not belong to, and
  /// the class it is moved to instead. Base64's `/` sits below `0`, and base64url's
  /// `_` above `Z`, so each of them is one such character.
  stray_a : V128
  shift_a : V128
  stray_b : V128
  shift_b : V128
  one_stray : Bool
  two_strays : Bool
}

///|
/// The class table of a six-bit alphabet, or `None` when its characters do not
/// divide into contiguous nibbles — an alphabet that reads either case has two
/// spellings of every value and one that skips letters has holes in a run.
#cfg(target="wasm")
#warnings("-14")
fn sextets_of(lookup : Array[Int32]) -> Sextets? {
  // Value to character, and the count that proves the spelling is the only one.
  let chars : Array[Int32] = Array::make(64, -1)
  let mut count = 0
  for c in 0..<128 {
    let value = lookup[c]
    if value >= 0 {
      guard value < 64 else { return None }
      guard chars[value] < 0 else { return None }
      chars[value] = c
      count = count + 1
    }
  }
  guard count == 64 else { return None }
  let offsets : Array[Int32] = Array::make(16, 0)
  let firsts : Array[Int32] = Array::make(16, 0)
  let spans : Array[Int32] = Array::make(16, 0)
  let used : Array[Bool] = Array::make(16, false)
  let strays : Array[(Int32, Int32)] = []
  for value in 0..<64 {
    let c = chars[value]
    guard c >= 0 && c < 128 else { return None }
    let class = c >> 4
    let offset = c - value
    if !used[class] {
      used[class] = true
      offsets[class] = offset
      firsts[class] = c
      spans[class] = 1
    } else if offsets[class] == offset {
      // A character that does not follow the one before it leaves a hole, and a
      // hole makes the compare that validates a block refuse a good character.
      guard c == firsts[class] + spans[class] else { return None }
      spans[class] = spans[class] + 1
    } else {
      strays.push((c, offset))
    }
  }
  guard strays.length() <= 2 else { return None }
  let marks : Array[Int32] = Array::make(2, 0)
  let shifts : Array[Int32] = Array::make(2, 0)
  let mut index = 0
  for stray in strays {
    let (c, offset) = stray
    let class = c >> 4
    // The nearest free class keeps the shift small, and a shift of minus one is
    // the compare's own mask, so it needs no second operation.
    let mut slot = -1
    if class > 0 && !used[class - 1] {
      slot = class - 1
    } else if class < 15 && !used[class + 1] {
      slot = class + 1
    } else {
      for s in 0..<16 {
        if !used[s] {
          slot = s
          break
        }
      }
    }
    guard slot >= 0 else { return None }
    used[slot] = true
    offsets[slot] = offset
    firsts[slot] = c
    spans[slot] = 1
    marks[index] = c
    shifts[index] = slot - class
    index = index + 1
  }
  let offset_bytes : Array[Byte] = Array::make(16, b'\x00')
  let first_bytes : Array[Byte] = Array::make(16, b'\x00')
  let span_bytes : Array[Byte] = Array::make(16, b'\x00')
  for i in 0..<16 {
    offset_bytes[i] = (offsets[i] & 0xFF).to_byte()
    first_bytes[i] = (firsts[i] & 0xFF).to_byte()
    span_bytes[i] = spans[i].to_byte()
  }
  Some(Sextets::{
    offset: vector(offset_bytes),
    first: vector(first_bytes),
    span: vector(span_bytes),
    stray_a: @v128.i8x16_splat((marks[0] & 0xFF).to_byte()),
    shift_a: @v128.i8x16_splat((shifts[0] & 0xFF).to_byte()),
    stray_b: @v128.i8x16_splat((marks[1] & 0xFF).to_byte()),
    shift_b: @v128.i8x16_splat((shifts[1] & 0xFF).to_byte()),
    one_stray: strays.length() >= 1,
    two_strays: strays.length() == 2,
  })
}

///|
/// Four sextets a lane into three bytes a lane, most significant first, with the
/// four leftover lanes zeroed for the store that follows.
#cfg(target="wasm")
#inline
#warnings("-14")
fn sextets_to_bytes(sextets : V128) -> V128 {
  let groups = @v128.v128_or_(
    @v128.v128_or_(
      @v128.i32x4_shl(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x0000003F)),
        18,
      ),
      @v128.i32x4_shl(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x00003F00)),
        4,
      ),
    ),
    @v128.v128_or_(
      @v128.i32x4_shr_u(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x003F0000)),
        10,
      ),
      @v128.i32x4_shr_u(
        @v128.v128_and_(sextets, @v128.i32x4_splat(0x3F000000)),
        24,
      ),
    ),
  )
  @v128.i8x16_shuffle(
    groups, groups, 2, 1, 0, 6, 5, 4, 10, 9, 8, 14, 13, 12, 0, 0, 0, 0,
  )
}

///|
/// How much input the sixteen-wide decoder wants before it is worth setting up:
/// below this, reading a 128-entry table and building three vectors costs more
/// than the whole decode, and the scalar loop's four-at-a-time path is cheaper.
#cfg(target="wasm")
const SIX_WIDE_FLOOR : Int32 = 128

///|
/// Sixteen characters at a time, on the one backend where that pays.
///
/// A MoonBit string is UTF-16, so sixteen characters are two `i16x8` loads
/// narrowed to one vector of bytes. The high nibble then names a class, one
/// lookup gives the constant to subtract, and a second lookup gives the class's
/// first character and width — which is the only check this path makes, and it is
/// exact: a character of the class passes, and one that is not is either short of
/// the class's first character, in which case the subtraction wraps, or past its
/// last, in which case the compare fails.
///
/// What this cannot take a block of — a `=`, a blank, a character outside the
/// alphabet, a tail shorter than a window — stops the loop at that index, and the
/// scalar loop that follows owns the padding and error rules and names the
/// position. Nothing is decided here that the scalar loop would decide
/// differently; this only avoids the work of doing it a character at a time.
///
/// The four bytes a block leaves in the destination beyond the twelve it wrote
/// are zeroes: the tail overwrites them, and the result is cut to the bytes
/// actually written.
#cfg(target="wasm")
#warnings("-14")
pub fn unpack_ascii(
  input : StringView,
  lookup : Array[Int32],
  out : FixedArray[Byte],
) -> (Int32, Int32) {
  let length = input.length()
  guard length >= SIX_WIDE_FLOOR else { return (0, 0) }
  let six = match sextets_of(lookup) {
    Some(six) => six
    None => return (0, 0)
  }
  // Into registers once: a field read inside the loop is a load the body cannot
  // schedule away.
  let offset = six.offset
  let first = six.first
  let span = six.span
  let stray_a = six.stray_a
  let shift_a = six.shift_a
  let stray_b = six.stray_b
  let shift_b = six.shift_b
  let one_stray = six.one_stray
  let two_strays = six.two_strays
  let src = input.data()
  let base = input.start_offset()
  let mut index = 0
  let mut written = 0
  while index + 16 <= length && out.length() - written >= 16 {
    let ascii = @v128.i8x16_narrow_i16x8_u(
      @v128.v128_load_i16x8(src, base + index),
      @v128.v128_load_i16x8(src, base + index + 8),
    )
    let mut class = @v128.i8x16_shr_u(ascii, 4)
    if one_stray {
      class = @v128.i8x16_add(
        class,
        @v128.v128_and_(@v128.i8x16_eq(ascii, stray_a), shift_a),
      )
    }
    if two_strays {
      class = @v128.i8x16_add(
        class,
        @v128.v128_and_(@v128.i8x16_eq(ascii, stray_b), shift_b),
      )
    }
    let inside = @v128.i8x16_lt_u(
      @v128.i8x16_sub(ascii, @v128.i8x16_swizzle(first, class)),
      @v128.i8x16_swizzle(span, class),
    )
    guard @v128.i8x16_all_true(inside) else { break }
    @v128.v128_store(
      out,
      written,
      sextets_to_bytes(
        @v128.i8x16_sub(ascii, @v128.i8x16_swizzle(offset, class)),
      ),
    )
    index = index + 16
    written = written + 12
  }
  (index, written)
}

///|
/// The same answer everywhere else: no vector path, so [`unpack`](#unpack) keeps
/// its scalar loop.
#cfg(not(target="wasm"))
pub fn unpack_ascii(
  input : StringView,
  lookup : Array[Int32],
  out : FixedArray[Byte],
) -> (Int32, Int32) {
  let _ = (input, lookup, out)
  (0, 0)
}
