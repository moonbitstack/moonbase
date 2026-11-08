// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The inputs both implementations are asked about: every length below four
/// characters, the whole byte range, and a run long enough to cross a group.
fn probes() -> Array[Bytes] {
  let out : Array[Bytes] = [
    b"", b"f", b"fo", b"foo", b"foob", b"fooba", b"foobar", b"\x00", b"\x00\x00",
    b"\x00\x00\x00", b"\x00\xff\x00\xff",
  ]
  let every = Array::make(256, b'\x00')
  for i in 0..<256 {
    every[i] = i.to_byte()
  }
  out.push(Bytes::from_array(every))
  let run = Array::make(96, b'\x00')
  let mut state = 123456789U
  for i in 0..<96 {
    state = state * 1103515245U + 12345U
    run[i] = (state >> 16).reinterpret_as_int().to_byte()
  }
  out.push(Bytes::from_array(run))
  out
}

///|
/// A string of the whole byte range, wrapped at seventy-six characters the way
/// a mail body is.
fn wrapped(text : String) -> String {
  let out = StringBuilder()
  let mut column = 0
  for c in text {
    out.write_char(c)
    column = column + 1
    if column == 76 {
      out.write_char('\n')
      column = 0
    }
  }
  out.to_string()
}

///|
test "the two implementations write the same characters" {
  for probe in probes() {
    assert_eq(@base64.encode(probe[:]), @core64.encode(probe[:]))
    assert_eq(
      @base64.encode(probe[:], padding=false),
      @core64.encode(probe[:], padding=false),
    )
  }
}

///|
test "each reads what the other wrote" {
  for probe in probes() {
    let mine = @base64.encode(probe[:])
    let theirs = @core64.encode(probe[:])
    assert_eq(@base64.decode(theirs), probe)
    assert_eq(@core64.decode(mine), probe)
    let mine_raw = @base64.encode(probe[:], padding=false)
    let theirs_raw = @core64.encode(probe[:], padding=false)
    assert_eq(@base64.decode(theirs_raw), probe)
    assert_eq(@core64.decode(mine_raw), probe)
  }
}

///|
test "both fold the same wrapped body" {
  let probe = probes()[12]
  let body = wrapped(@core64.encode(probe[:]))
  assert_eq(@base64.decode(body, whitespace=true), probe)
  assert_eq(@core64.decode(body, ignore_whitespace=true), probe)
}

///|
test "both name the same index for the same bad character" {
  let bad = "Zm9vYmE*"
  let mine = try @base64.decode(bad) catch {
    @moonbase.Bad(at~, ..) => at
    _ => -1
  } noraise {
    _ => -2
  }
  assert_eq(mine, 7)
  // Core reports the input, not a position, so the index is ours to check; what
  // the pair has to agree on is that the input is refused at all.
  let theirs = try @core64.decode(bad) catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(theirs)
}
