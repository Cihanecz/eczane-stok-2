# Kolay etiket verisini (endikasyon/kullanim/uyari) Eczane 2 bulutuna yukler: ayar.kolay_etiket_veri
# Sadece ayar tablosundaki kolay_etiket_* satirlarina yazar.
$KOK = "C:\EczaneStok"
$SB_URL = "https://hmgxulrssqsqnfhibmzz.supabase.co"
$SB_KEY = "sb_publishable_kGiwMdnja2OhbzBYEX0zog_dQ9R8m_h"
$GIRIS = Join-Path $KOK "giris.dat"
$ErrorActionPreference = "Stop"
$s = Get-Content $GIRIS -Encoding UTF8
$sf = ConvertTo-SecureString $s[1].Trim()
$duz = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sf))
$g = @{ email = $s[0].Trim(); password = $duz } | ConvertTo-Json
$jt = (Invoke-RestMethod -Method Post -Uri "$SB_URL/auth/v1/token?grant_type=password" -Headers @{ apikey = $SB_KEY } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($g))).access_token
$dosya = Join-Path $KOK "kolay-etiket-veri.json"
$metin = [IO.File]::ReadAllText($dosya, [Text.Encoding]::UTF8)
$v = $metin | ConvertFrom-Json
"Okundu: {0} ilac" -f @($v.l).Count
$H = @{ apikey = $SB_KEY; Authorization = "Bearer $jt"; Prefer = "resolution=merge-duplicates,return=minimal" }
foreach ($r in @(@{ anahtar = "kolay_etiket_veri"; deger = $metin }, @{ anahtar = "kolay_etiket_durum"; deger = ("{0} yuklendi ({1} ilac)" -f (Get-Date -Format "dd.MM HH:mm"), @($v.l).Count) })) {
  $json = ConvertTo-Json @($r) -Compress
  Invoke-RestMethod -Method Post -Uri "$SB_URL/rest/v1/ayar?on_conflict=anahtar" -Headers $H -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 300 | Out-Null
}
$k = Invoke-RestMethod -Uri "$SB_URL/rest/v1/ayar?anahtar=eq.kolay_etiket_veri&select=deger" -Headers @{ apikey = $SB_KEY; Authorization = "Bearer $jt" } -TimeoutSec 300
$geri = ($k[0].deger | ConvertFrom-Json)
"Bulutta: {0} ilac" -f @($geri.l).Count
"BITTI"
