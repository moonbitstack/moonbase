// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Sixteen bytes as a vector.
#cfg(target="wasm")
#inline
#warnings("-14")
fn vector(bytes : Array[Byte]) -> V128 {
  @v128.v128_load(FixedArray::from_array(bytes), 0)
}

///|
/// Up to sixteen characters as their ASCII bytes, one per lane.
#cfg(target="wasm")
fn table_of(chars : Array[Char], count : Int32) -> V128 {
  let bytes : Array[Byte] = Array::make(16, b'\x00')
  for i in 0..<count {
    if i < 16 {
      bytes[i] = chars[i].to_int().to_byte()
    }
  }
  vector(bytes)
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
/// The shapes an alphabet can take, cheapest first.
#cfg(target="wasm")
priv enum Shape {
  /// One run: the character is the value plus a constant.
  Constant
  /// Two runs: the constant, plus a step once the value passes the boundary.
  Two
  /// Otherwise: a table entry, addressed by the value's distance past the tail.
  Table
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
/// The cheapest way an alphabet can name a value, or `None` when no shape fits.
///
/// An alphabet is read as runs of constant offset: inside a run the character is
/// the value plus a fixed difference.
///
/// - one run — `01`, `0`–`7` — needs no naming at all, just the constant added to
///   the value.
/// - two runs — hexadecimal in either case, both spellings of base32 — need one
///   compare and one conditional step.
/// - anything else is driven off the table described by [`Naming`](#Naming), and
///   needs its last run narrow enough to address a value at a time: at most
///   fifteen values, which is what `base - starts[k] <= 14` says. A head of more
///   than one boundary would need slots that collide, so none is attempted
///   either. z-base-32 meets neither condition — twenty-seven runs, none of them
///   in a tail that narrow — and no path here is taken for it.
#cfg(target="wasm")
#warnings("-14")
fn naming_of(digits : Array[Char], base : Int32) -> Naming? {
  // The alphabet as runs of constant offset. Sixteen runs is the table's width,
  // and the last run of a spelling narrow enough to vectorise always falls
  // inside it.
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
  Some(Naming::{
    table: vector(table),
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
  })
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
