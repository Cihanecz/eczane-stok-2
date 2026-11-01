// Kolaysoft Köprüsü - ARKA PLAN (otomatik tarama)
// Chrome açık olduğu sürece her 30 dk'da bir, arka planda (pinned, pasif) bir Kolaysoft
// sekmesinde Giden / Gelen / e-Arşiv listelerini açar. İçerik betiği (kopru.js) o an
// yüklenen faturaları Supabase'e aktarır. Burada hiçbir şey yazılmaz/kesilmez; sadece
// doğru sayfalar açılır. Kolaysoft oturumu kapalıysa (login ekranı) sessizce geçer.
const SURE_DK = 30;
const SAYFALAR = [
  "https://portal.eczacikartfatura.com/accounting/eInvoiceOutbox#ksauto",
  "https://portal.eczacikartfatura.com/accounting/eInvoiceInbox#ksauto",
  "https://portal.eczacikartfatura.com/accounting/eAInvoice#ksauto"
];
const bekle = ms => new Promise(r => setTimeout(r, ms));

function kur() { chrome.alarms.create("ks-tara", { periodInMinutes: SURE_DK, delayInMinutes: 1 }); }
chrome.runtime.onInstalled.addListener(kur);
chrome.runtime.onStartup.addListener(kur);
chrome.alarms.onAlarm.addListener(a => { if (a.name === "ks-tara") tara(); });

let tabId = null, calisiyor = false;

async function sekme() {
  if (tabId != null) { try { const t = await chrome.tabs.get(tabId); if (t) return t; } catch (e) { tabId = null; } }
  const t = await chrome.tabs.create({ url: SAYFALAR[0], active: false, pinned: true });
  tabId = t.id; return t;
}
async function yuklenmesiniBekle(id, sn = 40) {
  for (let i = 0; i < sn * 2; i++) {
    await bekle(500);
    try { const t = await chrome.tabs.get(id); if (t.status === "complete") return; } catch (e) { return; }
  }
}
async function tara() {
  if (calisiyor) return; calisiyor = true;
  try {
    const t = await sekme();
    for (const url of SAYFALAR) {
      try {
        await chrome.tabs.update(t.id, { url, active: false });
        await yuklenmesiniBekle(t.id);
        await bekle(9000); // SPA liste çekimi + "Son 6 Ay" oto-tık + köprü aktarımı için süre
      } catch (e) { /* sekme kapanmış olabilir */ }
    }
  } finally { calisiyor = false; }
}
