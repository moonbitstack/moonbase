// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// SHA-256 (FIPS 180-4), for the one place an encoding needs a hash of its own:
/// base58check's four-byte trailer.
///
/// It lives here rather than in the package that uses it because a checksum is
/// not an encoding and has no business widening base58's public surface. The
/// arithmetic is done in `Int64` and masked back to 32 bits at every step, so
/// none of it depends on how wide the platform's `Int` happens to be.
pub fn sha256(input : BytesView) -> Bytes {
  let n = input.length()
  // Message, then 0x80, then zeros, then the length in bits — to a block.
  let total = (n + 9 + 63) / 64 * 64
  let msg = Array::make(total, b'\x00')
  for i in 0..<n {
    msg[i] = input[i]
  }
  msg[n] = b'\x80'
  let bits = n.to_int64() * 8L
  for i in 0..<8 {
    msg[total - 8 + i] = ((bits >> ((7 - i) * 8)) & 0xffL).to_int().to_byte()
  }
  let mut h0 = 0x6a09e667L
  let mut h1 = 0xbb67ae85L
  let mut h2 = 0x3c6ef372L
  let mut h3 = 0xa54ff53aL
  let mut h4 = 0x510e527fL
  let mut h5 = 0x9b05688cL
  let mut h6 = 0x1f83d9abL
  let mut h7 = 0x5be0cd19L
  let w = Array::make(64, 0L)
  let mut block = 0
  while block < total {
    for i in 0..<16 {
      let at = block + i * 4
      w[i] = (msg[at].to_int().to_int64() << 24) |
        (msg[at + 1].to_int().to_int64() << 16) |
        (msg[at + 2].to_int().to_int64() << 8) |
        msg[at + 3].to_int().to_int64()
    }
    for i in 16..<64 {
      let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
      let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & mask32
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    let mut f = h5
    let mut g = h6
    let mut h = h7
    for i in 0..<64 {
      let big_s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
      let ch = (e & f) ^ ((mask32 ^ e) & g)
      let t1 = (h + big_s1 + ch + round_constant(i) + w[i]) & mask32
      let big_s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
      let maj = (a & b) ^ (a & c) ^ (b & c)
      let t2 = (big_s0 + maj) & mask32
      h = g
      g = f
      f = e
      e = (d + t1) & mask32
      d = c
      c = b
      b = a
      a = (t1 + t2) & mask32
    }
    h0 = (h0 + a) & mask32
    h1 = (h1 + b) & mask32
    h2 = (h2 + c) & mask32
    h3 = (h3 + d) & mask32
    h4 = (h4 + e) & mask32
    h5 = (h5 + f) & mask32
    h6 = (h6 + g) & mask32
    h7 = (h7 + h) & mask32
    block = block + 64
  }
  let out : Array[Byte] = []
  for word in [h0, h1, h2, h3, h4, h5, h6, h7] {
    for i in 0..<4 {
      out.push(((word >> ((3 - i) * 8)) & 0xffL).to_int().to_byte())
    }
  }
  Bytes::from_array(out)
}

///|
let mask32 : Int64 = 0xffffffffL

///|
fn rotr(x : Int64, n : Int32) -> Int64 {
  ((x >> n) | (x << (32 - n))) & mask32
}

///|
/// The 64 round constants of FIPS 180-4 §4.2.2 — the first 32 bits of the
/// fractional part of the cube root of the first 64 primes.
fn round_constant(i : Int32) -> Int64 {
  constants[i]
}

///|
let constants : Array[Int64] = [
  0x428a2f98L, 0x71374491L, 0xb5c0fbcfL, 0xe9b5dba5L, 0x3956c25bL, 0x59f111f1L, 0x923f82a4L,
  0xab1c5ed5L, 0xd807aa98L, 0x12835b01L, 0x243185beL, 0x550c7dc3L, 0x72be5d74L, 0x80deb1feL,
  0x9bdc06a7L, 0xc19bf174L, 0xe49b69c1L, 0xefbe4786L, 0x0fc19dc6L, 0x240ca1ccL, 0x2de92c6fL,
  0x4a7484aaL, 0x5cb0a9dcL, 0x76f988daL, 0x983e5152L, 0xa831c66dL, 0xb00327c8L, 0xbf597fc7L,
  0xc6e00bf3L, 0xd5a79147L, 0x06ca6351L, 0x14292967L, 0x27b70a85L, 0x2e1b2138L, 0x4d2c6dfcL,
  0x53380d13L, 0x650a7354L, 0x766a0abbL, 0x81c2c92eL, 0x92722c85L, 0xa2bfe8a1L, 0xa81a664bL,
  0xc24b8b70L, 0xc76c51a3L, 0xd192e819L, 0xd6990624L, 0xf40e3585L, 0x106aa070L, 0x19a4c116L,
  0x1e376c08L, 0x2748774cL, 0x34b0bcb5L, 0x391c0cb3L, 0x4ed8aa4aL, 0x5b9cca4fL, 0x682e6ff3L,
  0x748f82eeL, 0x78a5636fL, 0x84c87814L, 0x8cc70208L, 0x90befffaL, 0xa4506cebL, 0xbef9a3f7L,
  0xc67178f2L,
]
