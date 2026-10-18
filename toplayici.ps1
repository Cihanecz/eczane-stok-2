# =====================================================================
#  ECZANE STOK — Rx toplayıcı
#  Rx'te SADECE rapor ekranlarını açar, Sorgula / Yazdır önizleme /
#  Dışa Aktar kullanır. Kayıt değiştiren hiçbir düğmeye basmaz.
# =====================================================================
param(
  [string]$Asama = "hepsi",          # envanter | stokdokum | satis | alis | hepsi
  [string]$Bas = "",                 # satış/alış başlangıç tarihi gg.aa.yyyy
  [string]$Bit = "",                 # bitiş tarihi
  [switch]$Kesif,                    # yeni açılan pencerelerin yapısını kaydet
  [switch]$Kur                       # bir kerelik: bulut giriş bilgisini kaydet
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public static class W2 {
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  public static void MesajTik(IntPtr h, int x, int y) { IntPtr lp = (IntPtr)((y << 16) | (x & 0xFFFF)); PostMessage(h, 0x201, (IntPtr)1, lp); System.Threading.Thread.Sleep(60); PostMessage(h, 0x202, IntPtr.Zero, lp); }
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static void Tik(int x, int y) { SetCursorPos(x, y); System.Threading.Thread.Sleep(80); mouse_event(2,0,0,0,IntPtr.Zero); mouse_event(4,0,0,0,IntPtr.Zero); }
}
"@

$KOK   = "C:\EczaneStok"
$SB_URL = "https://hmgxulrssqsqnfhibmzz.supabase.co"
$SB_KEY = "sb_publishable_kGiwMdnja2OhbzBYEX0zog_dQ9R8m_h"
$GIRIS  = Join-Path $KOK "giris.dat"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$VERI  = Join-Path $KOK "veri"
$GUNLUK = Join-Path $KOK "gunluk.txt"
New-Item -ItemType Directory -Force -Path $VERI | Out-Null
$DURDUR = Join-Path $KOK "durdur.flag"
function Log($m) { $s = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $m; Add-Content -Path $GUNLUK -Value $s -Encoding UTF8; Write-Host $s
  if ((Test-Path $DURDUR) -and $m -notlike "HATA*") { Remove-Item $DURDUR -Force -ErrorAction SilentlyContinue; throw "Kullanıcı Durdur'a bastı." } }

$A  = [System.Windows.Automation.AutomationElement]
$TS = [System.Windows.Automation.TreeScope]

# ---------- konumlar (Rx ekranı tam ekran açıkken, ekran pikseli) ----------
$K = @{
  RaporlarSekme   = @(1245, 56)
  SatisRaporlari  = @(49, 127);   UrunBazliSatis = @(128, 200)
  UrunHareket     = @(156, 127);  UrunBazliAlis  = @(205, 202)
  AlisTarihBas    = @(356, 274);  AlisTarihBit   = @(514, 274);  AlisSorgula = @(1212, 360)
  SatisTarihBas   = @(356, 280);  SatisTarihBit  = @(514, 280);  SatisSorgula = @(1059, 348)
  EnvanterRap     = @(258, 127);  GenelEnvanter  = @(332, 174);  UrunDokum = @(332, 203);  StokDokum = @(332, 233);  GenelKarekod = @(332, 352)
}

# ---------- pencere yardımcıları ----------
function RxSureci { $p = Get-Process -Name "RxMediaPharmaEYS" -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not $p) { throw "Rx açık değil." }; $p }
function Pencereler([int]$procId) {
  $liste = New-Object System.Collections.ArrayList
  $cb = [W2+EnumProc]{ param($h,$l) $p=0; [void][W2]::GetWindowThreadProcessId($h,[ref]$p)
        if ($p -eq $procId -and [W2]::IsWindowVisible($h)) { $sb = New-Object System.Text.StringBuilder 256; [void][W2]::GetWindowText($h,$sb,256); [void]$liste.Add([pscustomobject]@{H=$h;Ad=$sb.ToString()}) }; $true }.GetNewClosure()
  [void][W2]::EnumWindows($cb, [IntPtr]::Zero); $liste
}
function PencereBekle([int]$procId, [scriptblock]$kosul, [int]$sn = 30, [string]$ne = "pencere") {
  $son = (Get-Date).AddSeconds($sn)
  while ((Get-Date) -lt $son) { $w = Pencereler $procId | Where-Object $kosul | Select-Object -First 1; if ($w) { return $w }; Start-Sleep -Milliseconds 300 }
  throw "$ne açılmadı ($sn sn)."
}
function Dikdortgen($h) { $r = New-Object W2+RECT; [void][W2]::GetWindowRect($h,[ref]$r); $r }
function Kesfet($h, $etiket) {
  if (-not $Kesif) { return }
  $el = $A::FromHandle($h); $sb = New-Object System.Text.StringBuilder
  $yur = [System.Windows.Automation.TreeWalker]::ControlViewWalker; $n = 0
  function Y($e,$d) { if ($script:n -gt 3000 -or $d -gt 12) {return}; $script:n++
    $c=$e.Current; $t=$c.ControlType.ProgrammaticName -replace "ControlType\.",""; $r=$c.BoundingRectangle
    $ad=$c.Name; if($t -in @("DataGrid","Table","DataItem","Document")){$ad="(içerik yazılmadı)"}
    $kon = if ($r.IsEmpty -or [double]::IsInfinity($r.X)) { "-" } else { "$([int]$r.X),$([int]$r.Y),$([int]$r.Width)x$([int]$r.Height)" }
    [void]$sb.AppendLine(("  "*$d)+"[$t] '$ad' id='$($c.AutomationId)' konum=$kon")
    if($t -in @("DataGrid","Table","DataItem","Document")){return}
    $k=$yur.GetFirstChild($e); while($k -ne $null){ Y $k ($d+1); $k=$yur.GetNextSibling($k) } }
  Y $el 0
  $sb.ToString() | Out-File (Join-Path $KOK ("kesif-" + $etiket + ".txt")) -Encoding utf8
}
# Ada göre ekranda GÖRÜNEN öğeyi bulur; tabloların içine girmez (hem hızlı hem hasta verisine dokunmaz)
$script:ATLA = @("DataGrid","Table","DataItem","Tree","List","Document")
function AgacAra($el, [string]$ad, [int]$derin) {
  if ($derin -gt 16) { return $null }
  $yur = [System.Windows.Automation.TreeWalker]::ControlViewWalker
  $k = $yur.GetFirstChild($el)
  while ($k -ne $null) {
    try {
      $c = $k.Current
      if ($c.Name -eq $ad -and -not $c.IsOffscreen -and $c.BoundingRectangle.Width -gt 0) { return $k }
      $tip = $c.ControlType.ProgrammaticName -replace "ControlType\.",""
      if ($script:ATLA -notcontains $tip -and -not $c.IsOffscreen) { $s = AgacAra $k $ad ($derin + 1); if ($s) { return $s } }
    } catch { }
    $k = $yur.GetNextSibling($k)
  }
  return $null
}
function Bul($kokEl, [string]$ad, [int]$sn = 15) {
  $son = (Get-Date).AddSeconds($sn); $t0 = Get-Date
  while ((Get-Date) -lt $son) { $e = AgacAra $kokEl $ad 0; if ($e) { Log ("  '{0}' {1:N1} sn'de bulundu" -f $ad, ((Get-Date)-$t0).TotalSeconds); return $e }; Start-Sleep -Milliseconds 500 }
  throw "'$ad' bulunamadı."
}
$script:ON = [IntPtr]::Zero   # tıklamadan önce öne alınacak pencere
function OneAl { if ($script:ON -ne [IntPtr]::Zero) { [void][W2]::SetForegroundWindow($script:ON); Start-Sleep -Milliseconds 250 } }
# Düğmeye doğrudan pencere mesajıyla tıklar (üstte başka pencere/bildirim olsa da doğru düğmeye gider)
function ElTikla($e) {
  $c = $e.Current; $r = $c.BoundingRectangle; $h = [IntPtr]$c.NativeWindowHandle
  if ($h -ne [IntPtr]::Zero) { [W2]::MesajTik($h, [int]($r.Width/2), [int]($r.Height/2)) }
  else { OneAl; [W2]::Tik([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) }
}
function K($ad) { OneAl; [W2]::Tik($K[$ad][0], $K[$ad][1]); Start-Sleep -Milliseconds 900 }
function Tus($t) { [System.Windows.Forms.SendKeys]::SendWait($t); Start-Sleep -Milliseconds 250 }

function RxOne($p) {
  $h = AnaPencere $p
  [void][W2]::ShowWindow($h, 3)          # tam ekran
  [void][W2]::SetForegroundWindow($h); Start-Sleep -Milliseconds 600
  $script:ON = $h
  $A::FromHandle($h)
}

# Sorgu sonrası Rx'in rahatlamasını bekler (Filtreleme kapanır, Rx yanıt verir hâle gelir)
function YuklemeBekle($p, [int]$sn = 600) {
  $son = (Get-Date).AddSeconds($sn); Start-Sleep 3; $sakin = 0
  while ((Get-Date) -lt $son) {
    $p.Refresh()
    $acik = Pencereler $p.Id | Where-Object { $_.Ad -in @("Filtreleme","Lütfen Bekleyiniz") -or $_.Ad -like "*Bekley*" }
    if ($p.Responding -and -not $acik) { $sakin++ } else { $sakin = 0 }
    if ($sakin -ge 4) { Log "Rapor yüklendi"; return $A::FromHandle((AnaPencere $p)) }
    Start-Sleep -Milliseconds 700
  }
  throw "Rapor $sn saniyede yüklenmedi."
}
function AnaPencere($p) { (Pencereler $p.Id | Where-Object { $_.Ad -eq "RxMediaPharma Eczane Yönetim Sistemi" } | Select-Object -First 1).H }

# ---------- rapor açma ----------
function RaporAc($p, [string]$grup, [string]$oge, [string]$baslik) {
  $rx = RxOne $p
  K "RaporlarSekme"; K $grup; K $oge
  Log "Rapor açılıyor: $baslik"
}

# Yazdır önizlemesinden CSV'ye aktar
function OnizlemedenCsv($p, $rx, [string]$dosya) {
  if (Test-Path $dosya) { Remove-Item $dosya -Force }
  $once = @(Pencereler $p.Id | ForEach-Object { $_.H })
  Log "Yazdır düğmesi aranıyor"
  $yz = Bul $rx "Yazdır" 20
  $rr = $yz.Current.BoundingRectangle
  Log ("Yazdır bulundu: {0},{1} {2}x{3} — tıklanıyor" -f [int]$rr.X,[int]$rr.Y,[int]$rr.Width,[int]$rr.Height)
  # Gerçek fare tıklaması: arkadaki sekmelerde aynı yerde duran gizli "Yazdır" düğmelerine değil, görünene basılır
  $yeni = { Pencereler $p.Id | Where-Object { $_.Ad -eq "Yazdır" -and $once -notcontains $_.H } | Select-Object -First 1 }
  $on = $null
  for ($deneme = 1; $deneme -le 3 -and -not $on; $deneme++) {
    if ($deneme -le 2) { [void][W2]::ShowWindow($script:ON, 3); OneAl; [W2]::Tik([int]($rr.X + $rr.Width/2), [int]($rr.Y + $rr.Height/2)) }
    else { Log "  fareyle açılmadı, doğrudan düğmeye basılıyor"; ElTikla $yz }
    Log "Önizleme bekleniyor (deneme $deneme)"
    $son = (Get-Date).AddSeconds($(if ($deneme -lt 3) { 25 } else { 300 }))
    while (-not $on -and (Get-Date) -lt $son) {
      $on = & $yeni
      # önizleme hazırlanırken Rx meşgulse beklemeye devam et
      if (-not $on) { $p.Refresh(); if (-not $p.Responding) { $son = $son.AddSeconds(1) }; Start-Sleep -Milliseconds 500 }
    }
  }
  if (-not $on) { throw "Yazdır önizlemesi açılmadı." }
  # Önizlemeyi ekranı kaplayacak şekilde yerleştir (tam ekran komutu her zaman çalışmıyor)
  for ($i = 0; $i -lt 5; $i++) {
    [void][W2]::ShowWindow($on.H, 9); Start-Sleep -Milliseconds 400
    [void][W2]::MoveWindow($on.H, 0, 0, 1920, 1040, $true); Start-Sleep -Milliseconds 400
    [void][W2]::SetForegroundWindow($on.H); Start-Sleep -Milliseconds 600
    $r = Dikdortgen $on.H
    if ($r.L -le 0 -and $r.R -ge 1900) { break }
  }
  Start-Sleep 2
  Kesfet $on.H "onizleme"
  $r = Dikdortgen $on.H
  Log ("Önizleme penceresi: {0},{1} - {2},{3}" -f $r.L,$r.T,$r.R,$r.B)

  # --- Dışa Aktar oku → CSV (konumlar pencerenin sağ-üst köşesine göre) ---
  $script:ON = $on.H
  $okX = $r.R - 183; $okY = [Math]::Max($r.T, 0) + 97
  Log "Dışa aktar oku: $okX,$okY"
  OneAl; [W2]::Tik($okX, $okY); Start-Sleep -Milliseconds 1200
  OneAl; [W2]::Tik($okX + 52, $okY + 420); Start-Sleep -Milliseconds 1500
  $ayar = PencereBekle $p.Id { $_.Ad -like "*Dışa Aktarma Ayarları*" } 15 "Dışa aktarma ayarları"
  Log ("Açılan pencere: " + $ayar.Ad)
  if ($ayar.Ad -notlike "CSV*") { [void][W2]::SendMessage($ayar.H, 0x10, [IntPtr]::Zero, [IntPtr]::Zero); throw ("CSV yerine '" + $ayar.Ad + "' açıldı, iptal edildi.") }
  Kesfet $ayar.H "csv-ayar"
  [void][W2]::SetForegroundWindow($ayar.H); Start-Sleep -Milliseconds 400; Tus "{ENTER}"
  $kay = PencereBekle $p.Id { $_.Ad -in @("Save As","Farklı Kaydet","Kaydet") } 20 "Kaydet penceresi"
  Kesfet $kay.H "kaydet"
  Remove-Item $dosya -ErrorAction SilentlyContinue
  $ke = $A::FromHandle($kay.H)
  $kos = New-Object System.Windows.Automation.AndCondition(
    (New-Object System.Windows.Automation.PropertyCondition($A::AutomationIdProperty, "1001")),
    (New-Object System.Windows.Automation.PropertyCondition($A::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)))
  $ad = $ke.FindFirst($TS::Descendants, $kos)
  $yazildi = $false
  if ($ad) { try { $ad.SetFocus(); $vp = $ad.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern); $vp.SetValue($dosya); $yazildi = $true } catch { Log ("  değer yazılamadı: " + $_.Exception.Message) } }
  if (-not $yazildi) { [void][W2]::SetForegroundWindow($kay.H); Start-Sleep -Milliseconds 300; Tus "^a"; Tus $dosya }
  Log "Dosya adı yazıldı: $dosya"
  Start-Sleep -Milliseconds 400; [void][W2]::SetForegroundWindow($kay.H); Start-Sleep -Milliseconds 300; Tus "{ENTER}"
  Log "Kaydediliyor: $dosya"
  $son = (Get-Date).AddSeconds(600)
  while ((Get-Date) -lt $son) {
    $soru = Pencereler $p.Id | Where-Object { $_.Ad -like "*Aktar*" -and $_.Ad -notlike "*Ayarları*" } | Select-Object -First 1
    if ($soru) { Kesfet $soru.H "acsoru"; $se = $A::FromHandle($soru.H); try { ElTikla (Bul $se "Hayır" 5) } catch { [void][W2]::SetForegroundWindow($soru.H); Tus "{ESC}" }; break }
    if ((Test-Path $dosya) -and ((Get-Item $dosya).Length -gt 0) -and ((Get-Date) - (Get-Item $dosya).LastWriteTime).TotalSeconds -gt 5) { break }
    Start-Sleep -Milliseconds 700
  }
  if (-not (Test-Path $dosya)) { throw "CSV dosyası oluşmadı." }
  $onceki = -1; for ($i = 0; $i -lt 60; $i++) { $b = (Get-Item $dosya).Length; if ($b -gt 0 -and $b -eq $onceki) { break }; $onceki = $b; Start-Sleep 1 }
  Log ("CSV hazır: {0:N0} bayt" -f (Get-Item $dosya).Length)
  # önizlemeyi kapat
  try { $oe = $A::FromHandle($on.H); ElTikla (Bul $oe "Vazgeç" 5) } catch { [void][W2]::SendMessage($on.H, 0x10, [IntPtr]::Zero, [IntPtr]::Zero) }
  Start-Sleep 1
  return $dosya
}

# Raporu aldıktan sonra Rx'te açtığımız sekmeyi kapatır (sekme başlığındaki çarpıya basar; kayıt değiştirmez)
function SekmeKapat($p) {
  try {
    $h = AnaPencere $p; $rx = $A::FromHandle($h)
    $kos = New-Object System.Windows.Automation.PropertyCondition($A::NameProperty, "Raporlar")
    $pn = @($rx.FindAll($TS::Descendants, $kos) | Where-Object { -not $_.Current.IsOffscreen -and $_.Current.BoundingRectangle.Width -gt 500 }) | Select-Object -First 1
    if (-not $pn) { Log "  kapatılacak rapor sekmesi bulunamadı"; return }
    $ust = [int]$pn.Current.BoundingRectangle.Y
    [void][W2]::ShowWindow($h, 3); [void][W2]::SetForegroundWindow($h); Start-Sleep -Milliseconds 700
    $bm = New-Object System.Drawing.Bitmap 1920, 24
    $g = [System.Drawing.Graphics]::FromImage($bm); $g.CopyFromScreen(0, $ust - 24, 0, 0, $bm.Size); $g.Dispose()
    # satırı mavi (etkin sekme) / beyaz / diğer diye sınıflandır; mavinin içindeki 10-26 px beyaz kutu = çarpı düğmesi
    $kutu = $null
    foreach ($sat in 3, 19, 6, 16) {
      $tip = for ($x = 0; $x -lt 1920; $x++) { $c = $bm.GetPixel($x, $sat); if ($c.B -gt $c.R + 50) { 'B' } elseif ($c.R -gt 200 -and $c.G -gt 200 -and $c.B -gt 200) { 'W' } else { '.' } }
      $x = 2
      while ($x -lt 1916) {
        if ($tip[$x] -eq 'W' -and ($tip[$x - 1] -eq 'B' -or $tip[$x - 2] -eq 'B')) {
          $b = $x; while ($x -lt 1916 -and $tip[$x] -eq 'W') { $x++ }; $gen = $x - $b
          if (($tip[$x] -eq 'B' -or $tip[$x + 1] -eq 'B') -and $gen -ge 10 -and $gen -le 26) { $kutu = [int]($b + $gen / 2) } }
        $x++
      }
      if ($null -ne $kutu) { break }
    }
    $bm.Dispose()
    if ($null -eq $kutu) { Log "  sekmenin çarpısı bulunamadı, açık kaldı"; return }
    [W2]::Tik($kutu, $ust - 13); Start-Sleep -Milliseconds 1500
    Log "Rapor sekmesi kapatıldı"
  } catch { if ($_.Exception.Message -like "*Durdur*") { throw }; Log ("  sekme kapatılamadı: " + $_.Exception.Message) }
}

# Ürün Bazlı Satış: tarih aralığı yazılır, Sorgula, Yazdır → CSV. Hasta sütunu dosyadan okunurken atılır.
# Rx tarih kutusu noktayı ayraç saymıyor: sadece rakamlar yazılır (01.02.2026 -> 01022026)
function TarihYaz($ad, [string]$t) { K $ad; Tus "^a"; Tus ($t -replace '\D', ''); Tus "{TAB}"; Start-Sleep -Milliseconds 500 }
function AsamaSatis($p, [string]$bas, [string]$bit, [string]$dosyaAdi, [switch]$AyniSekme) {
  if (-not $AyniSekme) { RaporAc $p "SatisRaporlari" "UrunBazliSatis" "Ürün Bazlı Satış"; Start-Sleep 3 }
  Log "Satış tarihleri: $bas - $bit"; $script:ARALIK = @($bas, $bit)
  $script:ON = AnaPencere $p
  TarihYaz "SatisTarihBas" $bas
  TarihYaz "SatisTarihBit" $bit
  K "SatisSorgula"
  Log "Satış sorgulandı ($bas - $bit), yüklenmesi bekleniyor"
  $rx = YuklemeBekle $p 900
  OnizlemedenCsv $p $rx (Join-Path $VERI $dosyaAdi) | Out-Null
  SekmeKapat $p
}

# ---------- aşamalar ----------
# Filtreleme penceresinde: Temizle → "Sadece Stoktakiler" işaretle → Filtrele → yüklenince Yazdır → CSV
function StoktakilerRaporu($p, [string]$oge, [string]$baslik, [string]$dosyaAdi) {
  RaporAc $p "EnvanterRap" $oge $baslik
  $f = PencereBekle $p.Id { $_.Ad -eq "Filtreleme" } 20 "Filtreleme penceresi"
  Kesfet $f.H ("filtre-" + $oge)
  $script:ON = $f.H
  $fe = $A::FromHandle($f.H)
  ElTikla (Bul $fe "Temizle"); Start-Sleep 1                       # önceki filtreleri sıfırla
  $etiket = (Bul $fe "Sadece Stoktakiler").Current.BoundingRectangle
  [W2]::Tik([int]($etiket.X + 260), [int]($etiket.Y + $etiket.Height/2)); Start-Sleep 1   # kutucuğu işaretle
  ElTikla (Bul $fe "Filtrele")
  Log "$baslik sorgulandı, yüklenmesi bekleniyor"
  $rx = YuklemeBekle $p 600
  $script:ON = AnaPencere $p
  OnizlemedenCsv $p $rx (Join-Path $VERI $dosyaAdi) | Out-Null
  SekmeKapat $p
}
function AsamaEnvanter($p) { StoktakilerRaporu $p "GenelEnvanter" "Genel Envanter" "envanter.csv" }
function AsamaUrunDokum($p) { StoktakilerRaporu $p "UrunDokum" "Ürün Döküm" "urundokum.csv" }
function AsamaKarekod($p) { StoktakilerRaporu $p "StokDokum" "Stok Döküm (karekod)" "karekod.csv" }

# ---------- ALIŞ (Ürün Hareket Raporları → Ürün Bazlı Alış) ----------
# Satış ekranı gibi: Tarih aralığı yazılır, Sorgula, Yazdır → CSV. Depo satırda var.
function AsamaAlis($p, [string]$bas, [string]$bit, [string]$dosyaAdi, [switch]$AyniSekme) {
  if (-not $AyniSekme) { RaporAc $p "UrunHareket" "UrunBazliAlis" "Ürün Bazlı Alış"; Start-Sleep 3 } else { [void](RxOne $p) }
  Log "Alış tarihleri: $bas - $bit"; $script:ARALIK = @($bas, $bit)
  $script:ON = AnaPencere $p
  TarihYaz "AlisTarihBas" $bas
  TarihYaz "AlisTarihBit" $bit
  K "AlisSorgula"
  Log "Alış sorgulandı ($bas - $bit), yüklenmesi bekleniyor"
  $rx = YuklemeBekle $p 900
  OnizlemedenCsv $p $rx (Join-Path $VERI $dosyaAdi) | Out-Null
  SekmeKapat $p
}
# Dışa aktarılan dosya istenen tarih aralığının mı? (Rx bazen önceki sorgunun sonucunu aktarıyor)
function AralikKontrol($tarihler) {
  if (-not $script:ARALIK) { return }
  $b = [datetime]::ParseExact($script:ARALIK[0], "dd.MM.yyyy", $null).ToString("yyyy-MM-dd")
  $e = [datetime]::ParseExact($script:ARALIK[1], "dd.MM.yyyy", $null).ToString("yyyy-MM-dd")
  $t = @($tarihler); if ($t.Count -eq 0) { return }
  $ic = @($t | Where-Object { $_ -ge $b -and $_ -le $e }).Count
  if ($ic -lt $t.Count * 0.9) { throw ("Aktarılan dosya istenen tarihlerde değil ({0}/{1} satır aralıkta) — yüklenmedi." -f $ic, $t.Count) }
}
# Ürün Bazlı Alış CSV → alis tablosu. Sütunlar başlık adından bulunur (sıra değişse de çalışır).
function AlisYukle([string]$dosyaAdi) {
  $dosya = Join-Path $VERI $dosyaAdi
  $m = [IO.File]::ReadAllText($dosya, [Text.Encoding]::GetEncoding(1254))
  if ($m.StartsWith("#;")) { $i = 0 } else { $i = $m.IndexOf("`n#;"); if ($i -lt 0) { throw "$dosya içinde başlık satırı bulunamadı." }; $i++ }
  $j = $m.IndexOf("`n", $i)
  $bas = $m.Substring($i, $j - $i).TrimEnd("`r").Split(";") | ForEach-Object { $_.Trim() }
  $adlar = @(); for ($k = 0; $k -lt $bas.Count; $k++) { $adlar += "c$k" }
  function Sutun([string]$desen) { for ($k = 0; $k -lt $bas.Count; $k++) { if ($bas[$k] -match $desen) { return "c$k" } }; return $null }
  $S = @{ barkod = Sutun '^Barkod$'; urun = Sutun '^Ürün'; depo = Sutun '^Depo$'; tarih = Sutun 'Fat.*Tarih'; fatno = Sutun 'Fat.*No'
          adet = Sutun '^Adet$'; mf = Sutun '(?i)^mf$'; depocu = Sutun '^Depocu'; net = Sutun 'Net'; kdv = Sutun 'KDV'; brut = Sutun 'Brüt' }
  foreach ($a in @("barkod","tarih","adet","net")) { if (-not $S[$a]) { throw "Alış dosyasında '$a' sütunu bulunamadı. Başlık: $($bas -join ' | ')" } }
  $govde = $m.Substring($j + 1)
  $satirlar = ($govde -split "`r?`n") | Where-Object { $_ -ne "" } | ConvertFrom-Csv -Delimiter ";" -Header $adlar
  $sayac = @{}; $liste = New-Object System.Collections.ArrayList; $beklenen = 1
  foreach ($r in $satirlar) {
    if (-not ($r.c0 -match '^\d+$' -and [int]$r.c0 -eq $beklenen)) { continue }; $beklenen++
    $tarih = TarihIso ([string]$r.($S.tarih)); $barkod = ([string]$r.($S.barkod)).Trim()
    if (-not $tarih -or $barkod -eq "") { continue }
    $fn = if ($S.fatno) { ([string]$r.($S.fatno)).Trim() } else { "" }
    $dp = if ($S.depo) { ([string]$r.($S.depo)).Trim() } else { "" }
    $k = "$tarih|$dp|$fn|$barkod"; if ($sayac.ContainsKey($k)) { $sayac[$k]++ } else { $sayac[$k] = 1 }
    $depocu = if ($S.depocu) { Sayi $r.($S.depocu) } else { $null }; $net = Sayi $r.($S.net)
    [void]$liste.Add([ordered]@{
      satir_kodu = "$k|$($sayac[$k])"; fat_tarih = $tarih; fat_no = $fn; depo = $dp; barkod = $barkod
      urun_ad = if ($S.urun) { ([string]$r.($S.urun)).Trim() } else { $null }
      adet = [double](Sayi $r.($S.adet)); mf = if ($S.mf) { [double](Sayi $r.($S.mf)) } else { 0 }
      depocu = $depocu; top_iskonto = if ($null -ne $depocu -and $null -ne $net) { [Math]::Round($depocu - $net, 2) } else { $null }
      top_net = $net; top_kdv = if ($S.kdv) { Sayi $r.($S.kdv) } else { $null }; top_brut = if ($S.brut) { Sayi $r.($S.brut) } else { $null } })
  }
  AralikKontrol ($liste | ForEach-Object { $_.fat_tarih })
  $tut = ($liste | ForEach-Object { [double]$_.top_brut } | Measure-Object -Sum).Sum
  Log ("Alış: {0} satır, {1:N2} TL (KDV dahil)" -f $liste.Count, $tut)
  $jt = Jeton
  for ($i = 0; $i -lt $liste.Count; $i += 1000) { BulutEkle "alis" $liste.GetRange($i, [Math]::Min(1000, $liste.Count - $i)).ToArray() $jt "satir_kodu" }
  $un = @{}; foreach ($r in $liste) { if (-not $un.ContainsKey($r.barkod) -and $r.urun_ad) { $un[$r.barkod] = $r.urun_ad } }
  $urunler = @($un.Keys | ForEach-Object { [ordered]@{ barkod = $_; ad = $un[$_] } })
  for ($i = 0; $i -lt $urunler.Count; $i += 1000) { BulutEkle "urun" $urunler[$i..([Math]::Min($i + 999, $urunler.Count - 1))] $jt "barkod" }
  Kayit "alis" "tamam" $liste.Count ("{0:N0} TL alış" -f $tut) $jt
  Remove-Item $dosya -Force -ErrorAction SilentlyContinue
}
function AlisGecmis([string]$basAy) {
  $p = RxSureci
  $ay = [datetime]::ParseExact($basAy, "MM.yyyy", $null); $ilk = $true
  while ($ay -le (Get-Date)) {
    $son = $ay.AddMonths(1).AddDays(-1); if ($son -gt (Get-Date)) { $son = (Get-Date).Date }
    AsamaAlis $p $ay.ToString("dd.MM.yyyy") $son.ToString("dd.MM.yyyy") "alis.csv" ; $ilk = $false
    AlisYukle "alis.csv"
    $ay = $ay.AddMonths(1)
  }
}
function CsvBas([string]$dosya, [int]$n = 4) {
  $m = [IO.File]::ReadAllText($dosya, [Text.Encoding]::GetEncoding(1254))
  $i = $m.IndexOf("`n#;"); if ($i -lt 0) { $i = 0 }
  Write-Host "----- $dosya -----"
  $l = ($m.Substring($i + 1) -split "`r?`n") | Select-Object -First $n
  $h = $l[0].Split(";"); $d = $l[1].Split(";")
  for ($k = 0; $k -lt $h.Count; $k++) { Write-Host ("{0,2} {1,-22} {2}" -f $k, $h[$k], $(if ($k -lt $d.Count) { $d[$k] })) }
}


# ---------- CSV okuma (Rx Windows-1254, ; ayraçlı, 1.234,56 sayılar) ----------
function Sayi($t) {
  if ($null -eq $t) { return $null }
  $t = ([string]$t).Trim(); if ($t -eq "") { return $null }
  $t = ($t -replace '\(.*\)', '') -replace '[^0-9,.\-]', ''
  if ($t -eq "" -or $t -eq "-") { return $null }
  $t = $t.Replace(".", "").Replace(",", ".")
  $d = 0.0; if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d }; return $null
}
function CsvOku([string]$dosya, [string[]]$basliklar) {
  $metin = [IO.File]::ReadAllText($dosya, [Text.Encoding]::GetEncoding(1254))
  $i = $metin.IndexOf("`n#;"); if ($i -lt 0) { throw "$dosya içinde başlık satırı bulunamadı." }
  $j = $metin.IndexOf("`n", $i + 1)
  $govde = $metin.Substring($j + 1)
  $satirlar = ($govde -split "`r?`n") | Where-Object { $_ -ne "" } | ConvertFrom-Csv -Delimiter ";" -Header $basliklar
  # sıra numarası 1,2,3… gider; en alttaki toplam satırı (kalem sayısıyla başlar) atlanır
  $liste = New-Object System.Collections.ArrayList; $beklenen = 1
  foreach ($r in $satirlar) { if ($r.no -match '^\d+$' -and [int]$r.no -eq $beklenen) { [void]$liste.Add($r); $beklenen++ } }
  @($liste)
}
function AdAnahtar($ad) { (([string]$ad).Trim().ToUpperInvariant().Replace([string][char]0x130, "I")) -replace '\s+', ' ' }

# ---------- bulut ----------
function GirisKur {
  Write-Host ""
  Write-Host "Eczane Stok programına girişte kullandığın e-posta ve şifreyi yaz."
  $ep = Read-Host "E-posta"
  $sf = Read-Host "Şifre" -AsSecureString
  $duz = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sf))
  $null = BulutGiris $ep $duz
  ($ep + "`n" + (ConvertFrom-SecureString $sf)) | Out-File $GIRIS -Encoding utf8
  Log "Giriş bilgisi kaydedildi (şifreli) — $ep"
}
function BulutGiris([string]$ep, [string]$sf) {
  $govde = @{ email = $ep; password = $sf } | ConvertTo-Json
  try {
    $r = Invoke-RestMethod -Method Post -Uri "$SB_URL/auth/v1/token?grant_type=password" -Headers @{ apikey = $SB_KEY } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($govde))
  } catch { throw "Buluta giriş yapılamadı: " + $_.Exception.Message }
  $r.access_token
}
function Jeton {
  if (-not (Test-Path $GIRIS)) { throw "Giriş bilgisi yok. Önce: toplayici.ps1 -Kur" }
  $s = Get-Content $GIRIS -Encoding UTF8
  $sf = ConvertTo-SecureString $s[1].Trim()
  $duz = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sf))
  BulutGiris $s[0].Trim() $duz
}
function Bulut([string]$yol, $nesne, [string]$jeton) {
  $json = ConvertTo-Json $nesne -Depth 5 -Compress
  Invoke-RestMethod -Method Post -Uri "$SB_URL/rest/v1/$yol" -Headers @{ apikey = $SB_KEY; Authorization = "Bearer $jeton" } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 300
}
function Kayit([string]$rapor, [string]$durum, $satir, [string]$mesaj, [string]$jeton) {
  try { $null = Bulut "toplama_kaydi" @{ bilgisayar = $env:COMPUTERNAME; rapor = $rapor; durum = $durum; satir = $satir; mesaj = $mesaj } $jeton } catch { Log ("  kayıt yazılamadı: " + $_.Exception.Message) }
}

# Envanter (maliyet) + Ürün Döküm (barkod) birleştir → stok_yukle
function StokYukle {
  $envn = CsvOku (Join-Path $VERI "envanter.csv") @("no","ad","grup","uretici","stok","ort","bos","brut","envd","kdv","psf","toppsf","kamu","topkamu","karlilik")
  $ud  = CsvOku (Join-Path $VERI "urundokum.csv") @("no","ad","barkod","depo","bos","kki","psf","kamu","stok","toppsf","raf")
  Log ("Okundu: envanter {0} satır, ürün döküm {1} satır" -f $envn.Count, $ud.Count)
  # ada göre envanter havuzu
  $havuz = @{}
  foreach ($e in $envn) { $k = AdAnahtar $e.ad; if (-not $havuz.ContainsKey($k)) { $havuz[$k] = New-Object System.Collections.ArrayList }; [void]$havuz[$k].Add($e) }
  $sonuc = New-Object System.Collections.ArrayList
  $eslesmeyen = 0
  foreach ($u in $ud) {
    $k = AdAnahtar $u.ad; $e = $null
    if ($havuz.ContainsKey($k) -and $havuz[$k].Count -gt 0) {
      $aday = $havuz[$k]
      if ($aday.Count -eq 1) { $e = $aday[0] }
      else {
        $e = $aday | Where-Object { (Sayi $_.psf) -eq (Sayi $u.psf) -and (Sayi $_.stok) -eq (Sayi $u.stok) } | Select-Object -First 1
        if (-not $e) { $e = $aday | Where-Object { (Sayi $_.psf) -eq (Sayi $u.psf) } | Select-Object -First 1 }
        if (-not $e) { $e = $aday[0] }
      }
      [void]$aday.Remove($e)
    }
    if (-not $e) { $eslesmeyen++ }
    $ad = ([string]$u.ad).Trim(); if ($ad -eq "") { $ad = "(adsız ürün)" }
    [void]$sonuc.Add([ordered]@{
      barkod = ([string]$u.barkod).Trim(); ad = $ad
      grup = $(if ($e) { ([string]$e.grup).Trim() } else { "" }); uretici = $(if ($e) { ([string]$e.uretici).Trim() } else { "" })
      stok = $(if ($e) { Sayi $e.stok } else { Sayi $u.stok })
      ort_maliyet = $(if ($e) { Sayi $e.ort } else { $null }); ort_brut = $(if ($e) { Sayi $e.brut } else { $null })
      psf = Sayi $u.psf; kamu = Sayi $u.kamu; kdv = $(if ($e) { Sayi $e.kdv } else { $null })
    })
  }
  # Ürün Döküm'de olmayan envanter satırları (emanet vb.) — barkodsuz, adla tutulur
  $kalan = 0
  foreach ($k in $havuz.Keys) { foreach ($e in $havuz[$k]) { $kalan++
    $ad = ([string]$e.ad).Trim(); if ($ad -eq "") { $ad = "(adsız ürün)" }
    [void]$sonuc.Add([ordered]@{ barkod = "AD:" + $ad; ad = $ad; grup = ([string]$e.grup).Trim(); uretici = ([string]$e.uretici).Trim()
      stok = Sayi $e.stok; ort_maliyet = Sayi $e.ort; ort_brut = Sayi $e.brut; psf = Sayi $e.psf; kamu = Sayi $e.kamu; kdv = Sayi $e.kdv }) } }
  $topStok = ($sonuc | ForEach-Object { $_.stok } | Measure-Object -Sum).Sum
  $topMal  = ($sonuc | ForEach-Object { [double]$_.stok * [double]$_.ort_maliyet } | Measure-Object -Sum).Sum
  Log ("Birleşti: {0} ürün, {1:N0} kutu, maliyet {2:N2} TL (eşleşmeyen döküm {3}, barkodsuz envanter {4})" -f $sonuc.Count, $topStok, $topMal, $eslesmeyen, $kalan)
  $j = Jeton
  $tarih = (Get-Date).ToString("yyyy-MM-dd")
  $n = Bulut "rpc/stok_yukle" @{ p_tarih = $tarih; p_satirlar = $sonuc.ToArray() } $j
  Log "Buluta yüklendi: $n ürün ($tarih)"
  Kayit "stok" "tamam" $sonuc.Count ("{0:N0} kutu, {1:N2} TL" -f $topStok, $topMal) $j
}

# Stok Döküm (her karekodlu kutu bir satır) → karekod_yukle
function KarekodYukle {
  $kk = CsvOku (Join-Path $VERI "karekod.csv") @("no","ad","bos","barkod","psf","stok","seri","parti","miad")
  $liste = New-Object System.Collections.ArrayList
  $tr = [Globalization.CultureInfo]::InvariantCulture
  foreach ($r in $kk) {
    $seri = ([string]$r.seri).Trim(); if ($seri -eq "") { continue }
    $m = $null; $d = [datetime]::MinValue
    if ([datetime]::TryParseExact(([string]$r.miad).Trim(), [string[]]@("d.MM.yyyy","dd.MM.yyyy","d.M.yyyy"), $tr, [Globalization.DateTimeStyles]::None, [ref]$d) -and $d.Year -gt 2000) { $m = $d.ToString("yyyy-MM-dd") }
    [void]$liste.Add([ordered]@{ barkod = ([string]$r.barkod).Trim(); seri_no = $seri; parti_no = ([string]$r.parti).Trim(); miad = $m })
  }
  Log ("Karekod: {0} satır okundu, {1} karekodlu kutu" -f $kk.Count, $liste.Count)
  if ($liste.Count -eq 0) { throw "Karekod dosyasında kutu bulunamadı." }
  $j = Jeton
  $tarih = (Get-Date).ToString("yyyy-MM-dd")
  $n = Bulut "rpc/karekod_yukle" @{ p_tarih = $tarih; p_satirlar = $liste.ToArray() } $j
  Log "Buluta yüklendi: $n kutu"
  Kayit "karekod" "tamam" $liste.Count "$($liste.Count) kutu" $j
}

function TarihIso([string]$t) {
  $d = [datetime]::MinValue
  if ([datetime]::TryParseExact($t.Trim(), [string[]]@("d.MM.yyyy","dd.MM.yyyy","d.M.yyyy","dd.MM.yyyy HH:mm:ss","d.MM.yyyy HH:mm:ss","d.MM.yyyy HH:mm"), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$d)) { return $d.ToString("yyyy-MM-dd") }
  return $null
}
function BulutEkle([string]$tablo, $satirlar, [string]$jeton, [string]$cakisma) {
  $json = ConvertTo-Json @($satirlar) -Depth 4 -Compress
  Invoke-RestMethod -Method Post -Uri "$SB_URL/rest/v1/${tablo}?on_conflict=$cakisma" -Headers @{ apikey = $SB_KEY; Authorization = "Bearer $jeton"; Prefer = "resolution=ignore-duplicates,return=minimal" } -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 300 | Out-Null
}
# Ürün Bazlı Satış → satis tablosu. HASTA SÜTUNU OKUNMAZ, YÜKLENMEZ; dosya iş bitince silinir.
function SatisYukle([string]$dosyaAdi) {
  $dosya = Join-Path $VERI $dosyaAdi
  $ss = CsvOku $dosya @("no","satis_no","tarih","urun","barkod","b1","hasta","islem","aciklama","env_maliyet","stok","b2","adet","psf_top","kamu_top","birim_sat","top_sat","kar","top_env","iskonto")
  $sayac = @{}; $liste = New-Object System.Collections.ArrayList
  foreach ($r in $ss) {
    $tarih = TarihIso ([string]$r.tarih); $barkod = ([string]$r.barkod).Trim()
    if (-not $tarih -or $barkod -eq "") { continue }
    $sn = ([string]$r.satis_no).Trim()
    $k = "$sn|$barkod"; if ($sayac.ContainsKey($k)) { $sayac[$k]++ } else { $sayac[$k] = 1 }
    [void]$liste.Add([ordered]@{
      satir_kodu = "$k|$($sayac[$k])"; satis_no = $sn; tarih = $tarih; barkod = $barkod; urun_ad = ([string]$r.urun).Trim()
      tip = ([string]$r.aciklama).Trim(); islem_yapan = ([string]$r.islem).Trim()
      adet = Sayi $r.adet; birim_maliyet = Sayi $r.env_maliyet; top_maliyet = Sayi $r.top_env
      psf_toplam = Sayi $r.psf_top; kamu_toplam = Sayi $r.kamu_top; birim_satis = Sayi $r.birim_sat
      top_satis = Sayi $r.top_sat; kar = Sayi $r.kar; iskonto = Sayi $r.iskonto })
  }
  AralikKontrol ($liste | ForEach-Object { $_.tarih })
  $ciro = ($liste | ForEach-Object { [double]$_.top_satis } | Measure-Object -Sum).Sum
  $kar  = ($liste | ForEach-Object { [double]$_.kar } | Measure-Object -Sum).Sum
  Log ("Satış: {0} satır, ciro {1:N2} TL, kâr {2:N2} TL" -f $liste.Count, $ciro, $kar)
  $j = Jeton
  for ($i = 0; $i -lt $liste.Count; $i += 1000) {
    $parca = $liste.GetRange($i, [Math]::Min(1000, $liste.Count - $i))
    BulutEkle "satis" $parca.ToArray() $j "satir_kodu"
  }
  # stokta olmayan ama satılmış ürünlerin adı da görünsün: ürün listesinde olmayanları ekle (var olanlara dokunmaz)
  $adlar = @{}; foreach ($r in $liste) { if (-not $adlar.ContainsKey($r.barkod) -and $r.urun_ad) { $adlar[$r.barkod] = $r.urun_ad } }
  $urunler = @($adlar.Keys | ForEach-Object { [ordered]@{ barkod = $_; ad = $adlar[$_] } })
  for ($i = 0; $i -lt $urunler.Count; $i += 1000) { BulutEkle "urun" $urunler[$i..([Math]::Min($i + 999, $urunler.Count - 1))] $j "barkod" }
  Log "Buluta yüklendi: $($liste.Count) satış satırı, $($urunler.Count) ürün adı"
  Kayit "satis" "tamam" $liste.Count ("{0:N0} TL ciro" -f $ciro) $j
  Remove-Item $dosya -Force -ErrorAction SilentlyContinue      # hasta adı içeren dosya bilgisayarda kalmasın
}
# Aylık satış: verilen aydan bugüne her ay ayrı çekilir
function SatisGecmis([string]$basAy) {
  $p = RxSureci
  $ay = [datetime]::ParseExact($basAy, "MM.yyyy", $null); $ilk = $true
  while ($ay -le (Get-Date)) {
    $son = $ay.AddMonths(1).AddDays(-1); if ($son -gt (Get-Date)) { $son = (Get-Date).Date }
    AsamaSatis $p $ay.ToString("dd.MM.yyyy") $son.ToString("dd.MM.yyyy") "satis.csv" ; $ilk = $false
    SatisYukle "satis.csv"
    $ay = $ay.AddMonths(1)
  }
}

function BulutOku([string]$yol, [string]$jeton) {
  Invoke-RestMethod -Method Get -Uri "$SB_URL/rest/v1/$yol" -Headers @{ apikey = $SB_KEY; Authorization = "Bearer $jeton" } -TimeoutSec 60
}
# Bugün başka bir bilgisayar topladı mı / şu an topluyor mu?
function GunlukKilit([string]$jeton) {
  $bas = [Uri]::EscapeDataString((Get-Date).Date.ToString("yyyy-MM-ddTHH:mm:sszzz"))
  $k = @(BulutOku "toplama_kaydi?rapor=eq.gunluk&zaman=gte.$bas&select=durum,bilgisayar,zaman&order=zaman.desc" $jeton)
  $tamam = $k | Where-Object { $_.durum -eq "tamam" } | Select-Object -First 1
  if ($tamam) { return "Bugün $($tamam.bilgisayar) zaten topladı." }
  $suren = $k | Where-Object { $_.durum -eq "basladi" -and $_.bilgisayar -ne $env:COMPUTERNAME -and ((Get-Date) - [datetime]$_.zaman).TotalMinutes -lt 40 } | Select-Object -First 1
  if ($suren) { return "$($suren.bilgisayar) şu an topluyor." }
  return $null
}
# Bannerı ayrı süreçte aç (Rx'e tıklamaları engellemeyen, odak çalmayan küçük pencere)
function BannerAc { Remove-Item (Join-Path $KOK "bitti.flag") -Force -ErrorAction SilentlyContinue; $b = Join-Path $KOK "banner.ps1"; if (Test-Path $b) { Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$b`" -Ana $PID" -WindowStyle Hidden } }
function Gunluk {
  $j = Jeton
  $neden = GunlukKilit $j
  if ($neden) { Log "Atlandı: $neden"; return }
  Kayit "gunluk" "basladi" 0 "" $j
  Remove-Item $DURDUR -Force -ErrorAction SilentlyContinue
  BannerAc
  try {
    $p = RxSureci
    AsamaEnvanter $p; AsamaUrunDokum $p; StokYukle
    AsamaKarekod $p; KarekodYukle
    # satış: buluttaki son satış gününden 2 gün öncesinden bugüne
    $son = @(BulutOku "satis?select=tarih&tarih=lte.$((Get-Date).ToString('yyyy-MM-dd'))&order=tarih.desc&limit=1" $j)
    $bas = if ($son.Count -and $son[0].tarih) { ([datetime]$son[0].tarih).AddDays(-2) } else { (Get-Date).Date.AddDays(-30) }
    AsamaSatis $p $bas.ToString("dd.MM.yyyy") (Get-Date).ToString("dd.MM.yyyy") "satis.csv"
    SatisYukle "satis.csv"
    # alış: son fatura gününden 10 gün öncesinden bugüne (geç girilen faturalar da gelsin)
    $sa = @(BulutOku "alis?select=fat_tarih&fat_tarih=lte.$((Get-Date).ToString('yyyy-MM-dd'))&order=fat_tarih.desc&limit=1" (Jeton))
    $ab = if ($sa.Count -and $sa[0].fat_tarih) { ([datetime]$sa[0].fat_tarih).AddDays(-10) } else { (Get-Date).Date.AddDays(-30) }
    AsamaAlis $p $ab.ToString("dd.MM.yyyy") (Get-Date).ToString("dd.MM.yyyy") "alis.csv"
    AlisYukle "alis.csv"
    Kayit "gunluk" "tamam" 0 "" (Jeton)
  } catch {
    Kayit "gunluk" "hata" 0 $_.Exception.Message (Jeton)
    throw
  }
}

# ---------- çalıştır ----------
try {
  Log "=== Toplayıcı başladı (aşama: $Asama) ==="
  if ($Kur) { GirisKur; Log "Bitti."; return }
  if ($Asama -eq "yukle") { StokYukle; Log "Bitti."; return }
  if ($Asama -eq "kkyukle") { KarekodYukle; Log "Bitti."; return }
  if ($Asama -eq "gunluk") { Gunluk; Log "Bitti."; $script:KOD = 0; return }
  $p = RxSureci
  # elle çalıştırılınca konsol Rx'in önünde kalıp tıklamaları yutmasın: küçült (sonda geri açılır)
  $script:KONSOL = @(Get-Process -Name WindowsTerminal, powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object { $_.MainWindowHandle })
  foreach ($h in $script:KONSOL) { [void][W2]::ShowWindow($h, 6) }; Start-Sleep 1
  foreach ($w in (Pencereler $p.Id | Where-Object { $_.Ad -in @("Save As","Farklı Kaydet","Filtreleme") -or $_.Ad -like "*Ayarları*" })) { [void][W2]::SendMessage($w.H, 0x10, [IntPtr]::Zero, [IntPtr]::Zero); Start-Sleep -Milliseconds 500 }
  foreach ($w in (Pencereler $p.Id | Where-Object { $_.Ad -eq "Yazdır" })) { [void][W2]::SendMessage($w.H, 0x10, [IntPtr]::Zero, [IntPtr]::Zero); Log "Açık kalmış önizleme kapatıldı" }
  switch ($Asama) {
    "envanter"  { AsamaEnvanter $p }
    "urundokum" { AsamaUrunDokum $p }
    "stok"      { AsamaEnvanter $p; AsamaUrunDokum $p; StokYukle; AsamaKarekod $p; KarekodYukle }
    "yukle"     { StokYukle }
    "karekod"   { AsamaKarekod $p; KarekodYukle }
    "satis"     { AsamaSatis $p $Bas $Bit "satis.csv"; SatisYukle "satis.csv" }
    "satisgecmis" { SatisGecmis $Bas }
    "alis"      { AsamaAlis $p $Bas $Bit "alis.csv"; AlisYukle "alis.csv" }
    "alisgecmis" { AlisGecmis $Bas }
    "alisdene"  { AsamaAlis $p $Bas $Bit "alis.csv"; CsvBas (Join-Path $VERI "alis.csv") 6 }
    default     { Log "Bilinmeyen aşama: $Asama" }
  }
  Log "Bitti."
} catch {
  Log ("HATA: " + $_.Exception.Message); $script:KOD = 1
} finally {
  New-Item -ItemType File -Force -Path (Join-Path $KOK "bitti.flag") | Out-Null     # banner kapansın
}
if ($Asama -eq "gunluk") { exit $script:KOD }
foreach ($h in @($script:KONSOL)) { if ($h) { [void][W2]::ShowWindow($h, 9); [void][W2]::SetForegroundWindow($h) } }
