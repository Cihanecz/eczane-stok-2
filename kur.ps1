# Eczane Stok — toplayıcıyı internetten indirip kurar (bir kez çalıştırılır)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$KAYNAK = "https://cihanecz.github.io/eczane-stok-2"
$KOK = "C:\EczaneStok"
New-Item -ItemType Directory -Force -Path $KOK, "$KOK\veri" | Out-Null
$wc = New-Object Net.WebClient
foreach ($d in "toplayici.ps1","banner.ps1","gozcu.ps1","baslat.vbs") {
  $wc.DownloadFile("$KAYNAK/$d" + "?t=" + [DateTime]::Now.Ticks, (Join-Path $KOK $d))
  Write-Host ("indirildi: " + $d + " (" + (Get-Item (Join-Path $KOK $d)).Length + " bayt)")
}
$bas = [Environment]::GetFolderPath("Startup")
Copy-Item "$KOK\baslat.vbs" (Join-Path $bas "EczaneStok.vbs") -Force
Write-Host "Dosyalar kuruldu. Şimdi Eczane Stok programına girişte kullanılan e-posta ve şifreyi gir:" -ForegroundColor Green
& powershell -NoProfile -ExecutionPolicy Bypass -File "$KOK\toplayici.ps1" -Kur
Start-Process wscript.exe -ArgumentList "`"$KOK\baslat.vbs`""
Write-Host "Tamam. Bundan sonra Rx'e her gün ilk girişte veriler otomatik alınır." -ForegroundColor Green
