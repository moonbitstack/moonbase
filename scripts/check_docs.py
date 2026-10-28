#!/usr/bin/env python3
# Copyright 2026 Leo Cheng
# SPDX-License-Identifier: Apache-2.0
"""Check the documentation's JavaScript encoders against the library's vectors.

The site has two interactive pages, and both of them encode in the browser
rather than calling into WebAssembly. That is only honest if the browser code
says the same thing the MoonBit code does, so this script takes the vectors the
tests already trust — multibase's vendored fixtures, and the specification
examples `gen_vectors.py` reproduces — and replays them through
`docs/assets/codecs.js` with node.

Usage:
    python3 scripts/check_docs.py
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def load_vectors():
    """`scripts/gen_vectors.py` as a module, for its reference encoders."""
    spec = importlib.util.spec_from_file_location(
        "gen_vectors", os.path.join(HERE, "gen_vectors.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fixture_cases(vectors):
    """Every multibase fixture row, as (payload, encoding, body without prefix)."""
    cases = []
    for name, payload in (
        ("basic", b"yes mani !"),
        ("leading-zero", b"\x00yes mani !"),
        ("two-leading-zeros", b"\x00\x00yes mani !"),
        # The last file is deliberately non-canonical: every letter that could
        # be flipped has been. Decoding it is required, re-encoding it is not,
        # so its rows are compared without regard to case.
        ("case-insensitivity", b"hello world"),
    ):
        path = os.path.join(HERE, "vectors", "multibase", name + ".csv")
        for encoding, encoded in vectors.fixture_rows(path):
            # The row is `prefix + body`; the prefix is one character, and some
            # of them are outside the basic plane, so slice by character.
            cases.append(
                {
                    "codec": "name",
                    "name": encoding,
                    "hex": payload.hex(),
                    "want": encoded[1:],
                    "from": "tests/%s.csv" % name,
                    "fold": name == "case-insensitivity",
                }
            )
    return cases


def known_cases(vectors):
    """The specification examples, replayed through the browser encoders."""
    cases = []

    def add(codec, payload, got, extra=None):
        case = {"codec": codec, "hex": payload.hex(), "want": got}
        if extra:
            case.update(extra)
        cases.append(case)

    for payload in (b"Man ", b"easy", b"sure", b"hello world", b"moonbase", b"a", b"ab", b"abc"):
        add("a85", payload, vectors.ascii85_encode(payload))
    add("z85", bytes.fromhex("864FD26FB559F75B"), "HelloWorld")
    add("z85", b"moon", "zeTug")
    add("ipv6", bytes.fromhex("108000000000000000080800200C417A"), "4)+k&C#VzJ4br>0wv%Yp")
    add("ipv6", bytes(16), "0")
    add("b45", b"Hello!!", "%69 VD92EX0")
    add("b45", b"yes mani !", vectors.base45_encode(b"yes mani !"))
    add("bech32", b"moonbase", vectors.bech32_encode("moonbase", vectors.words_of(b"moonbase")),
        {"hrp": "moonbase"})
    add("bech32", b"moonbase", vectors.bech32_encode("moonbase", vectors.words_of(b"moonbase"), "bech32m"),
        {"hrp": "moonbase", "variant": "m"})
    add("bech32", b"", "a12uel5l", {"hrp": "a"})
    add("bech32", b"", "a1lqfn3a", {"hrp": "a", "variant": "m"})
    return cases


def main():
    vectors = load_vectors()
    cases = fixture_cases(vectors) + known_cases(vectors)
    handle, path = tempfile.mkstemp(suffix=".json")
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as out:
            json.dump(cases, out)
        done = subprocess.run(
            ["node", os.path.join(HERE, "check_docs.js"), path],
            cwd=ROOT,
            text=True,
        )
    finally:
        os.unlink(path)
    return done.returncode


if __name__ == "__main__":
    sys.exit(main())
