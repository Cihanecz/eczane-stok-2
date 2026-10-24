# Rx yazdır önizlemesindeki şerit düğmelerini ve Dışa Aktar menüsünü ölçer (sadece okur; menüyü açıp kapatır)
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms
$A = [Windows.Automation.AutomationElement]; $TS = [Windows.Automation.TreeScope]
$p = Get-Process RxMediaPharmaEYS -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { "Rx yok"; return }
$kok = $A::RootElement.FindAll($TS::Children, (New-Object Windows.Automation.PropertyCondition($A::ProcessIdProperty, $p.Id)))
$on = $kok | Where-Object { $_.Current.Name -in @("Yazdır","Preview","Önizleme") } | Select-Object -First 1
if (-not $on) { "Önizleme açık değil. Pencereler: " + (($kok | ForEach-Object { $_.Current.Name }) -join " | "); return }
$wr = $on.Current.BoundingRectangle
"Önizleme: {0},{1} - {2},{3}" -f $wr.Left, $wr.Top, $wr.Right, $wr.Bottom
"Ekran: " + [Windows.Forms.Screen]::PrimaryScreen.Bounds + "  Çalışma: " + [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$hep = $on.FindAll($TS::Descendants, [Windows.Automation.Condition]::TrueCondition)
"--- şerit (üst 160 px) ---"
foreach ($e in $hep) {
  $c = $e.Current; $r = $c.BoundingRectangle
  if ($c.Name -and -not $r.IsEmpty -and ($r.Top - $wr.Top) -lt 160) {
    "{0,-28} {1,-14} x={2} y={3} w={4} h={5}  (sağdan {6}, üstten {7})" -f $c.Name.Substring(0,[Math]::Min(28,$c.Name.Length)), $c.ControlType.ProgrammaticName.Replace("ControlType.",""), [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height, [int]($wr.Right - $r.X), [int]($r.Y - $wr.Top)
  }
}
"--- dışa aktar adayları ---"
$aday = @($hep | Where-Object { $_.Current.Name -match 'D[ıi][şs]a|Export|Aktar' })
foreach ($e in $aday) { $r = $e.Current.BoundingRectangle; "{0} | {1} | {2},{3} {4}x{5}" -f $e.Current.Name, $e.Current.ControlType.ProgrammaticName, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height }
