# Clicks in the game UI. SoC draws its own UI cursor from DirectInput relative mouse deltas and
# ignores the OS cursor position. Deltas must be sent in small steps (large bursts are dropped).
# Closed loop: push the cursor into the top-left corner, move by an estimate, then capture the window,
# find the cursor (its yellow radiation trefoil) and correct until the tip is within 3 px.
# X, Y are window-relative pixels in the capture_game.ps1 frame (window incl. title bar).
param([int]$X, [int]$Y, [switch]$NoClick, [switch]$Right, [switch]$Double, [switch]$Debug)
$ax = 0.7755; $ay = 0.7056          # window pixels per mouse count (measured at 1280x720)
$tipOff = @(-28, -24)                # arrow tip relative to the trefoil centroid
$mm = "$PSScriptRoot\mouse_move.ps1"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CW {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
[CW]::SetProcessDPIAware() | Out-Null
$h = (Get-Process XR_3DA | Select-Object -First 1).MainWindowHandle

function Find-Cursor {
    $r = New-Object CW+RECT; [CW]::GetWindowRect($h, [ref]$r) | Out-Null
    $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
    $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
    [CW]::PrintWindow($h, $dc, 2) | Out-Null; $g.ReleaseHdc($dc); $g.Dispose()
    # the trefoil: saturated yellow pixels; take the densest 30x30 cluster
    $pts = New-Object System.Collections.Generic.List[int[]]
    for ($yy = 32; $yy -lt $bmp.Height; $yy += 2) { for ($xx = 0; $xx -lt $bmp.Width; $xx += 2) {
        $c = $bmp.GetPixel($xx, $yy)
        if ($c.R -gt 200 -and $c.G -gt 170 -and $c.B -lt 70) { $pts.Add(@($xx, $yy)) } } }
    $bmp.Dispose()
    $best = $null; $bestN = 0
    foreach ($p in $pts) {
        $n = 0; $sx = 0; $sy = 0
        foreach ($q in $pts) { if ([Math]::Abs($q[0] - $p[0]) -lt 15 -and [Math]::Abs($q[1] - $p[1]) -lt 15) { $n++; $sx += $q[0]; $sy += $q[1] } }
        if ($n -gt $bestN) { $bestN = $n; $best = @(($sx / $n), ($sy / $n)) }
    }
    if ($bestN -lt 6) { return $null }
    return @(($best[0] + $tipOff[0]), ($best[1] + $tipOff[1]))
}

& $mm -DX -3000 -DY -3000
Start-Sleep -Milliseconds 150
& $mm -DX ([int](($X + 16.7) / $ax)) -DY ([int](($Y - 49.7) / $ay))
for ($i = 0; $i -lt 4; $i++) {
    Start-Sleep -Milliseconds 300
    $c = Find-Cursor
    if ($c -eq $null) { Start-Sleep -Milliseconds 300; $c = Find-Cursor }
    if ($c -eq $null) { break }
    $ex = $X - $c[0]; $ey = $Y - $c[1]
    if ($Debug) { "iter $i cursor $([int]$c[0]),$([int]$c[1]) err $([int]$ex),$([int]$ey)" | Out-File -Append (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path "appdata\click_debug.txt") }
    if ([Math]::Abs($ex) -le 3 -and [Math]::Abs($ey) -le 3) { break }
    & $mm -DX ([int]($ex / $ax)) -DY ([int]($ey / $ay))
}
Start-Sleep -Milliseconds 500   # let the game consume the last deltas before pressing
if (-not $NoClick) {
    $down = 0x0002; $up = 0x0004
    if ($Right) { $down = 0x0008; $up = 0x0010 }
    [MM]::Send(0, 0, $down); Start-Sleep -Milliseconds 60
    [MM]::Send(0, 0, $up)
    if ($Double) { Start-Sleep -Milliseconds 90; [MM]::Send(0, 0, $down); Start-Sleep -Milliseconds 60; [MM]::Send(0, 0, $up) }
}
