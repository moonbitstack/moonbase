<div align="center">

<h1>moonbase</h1>

<p><strong>Every base encoding for MoonBit, with one shape.</strong><br>
base2 &middot; base8 &middot; base10 &middot; base16 &middot; base32 &middot; base36 &middot; base45 &middot;
base58 &middot; base62 &middot; base64 &middot; base85 &middot; bech32 &middot; multibase</p>

<p>
<a href="https://moonbitstack.github.io/moonbase/"><b>Home</b></a> &nbsp;&middot;&nbsp;
<a href="https://moonbitstack.github.io/moonbase/guide.html"><b>Guide</b></a> &nbsp;&middot;&nbsp;
<a href="https://moonbitstack.github.io/moonbase/api.html"><b>API</b></a> &nbsp;&middot;&nbsp;
<a href="https://mooncakes.io/docs/moonbitstack/moonbase"><b>mooncakes</b></a>
</p>

</div>

---

Thirteen encodings with one shape. Every package exposes the same five functions in
the same order, so reading one is reading all of them.

```moonbit
let data = b"moonbase"
let pem = "bW9vbmJhc2U=\n"                        // a PEM body, newline and all

@base64.encode(data[:])                           // "bW9vbmJhc2U="
@base64.encode(data[:], kind=Url, padding=false)  // "bW9vbmJhc2U"
@base64.encode_bytes(data[:])                     // the ASCII bytes, no String on the way
@base64.decode("bW9vbmJhc2U=")                    // b"moonbase"
@base64.decode_lossy(pem)                         // b"moonbase"
```

## Install

```sh
moon add moonbitstack/moonbase
```

Then import only the encodings you use. An application that needs base64 does not
link base58's big-integer core.

```moonbit
// moon.pkg
import {
  "moonbitstack/moonbase/base64",
}
```

## The five faces

| Face | Signature | For |
|:--|:--|:--|
| `encode` | `(BytesView, …) -> String` | the ordinary case |
| `encode_bytes` | `(BytesView, …) -> Bytes` | wire formats that hold bytes — an HTTP header, a gRPC metadata value — with no round trip through `String` |
| `decode` | `(StringView, …) -> Bytes raise Malformed` | input you want checked |
| `decode_bytes` | `(BytesView, …) -> Bytes raise Malformed` | the same, for callers who never had a string |
| `decode_lossy` | `(StringView, …) -> Bytes` | a PEM body full of newlines, a fingerprint full of colons |

Variants are a named argument, not another function name:

```moonbit
@base32.encode(data[:], kind=Hex)          // "DLNMURJ2C5PMA==="
@base32.encode(data[:], kind=Crockford)    // "DNQPYVK2C5SPA"
@base16.encode(data[:], kind=Upper)        // "6D6F6F6E62617365"
@base64.encode(data[:], padding=false)     // "bW9vbmJhc2U"
@base85.encode(b"\x00\xff\x01\xfe"[:], kind=Z85)   // "0ri90"
```

Decoding reads either padding by default. base32 and base64 take `padding` to require or forbid the `=`, and `strict` to refuse an incomplete run of `=` and spare bits that are not zero, so a format that compares or signs the text accepts only the spelling `encode` writes:

```moonbit
@base64.decode("Zg==", padding=true, strict=true)   // b"f"
@base64.decode("Zh==", strict=true)                 // raises Padding(at=1)
@base64.decode("Zg==", padding=false)               // raises Padding(at=2)
```

## Streaming

The bit-packing families — base2, base8, base16, base32, base45, base64, base85 —
have a `sink()` and a `source()`. Feed them in whatever chunks the transport hands
you; the bytes that come out are the bytes one call would have produced.

```moonbit
let sink = @base64.sink()
sink.write(b"moon"[:])
sink.write(b"base"[:])
sink.finish()                    // "bW9vbmJhc2U="

let source = @base64.source()
source.write("bW9vbm")           // six characters are four bytes and four bits
source.drain()                   // b"moon" — the leftover bits stay behind
source.write("Jhc2U=")
source.finish()                  // b"base"
```

`drain()` hands over what is already decided and keeps the rest; `finish()` flushes
the tail. A failure names the index in the whole input, counted across every chunk,
so a split never moves an error to a place the caller cannot find.

The big-integer families — base10, base36, base58, base62 — have no streaming face on
purpose: their first digit depends on the last byte, so there is nothing to emit until
the input ends.

## Whole numbers

base36, base58 and base62 add `encode_int` / `decode_int`, for values where leading
zeros have no meaning.

```moonbit
@base36.encode_int(123456789)   // "21i3v9"
@base62.encode_int(123456789)   // "8M0kX"
@base36.decode_int("21i3v9")    // 123456789
```

Anything larger goes through `BigInt`, on any alphabet:

```moonbit
@moonbase.encode_big(@bigint.BigInt::from_int(123456789), hex)   // "75bcd15"
@moonbase.decode_big("75bcd15", hex)                             // the same number
```

## Failures say where

A malformed input names the index it broke at, instead of a silent `None`.

```moonbit
try {
  @base64.decode("Zm*vYg==")
} catch {
  failure => match failure {
    Bad(at~, char~) => println("bad " + char.to_string() + " at " + at.to_string())
    Truncated(at~)  => println("truncated at " + at.to_string())
    Padding(at~)    => println("padding at " + at.to_string())
    Checksum(at~)   => println("checksum at " + at.to_string())
  }
} noraise {
  _ => println("decoded")
}
```

Want the old "just tell me it failed"? `try? @base64.decode(s)` gives you a
`Result`.

## Custom alphabets

The positional core is public, so any base-N system is two lines.

```moonbit
let crockford = @moonbase.Alphabet::new("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
@moonbase.encode(data[:], crockford)   // "6TVVFDSH62WV5"
```

`Alphabet::new` raises when the alphabet is wrong — a repeated character, a non-ASCII
character, or fewer than two digits — because it often arrives from configuration.
`Alphabet::of` is the same thing for literals in your own source, and aborts instead.

## Self-identifying strings

`multibase` puts one character in front of any of the above, so the string says how
to read itself.

```moonbit
@multibase.encode(data[:], base=Base58Btc)   // "zKJfFLz7PRba"
@multibase.detect("zKJfFLz7PRba")            // Some(Base58Btc)
@multibase.decode("zKJfFLz7PRba")            // b"moonbase"
```

`bech32` is the other way round: it makes the prefix part of the checksum, so a
typo in the prefix is as visible as a typo anywhere else.

```moonbit
@bech32.encode("moonbase", data[:])                    // "moonbase1d4hk7mnzv9ek2s84pra"
@bech32.encode("moonbase", data[:], kind=Bech32m)      // "moonbase1d4hk7mnzv9ek29m9dxl"
@bech32.decode_words("moonbase1d4hk7mnzv9ek2s84pra")   // { hrp: "moonbase", words: … }
```

## The thirteen encodings

| Package | Specification | Notes |
|:--|:--|:--|
| `base2` | multibase `0` | one bit a character; eight characters a byte |
| `base8` | multibase `7` | three bits a character — a bit packing, not an octal of a number |
| `base10` | multibase `9` | the bytes as one decimal integer, so a leading zero byte stays a leading `0` |
| `base16` | RFC 4648 §8 | byte-aligned, so leading zeros survive; `encode_colons` writes fingerprints |
| `base32` | RFC 4648 §6, §7 | `kind=Hex` keeps byte order under sorting; `Crockford` and `Z` for people |
| `base36` | multibase `k` / `K` | numbers and identifiers |
| `base45` | RFC 9285 | two bytes in three characters a QR code's alphanumeric mode can hold; no padding |
| `base58` | multibase `z` | `Flickr` and `Ripple` alphabets, plus `encode_check` / `decode_check` |
| `base62` | — | digits, upper, lower; short identifiers |
| `base64` | RFC 4648 §4, §5 | `kind=Url` for tokens and file names; `decode_any` reads either alphabet |
| `base85` | Adobe, ZeroMQ RFC 32, RFC 1924 | `kind=Ascii85`, `kind=Z85`, `kind=Ipv6` — four bytes in five characters, three ways |
| `bech32` | BIP 173, BIP 350 | a human-readable prefix, five-bit groups and a BCH checksum; `kind=Bech32m` for version 1 and up |
| `multibase` | multiformats | one prefix character, from `0` for base2 to a rocket for base256emoji |

Every package passes its own specification's vectors: RFC 4648 §10, RFC 9285
Appendix, ZeroMQ RFC 32, RFC 1924 §5, the full BIP 173 and BIP 350 valid/invalid
lists, and multiformats' `tests/*.csv` fixture files. `scripts/gen_vectors.py`
regenerates what can be generated and checks the rest against a reference
implementation.

## Examples

- [`src/examples/minimal`](src/examples/minimal) — the smallest program that encodes and decodes.
- [`src/examples/tour`](src/examples/tour) — every face of every package, including a failure.
- [`src/examples/integration`](src/examples/integration) — one payload in every base, read
  back without being told which is which; a Bitcoin address; a bech32 address.

```sh
moon run src/examples/minimal --target wasm-gc
moon run src/examples/tour --target wasm-gc
moon run src/examples/integration --target wasm-gc
```

## Licence

Apache-2.0.
