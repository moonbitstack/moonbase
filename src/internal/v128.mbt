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
/// How an alphabet turns a value into its character, worked out once per call.
///
/// The table is the general case: class zero is the run under the tail, class
/// `c` is the value `c` past the tail's start, and the top slot is the first run
/// — for base64 that is `+` and `/` addressed one at a time, with `A`–`Z` on the
/// top slot.
#cfg(target="wasm")
priv struct Naming {
  table : V128
  /// The alphabet itself, when a value is small enough to index it.
  direct : V128
  below : V128
  head : V128
  at : V128
  base : V128
  step : V128
  one : V128
  fifteen : V128
  /// Whether the table path's tail is one run, which a compare can express.
  tail_single : Bool
  shape : Shape
}

///|
/// The four shapes an alphabet can take, cheapest first.
#cfg(target="wasm")
priv enum Shape {
  /// One run: the character is the value plus a constant.
  Constant
  /// A value small enough to be a lane index: one lookup in a sixteen-lane
  /// table, which is what a hexadecimal digit is.
  Direct
  /// Two runs: the constant, plus a step once the value passes the boundary.
  Two
  /// Otherwise: a table entry, addressed by the value's distance past the tail.
  Table
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
/// - **name.** The alphabet decides how, and the cheapest of four ways is
///   derived from its runs rather than written for one spelling: a constant for
///   a single run, a lane-index lookup for a value that fits a lane, one compare
///   and a step for two runs, and otherwise a table addressed by how far past the
///   last run the value sits.
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
  // value plus a fixed offset. Sixteen runs is the table's width, and the last
  // run of a spelling narrow enough to vectorise always falls inside it.
  let starts : Array[Int32] = Array::make(16, 0)
  let offsets : Array[Int32] = Array::make(16, 0)
  let mut runs = 1
  let mut previous = digits[0].to_int()
  offsets[0] = previous
  for i in 1..<base {
    let offset = digits[i].to_int() - i
    if offset != previous {
      guard runs < 16 else { return None }
      starts[runs] = i
      offsets[runs] = offset
      runs = runs + 1
      previous = offset
    }
  }

  // Which shape names a value cheapest depends on how many runs the alphabet
  // has, and a run is a stretch of characters whose offsets from their values
  // are equal:
  //
  // - one run — base2's `01`, base8's `0`–`7` — needs no naming at all, just the
  //   constant added to the value.
  // - a value that fits a lane — a hexadecimal digit — is its own lane index, so
  //   the alphabet is the table and one lookup is the whole job.
  // - two runs — hex in either case, base32's standard and hexadecimal
  //   spellings — need one compare and one conditional step.
  // - anything else is driven off the table described by [`Naming`](#Naming), and
  //   needs its last run narrow enough to address a value at a time: at most
  //   fifteen values, which is what `base - starts[k] <= 14` says. A head of
  //   more than one boundary would need slots that collide, so none is
  //   attempted either. z-base-32 meets neither condition — twenty-seven runs,
  //   none of them in a tail that narrow — and goes scalar.
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
  let shape = if runs == 1 {
    Constant
  } else if base <= 16 {
    // A value that fits a lane is also a lane index, so the alphabet itself is
    // the table: one lookup, no compare, no arithmetic.
    Direct
  } else if tail <= 0 {
    return None
  } else if tail == 1 && runs == 2 {
    Two
  } else {
    Table
  }
  let below = if tail > 0 { starts[tail] - 1 } else { 0 }
  let head = tail > 1
  let table : Array[Byte] = Array::make(16, b'\x00')
  // The run just under the tail is class zero.
  table[0] = ((if tail > 0 { offsets[tail - 1] } else { offsets[0] }) & 0xFF).to_byte()
  // Values from the tail's start get one class each, clamped to fourteen; a
  // single-run tail therefore keeps landing on the same entry.
  for c in 1..<15 {
    table[c] = (offsets[run_of(starts, runs, below + c)] & 0xFF).to_byte()
  }
  // The first run, when there is one, takes the top slot.
  if head {
    table[15] = (offsets[0] & 0xFF).to_byte()
  }
  let direct : Array[Byte] = Array::make(16, b'\x00')
  for i in 0..<base {
    if i < 16 {
      direct[i] = digits[i].to_int().to_byte()
    }
  }
  let names = Naming::{
    table: vector(table),
    direct: vector(direct),
    below: @v128.i8x16_splat(below.to_byte()),
    head: @v128.i8x16_splat((if head { starts[1] } else { 0 }).to_byte()),
    at: @v128.i8x16_splat(
      (if tail > 0 { starts[tail] } else { offsets[0] }).to_byte(),
    ),
    base: @v128.i8x16_splat(offsets[0].to_byte()),
    step: @v128.i8x16_splat(
      ((if tail > 0 { offsets[tail] - offsets[0] } else { 0 }) & 0xFF).to_byte(),
    ),
    one: @v128.i8x16_splat(1),
    fifteen: @v128.i8x16_splat(15),
    tail_single: runs == tail + 1,
    shape,
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
  // byte into their window; the loop shifts those two before cutting.
  let (keep, take) = masks()
  let blocks = fill(input, bits, gather, keep, take, names, out)

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
    4 => fill4(input, gather, keep, take, names, out)
    5 => fill5(input, gather, keep, take, names, out)
    6 => fill6(input, gather, keep, take, names, out)
    _ => fill2(input, gather, keep, take, names, out)
  }
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
/// A value and its character, one of three ways.
#cfg(target="wasm")
#inline
#warnings("-14")
fn name_of(
  fields : V128,
  shape : Shape,
  table : V128,
  direct : V128,
  below : V128,
  head : V128,
  at : V128,
  base : V128,
  step : V128,
  one : V128,
  fifteen : V128,
  tail_single : Bool,
) -> V128 {
  match shape {
    Constant => @v128.i8x16_add(fields, base)
    Direct => @v128.i8x16_swizzle(direct, fields)
    Two =>
      @v128.i8x16_add(
        @v128.i8x16_add(fields, base),
        @v128.v128_and_(@v128.i8x16_ge_u(fields, at), step),
      )
    Table => {
      let class = if tail_single {
        @v128.v128_or_(
          @v128.v128_and_(@v128.i8x16_ge_u(fields, at), one),
          @v128.v128_and_(@v128.i8x16_lt_u(fields, head), fifteen),
        )
      } else {
        @v128.v128_or_(
          @v128.i8x16_sub_sat_u(fields, below),
          @v128.v128_and_(@v128.i8x16_lt_u(fields, head), fifteen),
        )
      }
      @v128.i8x16_add(fields, @v128.i8x16_swizzle(table, class))
    }
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
  let direct = names.direct
  let below = names.below
  let head = names.head
  let at = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let text = name_of(
          block1(window_of(window, gather, true, keep, take)),
          shape,
          table,
          direct,
          below,
          head,
          at,
          base,
          step,
          one,
          fifteen,
          tail_single,
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[2:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
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
  let direct = names.direct
  let below = names.below
  let head = names.head
  let at = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let text = name_of(
          block2(window_of(window, gather, false, keep, take)),
          shape,
          table,
          direct,
          below,
          head,
          at,
          base,
          step,
          one,
          fifteen,
          tail_single,
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[4:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
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
  let direct = names.direct
  let below = names.below
  let head = names.head
  let at = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let text = name_of(
          block3(window_of(window, gather, true, keep, take)),
          shape,
          table,
          direct,
          below,
          head,
          at,
          base,
          step,
          one,
          fifteen,
          tail_single,
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[6:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
}

///|
/// The sixteen-wide loop for a four-bit character.
#cfg(target="wasm")
#warnings("-14")
fn fill4(
  input : BytesView,
  gather : V128,
  keep : V128,
  take : V128,
  names : Naming,
  out : FixedArray[Byte],
) -> Int32 {
  let table = names.table
  let direct = names.direct
  let below = names.below
  let head = names.head
  let at = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let text = name_of(
          block4(window_of(window, gather, false, keep, take)),
          shape,
          table,
          direct,
          below,
          head,
          at,
          base,
          step,
          one,
          fifteen,
          tail_single,
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[8:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
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
  let direct = names.direct
  let below = names.below
  let head = names.head
  let at = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let text = name_of(
          block5(window_of(window, gather, true, keep, take)),
          shape,
          table,
          direct,
          below,
          head,
          at,
          base,
          step,
          one,
          fifteen,
          tail_single,
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[10:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
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
  let direct = names.direct
  let below = names.below
  let head = names.head
  let at = names.at
  let base = names.base
  let step = names.step
  let one = names.one
  let fifteen = names.fifteen
  let tail_single = names.tail_single
  let shape = names.shape
  let mut rest = input
  let mut blocks = 0
  while true {
    match rest {
      [v128le(window), ..] as current => {
        let text = name_of(
          block6(window_of(window, gather, false, keep, take)),
          shape,
          table,
          direct,
          below,
          head,
          at,
          base,
          step,
          one,
          fifteen,
          tail_single,
        )
        @v128.v128_store(out, blocks * 32, @v128.i16x8_extend_low_i8x16_u(text))
        @v128.v128_store(
          out,
          blocks * 32 + 16,
          @v128.i16x8_extend_high_i8x16_u(text),
        )
        rest = current[12:]
        blocks = blocks + 1
      }
      _ => break
    }
  }
  blocks
}
