// Kolaysoft Köprüsü - AĞ YAKALAYICI (sayfa bağlamı / MAIN world)
// Portalın kendi yaptığı istekleri DİNLER. Yanıtları KOPYALAYARAK okur; orijinal akışa
// asla dokunmaz (sayfa normal çalışır). Hiçbir istek göndermez, değiştirmez, engellemez.
(function () {
  "use strict";
  if (window.__kolaysoftYakala) return;
  window.__kolaysoftYakala = true;

  const GONDER = (url, body) => {
    try {
      // Sadece makul boyutlu metinleri işle
      if (typeof body !== "string" || body.length < 2 || body.length > 4000000) return;
      const t = body.trim();
      if (t[0] !== "{" && t[0] !== "[") return;     // JSON değilse boşver
      let veri; try { veri = JSON.parse(t); } catch { return; }
      window.postMessage({ __kolaysoft: true, url: String(url || ""), veri }, "*");
    } catch { /* sessiz */ }
  };

  // --- fetch ---
  const asilFetch = window.fetch;
  if (asilFetch) {
    window.fetch = function (...a) {
      return asilFetch.apply(this, a).then(yanit => {
        try {
          const ct = (yanit.headers && yanit.headers.get("content-type")) || "";
          if (/json|text/i.test(ct) || ct === "") {
            yanit.clone().text().then(txt => GONDER(yanit.url || (a[0] && a[0].url) || a[0], txt)).catch(() => {});
          }
        } catch {}
        return yanit;   // orijinal yanıt sayfaya dokunulmadan döner
      });
    };
  }

  // --- XMLHttpRequest ---
  const asilOpen = XMLHttpRequest.prototype.open;
  const asilSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) { this.__ksUrl = u; return asilOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function () {
    try {
      this.addEventListener("load", () => {
        try {
          const rt = this.responseType;
          if (rt === "" || rt === "text") GONDER(this.__ksUrl, this.responseText);
          else if (rt === "json" && this.response) GONDER(this.__ksUrl, JSON.stringify(this.response));
        } catch {}
      });
    } catch {}
    return asilSend.apply(this, arguments);
  };
})();
