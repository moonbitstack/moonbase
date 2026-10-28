// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The streaming engine, exercised directly.
///
/// The property each test states is the one the interface promises: a payload fed
/// in pieces comes out byte for byte the same as a payload fed at once. The
/// splits are drawn from a generator rather than written by hand, so a boundary
/// lands inside a group about as often as anywhere else — which is the case an
/// implementation gets wrong.
/// A small linear congruential generator, so a failing split can be reproduced
/// from its seed.
fn next(state : Int32) -> Int32 {
  (state * 1103515245 + 12345) & 0x7fffffff
}

///|
/// Where to cut a payload of `length` into pieces: the boundaries are drawn from
/// the generator seeded with `seed`, sorted, and closed with both ends.
fn boundaries(length : Int32, seed : Int32, cuts : Int32) -> Array[Int32] {
  let out : Array[Int32] = [0]
  let mut state = seed
  for _ in 0..<cuts {
    state = next(state)
    out.push(state % (length + 1))
  }
  out.push(length)
  insertion_sort(out)
  out
}

///|
fn insertion_sort(values : Array[Int32]) -> Unit {
  for i in 1..<values.length() {
    let item = values[i]
    let mut j = i - 1
    while j >= 0 && values[j] > item {
      values[j + 1] = values[j]
      j = j - 1
    }
    values[j + 1] = item
  }
}

///|
/// A payload with every byte value in it, then some, so a split has something to
/// cut through.
fn payload() -> Bytes {
  let all : Array[Byte] = []
  for i in 0..<256 {
    all.push((i * 7 % 256).to_byte())
  }
  for i in 0..<40 {
    all.push(i.to_byte())
  }
  Bytes::from_array(all)
}

///|
/// The 128-entry table a source needs, built here so the test does not reach into
/// the internal package.
fn table_of(chars : String) -> Array[Int32] {
  let table = Array::make(128, -1)
  let digits = chars.to_array()
  for i in 0..<digits.length() {
    table[digits[i].to_int()] = i
  }
  table
}

///|
let hex : String = "0123456789abcdef"

///|
let base32 : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

///|
let base64 : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

///|
test "a sink fed in pieces writes what a sink fed at once writes" {
  let raw = payload()
  for case in [(hex, 4), (base32, 5), (base64, 6)] {
    let (chars, bits) = case
    let whole = @moonbase.Sink::new(bits, chars.to_array(), true)
    whole.write(raw[:])
    let want = whole.finish()
    for seed in 1..<40 {
      let sink = @moonbase.Sink::new(bits, chars.to_array(), true)
      let cuts = boundaries(raw.length(), seed * seed * 7 + seed, 12)
      for i in 0..<(cuts.length() - 1) {
        sink.write(raw[cuts[i]:cuts[i + 1]])
      }
      assert_eq(sink.finish(), want)
    }
  }
}

///|
test "a source fed in pieces reads what a source fed at once reads" {
  let raw = payload()
  for case in [(hex, 4), (base32, 5), (base64, 6)] {
    let (chars, bits) = case
    let sink = @moonbase.Sink::new(bits, chars.to_array(), true)
    sink.write(raw[:])
    let text = sink.finish()
    let table = table_of(chars)
    for seed in 1..<30 {
      let source = @moonbase.Source::new(bits, table, false)
      let cuts = boundaries(text.length(), seed * 13 + 1, 9)
      for i in 0..<(cuts.length() - 1) {
        try source.write(text[cuts[i]:cuts[i + 1]]) catch {
          _ => fail("a split inside valid text should never fail")
        } noraise {
          _ => ()
        }
      }
      assert_eq(source.finish(), raw)
    }
  }
}

///|
test "the padding is added once, at the end, and a drain does not add it" {
  let sink = @moonbase.Sink::new(6, base64.to_array(), true)
  sink.write(b"foo"[:])
  // Three bytes are four characters; the half-finished group is not among them.
  assert_eq(sink.drain(), "Zm9v")
  sink.write(b"bar"[:])
  // What was drained is gone; the rest is the second group.
  assert_eq(sink.finish(), "YmFy")
  // Four bytes are six characters and two of padding, not eight.
  let padded = @moonbase.Sink::new(6, base64.to_array(), true)
  padded.write(b"foob"[:])
  assert_eq(padded.finish(), "Zm9vYg==")
  // Without padding the same sink stops at six.
  let bare = @moonbase.Sink::new(6, base64.to_array(), false)
  bare.write(b"foob"[:])
  assert_eq(bare.finish(), "Zm9vYg")
}

///|
test "a failure in a later chunk names the index in the whole input" {
  let source = @moonbase.Source::new(4, table_of(hex), false)
  try source.write("abcd") catch {
    _ => fail("the first chunk is valid")
  } noraise {
    _ => ()
  }
  try source.write("ef0!") catch {
    failure => assert_eq(failure, Bad(at=7, char='!'))
  } noraise {
    _ => fail("expected the mark to be named at its own index")
  }
}

///|
test "a lossy source skips what it cannot read, a strict one stops" {
  let lossy = @moonbase.Source::new(4, table_of(hex), true)
  lossy.write("ab cd\nef")
  assert_eq(lossy.finish(), b"\xab\xcd\xef")
  let strict = @moonbase.Source::new(4, table_of(hex), false)
  try strict.write("ab cd") catch {
    failure => assert_eq(failure, Bad(at=2, char=' '))
  } noraise {
    _ => fail("expected the space to be rejected")
  }
}

///|
test "the source refuses a length that ends inside a character" {
  let source = @moonbase.Source::new(5, table_of(base32), false)
  try source.write("A") catch {
    _ => fail("one character is a legal prefix")
  } noraise {
    _ => ()
  }
  try source.finish() catch {
    failure => assert_eq(failure, Truncated(at=1))
  } noraise {
    _ => fail("expected five bits to be rejected as not a byte")
  }
}
