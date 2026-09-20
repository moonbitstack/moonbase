<!-- Copyright 2026 Leo Cheng -->

# moonbase

[![check and test](https://github.com/moonbitstack/moonbase/actions/workflows/ci.yml/badge.svg)](https://github.com/moonbitstack/moonbase/actions/workflows/ci.yml)

Encodings for MoonBit: base16, base32, base36, base58, base62 and base64.

Six encodings, one shape. Every package has the same five functions in the same
order, so reading one is learning all of them:

```moonbit
@base64.encode(data[:])                            // "bW9vbmJhc2U="
@base64.encode(data[:], kind=Url, padding=false)   // "bW9vbmJhc2U"
@base64.decode("bW9vbmJhc2U=")                     // raises on bad input
@base64.decode_lossy(pem_body)                     // skips newlines, never fails
@base64.encode_bytes(data[:])                      // ASCII bytes, no String on the way
```

## Install

```json
{ "deps": { "moonbitstack/moonbase": "0.4.0" } }
```

Then import only what you use — an application that needs base64 does not link
base58's big-integer core:

```json
{ "import": ["moonbitstack/moonbase/base64"] }
```

## The five faces

| Face | For |
|:--:|:--|
| `encode(input : BytesView, …) -> String` | the ordinary case |
| `encode_bytes(input : BytesView, …) -> Bytes` | wire formats that hold bytes — an HTTP header, a gRPC metadata value — without a round trip through `String` |
| `decode(input : StringView, …) -> Bytes raise Malformed` | input you want checked |
| `decode_bytes(input : BytesView, …) -> Bytes raise Malformed` | the same, for callers who never had a string |
| `decode_lossy(input : StringView, …) -> Bytes` | a PEM body full of newlines, a fingerprint full of colons, a token with spaces in it |

Variants are a named argument, not another function name:

```moonbit
@base32.encode(data[:], kind=Hex)          // RFC 4648 §7, sort-order preserving
@base16.encode(data[:], kind=Upper)        // 666F6F
@base64.encode(data[:], padding=false)     // no trailing '='
```

base36, base58 and base62 add two more for whole numbers, where leading zeros
have no meaning:

```moonbit
@base62.encode_int(123456789)   // "8M0kX"
@base62.decode_int("8M0kX")     // 123456789
```

## Failures say where

```moonbit
try @base64.decode("Zm*vYg==") catch {
  Bad(at~, char~)  => …   // at = 2, char = '*'
  Truncated(at~)   => …   // the input ends mid-group
  Padding(at~)     => …   // '=' where it cannot be
  Checksum(at~)    => …   // for the encodings that carry one
}
```

Want the old "just tell me it failed"? `try? @base64.decode(s)` gives you a
`Result` back.

## What each encoding is for

| Package | Specification | Notes |
|:--:|:--|:--|
| `base16` | [RFC 4648 §8](https://www.rfc-editor.org/rfc/rfc4648#section-8) | byte-aligned, so leading zeros survive; `encode_colons` writes fingerprints |
| `base32` | [§6](https://www.rfc-editor.org/rfc/rfc4648#section-6), [§7](https://www.rfc-editor.org/rfc/rfc4648#section-7) | `kind=Hex` keeps byte order under sorting |
| `base36` | [multibase](https://github.com/multiformats/multibase) `k`/`K` | numbers and identifiers |
| `base58` | [Bitcoin](https://github.com/bitcoin/bitcoin/blob/master/src/base58.cpp) | no `0`, `O`, `I` or `l`; leading zero bytes stay as leading `1` |
| `base62` | — | digits, upper, lower; short identifiers |
| `base64` | [§4](https://www.rfc-editor.org/rfc/rfc4648#section-4), [§5](https://www.rfc-editor.org/rfc/rfc4648#section-5) | `kind=Url` for tokens and file names; `decode_any` reads either alphabet |

## Custom alphabets

The big-integer core is public, so any positional system is two lines:

```moonbit
let crockford = @moonbase.Alphabet::new("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
@moonbase.encode(data[:], crockford)
```

`Alphabet::new` raises when the alphabet is wrong (repeated character, not
ASCII, fewer than two digits) — it often comes from configuration. `Alphabet::of`
is the same thing for literals in your own source, and aborts instead.

## Examples and tests

`examples/tour` prints every face, including what a failure looks like:

```bash
moon run examples/tour --target wasm-gc
```

54 tests on all four backends, pinned to the authoritative vectors: RFC 4648 §10
for base16, base32 and base64; Bitcoin Core's `base58_encode_decode.json` for
base58; JavaScript's `toString(36)` for base36; hand-computed values for base62.

```bash
moon check --target all --deny-warn
moon test --target all
```

## License

Apache-2.0.
