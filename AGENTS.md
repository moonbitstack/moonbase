<!-- Copyright 2026 Leo Cheng -->

# Working here

Run the gate before every commit and read every result:

```bash
moon clean && moon fmt && moon check --target all --deny-warn && moon build --target all && moon test --target all
```

`moon test` does not deny warnings, so `check` has to be run on its own. All four
backends have to pass: `wasm`, `wasm-gc`, `js` and `native`.

# The shape every encoding has

Five faces, the same names and the same argument order in every package:

```moonbit
encode(input : BytesView, kind? : Kind, padding? : Bool) -> String
encode_bytes(input : BytesView, kind? : Kind, padding? : Bool) -> Bytes
decode(input : StringView, kind? : Kind) -> Bytes raise @moonbase.Malformed
decode_bytes(input : BytesView, kind? : Kind) -> Bytes raise @moonbase.Malformed
decode_lossy(input : StringView, kind? : Kind) -> Bytes
```

`padding~` exists only where padding does; `kind~` only where there are
variants. The big-integer encodings add `encode_int` and `decode_int`.

# Things worth knowing

- **Variants are a named argument, never a function name.** `encode(x, kind=Url)`,
  not `encode_url(x)` — six encodings times their variants would otherwise be
  forty function names to remember.
- **Failures name their position.** `Bad(at~, char~)`, `Truncated(at~)`,
  `Padding(at~)`, `Checksum(at~)`. A caller who only wants the old `Option`
  writes `try? decode(s)`.
- **`abort` is for programming errors only.** `Alphabet::new` raises, because an
  alphabet can come from configuration; `Alphabet::of` aborts, because it is for
  the six literals in this library's own source.
- **base16, base32 and base64 share one bit packer** in `bits.mbt`: they differ
  only in bits per character and in their alphabet. Fix padding or error
  positions there and all three get it.
- **base36, base58 and base62 share the big-integer kernel** in `moonbase.mbt`.
  Leading zero bytes are preserved as leading zero digits; the integer faces
  have no such rule, which is why they are named apart.
- `moon info --target all` regenerates `pkg.generated.mbti`; CI fails if the
  result differs from what is committed.
- Every package's `moon.pkg` carries the URL of the specification it implements.
  A new package without one is not finished.
