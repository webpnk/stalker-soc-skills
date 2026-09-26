# Captures the XR_3DA game window with PrintWindow (works while the window is occluded or unfocused).
# Must run in the interactive session. Optional -Front brings the window to the foreground first.
param([string]$Out = (Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path "appdata\game.png"), [switch]$Front)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@
[W]::SetProcessDPIAware() | Out-Null   # otherwise 125% display scaling crops the capture
$p = Get-Process XR_3DA -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { "no game window" | Out-File "$Out.txt" -Encoding ascii; exit 1 }
$h = $p.MainWindowHandle
if ($Front) { [W]::ShowWindow($h, 9) | Out-Null; [W]::SetForegroundWindow($h) | Out-Null; Start-Sleep -Milliseconds 800 }
$r = New-Object W+RECT
[W]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L; $ht = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dc = $g.GetHdc()
$ok = [W]::PrintWindow($h, $dc, 2)   # PW_RENDERFULLCONTENT
$g.ReleaseHdc($dc)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"ok=$ok ${w}x${ht} title=$($p.MainWindowTitle)" | Out-File "$Out.txt" -Encoding ascii
