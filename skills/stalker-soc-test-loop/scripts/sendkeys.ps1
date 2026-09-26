# Sends keystrokes to the focused game window as hardware scan codes (DirectInput ignores VK events).
# Usage (in the interactive session): sendkeys.ps1 -Keys "grave","f","l","u","s","h","enter","grave"
# Special names: enter, esc, grave (console ~), space, tab, backspace, f1..f12, up, down, left, right.
# "_" pauses 0.5 s; "w:3000" holds a key for 3000 ms.
param([string[]]$Keys, [int]$DelayMs = 60)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class K {
  [StructLayout(LayoutKind.Sequential)] public struct KI { public ushort vk; public ushort scan; public uint flags; public uint time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit, Size = 40)] public struct IN { [FieldOffset(0)] public uint type; [FieldOffset(8)] public KI ki; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, IN[] i, int size);
  public static void Hold(ushort scan, bool ext, int ms) {
    uint e = ext ? 1u : 0u;
    IN[] d = new IN[1]; d[0].type = 1; d[0].ki.scan = scan; d[0].ki.flags = 8 | e;
    IN[] u = new IN[1]; u[0].type = 1; u[0].ki.scan = scan; u[0].ki.flags = 8 | 2 | e;
    SendInput(1, d, Marshal.SizeOf(typeof(IN)));
    System.Threading.Thread.Sleep(ms);
    SendInput(1, u, Marshal.SizeOf(typeof(IN)));
  }
  public static void Key(ushort scan, bool ext) {
    uint e = ext ? 1u : 0u;
    IN[] a = new IN[2];
    a[0].type = 1; a[0].ki.scan = scan; a[0].ki.flags = 8 | e;
    a[1].type = 1; a[1].ki.scan = scan; a[1].ki.flags = 8 | 2 | e;
    SendInput(1, new IN[] { a[0] }, Marshal.SizeOf(typeof(IN)));
    System.Threading.Thread.Sleep(30);
    SendInput(1, new IN[] { a[1] }, Marshal.SizeOf(typeof(IN)));
  }
}
"@
$map = @{
    esc = 0x01; "1" = 0x02; "2" = 0x03; "3" = 0x04; "4" = 0x05; "5" = 0x06; "6" = 0x07; "7" = 0x08; "8" = 0x09; "9" = 0x0A; "0" = 0x0B
    minus = 0x0C; equals = 0x0D; backspace = 0x0E; tab = 0x0F
    q = 0x10; w = 0x11; e = 0x12; r = 0x13; t = 0x14; y = 0x15; u = 0x16; i = 0x17; o = 0x18; p = 0x19
    enter = 0x1C; a = 0x1E; s = 0x1F; d = 0x20; f = 0x21; g = 0x22; h = 0x23; j = 0x24; k = 0x25; l = 0x26
    grave = 0x29; z = 0x2C; x = 0x2D; c = 0x2E; v = 0x2F; b = 0x30; n = 0x31; m = 0x32; period = 0x34; space = 0x39
    f1 = 0x3B; f2 = 0x3C; f3 = 0x3D; f4 = 0x3E; f5 = 0x3F; f6 = 0x40; f7 = 0x41; f8 = 0x42; f9 = 0x43; f10 = 0x44; f11 = 0x57; f12 = 0x58
}
$ext = @{ up = 0x48; down = 0x50; left = 0x4B; right = 0x4D }
foreach ($k in $Keys) {
    if ($k -match '^(\w+):(\d+)$') {   # "w:3000" holds W for 3 s
        $n = $Matches[1]; $ms = [int]$Matches[2]
        if ($ext.ContainsKey($n)) { [K]::Hold($ext[$n], $true, $ms) } else { [K]::Hold($map[$n], $false, $ms) }
    }
    elseif ($ext.ContainsKey($k)) { [K]::Key($ext[$k], $true) }
    elseif ($map.ContainsKey($k)) { [K]::Key($map[$k], $false) }
    elseif ($k -eq "_") { Start-Sleep -Milliseconds 500 }
    else { throw "unknown key $k" }
    Start-Sleep -Milliseconds $DelayMs
}
