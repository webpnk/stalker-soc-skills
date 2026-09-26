# Brings the XR_3DA window to the foreground. SoC pauses while its window is inactive, so every
# test run needs this. Uses the Alt-key + AttachThreadInput workaround for the foreground lock.
# Must run in the interactive session. Writes the result to <root>\appdata\focus.txt.
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class F {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern void SwitchToThisWindow(IntPtr h, bool alt);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, IntPtr p);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool f);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
}
"@
$out = Join-Path (Resolve-Path "$PSScriptRoot\..\..").Path "appdata\focus.txt"
$p = Get-Process XR_3DA -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p -or $p.MainWindowHandle -eq 0) { "no window" | Out-File $out -Encoding ascii; exit 1 }
$h = $p.MainWindowHandle
for ($try = 0; $try -lt 5 -and [F]::GetForegroundWindow() -ne $h; $try++) {
    $fg = [F]::GetForegroundWindow()
    $fgThread = [F]::GetWindowThreadProcessId($fg, [IntPtr]::Zero)
    $me = [F]::GetCurrentThreadId()
    [F]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)      # Alt down
    [F]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)      # Alt up
    [F]::AttachThreadInput($me, $fgThread, $true) | Out-Null
    [F]::ShowWindow($h, 9) | Out-Null
    [F]::BringWindowToTop($h) | Out-Null
    [F]::SetForegroundWindow($h) | Out-Null
    [F]::SwitchToThisWindow($h, $true)
    [F]::AttachThreadInput($me, $fgThread, $false) | Out-Null
    Start-Sleep -Milliseconds 400
}
"focused=$([F]::GetForegroundWindow() -eq $h)" | Out-File $out -Encoding ascii
