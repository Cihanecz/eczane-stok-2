// Kolaysoft Köprüsü (içerik betiği / izole dünya)
// Yakalayıcıdan gelen fatura verisini tekilleştirip İstiklal Üstün Muhasebe'ye (Supabase) yazar.
// SADECE OKUR + AKTARIR. Portalda hiçbir şeye tıklamaz, fatura kesmez/göndermez.
// Giriş: İstiklal stok programının Supabase kullanıcısı (bir kez panelde girilir, hatırlanır).
(function () {
  "use strict";
  if (window.__kolaysoftKopru) return;
  window.__kolaysoftKopru = true;
  if (window.top !== window && !document.querySelector) return;

  const SB_URL = "https://hmgxulrssqsqnfhibmzz.supabase.co";
  const SB_KEY = "sb_publishable_kGiwMdnja2OhbzBYEX0zog_dQ9R8m_h";
  const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

  // Oturum eklentinin kendi deposunda tutulur (portal sayfasının localStorage'ına sızmaz)
  const depo = {
    getItem: (k) => new Promise(r => chrome.storage.local.get(k, o => r(o[k] == null ? null : o[k]))),
    setItem: (k, v) => new Promise(r => chrome.storage.local.set({ [k]: v }, r)),
    removeItem: (k) => new Promise(r => chrome.storage.local.remove(k, r))
  };
  const db = (typeof supabase !== "undefined" && supabase.createClient)
    ? supabase.createClient(SB_URL, SB_KEY, { auth: { storage: depo, persistSession: true, autoRefreshToken: true, storageKey: "ks_kopru_oturum" } })
    : null;

  const tampon = { giden: {}, gelen: {}, earsiv: {}, diger: {} };
  const sayac = { giden: 0, gelen: 0, earsiv: 0, diger: 0 };
  let alanlar = [], sonDurum = "başlatılıyor…", oturum = false, flushZaman = null;

  async function supaOku(anahtar) {
    const { data, error } = await db.from("ayar").select("deger").eq("anahtar", anahtar).maybeSingle();
    if (error) throw new Error(error.message); return data ? data.deger : null;
  }
  async function supaYaz(anahtar, deger) {
    const { error } = await db.from("ayar").upsert({ anahtar, deger, guncelleme: new Date().toISOString() }, { onConflict: "anahtar" });
    if (error) throw new Error(error.message);
  }

  // ---------- Fatura tespiti ----------
  function uuidDeger(o) { if (!o || typeof o !== "object") return null; for (const k in o) { const v = o[k]; if (typeof v === "string" && UUID.test(v)) return v; } return null; }
  function faturaMi(o) {
    if (!o || typeof o !== "object" || Array.isArray(o)) return false;
    if (!uuidDeger(o)) return false;
    return /fatura|ettn|tutar|unvan|vkn|tckn|senaryo|matrah|kdv|belge|tarih|alici|odenecek/.test(Object.keys(o).join("|").toLowerCase());
  }
  function faturaDizileriBul(veri, derinlik, cikti) {
    cikti = cikti || []; if (derinlik == null) derinlik = 0;
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

  window.addEventListener("message", (ev) => {
    const d = ev.data; if (!d || d.__kolaysoft !== true) return;
    try {
      const diziler = faturaDizileriBul(d.veri); if (!diziler.length) return;
      const yon = yonBul(); let yeni = 0;
      for (const arr of diziler) {
        for (const o of arr) { const id = uuidDeger(o); if (!id) continue; if (!tampon[yon][id]) yeni++; tampon[yon][id] = o; }
        if (arr[0]) alanlar = Object.keys(arr[0]);
      }
      if (yeni > 0) { panelCiz(); if (oturum) flushPlanla(); else { sonDurum = "yakalandı, giriş bekleniyor"; panelCiz(); } }
    } catch {}
  });

  function flushPlanla() { clearTimeout(flushZaman); flushZaman = setTimeout(flush, 2500); }
  async function flush() {
    if (!oturum) return;
    for (const yon of ["giden", "gelen", "earsiv", "diger"]) {
      const map = tampon[yon], ids = Object.keys(map); if (!ids.length) continue;
      const anahtar = "muh_ham_" + yon, birlesik = {};
      try { const s = await supaOku(anahtar); if (s) { for (const o of JSON.parse(s)) { const id = uuidDeger(o); if (id) birlesik[id] = o; } } }
      catch (e) { sonDurum = "okuma hatası: " + e.message; panelCiz(); }
      for (const id of ids) birlesik[id] = map[id];
      const dizi = Object.values(birlesik);
      try { await supaYaz(anahtar, JSON.stringify(dizi)); sayac[yon] = dizi.length; }
      catch (e) { sonDurum = "⚠ yazma hatası: " + e.message; panelCiz(); return; }
    }
    try { await supaYaz("muh_kopru_durum", JSON.stringify({ zaman: new Date().toISOString(), say: sayac, alanlar })); } catch {}
    sonDurum = "aktarıldı ✓ " + new Date().toLocaleTimeString("tr-TR"); panelCiz();
  }

  // ---------- Giriş ----------
  async function oturumKontrol() {
    if (!db) { sonDurum = "supabase yüklenemedi"; panelCiz(); return; }
    try { const { data } = await db.auth.getSession(); oturum = !!(data && data.session); } catch { oturum = false; }
    sonDurum = oturum ? "bağlı, faturalar bekleniyor…" : "giriş gerekli (İstiklal stok girişi)";
    panelCiz();
    if (oturum) flushPlanla();
  }
  async function girisYap() {
    const e = (document.getElementById("ks-email") || {}).value, p = (document.getElementById("ks-sifre") || {}).value;
    if (!e || !p) { sonDurum = "e-posta/şifre gir"; panelCiz(); return; }
    sonDurum = "giriş yapılıyor…"; panelCiz();
    try { const { error } = await db.auth.signInWithPassword({ email: e.trim(), password: p }); if (error) throw error; oturum = true; sonDurum = "giriş başarılı ✓"; panelCiz(); flushPlanla(); }
    catch (err) { sonDurum = "⚠ giriş hatası: " + (err.message || err); panelCiz(); }
  }

  // ---------- Panel ----------
  let panel = null;
  function panelCiz() {
    if (window.top !== window) return;
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "ks-kopru-panel";
      panel.style.cssText = "position:fixed;right:14px;bottom:14px;z-index:2147483647;width:280px;font:13px/1.4 system-ui,Segoe UI,Arial;color:#0f172a;background:#fff;border:2px solid #0ea5e9;border-radius:14px;box-shadow:0 10px 30px rgba(2,132,199,.25);overflow:hidden";
      document.documentElement.appendChild(panel);
    }
    let govde;
    if (!oturum) {
      govde = '<div style="padding:11px 12px">' +
        '<div style="font-size:12px;color:#334155;margin-bottom:8px">İstiklal stok programı girişinle bağlan (bir kez):</div>' +
        '<input id="ks-email" type="email" placeholder="e-posta" style="width:100%;margin-bottom:6px;padding:7px 9px;border:1px solid #cbd5e1;border-radius:8px;font-size:13px">' +
        '<input id="ks-sifre" type="password" placeholder="şifre" style="width:100%;margin-bottom:8px;padding:7px 9px;border:1px solid #cbd5e1;border-radius:8px;font-size:13px">' +
        '<button id="ks-giris" style="width:100%;background:#2563eb;color:#fff;border:0;border-radius:8px;padding:9px;font-weight:700;cursor:pointer">Bağlan</button>' +
        '<div style="font-size:11px;color:#64748b;margin-top:8px">' + sonDurum + '</div></div>';
    } else {
      govde = '<div style="padding:10px 12px">' +
        '<div style="display:flex;gap:6px;margin-bottom:8px">' +
        kutu("Giden", sayac.giden, "#16a34a") + kutu("Gelen", sayac.gelen, "#dc2626") + kutu("e-Arşiv", sayac.earsiv, "#9333ea") + '</div>' +
        '<div style="font-size:12px;color:#334155">' + sonDurum + '</div>' +
        (alanlar.length ? '<div style="font-size:10px;color:#94a3b8;margin-top:6px;word-break:break-all">alan: ' + alanlar.slice(0, 16).join(", ") + '</div>' : '') +
        '<div style="font-size:11px;color:#64748b;margin-top:8px">Portalda ay ay faturalara bakın; görünenler otomatik aktarılır. Sadece okur.</div></div>';
    }
    panel.innerHTML =
      '<div style="background:linear-gradient(135deg,#0ea5e9,#2563eb);color:#fff;padding:9px 12px;font-weight:800;display:flex;justify-content:space-between;align-items:center">' +
      '<span>🌉 Kolaysoft Köprüsü</span><span id="ks-gizle" style="cursor:pointer;opacity:.85">✕</span></div>' + govde;
    const g = panel.querySelector("#ks-gizle"); if (g) g.onclick = () => { panel.style.display = "none"; };
    const b = panel.querySelector("#ks-giris"); if (b) b.onclick = girisYap;
    const s = panel.querySelector("#ks-sifre"); if (s) s.onkeydown = (e) => { if (e.key === "Enter") girisYap(); };
  }
  function kutu(ad, say, renk) {
    return '<div style="flex:1;text-align:center;background:' + renk + '14;border:1px solid ' + renk + '55;border-radius:9px;padding:5px 2px">' +
      '<div style="font-weight:800;color:' + renk + ';font-size:16px">' + say + '</div><div style="font-size:10px;color:#64748b">' + ad + '</div></div>';
  }

  if (window.top === window) {
    const basla = () => { panelCiz(); oturumKontrol(); };
    if (document.body) basla(); else window.addEventListener("DOMContentLoaded", basla);
  }
})();
