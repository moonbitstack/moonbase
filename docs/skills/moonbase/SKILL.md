---
name: moonbase
description: "Base encodings for MoonBit — base64 and base32 for tokens, keys and wire formats, base58 and bech32 for addresses, multibase for strings that name their own encoding, base16 for fingerprints. Reach for it whenever bytes have to travel through a text channel, or a text payload has to become bytes again."
---

# moonbase

Thirteen encodings, one shape: `encode`, `encode_bytes`, `decode`, `decode_bytes`,
`decode_lossy`. Variants are named arguments (`kind`, `padding`, `strict`,
`whitespace`), never a second function name.

Add the module, then import only the packages you use — an application that needs
base64 does not link base58's big-integer core.

```sh
moon add moonbitstack/moonbase
```

```moonbit
// moon.pkg
import {
  "moonbitstack/moonbase/base64",
}
```

## Encode bytes and read them back

`encode` returns a `String`; `encode_bytes` returns the ASCII bytes, which is what an
HTTP header or a gRPC metadata value actually holds. `decode` raises `Malformed` with
the index it broke at, rather than returning `None`.

```moonbit
let data = b"moonbase"

assert_eq(@base64.encode(data[:]), "bW9vbmJhc2U=")
assert_eq(@base64.encode_bytes(data[:]), b"bW9vbmJhc2U=")
assert_eq(@base64.decode("bW9vbmJhc2U="), data)
assert_eq(@base64.encode(data[:], kind=@base64.Url, padding=false), "bW9vbmJhc2U")
```

The same five faces are on every package:

```moonbit
let data = b"moonbase"

assert_eq(@base16.encode(data[:]), "6d6f6f6e62617365")
assert_eq(@base58.encode(data[:]), "KJfFLz7PRba")
assert_eq(@base32.encode(data[:], kind=@base32.Crockford), "DNQPYVK2C5SPA")
```

## Decode text that came from somewhere else

A body that arrived wrapped in line breaks — a PEM block, a key pasted out of a
terminal — takes `whitespace=true`. It skips the four ASCII blanks and nothing else,
so a typo still fails. `decode_lossy` is the blunt version: it skips every character
outside the alphabet and never raises, which is what a `ab:cd:ef` fingerprint needs.

```moonbit
assert_eq(@base64.decode("bW9v\nbmJh\nc2U=", whitespace=true), b"moonbase")
assert_eq(@base16.decode_lossy("ab:cd:ef"), b"\xab\xcd\xef")
```

Where a format compares or signs the text, accept only the one spelling `encode`
writes: `padding` requires or forbids the trailing `=`, and `strict` refuses an
incomplete run of `=` and spare bits that are not zero.

```moonbit
assert_eq(@base64.decode("Zg==", padding=true, strict=true), b"f")
assert_eq(@base64.decode("Zg", padding=false, strict=true), b"f")
```

## Streams, when the payload does not fit in one buffer

base2, base8, base16, base32, base45, base64 and base85 have `sink()` and `source()`.
`drain()` hands over what is already decided, `finish()` flushes the tail. A failure
names the index in the whole input, not in the chunk.

```moonbit
let sink = @base64.sink()
sink.write(b"moon"[:])
sink.write(b"base"[:])
assert_eq(sink.finish(), "bW9vbmJhc2U=")

let source = @base64.source()
source.write("bW9vbm")
assert_eq(source.drain(), b"moon")
```

base10, base36, base58 and base62 have no streaming face on purpose: the first digit
depends on the last byte.

## Whole numbers and addresses

`encode_int` / `decode_int` cover values where leading zeros have no meaning;
`BigInt` covers anything larger, on any alphabet. base58 adds `encode_check` /
`decode_check`; bech32 folds its human-readable prefix into the checksum.

```moonbit
let data = b"moonbase"

assert_eq(@base36.encode_int(123456789), "21i3v9")
assert_eq(@base62.encode_int(123456789), "8M0kX")
assert_eq(@bech32.encode("moonbase", data[:]), "moonbase1d4hk7mnzv9ek2s84pra")
assert_eq(@bech32.decode_words("moonbase1d4hk7mnzv9ek2s84pra").hrp, "moonbase")
```

`multibase` is the other way round: one character in front says how to read the rest,
and `detect` answers without decoding.

```moonbit
assert_eq(@multibase.encode(b"moonbase"[:], base=@multibase.Base58Btc), "zKJfFLz7PRba")
assert_eq(@multibase.detect("zKJfFLz7PRba"), Some(@multibase.Base58Btc))
assert_eq(@multibase.decode("zKJfFLz7PRba"), b"moonbase")
```

## Rules that catch people out

- `base8` and `base2` are bit packings, not the octal or binary spelling of a number:
  `base8` takes three bits at a time across the whole stream, so it is not `printf "%o"`
  of each byte.
- `base16` is byte-aligned, so a leading zero byte survives as `00`. The big-integer
  families (`base10`, `base36`, `base58`, `base62`) do not preserve leading zeros on
  their integer face — use the byte face when that matters.
- MoonBit has no implicit conversion: a `decode_int` result is `UInt64`, so write
  `123456789UL`, not `123456789`.
- Only base32 and base64 take `padding` and `strict`. base45 has no padding character,
  and its alphabet includes the space, so `whitespace` is not offered there.
- `decode_lossy` returns `b""` when the input cannot be read at all. It cannot tell a
  typo from an unimportant character; when the body has to be right, use `decode` with
  `whitespace=true`.
- `encode` and `decode` take the whole body, whatever its size — there is nothing to gain
  from chunking it by hand. `sink()` and `source()` are for a transport that hands you
  pieces, not for size.
- A `Malformed` carries `at` (the index), and `char` for `Bad`. The index is the
  position in the whole input, even after chunks have been fed to a `source()`.
