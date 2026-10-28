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

if (failed) {
  console.log(failed + " of " + cases.length + " documentation vectors disagree");
  process.exit(1);
}
console.log("all " + cases.length + " documentation vectors reproduce");
