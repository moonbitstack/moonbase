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
/// The vectors that name a value, worked out once per call.
#cfg(target="wasm")
priv struct Naming {
  table : V128
  below : V128
  head : V128
  at : V128
  one : V128
  fifteen : V128
  single : Bool
}

///|
/// Which run a value belongs to.
#cfg(target="wasm")
fn run_of(starts : Array[Int32], runs : Int32, value : Int32) -> Int32 {
  let mut r = runs - 1
  while r > 0 && starts[r] > value {
    r = r - 1
  }
  r
}

///|
/// Sixteen characters at a time, on the one backend where that pays.
///
/// The gate is `wasm`, not "every backend with a 128-bit type": on the native
/// backend of the toolchain this was built against, a `V128` operation lowers to
/// a lane-by-lane sequence, and the same input measured nine to nineteen times
/// slower through this path than through the scalar loop.
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
/// - **name.** One saturating subtract, a clamp and one lookup. The last stretch
///   of the alphabet is addressed a value at a time; everything below it is
///   class zero, or the top slot when a second run sits under it. That is the
///   shape the core encoder hand-writes for its own alphabet, derived here from
///   the alphabet instead — so base64 in both spellings, base32 in three,
///   base16 in two and Crockford's all get it.
///
/// Anything that is not a whole block — the last few bytes, the trailing `=`,
/// an alphabet whose tail is both wide and multi-run — is left to the scalar
/// path: this answers `None` rather than a short string, so `pack` can hand the
/// whole input to the loop it already had.
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

  // The alphabet as runs of constant offset: inside a run the character is the
  // value plus a fixed offset.
  let starts : Array[Int32] = Array::make(8, 0)
  let offsets : Array[Int32] = Array::make(8, 0)
  let mut runs = 1
  let mut previous = digits[0].to_int()
  offsets[0] = previous
  for i in 1..<base {
    let offset = digits[i].to_int() - i
    if offset != previous {
      guard runs < 8 else { return None }
      starts[runs] = i
      offsets[runs] = offset
      runs = runs + 1
      previous = offset
    }
  }

  // The tail has to fit a sixteen-entry table, or be a single run so that the
  // clamp folds it. A head of more than one boundary would need slots that
  // collide, so that is not attempted either. z-base-32 meets neither condition
  // — twenty-seven runs, all of them below the last — and goes scalar.
  let mut tail = -1
  for k in 1..<runs {
    if k > 2 {
      break
    }
    if base - starts[k] <= 14 || runs == k + 1 {
      tail = k
      break
    }
  }
  guard tail > 0 else { return None }
  let below = starts[tail] - 1
  let head = tail > 1
  let table : Array[Byte] = Array::make(16, b'\x00')
  // The run just under the tail is class zero.
  table[0] = (offsets[tail - 1] & 0xFF).to_byte()
  // Values from the tail's start get one class each, clamped to fourteen; a
  // single-run tail therefore keeps landing on the same entry.
  for c in 1..<15 {
    table[c] = (offsets[run_of(starts, runs, below + c)] & 0xFF).to_byte()
  }
  // The first run, when there is one, takes the top slot.
  if head {
    table[15] = (offsets[0] & 0xFF).to_byte()
  }
  let names = Naming::{
    table: vector(table),
    below: @v128.i8x16_splat(below.to_byte()),
    head: @v128.i8x16_splat((if head { starts[1] } else { 0 }).to_byte()),
    at: @v128.i8x16_splat(starts[tail].to_byte()),
    one: @v128.i8x16_splat(1),
    fifteen: @v128.i8x16_splat(15),
    single: runs == tail + 1,
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
  // An odd number of bits leaves the second and fourth lanes starting half a
  // byte into their window; `fill` shifts those two before cutting.
  let odd = 4 * bits % 8 != 0
  let blocks = match bits {
    1 => fill(input, 2, gather, odd, block1, names, out)
    3 => fill(input, 6, gather, odd, block3, names, out)
    4 => fill(input, 8, gather, odd, block4, names, out)
    5 => fill(input, 10, gather, odd, block5, names, out)
    6 => fill(input, 12, gather, odd, block6, names, out)
    _ => fill(input, 4, gather, odd, block2, names, out)
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
  names : Naming,
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
        // A tail of one run is one compare; a tail of several is a saturating
        // subtract, because each of its values has to reach its own entry.
        let class = if names.single {
          @v128.v128_or_(
            @v128.v128_and_(@v128.i8x16_ge_u(fields, names.at), names.one),
            @v128.v128_and_(@v128.i8x16_lt_u(fields, names.head), names.fifteen),
          )
        } else {
          @v128.v128_or_(
            @v128.i8x16_sub_sat_u(fields, names.below),
            @v128.v128_and_(@v128.i8x16_lt_u(fields, names.head), names.fifteen),
          )
        }
        let text = @v128.i8x16_add(
          fields,
          @v128.i8x16_swizzle(names.table, class),
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
