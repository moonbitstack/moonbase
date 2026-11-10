// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Writes one ASCII character as a little-endian UTF-16 code unit.
#cfg(target="wasm")
#inline
fn write_code_unit(out : FixedArray[Byte], offset : Int32, code : Byte) -> Unit {
  out[offset] = code
  out[offset + 1] = 0
}

///|
/// Four masked fields, or-ed into one lane.
#cfg(target="wasm")
#inline
#warnings("-14")
fn join(a : V128, b : V128, c : V128, d : V128) -> V128 {
  @v128.v128_or_(@v128.v128_or_(a, b), @v128.v128_or_(c, d))
}

///|
/// The two masks the half-byte correction of an odd width needs: the low byte
/// pair of each 32-bit lane, and the high pair.
#cfg(target="wasm")
#warnings("-14")
fn masks() -> (V128, V128) {
  (
    vector(
      [0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0].map(fn(
          value,
        ) {
          value.to_byte()
        },
      ),
    ),
    vector(
      [0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF].map(fn(
          value,
        ) {
          value.to_byte()
        },
      ),
    ),
  )
}

// The four cuts, one function to a bit width. The shift amounts have to be
// literals: a vector shift takes its count from the instruction itself, so a
// count the compiler only knows at run time falls back to a lane-by-lane
// version and the whole path loses to the scalar loop.

///|
/// One bit a character.
#cfg(target="wasm")
#inline
#warnings("-14")
fn block1(lanes : V128) -> V128 {
  join(
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 31), @v128.i32x4_splat(0x00000001)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 22), @v128.i32x4_splat(0x00000100)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 13), @v128.i32x4_splat(0x00010000)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 4), @v128.i32x4_splat(0x01000000)),
  )
}

///|
/// Two bits a character.
#cfg(target="wasm")
#inline
#warnings("-14")
fn block2(lanes : V128) -> V128 {
  join(
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 30), @v128.i32x4_splat(0x00000003)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 20), @v128.i32x4_splat(0x00000300)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 10), @v128.i32x4_splat(0x00030000)),
    @v128.v128_and_(lanes, @v128.i32x4_splat(0x03000000)),
  )
}

///|
/// Three bits a character — the first width that needs a leftward cut, because
/// four characters of three bits are twelve bits and have to be spread across
/// thirty-two.
#cfg(target="wasm")
#inline
#warnings("-14")
fn block3(lanes : V128) -> V128 {
  join(
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 29), @v128.i32x4_splat(0x00000007)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 18), @v128.i32x4_splat(0x00000700)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 7), @v128.i32x4_splat(0x00070000)),
    @v128.v128_and_(@v128.i32x4_shl(lanes, 4), @v128.i32x4_splat(0x07000000)),
  )
}

///|
/// Five bits a character.
#cfg(target="wasm")
#inline
#warnings("-14")
fn block5(lanes : V128) -> V128 {
  join(
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 27), @v128.i32x4_splat(0x0000001F)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 14), @v128.i32x4_splat(0x00001F00)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 1), @v128.i32x4_splat(0x001F0000)),
    @v128.v128_and_(@v128.i32x4_shl(lanes, 12), @v128.i32x4_splat(0x1F000000)),
  )
}

///|
/// Six bits a character.
#cfg(target="wasm")
#inline
#warnings("-14")
fn block6(lanes : V128) -> V128 {
  join(
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 26), @v128.i32x4_splat(0x0000003F)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 12), @v128.i32x4_splat(0x00003F00)),
    @v128.v128_and_(@v128.i32x4_shl(lanes, 2), @v128.i32x4_splat(0x003F0000)),
    @v128.v128_and_(@v128.i32x4_shl(lanes, 16), @v128.i32x4_splat(0x3F000000)),
  )
}

///|
/// How many characters a whole input of `length` bytes becomes, padding counted.
#cfg(target="wasm")
fn char_count(length : Int32, bits : Int32, pad : Bool) -> Int32 {
  let mut chars = (length * 8 + bits - 1) / bits
  if pad {
    let group = group_of(bits)
    chars = (chars + group - 1) / group * group
  }
  chars
}

///|
/// The characters the windows did not cover, and the padding, one at a time —
/// the same arithmetic the scalar packer uses.
#cfg(target="wasm")
fn write_tail(
  out : FixedArray[Byte],
  rest : BytesView,
  bits : Int32,
  digits : Array[Char],
  at_start : Int32,
  chars : Int32,
) -> Unit {
  let mask = (1 << bits) - 1
  let mut at = at_start
  let mut buffer = 0
  let mut held = 0
  for i in 0..<rest.length() {
    buffer = (buffer << 8) | rest[i].to_int()
    held = held + 8
    while held >= bits {
      held = held - bits
      write_code_unit(
        out,
        at * 2,
        digits[(buffer >> held) & mask].to_int().to_byte(),
      )
      at = at + 1
    }
    buffer = buffer & ((1 << held) - 1)
  }
  if held > 0 {
    write_code_unit(
      out,
      at * 2,
      digits[(buffer << (bits - held)) & mask].to_int().to_byte(),
    )
    at = at + 1
  }
  while at < chars {
    write_code_unit(out, at * 2, b'=')
    at = at + 1
  }
}

///|
/// Sixteen bytes a window to thirty-two characters, for the one alphabet whose
/// characters are nibbles.
///
/// A hexadecimal digit is a nibble, so the alphabet is a sixteen-lane table and
/// the whole job is one load, two shuffles and two lookups: the high and low
/// nibbles of sixteen bytes are interleaved into output order, and each one is
/// named by a `i8x16_swizzle` into the alphabet. Thirty-two characters then
/// leave as four stores, two per vector, because a MoonBit character is a UTF-16
/// code unit.
#cfg(target="wasm")
#warnings("-14")
fn pack_nibbles(input : BytesView, digits : Array[Char], pad : Bool) -> String? {
  let chars = char_count(input.length(), 4, pad)
  let out = FixedArray::make(chars * 2, b'\x00')
  let table = table_of(digits, 16)
  let data = input.data()
  let start = input.start_offset()
  let length = input.length()
  let mut at = 0
  let mut written = 0
  while at + 16 <= length {
    let window = data.unsafe_extract_v128_aligned(start + at)
    let high = @v128.i8x16_shr_u(window, 4)
    let low = @v128.v128_and_(window, @v128.i8x16_splat(0x0F))
    // Source byte k becomes the characters at 2k (its high nibble) and 2k + 1
    // (its low nibble), so the two halves of the output are one shuffle each.
    let first = @v128.i8x16_shuffle(
      high, low, 0, 16, 1, 17, 2, 18, 3, 19, 4, 20, 5, 21, 6, 22, 7, 23,
    )
    let second = @v128.i8x16_shuffle(
      high, low, 8, 24, 9, 25, 10, 26, 11, 27, 12, 28, 13, 29, 14, 30, 15, 31,
    )
    let left = @v128.i8x16_swizzle(table, first)
    let right = @v128.i8x16_swizzle(table, second)
    @v128.v128_store(out, written, @v128.i16x8_extend_low_i8x16_u(left))
    @v128.v128_store(out, written + 16, @v128.i16x8_extend_high_i8x16_u(left))
    @v128.v128_store(out, written + 32, @v128.i16x8_extend_low_i8x16_u(right))
    @v128.v128_store(out, written + 48, @v128.i16x8_extend_high_i8x16_u(right))
    at = at + 16
    written = written + 64
  }
  write_tail(out, input[at:], 4, digits, at * 2, chars)
  Some(out.unsafe_reinterpret_as_bytes().to_unchecked_string())
}

///|
/// The window the four fields of a lane are cut from: one gather, and a
/// half-byte correction when a character is an odd number of bits wide.
#cfg(target="wasm")
#inline
#warnings("-14")
fn window_of(
  window : V128,
  gather : V128,
  odd : Bool,
  keep : V128,
  take : V128,
) -> V128 {
  let lanes = @v128.i8x16_swizzle(window, gather)
  if odd {
    let shifted = @v128.i32x4_shl(lanes, 4)
    @v128.v128_or_(@v128.v128_and_(lanes, keep), @v128.v128_and_(shifted, take))
  } else {
    lanes
  }
}

///|
/// The sixteen-wide loop for a one-bit character.
#cfg(target="wasm")
#warnings("-14")
fn fill1(
  input : BytesView,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  // Out of the struct and into registers once: a field read inside the loop is
  // a load the body cannot schedule away.
  let table = names.table
  let below = names.below
  let head = names.head
  let at_ = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let data = input.data()
  let start = input.start_offset()
  let length = input.length()
  // Loaded by index rather than through a pattern: a pattern binds the rest of
  // the view, and creating that view costs two reference-counted calls a block —
  // more than the body it wraps.
  let mut at = 0
  let mut written = 0
  while at + 16 <= length {
    let text = name_of(
      block1(
        window_of(
          data.unsafe_extract_v128_aligned(start + at),
          gather,
          true,
          keep,
          take,
        ),
      ),
      shape,
      table,
      below,
      head,
      at_,
      base,
      step,
      one,
      fifteen,
      tail_single,
    )
    @v128.v128_store(out, written, @v128.i16x8_extend_low_i8x16_u(text))
    @v128.v128_store(out, written + 16, @v128.i16x8_extend_high_i8x16_u(text))
    at = at + 2
    written = written + 32
  }
  at
}

///|
/// The sixteen-wide loop for a two-bit character.
#cfg(target="wasm")
#warnings("-14")
fn fill2(
  input : BytesView,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  // Out of the struct and into registers once: a field read inside the loop is
  // a load the body cannot schedule away.
  let table = names.table
  let below = names.below
  let head = names.head
  let at_ = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let data = input.data()
  let start = input.start_offset()
  let length = input.length()
  // Loaded by index rather than through a pattern: a pattern binds the rest of
  // the view, and creating that view costs two reference-counted calls a block —
  // more than the body it wraps.
  let mut at = 0
  let mut written = 0
  while at + 16 <= length {
    let text = name_of(
      block2(
        window_of(
          data.unsafe_extract_v128_aligned(start + at),
          gather,
          false,
          keep,
          take,
        ),
      ),
      shape,
      table,
      below,
      head,
      at_,
      base,
      step,
      one,
      fifteen,
      tail_single,
    )
    @v128.v128_store(out, written, @v128.i16x8_extend_low_i8x16_u(text))
    @v128.v128_store(out, written + 16, @v128.i16x8_extend_high_i8x16_u(text))
    at = at + 4
    written = written + 32
  }
  at
}

///|
/// The sixteen-wide loop for a three-bit character.
#cfg(target="wasm")
#warnings("-14")
fn fill3(
  input : BytesView,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  // Out of the struct and into registers once: a field read inside the loop is
  // a load the body cannot schedule away.
  let table = names.table
  let below = names.below
  let head = names.head
  let at_ = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let data = input.data()
  let start = input.start_offset()
  let length = input.length()
  // Loaded by index rather than through a pattern: a pattern binds the rest of
  // the view, and creating that view costs two reference-counted calls a block —
  // more than the body it wraps.
  let mut at = 0
  let mut written = 0
  while at + 16 <= length {
    let text = name_of(
      block3(
        window_of(
          data.unsafe_extract_v128_aligned(start + at),
          gather,
          true,
          keep,
          take,
        ),
      ),
      shape,
      table,
      below,
      head,
      at_,
      base,
      step,
      one,
      fifteen,
      tail_single,
    )
    @v128.v128_store(out, written, @v128.i16x8_extend_low_i8x16_u(text))
    @v128.v128_store(out, written + 16, @v128.i16x8_extend_high_i8x16_u(text))
    at = at + 6
    written = written + 32
  }
  at
}

///|
/// The sixteen-wide loop for a five-bit character.
#cfg(target="wasm")
#warnings("-14")
fn fill5(
  input : BytesView,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  // Out of the struct and into registers once: a field read inside the loop is
  // a load the body cannot schedule away.
  let table = names.table
  let below = names.below
  let head = names.head
  let at_ = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let data = input.data()
  let start = input.start_offset()
  let length = input.length()
  // Loaded by index rather than through a pattern: a pattern binds the rest of
  // the view, and creating that view costs two reference-counted calls a block —
  // more than the body it wraps.
  let mut at = 0
  let mut written = 0
  while at + 16 <= length {
    let text = name_of(
      block5(
        window_of(
          data.unsafe_extract_v128_aligned(start + at),
          gather,
          true,
          keep,
          take,
        ),
      ),
      shape,
      table,
      below,
      head,
      at_,
      base,
      step,
      one,
      fifteen,
      tail_single,
    )
    @v128.v128_store(out, written, @v128.i16x8_extend_low_i8x16_u(text))
    @v128.v128_store(out, written + 16, @v128.i16x8_extend_high_i8x16_u(text))
    at = at + 10
    written = written + 32
  }
  at
}

///|
/// The sixteen-wide loop for a six-bit character.
#cfg(target="wasm")
#warnings("-14")
fn fill6(
  input : BytesView,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  // Out of the struct and into registers once: a field read inside the loop is
  // a load the body cannot schedule away.
  let table = names.table
  let below = names.below
  let head = names.head
  let at_ = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let data = input.data()
  let start = input.start_offset()
  let length = input.length()
  // Loaded by index rather than through a pattern: a pattern binds the rest of
  // the view, and creating that view costs two reference-counted calls a block —
  // more than the body it wraps.
  let mut at = 0
  let mut written = 0
  while at + 16 <= length {
    let text = name_of(
      block6(
        window_of(
          data.unsafe_extract_v128_aligned(start + at),
          gather,
          false,
          keep,
          take,
        ),
      ),
      shape,
      table,
      below,
      head,
      at_,
      base,
      step,
      one,
      fifteen,
      tail_single,
    )
    @v128.v128_store(out, written, @v128.i16x8_extend_low_i8x16_u(text))
    @v128.v128_store(out, written + 16, @v128.i16x8_extend_high_i8x16_u(text))
    at = at + 12
    written = written + 32
  }
  at
}

///|
/// A block of bytes to sixteen characters, with the two decisions the body
/// makes — how wide a character is, and which shape names it — taken here
/// rather than inside the loop.
///
/// A function bound once and called from the loop looked like the cheaper
/// arrangement and measured 6.8 ns a block, more than the body itself: a call
/// the compiler cannot see through costs that much on this backend. Branching
/// to a direct call costs nothing measurable, so every width gets its own loop
/// and every shape is a branch inside it.
#cfg(target="wasm")
#warnings("-14")
fn fill(
  input : BytesView,
  bits : Int32,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  match bits {
    1 => fill1(input, gather, keep, take, names, out)
    3 => fill3(input, gather, keep, take, names, out)
    5 => fill5(input, gather, keep, take, names, out)
    6 => fill6(input, gather, keep, take, names, out)
    // Two bits a character, the only other width the kernel carries.
    _ => fill2(input, gather, keep, take, names, out)
  }
}

///|
/// Bit packing, sixteen characters at a time, for every width but the nibble.
///
/// [`pack`](#pack) is a loop over characters. This is the same loop done
/// sixteen-wide, in three steps that map onto the encoding rather than onto one
/// alphabet:
///
/// - **gather.** Sixteen characters of `bits` bits are `2 * bits` bytes. One
///   `i8x16_swizzle` reads the four bytes each output lane needs, so the lanes
///   may overlap and the window is loaded once.
/// - **cut.** Inside a lane the four fields sit at fixed offsets, so each one is
///   a shift and a mask — no per-character table, no branch on the bit count.
/// - **name.** The alphabet decides how, and the cheapest of three ways is
///   derived from its runs rather than written for one spelling: a constant for
///   a single run, one compare and a step for two, and otherwise a table
///   addressed by how far past its last run the value sits.
///
/// Both decisions are branches inside the loop and not functions bound before
/// it, because binding either one measured 6.8 ns a block — more than the body
/// itself, on a backend where a call the compiler cannot see through is that
/// expensive. Per-width loops and direct calls cost nothing measurable.
///
/// Anything that is not a whole block — the last few bytes, the trailing `=`,
/// an alphabet whose runs are too many and too wide for either shape — is left
/// to the scalar path: this answers `None` rather than a short string, so `pack`
/// can hand the whole input to the loop it already had.
#cfg(target="wasm")
#warnings("-14")
fn pack_bits(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> String? {
  let base = 1 << bits
  let names = match naming_of(digits, base) {
    Some(names) => names
    None => return None
  }
  let chars = char_count(input.length(), bits, pad)
  let out = FixedArray::make(chars * 2, b'\x00')

  // Lane `j` reads the four bytes that begin at bit `j * 4 * bits`. The read is
  // reversed because a lane is little-endian and the bit stream is not.
  let gather_bytes : Array[Byte] = Array::make(16, b'\x00')
  for j in 0..<4 {
    let start = j * bits / 2
    gather_bytes[j * 4] = (start + 3).to_byte()
    gather_bytes[j * 4 + 1] = (start + 2).to_byte()
    gather_bytes[j * 4 + 2] = (start + 1).to_byte()
    gather_bytes[j * 4 + 3] = start.to_byte()
  }
  let gather = vector(gather_bytes)
  // An odd number of bits leaves the second and fourth lanes starting half a
  // byte into their window; the loop shifts those two before cutting.
  let (keep, take) = masks()
  let consumed = fill(input, bits, gather, keep, take, names, out)
  write_tail(out, input[consumed:], bits, digits, consumed * 8 / bits, chars)
  Some(out.unsafe_reinterpret_as_bytes().to_unchecked_string())
}

///|
/// Sixteen characters at a time, on the one backend where that pays.
///
/// The gate is `wasm`, not "every backend with a 128-bit type": on the native
/// backend of the toolchain this was built against, a `V128` operation lowers to
/// a lane-by-lane sequence, and the same input measured nine to nineteen times
/// slower through this path than through the scalar loop.
///
/// The nibble alphabet takes a path of its own; every other width goes through
/// the kernel in [`pack_bits`](#pack_bits).
#cfg(target="wasm")
pub fn pack_ascii(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> String? {
  guard bits >= 1 && bits <= 6 && digits.length() >= 1 << bits else {
    return None
  }
  // Below one window there is nothing to gather from.
  guard input.length() >= 16 else { return None }
  // The vector stores are not bounds checked, so an input whose UTF-16 buffer
  // would wrap is refused before the allocation.
  guard input.length() <= 0x0FFF_FFFF else { return None }
  if bits == 4 {
    pack_nibbles(input, digits, pad)
  } else {
    pack_bits(input, bits, digits, pad)
  }
}

///|
/// The same answer everywhere else: no vector path, so [`pack`](#pack) keeps its
/// scalar loop.
#cfg(not(target="wasm"))
pub fn pack_ascii(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> String? {
  let _ = (input, bits, digits, pad)
  None
}
