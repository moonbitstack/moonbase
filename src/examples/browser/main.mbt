///|
/// What a refusal says, for the page to print.
fn message(e : @moonbase.Malformed) -> String {
  match e {
    Bad(at~, char~) => "'\{char}' at \{at} is refused"
    Truncated(at~) => "the input stops early, at \{at}"
    Padding(at~) => "the padding at \{at} is wrong"
    Checksum(at~) => "the checksum at \{at} does not match"
  }
}

///|
fn result(run : () -> String raise @moonbase.Malformed) -> String {
  let json : Json = { "ok": true, "value": Json::string(run()) } catch {
    e => { "ok": false, "error": Json::string(message(e)) }
  }
  json.stringify()
}

///|
/// What each package's own `encode` writes for `kind`, the showcase's choices.
fn encoded(kind : String, b : Bytes) -> String raise @moonbase.Malformed {
  match kind {
    "base2" => @base2.encode(b)
    "base8" => @base8.encode(b)
    "base10" => @base10.encode(b)
    "base16" => @base16.encode(b)
    "base32" => @base32.encode(b)
    "base36" => @base36.encode(b)
    "base45" => @base45.encode(b)
    "base58" => @base58.encode(b)
    "base62" => @base62.encode(b)
    "base64" => @base64.encode(b)
    "base85" => @base85.encode(b)
    "base256emoji" => {
      // Multibase writes the alphabet's rocket as the prefix; the body follows.
      let s = @multibase.encode(b, base=Base256Emoji)
      s.view(start_offset=s.offset_of_nth_char(1).unwrap_or(0)).to_owned()
    }
    _ => abort("no encoding called \{kind}")
  }
}

///|
/// The showcase's result for `kind` over the UTF-8 of `text`.
pub fn show(kind : String, text : String) -> String {
  result(() => encoded(kind, @utf8.encode(text)))
}

///|
/// A Bech32 string with the human-readable part `hrp`.
pub fn bech32(hrp : String, text : String) -> String {
  result(() => @bech32.encode(hrp, @utf8.encode(text)))
}

///|
/// The playground's rows: one label and one string per encoding.
pub fn rows(text : String) -> String {
  let b = @utf8.encode(text)
  let hrp = "moonbase"
  let line = (label : String, run : () -> String raise @moonbase.Malformed) => {
    let value = run() catch { e => "— " + message(e) }
    Json::array([Json::string(label), Json::string(value)])
  }
  let out : Array[Json] = [
    line("base2", () => @base2.encode(b)),
    line("base8", () => @base8.encode(b)),
    line("base10", () => @base10.encode(b)),
    line("base16", () => @base16.encode(b)),
    line("base32", () => @base32.encode(b)),
    line("base32 hex", () => @base32.encode(b, kind=Hex)),
    line("base36", () => @base36.encode(b)),
    line("base45", () => @base45.encode(b)),
    line("base58", () => @base58.encode(b)),
    line("base62", () => @base62.encode(b)),
    line("base64", () => @base64.encode(b)),
    line("base64 url", () => @base64.encode(b, kind=Url, padding=false)),
    line("base85", () => @base85.encode(b)),
    line("base256emoji", () => encoded("base256emoji", b)),
    line("bech32 (\{hrp})", () => @bech32.encode(hrp, b)),
    line("multibase (z, base58btc)", () => @multibase.encode(b, base=Base58Btc)),
  ]
  Json::array(out).stringify()
}

///|
fn letters(a : @moonbase.Alphabet) -> String {
  let out = StringBuilder()
  for i in 0..<a.base() {
    out.write_char(a.char_of(i))
  }
  out.to_string()
}

///|
/// The alphabets the showcase draws digit tables from. Bech32's is read off an
/// encoding of the thirty-two five-bit values in order.
pub fn alphabets() -> String {
  let words = Bytes::makei(32, i => i.to_byte())
  let spelled = @bech32.encode_words("a", words) catch { _ => "" }
  let bech32 = spelled.view(start_offset=2, end_offset=34).to_owned()
  let json : Json = {
    "base10": Json::string(letters(@base10.alphabet)),
    "base36": Json::string(letters(@base36.alphabet)),
    "base58": Json::string(letters(@base58.alphabet)),
    "base62": Json::string(letters(@base62.alphabet)),
    "bech32": Json::string(bech32),
  }
  json.stringify()
}
