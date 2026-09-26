# Sends a relative mouse move (DX, DY) in small steps via SendInput. Interactive session only.
param([int]$DX = 0, [int]$DY = 0)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class MM {
  [StructLayout(LayoutKind.Sequential)] public struct MI { public int dx; public int dy; public uint data; public uint flags; public uint time; public IntPtr extra; }
  [StructLayout(LayoutKind.Explicit, Size = 40)] public struct IN { [FieldOffset(0)] public uint type; [FieldOffset(8)] public MI mi; }
  [DllImport("user32.dll")] public static extern uint SendInput(uint n, IN[] i, int size);
  public static void Send(int dx, int dy, uint flags) {
    IN[] a = new IN[1]; a[0].type = 0; a[0].mi.dx = dx; a[0].mi.dy = dy; a[0].mi.flags = flags;
    SendInput(1, a, Marshal.SizeOf(typeof(IN)));
  }
}
"@
$n = [Math]::Max(1, [Math]::Ceiling([Math]::Max([Math]::Abs($DX), [Math]::Abs($DY)) / 20))
for ($i = 0; $i -lt $n; $i++) { [MM]::Send([int]($DX / $n), [int]($DY / $n), 1); Start-Sleep -Milliseconds 10 }
