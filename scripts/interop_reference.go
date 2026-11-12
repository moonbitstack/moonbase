// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0
//
// The reference half of scripts/check_interop.py: the same question the MoonBit
// driver answers, put to Go's standard library instead.
//
//	go run scripts/interop_reference.go
//
// One case a line on standard input — `encode base64 <payload hex>` or
// `decode base64 <text hex>` — and one answer a line on standard output, with
// `!error` for a case this implementation refuses. Reading the whole batch from
// one process keeps the comparison cheap enough to run over every payload.
package main

import (
	"bufio"
	"encoding/ascii85"
	"encoding/base32"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
)

func main() {
	in := bufio.NewScanner(os.Stdin)
	in.Buffer(make([]byte, 0, 64*1024), 1<<22)
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for in.Scan() {
		// Split rather than Fields: an empty payload is a case too, and Fields
		// would drop it and leave two fields behind.
		fields := strings.Split(in.Text(), " ")
		if len(fields) != 3 {
			fmt.Fprintln(out, "!error")
			continue
		}
		answer, err := answer(fields[0], fields[1], fields[2])
		if err != nil {
			fmt.Fprintln(out, "!error")
			continue
		}
		fmt.Fprintln(out, answer)
	}
}

// answer is one case: a payload and a text, both hexadecimal, one of them given.
func answer(direction, codec, payload string) (string, error) {
	raw, err := hex.DecodeString(payload)
	if err != nil {
		return "", err
	}
	if direction == "encode" {
		text, err := encode(codec, raw)
		if err != nil {
			return "", err
		}
		return hex.EncodeToString([]byte(text)), nil
	}
	text, err := decode(codec, string(raw))
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(text), nil
}

func encode(codec string, raw []byte) (string, error) {
	switch codec {
	case "base16":
		return hex.EncodeToString(raw), nil
	case "base16-upper":
		return strings.ToUpper(hex.EncodeToString(raw)), nil
	case "base32":
		return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(raw), nil
	case "base32-pad":
		return base32.StdEncoding.EncodeToString(raw), nil
	case "base32-hex":
		return base32.HexEncoding.WithPadding(base32.NoPadding).EncodeToString(raw), nil
	case "base32-hex-pad":
		return base32.HexEncoding.EncodeToString(raw), nil
	case "base64":
		return base64.RawStdEncoding.EncodeToString(raw), nil
	case "base64-pad":
		return base64.StdEncoding.EncodeToString(raw), nil
	case "base64-url":
		return base64.RawURLEncoding.EncodeToString(raw), nil
	case "base64-url-pad":
		return base64.URLEncoding.EncodeToString(raw), nil
	case "base85":
		dst := make([]byte, ascii85.MaxEncodedLen(len(raw)))
		n := ascii85.Encode(dst, raw)
		return string(dst[:n]), nil
	}
	return "", fmt.Errorf("no codec named %q", codec)
}

func decode(codec, text string) ([]byte, error) {
	src := []byte(text)
	switch codec {
	case "base16", "base16-upper":
		return hex.DecodeString(text)
	case "base32":
		return base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(text)
	case "base32-pad":
		return base32.StdEncoding.DecodeString(text)
	case "base32-hex":
		return base32.HexEncoding.WithPadding(base32.NoPadding).DecodeString(text)
	case "base32-hex-pad":
		return base32.HexEncoding.DecodeString(text)
	case "base64":
		return base64.RawStdEncoding.DecodeString(text)
	case "base64-pad":
		return base64.StdEncoding.DecodeString(text)
	case "base64-url":
		return base64.RawURLEncoding.DecodeString(text)
	case "base64-url-pad":
		return base64.URLEncoding.DecodeString(text)
	case "base85":
		dst := make([]byte, len(src)/5*4+4)
		n, _, err := ascii85.Decode(dst, src, true)
		if err != nil {
			return nil, err
		}
		return dst[:n], nil
	}
	return nil, fmt.Errorf("no codec named %q", codec)
}
