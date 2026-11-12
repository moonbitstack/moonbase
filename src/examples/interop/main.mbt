// Copyright 2026 Leo Cheng
// SPDX-License-Identifier: Apache-2.0

///|
/// The program `scripts/check_interop.py` drives, so that this library can be
/// asked the same question as a reference implementation and the two answers
/// compared.
///
/// ```text
/// interop encode base64 6d6f6f6e 6d6f6f6e62617365
/// 6d57397662324e6c
/// 6d57397662324e6c626d467a5a513d3d
/// ```
///
/// The direction, the codec and every case come from the command line, and one
/// answer is printed per case. Both the payload and the answer travel as
/// hexadecimal: that keeps the argument ASCII, so a space inside a base45 string
/// cannot be split by a shell and a character above U+00FF cannot be mangled by
/// a console code page on the way in.
///
/// A case that the codec refuses prints `!error`, which is an answer too: a
/// reference implementation and this one have to agree on what is malformed, not
/// only on what is not.
fn main {
  let argv = @env.args()
  guard argv.length() >= 4 else {
    println("usage: interop encode|decode <codec> <hex> [<hex> ...]")
    return
  }
  let direction = argv[1][:]
  let codec = argv[2][:]
  for i in 3..<argv.length() {
    let answer = Ok(answer_of(direction, codec, argv[i][:])) catch {
      _ => Err(())
    }
    match answer {
      Ok(text) => println(text)
      Err(_) => println("!error")
    }
  }
}

///|
/// One case: the payload as hexadecimal in, the answer as hexadecimal out.
///
/// `encode` reads the payload as bytes and writes the text's UTF-8 bytes;
/// `decode` reads the text's UTF-8 bytes and writes the payload it stands for.
fn answer_of(
  direction : StringView,
  codec : StringView,
  payload : StringView,
) -> String raise {
  let raw = @base16.decode(payload)
  if direction == "encode" {
    @base16.encode(@utf8.encode(encode(codec, raw[:])[:]))
  } else {
    @base16.encode(decode(codec, @utf8.decode(raw[:]))[:])
  }
}

///|
/// The codecs the script may name. The names are the script's, not a public
/// surface: they say which spelling of an encoding is wanted, since a variant is
/// an argument here as it is in the library.
fn encode(
  codec : StringView,
  raw : BytesView,
) -> String raise @moonbase.Malformed {
  match codec {
    "base2" => @base2.encode(raw)
    "base8" => @base8.encode(raw)
    "base10" => @base10.encode(raw)
    "base16" => @base16.encode(raw)
    "base16-upper" => @base16.encode(raw, kind=@base16.Upper)
    "base32" => @base32.encode(raw, padding=false)
    "base32-pad" => @base32.encode(raw, padding=true)
    "base32-hex" => @base32.encode(raw, kind=@base32.Hex, padding=false)
    "base32-hex-pad" => @base32.encode(raw, kind=@base32.Hex, padding=true)
    "base32-crockford" => @base32.encode(raw, kind=@base32.Crockford)
    "base32-z" => @base32.encode(raw, kind=@base32.Z)
    "base36" => @base36.encode(raw)
    "base45" => @base45.encode(raw)
    "base58" => @base58.encode(raw)
    "base58-flickr" => @base58.encode(raw, kind=@base58.Flickr)
    "base58-check" => @base58.encode_check(raw)
    "base62" => @base62.encode(raw)
    "base64" => @base64.encode(raw, padding=false)
    "base64-pad" => @base64.encode(raw, padding=true)
    "base64-url" => @base64.encode(raw, kind=@base64.Url, padding=false)
    "base64-url-pad" => @base64.encode(raw, kind=@base64.Url, padding=true)
    "base85" => @base85.encode(raw)
    "base85-z85" => @base85.encode(raw, kind=@base85.Z85)
    "bech32" => @bech32.encode("moonbase", raw)
    _ => abort("interop: no codec named " + codec.to_owned())
  }
}

///|
/// The reverse of [`encode`](#encode), with the same names.
fn decode(
  codec : StringView,
  text : StringView,
) -> Bytes raise @moonbase.Malformed {
  match codec {
    "base2" => @base2.decode(text)
    "base8" => @base8.decode(text)
    "base10" => @base10.decode(text)
    "base16" => @base16.decode(text)
    "base16-upper" => @base16.decode(text)
    "base32" => @base32.decode(text, padding=false)
    "base32-pad" => @base32.decode(text, padding=true)
    "base32-hex" => @base32.decode(text, kind=@base32.Hex, padding=false)
    "base32-hex-pad" => @base32.decode(text, kind=@base32.Hex, padding=true)
    "base32-crockford" => @base32.decode(text, kind=@base32.Crockford)
    "base32-z" => @base32.decode(text, kind=@base32.Z)
    "base36" => @base36.decode(text)
    "base45" => @base45.decode(text)
    "base58" => @base58.decode(text)
    "base58-flickr" => @base58.decode(text, kind=@base58.Flickr)
    "base58-check" => @base58.decode_check(text)
    "base62" => @base62.decode(text)
    "base64" => @base64.decode(text, padding=false)
    "base64-pad" => @base64.decode(text, padding=true)
    "base64-url" => @base64.decode(text, kind=@base64.Url, padding=false)
    "base64-url-pad" => @base64.decode(text, kind=@base64.Url, padding=true)
    "base85" => @base85.decode(text)
    "base85-z85" => @base85.decode(text, kind=@base85.Z85)
    "bech32" => @bech32.decode(text).data
    _ => abort("interop: no codec named " + codec.to_owned())
  }
}
