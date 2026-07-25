# basex

**Base58 and base62 encoding for [MoonBit](https://www.moonbitlang.com/), built on one small generic base-N core.**

[![tests](https://img.shields.io/badge/tests-8%20passing-2ea44f)](#tests)
[![license](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

`basex` turns bytes into short, copy-safe text and back. It ships two ready-made alphabets — **base58** (the Bitcoin / IPFS alphabet, which drops the look-alike characters `0`, `O`, `I`, `l`) and **base62** (`0-9A-Za-z`, URL-safe and dense) — over a `basex` core you can also point at any alphabet of your own.

## Install

```bash
moon add Lfan-ke/basex
```

## base58

The alphabet Bitcoin addresses and IPFS CIDv0 hashes use. Leading zero bytes are preserved as leading `1`s.

```moonbit
let encoded = @base58.encode(b"Hello, MoonBit!")
let decoded = @base58.decode(encoded) // -> Some(b"Hello, MoonBit!")

@base58.decode("0OIl") // -> None  (none of these are base58 characters)
```

## base62

Bytes in, URL-safe text out — plus an integer mode that is the compact form a URL shortener gives a numeric id.

```moonbit
@base62.encode(b"\xde\xad\xbe\xef") // bytes  -> a base62 string
@base62.decode("...")               // string -> Some(bytes) / None

@base62.encode_uint(123456789)      // -> "8M0kX"
@base62.decode_uint("8M0kX")        // -> Some(123456789)
```

## Custom alphabets

Both packages are thin wrappers over the core. Build an `Alphabet` from any ordered set of ASCII characters (the first is the zero digit) and encode against it:

```moonbit
let base16 = @basex.Alphabet::new("0123456789abcdef")
@basex.encode(b"\xde\xad\xbe\xef", base16) // -> "deadbeef"
@basex.decode("deadbeef", base16)          // -> Some(b"\xde\xad\xbe\xef")
```

`decode` returns `None` on any character outside the alphabet, so it doubles as validation.

## Tests

Correctness is pinned to published vectors: base58 against Bitcoin Core's `base58_encode_decode.json`, base62's integer mode against hand-computed values, and every codec against encode/decode round-trips.

```bash
moon test
```

## License

Apache-2.0 © Leo Cheng
