#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Ask this library and two reference implementations the same question.

Every other vector in this repository is a table that was generated once and
checked in, so it can only ever say what the two implementations agreed on the
day the table was written. This script asks a different question, at build time:

  * what this library writes for a payload, against what Python's ``base64``
    module writes and what Go's ``encoding/*`` writes;
  * what this library reads from the text those two wrote;
  * what those two read from the text this library wrote.

The third check is the one a vector table cannot make: it is the difference
between a library that agrees with a reference on paper and one a program using
that reference can actually talk to.

    python3 scripts/check_interop.py

Go is required; the CI job installs it. On a machine without a Go toolchain the
script says so rather than quietly checking half of what it claims.
"""

from __future__ import annotations

import base64
import pathlib
import random
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DRIVER_PACKAGE = "src/examples/interop"
GO_REFERENCE = ROOT / "scripts" / "interop_reference.go"
BATCH = 16  # cases per process: payload hex is long, and Windows caps argv at 32 KiB


# ----------------------------------------------------------------- references


def _pad(text: str, size: int) -> str:
    return text + "=" * (-len(text) % size)


class Codec:
    """One spelling of one encoding, as this library and the references name it.

    ``encode`` and ``decode`` are Python's answer; ``go`` is the name the Go
    reference knows it by, or None where Go has no implementation.
    """

    def __init__(self, name, encode, decode, go=None):
        self.name = name
        self.encode = encode
        self.decode = decode
        self.go = go


def _b64(text: str) -> bytes:
    return base64.b64decode(_pad(text, 4), validate=True)


def _b64url(text: str) -> bytes:
    return base64.urlsafe_b64decode(_pad(text, 4))


def _b32(text: str) -> bytes:
    return base64.b32decode(_pad(text, 8))


def _b32hex(text: str) -> bytes:
    return base64.b32hexdecode(_pad(text, 8))


CODECS = [
    Codec(
        "base16",
        lambda raw: raw.hex(),
        bytes.fromhex,
        go="base16",
    ),
    Codec(
        "base16-upper",
        lambda raw: raw.hex().upper(),
        bytes.fromhex,
        go="base16-upper",
    ),
    Codec(
        "base32",
        lambda raw: base64.b32encode(raw).decode().rstrip("="),
        _b32,
        go="base32",
    ),
    Codec(
        "base32-pad",
        lambda raw: base64.b32encode(raw).decode(),
        _b32,
        go="base32-pad",
    ),
    Codec(
        "base32-hex",
        lambda raw: base64.b32hexencode(raw).decode().rstrip("="),
        _b32hex,
        go="base32-hex",
    ),
    Codec(
        "base32-hex-pad",
        lambda raw: base64.b32hexencode(raw).decode(),
        _b32hex,
        go="base32-hex-pad",
    ),
    Codec(
        "base64",
        lambda raw: base64.b64encode(raw).decode().rstrip("="),
        _b64,
        go="base64",
    ),
    Codec(
        "base64-pad",
        lambda raw: base64.b64encode(raw).decode(),
        _b64,
        go="base64-pad",
    ),
    Codec(
        "base64-url",
        lambda raw: base64.urlsafe_b64encode(raw).decode().rstrip("="),
        _b64url,
        go="base64-url",
    ),
    Codec(
        "base64-url-pad",
        lambda raw: base64.urlsafe_b64encode(raw).decode(),
        _b64url,
        go="base64-url-pad",
    ),
    Codec(
        "base85",
        lambda raw: base64.a85encode(raw, adobe=False).decode(),
        lambda text: base64.a85decode(text.encode("ascii")),
        go="base85",
    ),
]


def payloads():
    """The payloads every codec is asked about.

    Short lengths first — one group, a group and a byte, exactly a group, a group
    and one byte again — then the two orderings of every byte value, then a fixed
    sample of random lengths, because the fixed seed is what makes a failure here
    reproducible a year later.
    """
    out = [
        b"",
        b"f",
        b"fo",
        b"foo",
        b"foob",
        b"fooba",
        b"foobar",
        b"yes mani !",
        b"Man is distinguished, not only by his reason",
        bytes(range(256)),
        bytes(range(255, -1, -1)),
    ]
    widths = [1, 2, 3, 4, 5, 6, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65,
              100, 127, 128, 129, 255, 256, 300]
    rng = random.Random(20261113)
    for width in widths:
        out.append(bytes(rng.randrange(256) for _ in range(width)))
    return out


# ------------------------------------------------------------------- drivers


def build(name="interop"):
    """Build the MoonBit driver and return the path to the binary."""
    subprocess.run(
        ["moon", "build", "--target", "native", "--release", DRIVER_PACKAGE],
        cwd=ROOT,
        check=True,
    )
    built = ROOT / "_build/native/release/build/examples/interop"
    for candidate in (built / f"{name}.exe", built / name):
        if candidate.exists():
            return candidate
    sys.exit(f"`moon build` did not put {name} where this script looks for it")


class Moon:
    """This library, through the driver that takes one batch at a time."""

    def __init__(self, path):
        self.path = path

    def ask(self, direction, codec, hexes):
        answers = []
        for start in range(0, len(hexes), BATCH):
            batch = hexes[start:start + BATCH]
            proc = subprocess.run(
                [str(self.path), direction, codec, *batch],
                cwd=ROOT,
                capture_output=True,
                text=True,
            )
            if proc.returncode != 0:
                sys.exit(f"the driver failed on {direction} {codec}:\n{proc.stderr}")
            answers += proc.stdout.splitlines()
        if len(answers) != len(hexes):
            sys.exit(
                f"the driver answered {len(answers)} of {len(hexes)} cases "
                f"for {direction} {codec}"
            )
        return answers


class Go:
    """Go's standard library, through one long-running reference process."""

    def __init__(self, go):
        self.go = go

    def ask(self, cases):
        """`cases` is a list of (direction, codec, hex); one answer each."""
        text = "".join(f"{d} {c} {h}\n" for d, c, h in cases)
        proc = subprocess.run(
            [self.go, "run", str(GO_REFERENCE)],
            cwd=ROOT,
            input=text,
            capture_output=True,
            text=True,
        )
        if proc.returncode != 0:
            sys.exit(f"the Go reference failed:\n{proc.stderr}")
        answers = proc.stdout.splitlines()
        if len(answers) != len(cases):
            sys.exit(f"the Go reference answered {len(answers)} of {len(cases)} cases")
        return answers


# ---------------------------------------------------------------------- check


class Report:
    def __init__(self):
        self.checks = 0
        self.failures = []

    def equal(self, what, got, want):
        self.checks += 1
        if got != want:
            self.failures.append(f"{what}\n    got  {got!r}\n    want {want!r}")

    def note(self, what, detail):
        self.checks += 1
        self.failures.append(f"{what}\n    {detail}")


def check_codec(report, moon, go, codec, cases):
    """Every direction, for one codec, over every payload."""
    payload_hex = [p.hex() for p in cases]

    # 1. We write what the references write.
    ours = moon.ask("encode", codec.name, payload_hex)
    reference = [codec.encode(p) for p in cases]
    for payload, mine, theirs in zip(cases, ours, reference):
        report.equal(
            f"{codec.name}: encode({payload[:16]!r}…) as text",
            mine,
            theirs.encode().hex(),
        )
    if go is not None and codec.go is not None:
        go_answers = go.ask([("encode", codec.go, h) for h in payload_hex])
        for payload, theirs, go_answer in zip(cases, reference, go_answers):
            report.equal(
                f"{codec.name}: Go writes the same text for {payload[:16]!r}…",
                go_answer,
                theirs.encode().hex(),
            )

    # 2. We read what they wrote.
    got = moon.ask("decode", codec.name, [t.encode().hex() for t in reference])
    for payload, decoded in zip(cases, got):
        report.equal(
            f"{codec.name}: decode of Python's text for {payload[:16]!r}…",
            decoded,
            payload.hex(),
        )

    # 3. They read what we wrote, which is the direction a vector table cannot check.
    for payload, mine in zip(cases, ours):
        text = bytes.fromhex(mine).decode("ascii")
        try:
            decoded = codec.decode(text)
        except Exception as failure:  # noqa: BLE001 - any refusal is a finding
            report.note(
                f"{codec.name}: Python refused our text for {payload[:16]!r}…",
                f"{text!r}: {failure}",
            )
            continue
        report.equal(
            f"{codec.name}: Python reads our text for {payload[:16]!r}…",
            decoded.hex(),
            payload.hex(),
        )
    if go is not None and codec.go is not None:
        go_answers = go.ask([("decode", codec.go, mine) for mine in ours])
        for payload, decoded in zip(cases, go_answers):
            report.equal(
                f"{codec.name}: Go reads our text for {payload[:16]!r}…",
                decoded,
                payload.hex(),
            )


def check_postscript_framing(report, moon, cases):
    """The framing PostScript puts around an Ascii85 body.

    Adobe's own writer wraps the payload in `<~` and `~>` and breaks lines inside
    it; a PDF content stream is full of both. Python's `adobe=True` is the
    reference, and the case is fed with a newline in the middle so that skipping
    whitespace is checked at the same time.
    """
    bodies = [base64.a85encode(p, adobe=False).decode() for p in cases]
    framed = []
    for body in bodies:
        cut = len(body) // 2
        framed.append(f"<~{body[:cut]}\n{body[cut:]}~>".encode().hex())
    got = moon.ask("decode", "base85", framed)
    for payload, decoded in zip(cases, got):
        report.equal(
            f"base85: a <~ ~> body decodes for {payload[:16]!r}…",
            decoded,
            payload.hex(),
        )
    for payload, body in zip(cases, bodies):
        try:
            want = base64.a85decode(f"<~{body}~>".encode(), adobe=True)
        except Exception as failure:  # noqa: BLE001
            report.note("base85: Python refused its own framed text", f"{body!r}: {failure}")
            continue
        report.equal(
            f"base85: Python's framed text is the payload for {payload[:16]!r}…",
            want.hex(),
            payload.hex(),
        )


def main():
    if shutil.which("moon") is None:
        sys.exit("moon is not on PATH")
    go_binary = shutil.which("go")
    if go_binary is None:
        sys.exit(
            "go is not on PATH; this check compares two reference implementations "
            "and will not run with one"
        )
    moon = Moon(build())
    go = Go(go_binary)
    cases = payloads()
    report = Report()

    for codec in CODECS:
        check_codec(report, moon, go, codec, cases)
    check_postscript_framing(report, moon, cases)

    if report.failures:
        print("\n".join(report.failures))
        print(f"\n{len(report.failures)} of {report.checks} comparisons disagree")
        return 1
    print(
        f"{report.checks} comparisons agree: {len(CODECS)} spellings x {len(cases)} "
        f"payloads, both directions, against Python and Go"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
