// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// Runs the documentation's codec engine over the library's own vectors. Driven
// by `scripts/check_docs.py`, which writes the cases out as JSON: the MoonBit
// tests, the fixtures and this file then all read from the same table.
//
//     node scripts/check_docs.js cases.json

const fs = require("fs");
const path = require("path");

const Moonbase = require(path.join(__dirname, "..", "docs", "assets", "codecs.js"));

const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));

function hexBytes(hex) {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

let failed = 0;
for (const item of cases) {
  const bytes = hexBytes(item.hex);
  let got;
  try {
    if (item.codec === "name") {
      got = Moonbase.byName(item.name, bytes);
    } else if (item.codec === "bech32") {
      got = Moonbase.bech32(item.hrp, bytes, item.variant);
    } else {
      got = Moonbase[item.codec](bytes);
    }
  } catch (failure) {
    got = "<" + failure.message + ">";
  }
  if (item.fold ? got.toLowerCase() !== item.want.toLowerCase() : got !== item.want) {
    failed++;
    console.log(
      "  " +
        (item.from || item.codec) +
        " " +
        (item.name || "") +
        " " +
        item.hex +
        "\n    got  " +
        JSON.stringify(got) +
        "\n    want " +
        JSON.stringify(item.want)
    );
  }
}

// The playground on the homepage is assembled by hand, so none of the vectors
// above would notice a package that never got a row. Pin the labels, then check
// the two rows whose values are derived rather than copied.
const PLAYGROUND = "Hello, MoonBit!";
const playgroundBytes = new TextEncoder().encode(PLAYGROUND);
const rows = Moonbase.rows(PLAYGROUND);
const WANT_ROWS = [
  "base2", "base8", "base10", "base16", "base32", "base32 hex", "base36",
  "base45", "base58", "base62", "base64", "base64 url", "base85",
  "base256emoji", "bech32 (moonbase)", "multibase (z, base58btc)",
];

let rowsFailed = 0;
function rowProblem(text) {
  rowsFailed++;
  console.log("  playground " + text);
}

const labels = rows.map((row) => row[0]);
if (JSON.stringify(labels) !== JSON.stringify(WANT_ROWS)) {
  rowProblem(
    "rows are " + JSON.stringify(labels) + "\n    want " + JSON.stringify(WANT_ROWS)
  );
}
for (const [label, value] of rows) {
  if (typeof value !== "string" || value === "") rowProblem(label + " is empty");
}
const rowOf = (label) => (rows.find((row) => row[0] === label) || [])[1];
if (rowOf("bech32 (moonbase)") !== Moonbase.bech32("moonbase", playgroundBytes)) {
  rowProblem("the bech32 row disagrees with bech32()");
}
if (rowOf("multibase (z, base58btc)") !== "z" + Moonbase.byName("base58btc", playgroundBytes)) {
  rowProblem("the multibase row disagrees with base58");
}

if (failed || rowsFailed) {
  if (failed) {
    console.log(failed + " of " + cases.length + " documentation vectors disagree");
  }
  process.exit(1);
}
console.log("all " + cases.length + " documentation vectors reproduce");
console.log("the playground lists all " + WANT_ROWS.length + " rows and they agree with their codecs");
