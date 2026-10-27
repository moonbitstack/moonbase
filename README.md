<div align="center">

<h1>moonbase</h1>

<p><strong>Six base encodings for MoonBit.</strong><br>
base16 &middot; base32 &middot; base36 &middot; base58 &middot; base62 &middot; base64</p>

<p>
<a href="https://moonbitstack.github.io/moonbase/"><b>Home</b></a> &nbsp;&middot;&nbsp;
<a href="https://moonbitstack.github.io/moonbase/guide.html"><b>Guide</b></a> &nbsp;&middot;&nbsp;
<a href="https://moonbitstack.github.io/moonbase/api.html"><b>API</b></a> &nbsp;&middot;&nbsp;
<a href="https://mooncakes.io/docs/moonbitstack/moonbase"><b>mooncakes</b></a>
</p>

</div>

---

Six encodings with one shape. Every package exposes the same five functions in the
same order, so reading one is reading all of them.

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
@base32.encode(data[:], kind=Hex)          // RFC 4648 §7, sort-order preserving
@base16.encode(data[:], kind=Upper)        // "6D6F6F4E62617365"
@base64.encode(data[:], padding=false)     // no trailing '='
```

## Whole numbers

base36, base58 and base62 add `encode_int` / `decode_int`, for values where leading
zeros have no meaning.

```moonbit
@base36.encode_int(123456789)   // "21i3v9"
@base62.encode_int(123456789)   // "8M0kX"
@base36.decode_int("21i3v9")    // 123456789
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

## The six encodings

| Package | Specification | Notes |
|:--|:--|:--|
| `base16` | RFC 4648 §8 | byte-aligned, so leading zeros survive; `encode_colons` writes fingerprints |
| `base32` | RFC 4648 §6, §7 | `kind=Hex` keeps byte order under sorting |
| `base36` | multibase `k` / `K` | numbers and identifiers |
| `base58` | multibase `z` | no `0`, `O`, `I` or `l`; leading zero bytes stay as leading `1` |
| `base62` | — | digits, upper, lower; short identifiers |
| `base64` | RFC 4648 §4, §5 | `kind=Url` for tokens and file names; `decode_any` reads either alphabet |

## Examples

- [`src/examples/minimal`](src/examples/minimal) — the smallest program that encodes and decodes.
- [`src/examples/tour`](src/examples/tour) — every face of every package, including a failure.

```sh
moon run src/examples/minimal --target wasm-gc
moon run src/examples/tour --target wasm-gc
```

## Licence

Apache-2.0.
