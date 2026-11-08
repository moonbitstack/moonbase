// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// Every length from nothing to a byte, the whole byte range, and a run that
/// crosses both a byte and a line.
fn probes() -> Array[Bytes] {
  let out : Array[Bytes] = [
    b"", b"\x00", b"\xff", b"\x0f", b"\xf0", b"\xab\xcd\xef",
  ]
  let every = Array::make(256, b'\x00')
  for i in 0..<256 {
    every[i] = i.to_byte()
  }
  out.push(Bytes::from_array(every))
  out
}

///|
test "the two implementations write the same characters" {
  for probe in probes() {
    assert_eq(@base16.encode(probe[:]), @corehex.encode(probe[:]))
    assert_eq(
      @base16.encode(probe[:], kind=@base16.Upper),
      @corehex.encode(probe[:]).to_upper(),
    )
  }
}

///|
test "each reads what the other wrote" {
  for probe in probes() {
    let mine = @base16.encode(probe[:])
    let theirs = @corehex.encode(probe[:])
    assert_eq(@base16.decode(theirs), probe)
    assert_eq(@corehex.decode(mine), probe)
    // core writes lower case only and reads either, as this does.
    assert_eq(
      @base16.decode(@base16.encode(probe[:], kind=@base16.Upper)),
      probe,
    )
    assert_eq(
      @corehex.decode(@base16.encode(probe[:], kind=@base16.Upper)),
      probe,
    )
  }
}

///|
test "both refuse the same odd length and the same bad character" {
  let odd = try @base16.decode("abc") catch {
    @moonbase.Truncated(at~) => at
    _ => -1
  } noraise {
    _ => -2
  }
  assert_eq(odd, 3)
  let theirs_odd = try @corehex.decode("abc") catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(theirs_odd)
  let bad = try @base16.decode("0g") catch {
    @moonbase.Bad(char~, ..) => char == 'g'
    _ => false
  } noraise {
    _ => false
  }
  assert_true(bad)
  let theirs_bad = try @corehex.decode("0g") catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(theirs_bad)
}
