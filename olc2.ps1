# Dışa Aktar okuna basar, açılan menüyü (Rx'e ait tüm görünür pencereler + UIA öğeleri) listeler, sonra ESC ile kapatır. Hiçbir şey seçmez.
param([int]$dx = 150, [int]$dy = 74)
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices;
public static class W3 {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static void Tik(int x, int y) { SetCursorPos(x, y); System.Threading.Thread.Sleep(80); mouse_event(2,0,0,0,IntPtr.Zero); mouse_event(4,0,0,0,IntPtr.Zero); }
}
"@
$A = [Windows.Automation.AutomationElement]; $TS = [Windows.Automation.TreeScope]
$p = Get-Process RxMediaPharmaEYS -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { "Rx yok"; return }
function Liste {
  $l = New-Object System.Collections.ArrayList
  [W3]::EnumWindows({ param($h, $x)
    $pid2 = 0; [void][W3]::GetWindowThreadProcessId($h, [ref]$pid2)
    if ($pid2 -eq $p.Id -and [W3]::IsWindowVisible($h)) {
      $c = New-Object Text.StringBuilder 256; [void][W3]::GetClassName($h, $c, 256)
      $t = New-Object Text.StringBuilder 256; [void][W3]::GetWindowText($h, $t, 256)
      $r = New-Object W3+RECT; [void][W3]::GetWindowRect($h, [ref]$r)
      [void]$l.Add([pscustomobject]@{ H = $h; Ad = $t.ToString(); Sinif = $c.ToString(); L = $r.L; T = $r.T; R = $r.R; B = $r.B })
    }; $true }, [IntPtr]::Zero) | Out-Null
  return $l
}
$once = Liste
$on = $once | Where-Object { $_.Ad -in @("Yazdır","Preview","Önizleme") } | Select-Object -First 1
if (-not $on) { "Önizleme yok"; $once | Format-Table -AutoSize | Out-String -Width 200; return }
"Önizleme: {0},{1} - {2},{3}" -f $on.L, $on.T, $on.R, $on.B
$x = $on.R - $dx; $y = [Math]::Max($on.T, 0) + $dy
"Tıklanan ok: $x,$y"
[void][W3]::SetForegroundWindow($on.H); Start-Sleep -Milliseconds 500
[W3]::Tik($x, $y); Start-Sleep -Milliseconds 1500
$sonra = Liste
"--- yeni görünen pencereler ---"
$yeni = @($sonra | Where-Object { $h = $_.H; -not ($once | Where-Object { $_.H -eq $h }) })
$yeni | Format-Table Ad, Sinif, L, T, R, B -AutoSize | Out-String -Width 200
foreach ($w in $yeni) {
  "--- {0} içindeki öğeler ---" -f $w.Sinif
  try {
    $e = $A::FromHandle($w.H)
    foreach ($c in $e.FindAll($TS::Descendants, [Windows.Automation.Condition]::TrueCondition)) {
      $r = $c.Current.BoundingRectangle
      if ($c.Current.Name -and -not $r.IsEmpty) { "{0,-30} x={1} y={2} w={3} h={4}  (oktan dx={5} dy={6})" -f $c.Current.Name, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height, [int]($r.X + $r.Width/2 - $x), [int]($r.Y + $r.Height/2 - $y) }
    }
  } catch { "  okunamadı: " + $_.Exception.Message }
}
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
"bitti (menü kapatıldı)"
