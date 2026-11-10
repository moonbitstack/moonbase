// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

// The same work through this package and through the core encoder, measured in one
// binary so both run under the same clock and cache state: two separate builds would
// compare two machines, not two implementations.
//
//   moon bench --release --target wasm
//
// The two benches are order sensitive: whichever runs first in a process pays the ramp of
// the clock and of the buffers, which is worth about a tenth on this machine. Read them by
// running `moon bench` twice and comparing each implementation with itself, or interleave
// the two calls. No ratio is asserted anywhere, because it belongs to the host.

///|
/// 64 KiB of every byte value and then some, which is what a real payload looks like
/// better than a run of zeroes does.
let wide_input : Bytes = {
  let out = Array::make(65536, b'\x00')
  let mut state = 123456789U
  for i in 0..<65536 {
    state = state * 1103515245U + 12345U
    out[i] = (i % 251).to_byte() ^ (state >> 16).reinterpret_as_int().to_byte()
  }
  Bytes::from_array(out)
}

///|
test "bench core encode 64 KiB" (it : @bench.T) {
  it.bench(name="core", fn() {
    it.keep(@corehex.encode(wide_input[:]).length())
  })
}

///|
test "bench encode 64 KiB" (it : @bench.T) {
  it.bench(name="moonbase", fn() {
    it.keep(@base16.encode(wide_input[:], kind=Lower).length())
  })
}
