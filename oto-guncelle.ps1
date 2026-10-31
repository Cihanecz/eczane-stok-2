# =====================================================================
#  OTO-GUNCELLE (ECZANE 2)  — eczane-stok-2 repo'sundaki feed .ps1
#  dosyalarini GitHub'dan ceker. Degisiklik varsa (son commit SHA farkli)
#  indirir, yoksa cikar. Ecz2 GOZCU KULLANMAZ (her feed ayri Scheduled
#  Task); bu yuzden gozcu yeniden baslatmaz — tasklar bir sonraki
#  tetiklemede yeni .ps1'i calistirir.
#  EczaneStok-Guncelle scheduled task'i ile periyodik calisir (gizli.vbs).
#  Kendini de gunceller (oto-guncelle.ps1 listede).
#  NOT: toplayici / eklenti / local stok feed'leri (rx-satis vb.) BURADA
#  guncellenmez — onlar Ecz2'ye ozel, elle yonetilir.
# =====================================================================
$ErrorActionPreference = "Stop"
$KOK  = "C:\EczaneStok"
$REPO = "Cihanecz/eczane-stok-2"
$dosyalar = "oto-guncelle.ps1", "rx-eksik.ps1", "rx-alim.ps1", "rx-kart.ps1", "rx-kesif.ps1"
function GLog($m) { try { Add-Content -Path (Join-Path $KOK "guncelle.log") -Value ((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $m) -Encoding UTF8 } catch {} }
try {
  $sha = "$(Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/commits/main" -Headers @{ Accept = "application/vnd.github.sha"; "User-Agent" = "EczaneStok" } -TimeoutSec 30)".Trim()
  if ($sha -notmatch '^[0-9a-f]{40}$') { return }
  $sf = Join-Path $KOK "surum-feed.txt"
  $yerel = if (Test-Path $sf) { (Get-Content $sf -Raw).Trim() } else { "" }
  if ($yerel -eq $sha) { return }                       # degisiklik yok
  # Once hepsini .yeni olarak indir (yarida kalirsa eski dosyalar bozulmasin)
  foreach ($d in $dosyalar) {
    Invoke-WebRequest "https://raw.githubusercontent.com/$REPO/$sha/$d" -UseBasicParsing -OutFile ((Join-Path $KOK $d) + ".yeni") -TimeoutSec 60
  }
  foreach ($d in $dosyalar) { Move-Item -Force ((Join-Path $KOK $d) + ".yeni") (Join-Path $KOK $d) }
  Set-Content -Path $sf -Value $sha -Encoding ASCII
  GLog ("Feed guncellendi -> " + $sha.Substring(0, 7))
} catch { GLog ("Hata: " + $_.Exception.Message) }
