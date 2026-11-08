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
/// Sixteen bytes as a vector.
#cfg(target="wasm")
#inline
#warnings("-14")
fn vector(bytes : Array[Byte]) -> V128 {
  @v128.v128_load(FixedArray::from_array(bytes), 0)
}

///|
/// Four masked fields, or-ed into one lane.
#cfg(target="wasm")
#inline
#warnings("-14")
fn join(a : V128, b : V128, c : V128, d : V128) -> V128 {
  @v128.v128_or_(@v128.v128_or_(a, b), @v128.v128_or_(c, d))
}

// The four cuts, one function to a bit width. The shift amounts have to be
// literals: a vector shift takes its count from the instruction itself, so a
// count the compiler only knows at run time falls back to a lane-by-lane
// version and the whole path loses to the scalar loop. `bits` is therefore
// branched on once per block, and each block is straight-line.

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
/// Four bits a character.
#cfg(target="wasm")
#inline
#warnings("-14")
fn block4(lanes : V128) -> V128 {
  join(
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 28), @v128.i32x4_splat(0x0000000F)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 16), @v128.i32x4_splat(0x00000F00)),
    @v128.v128_and_(@v128.i32x4_shr_u(lanes, 4), @v128.i32x4_splat(0x000F0000)),
    @v128.v128_and_(@v128.i32x4_shl(lanes, 8), @v128.i32x4_splat(0x0F000000)),
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
/// Sixteen characters at a time, on the one backend where that pays.
///
/// The gate is `wasm`, not "every backend with a 128-bit type": on the native
/// backend of the toolchain this was built against, a `V128` operation lowers to
/// a lane-by-lane sequence, and the same input measured nine to nineteen times
/// slower through this path than through the scalar loop. The scalar loop is
/// what native gets, and it is the faster of the two there by a wide margin —
/// the same reason the core encoders' vector paths are slower than their scalar
/// ones on native.
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
/// - **name.** An alphabet is a sequence of constant-offset runs, and a value's
///   run is one table entry plus one compare per boundary in its group of eight
///   values. Two boundaries at most, which is what base64 needs: `+` and `/` are
///   two separate runs that share a group.
///
/// Anything that is not a whole block — the last few bytes, the trailing `=`,
/// an alphabet whose groups straddle more than two boundaries — is left to the
/// scalar path: this answers `None` rather than a short string, so `pack` can
/// hand the whole input to the loop it already had.
#cfg(target="wasm")
#warnings("-14")
pub fn pack_ascii(
  input : BytesView,
  bits : Int32,
  digits : Array[Char],
  pad : Bool,
) -> String? {
  let length = input.length()
  let base = 1 << bits
  // Six bits is the widest any package here asks for, and a lane holds four
  // characters of six bits and not one more.
  guard bits >= 1 && bits <= 6 && digits.length() >= base else { return None }
  // Below one window there is nothing to gather from.
  guard length >= 16 else { return None }
  // The vector stores are not bounds checked, so an input whose UTF-16 buffer
  // would wrap is refused before the allocation.
  guard length <= 0x0FFF_FFFF else { return None }
  let group = group_of(bits)

  // The alphabet, as runs of constant offset: within a run the character is the
  // value plus a fixed offset, and every spelling in this library is a handful
  // of runs.
  let starts : Array[Byte] = Array::make(8, b'\x00')
  let offsets : Array[Byte] = Array::make(8, b'\x00')
  let mut runs = 1
  let mut previous = digits[0].to_int()
  offsets[0] = previous.to_byte()
  for i in 1..<base {
    let offset = digits[i].to_int() - i
    if offset != previous {
      guard runs < 8 else { return None }
      starts[runs] = i.to_byte()
      offsets[runs] = (offset & 0xFF).to_byte()
      runs = runs + 1
      previous = offset
    }
  }

  // Naming a value is then a table entry and one compare per boundary in its
  // group of eight values. A group with three boundaries — Crockford's alphabet,
  // which skips I, L, O and U — is answered with `None` and goes scalar.
  let first_boundary : Array[Byte] = Array::make(16, b'\xFF')
  let second_boundary : Array[Byte] = Array::make(16, b'\xFF')
  let buckets : Array[Byte] = Array::make(16, b'\x00')
  for g in 0..<8 {
    let low = 8 * g
    let mut seen = 0
    let mut class = 0
    for r in 1..<runs {
      let start = starts[r].to_int()
      if start < low {
        class = class + 1
      } else if start < low + 8 {
        guard seen < 2 else { return None }
        if seen == 0 {
          first_boundary[g] = starts[r]
        } else {
          second_boundary[g] = starts[r]
        }
        seen = seen + 1
      }
    }
    buckets[g] = class.to_byte()
  }
  let class_offset : Array[Byte] = Array::make(16, b'\x00')
  for r in 0..<runs {
    class_offset[r] = offsets[r]
  }

  let mut chars = (length * 8 + bits - 1) / bits
  if pad {
    chars = (chars + group - 1) / group * group
  }
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
  let first_names = vector(first_boundary)
  let second_names = vector(second_boundary)
  let bucket_names = vector(buckets)
  let offset_names = vector(class_offset)
  // An odd number of bits leaves the second and fourth lanes starting half a
  // byte into their window; `fill` shifts those two before cutting.
  let odd = 4 * bits % 8 != 0
  let blocks = match bits {
    1 =>
      fill(
        input, 2, gather, odd, block1, first_names, second_names, bucket_names, offset_names,
        out,
      )
    3 =>
      fill(
        input, 6, gather, odd, block3, first_names, second_names, bucket_names, offset_names,
        out,
      )
    4 =>
      fill(
        input, 8, gather, odd, block4, first_names, second_names, bucket_names, offset_names,
        out,
      )
    5 =>
      fill(
        input, 10, gather, odd, block5, first_names, second_names, bucket_names,
        offset_names, out,
      )
    6 =>
      fill(
        input, 12, gather, odd, block6, first_names, second_names, bucket_names,
        offset_names, out,
      )
    _ =>
      fill(
        input, 4, gather, odd, block2, first_names, second_names, bucket_names, offset_names,
        out,
      )
  }

  // The bytes the window could not cover, and the padding, go in one character
  // at a time — the same arithmetic the scalar packer uses.
  let rest = input[2 * bits * blocks:]
  let mask = (1 << bits) - 1
  let mut at = blocks * 16
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
  Some(out.unsafe_reinterpret_as_bytes().to_unchecked_string())
}

///|
/// Runs the sixteen-wide loop and answers how many blocks it wrote.
#cfg(target="wasm")
#warnings("-14")
fn fill(
  input : BytesView,
  stride : Int32,
  gather : V128,
  odd : Bool,
  block : (V128) -> V128,
  first_names : V128,
  second_names : V128,
  bucket_names : V128,
  offset_names : V128,
  out : FixedArray[Byte],
) -> Int32 {
  let keep = vector(
    [0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0].map(fn(
        value,
      ) {
        value.to_byte()
      },
    ),
  )
  let take = vector(
    [0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF].map(fn(
        value,
      ) {
        value.to_byte()
      },
    ),
  )
  let one = @v128.i8x16_splat(1)
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let mut lanes = @v128.i8x16_swizzle(window, gather)
        if odd {
          let shifted = @v128.i32x4_shl(lanes, 4)
          lanes = @v128.v128_or_(
            @v128.v128_and_(lanes, keep),
            @v128.v128_and_(shifted, take),
          )
        }
        let fields = block(lanes)
        // The run of a value: the group it falls in, plus one for each boundary
        // it has passed inside that group.
        let group = @v128.i8x16_shr_u(fields, 3)
        let class = @v128.i8x16_add(
          @v128.i8x16_add(
            @v128.i8x16_swizzle(bucket_names, group),
            @v128.v128_and_(
              @v128.i8x16_ge_u(fields, @v128.i8x16_swizzle(first_names, group)),
              one,
            ),
          ),
          @v128.v128_and_(
            @v128.i8x16_ge_u(fields, @v128.i8x16_swizzle(second_names, group)),
            one,
          ),
        )
        let text = @v128.i8x16_add(
          fields,
          @v128.i8x16_swizzle(offset_names, class),
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[stride:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
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
