// Kolaysoft Köprüsü (içerik betiği / izole dünya)
// Yakalayıcıdan gelen fatura verisini tekilleştirip İstiklal Muhasebe'ye (Supabase) yazar.
// SADECE OKUR + AKTARIR. Portalda hiçbir şeye tıklamaz, fatura kesmez/göndermez.
(function () {
  "use strict";
  if (window.__kolaysoftKopru) return;
  window.__kolaysoftKopru = true;

  const SB_URL = "https://hmgxulrssqsqnfhibmzz.supabase.co";
  const SB_KEY = "sb_publishable_kGiwMdnja2OhbzBYEX0zog_dQ9R8m_h";
  const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

  const tampon = { giden: {}, gelen: {}, earsiv: {}, diger: {} };
  const sayac = { giden: 0, gelen: 0, earsiv: 0, diger: 0 };
  let alanlar = [];
  let sonDurum = "bağlı, bekleniyor…";
  let flushZaman = null;

  // ---------- Supabase REST ----------
  const basliklar = (ekstra) => Object.assign({ apikey: SB_KEY, Authorization: "Bearer " + SB_KEY }, ekstra || {});
  async function supaOku(anahtar) {
    const r = await fetch(`${SB_URL}/rest/v1/ayar?anahtar=eq.${encodeURIComponent(anahtar)}&select=deger`, { headers: basliklar() });
    if (!r.ok) throw new Error("oku " + r.status);
    const j = await r.json();
    return (j && j[0]) ? j[0].deger : null;
  }
  async function supaYaz(anahtar, deger) {
    const r = await fetch(`${SB_URL}/rest/v1/ayar?on_conflict=anahtar`, {
      method: "POST",
      headers: basliklar({ "Content-Type": "application/json", Prefer: "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify({ anahtar, deger, guncelleme: new Date().toISOString() })
    });
    if (!r.ok) throw new Error("yaz " + r.status + " " + (await r.text().catch(() => "")).slice(0, 140));
  }

  // ---------- Fatura tespiti ----------
  function uuidDeger(o) {
    if (!o || typeof o !== "object") return null;
    for (const k in o) { const v = o[k]; if (typeof v === "string" && UUID.test(v)) return v; }
    return null;
  }
  function faturaMi(o) {
    if (!o || typeof o !== "object" || Array.isArray(o)) return false;
    if (!uuidDeger(o)) return false;
    const adlar = Object.keys(o).join("|").toLowerCase();
    return /fatura|ettn|tutar|unvan|vkn|tckn|senaryo|matrah|kdv|belge|tarih|alici|odenecek| unvani/.test(adlar);
  }
  // Veri içinde fatura dizilerini (iç içe de olsa) bulur
  function faturaDizileriBul(veri, derinlik, cikti) {
    cikti = cikti || [];
    if (derinlik == null) derinlik = 0;
    if (derinlik > 6 || !veri || typeof veri !== "object") return cikti;
    if (Array.isArray(veri)) {
      if (veri.length && faturaMi(veri[0])) { cikti.push(veri); return cikti; }
      for (let i = 0; i < Math.min(veri.length, 50); i++) faturaDizileriBul(veri[i], derinlik + 1, cikti);
      return cikti;
    }
    for (const k in veri) faturaDizileriBul(veri[k], derinlik + 1, cikti);
    return cikti;
  }
  function yonBul() {
    const u = location.href.toLowerCase();
    if (u.includes("outbox") || u.includes("giden")) return "giden";
    if (u.includes("inbox") || u.includes("gelen")) return "gelen";
    if (u.includes("archive") || u.includes("arsiv") || u.includes("earchive")) return "earsiv";
    return "diger";
  }

  // ---------- Yakalama ----------
  window.addEventListener("message", (ev) => {
    const d = ev.data;
    if (!d || d.__kolaysoft !== true) return;
    try {
      const diziler = faturaDizileriBul(d.veri);
      if (!diziler.length) return;
      const yon = yonBul();
      let yeni = 0;
      for (const arr of diziler) {
        for (const o of arr) {
          const id = uuidDeger(o);
          if (!id) continue;
          if (!tampon[yon][id]) yeni++;
          tampon[yon][id] = o;
        }
        if (arr[0]) alanlar = Object.keys(arr[0]);
      }
      if (yeni > 0) { panelCiz(); flushPlanla(); }
    } catch {}
  });

  function flushPlanla() { clearTimeout(flushZaman); flushZaman = setTimeout(flush, 2500); }

  async function flush() {
    for (const yon of ["giden", "gelen", "earsiv", "diger"]) {
      const map = tampon[yon];
      const ids = Object.keys(map);
      if (!ids.length) continue;
      const anahtar = "muh_ham_" + yon;
      const birlesik = {};
      try {
        const s = await supaOku(anahtar);
        if (s) { const a = JSON.parse(s); for (const o of a) { const id = uuidDeger(o); if (id) birlesik[id] = o; } }
      } catch (e) { sonDurum = "okuma hatası: " + e.message; panelCiz(); }
      for (const id of ids) birlesik[id] = map[id];
      const dizi = Object.values(birlesik);
      try { await supaYaz(anahtar, JSON.stringify(dizi)); sayac[yon] = dizi.length; }
      catch (e) { sonDurum = "⚠ yazma hatası: " + e.message; panelCiz(); return; }
    }
    try { await supaYaz("muh_kopru_durum", JSON.stringify({ zaman: new Date().toISOString(), say: sayac, alanlar })); } catch {}
    sonDurum = "aktarıldı ✓ " + new Date().toLocaleTimeString("tr-TR");
    panelCiz();
  }

  // ---------- Panel (sadece üst çerçevede) ----------
  let panel = null;
  function panelCiz() {
    if (window.top !== window) return;
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "ks-kopru-panel";
      panel.style.cssText = "position:fixed;right:14px;bottom:14px;z-index:2147483647;width:270px;font:13px/1.4 system-ui,Segoe UI,Arial;color:#0f172a;background:#fff;border:2px solid #0ea5e9;border-radius:14px;box-shadow:0 10px 30px rgba(2,132,199,.25);overflow:hidden";
      document.documentElement.appendChild(panel);
    }
    const t = sayac.giden + sayac.gelen + sayac.earsiv + sayac.diger;
    panel.innerHTML =
      '<div style="background:linear-gradient(135deg,#0ea5e9,#2563eb);color:#fff;padding:9px 12px;font-weight:800;display:flex;justify-content:space-between;align-items:center">' +
      '<span>🌉 Kolaysoft Köprüsü</span><span id="ks-gizle" style="cursor:pointer;opacity:.85">✕</span></div>' +
      '<div style="padding:10px 12px">' +
      '<div style="display:flex;gap:6px;margin-bottom:8px">' +
      kutu("Giden", sayac.giden, "#16a34a") + kutu("Gelen", sayac.gelen, "#dc2626") + kutu("e-Arşiv", sayac.earsiv, "#9333ea") +
      '</div>' +
      '<div style="font-size:12px;color:#334155">' + sonDurum + '</div>' +
      (alanlar.length ? '<div style="font-size:10px;color:#94a3b8;margin-top:6px;word-break:break-all">alan: ' + alanlar.slice(0, 16).join(", ") + '</div>' : '') +
      '<div style="font-size:11px;color:#64748b;margin-top:8px">Portalda ay ay faturalara bakın; görünenler otomatik aktarılır. Sadece okur.</div>' +
      '</div>';
    const g = panel.querySelector("#ks-gizle"); if (g) g.onclick = () => { panel.style.display = "none"; };
  }
  function kutu(ad, say, renk) {
    return '<div style="flex:1;text-align:center;background:' + renk + '14;border:1px solid ' + renk + '55;border-radius:9px;padding:5px 2px">' +
      '<div style="font-weight:800;color:' + renk + ';font-size:16px">' + say + '</div>' +
      '<div style="font-size:10px;color:#64748b">' + ad + '</div></div>';
  }

  if (window.top === window) {
    const basla = () => panelCiz();
    if (document.body) basla(); else window.addEventListener("DOMContentLoaded", basla);
  }
})();
