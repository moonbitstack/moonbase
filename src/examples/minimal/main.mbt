// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The smallest useful program: encode a byte string, then read it back.
fn main {
  let data = b"moonbase"
  let text = @base64.encode(data[:])
  println(text)

  try @base64.decode(text) catch {
    _ => println("failed")
  } noraise {
    bytes => println(bytes.to_string())
  }
}
