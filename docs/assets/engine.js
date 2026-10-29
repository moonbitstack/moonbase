/* ============================================================================
   moonbase documentation — the engine
   ----------------------------------------------------------------------------
   moonbase itself, built to JavaScript by the docs workflow into
   engine/moonbase.js. The playground and the showcase wait on
   `window.moonbaseEngine` and encode through it, so what the pages print is
   what the library writes.
   ========================================================================== */
(function () {
  "use strict";

  function unwrap(json) {
    var result = JSON.parse(json);
    if (!result.ok) throw new Error(result.error);
    return result.value;
  }

  window.moonbaseEngine = import(new URL("engine/moonbase.js", document.baseURI).href)
    .then(function (m) {
      return {
        ALPHA: JSON.parse(m.alphabets()),
        bytesOf: function (text) { return new TextEncoder().encode(text); },
        rows: function (text) { return JSON.parse(m.rows(text)); },
        show: function (kind, text) { return unwrap(m.show(kind, text)); },
        bech32: function (hrp, text) { return unwrap(m.bech32(hrp, text)); }
      };
    });
})();
