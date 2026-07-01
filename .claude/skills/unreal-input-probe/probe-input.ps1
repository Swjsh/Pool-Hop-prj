# VerifyProbe.ps1 — relaunch PoolHop standalone, enable the enhancedinput debug overlay,
# then inject real S / mouse-look / Space and capture the overlay + world in the same frames.
param([string]$OutDir = "$PSScriptRoot", [int]$BootTimeoutSec = 150)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Probe3 {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern uint SendInput(uint n, INPUT[] inputs, int size);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public InputUnion U; }
    [StructLayout(LayoutKind.Explicit)] public struct InputUnion {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
    }
    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
    public static void Key(ushort vk, bool up) {
        INPUT[] inp = new INPUT[1];
        inp[0].type = 1;
        inp[0].U.ki.vk = vk;
        inp[0].U.ki.scan = (ushort)MapVirtualKey(vk, 0);
        inp[0].U.ki.flags = up ? 2u : 0u;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void MouseBtn(bool up) {
        INPUT[] inp = new INPUT[1];
        inp[0].type = 0;
        inp[0].U.mi.dwFlags = up ? 4u : 2u;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void MouseMoveRel(int dx, int dy) {
        INPUT[] inp = new INPUT[1];
        inp[0].type = 0;
        inp[0].U.mi.dx = dx; inp[0].U.mi.dy = dy;
        inp[0].U.mi.dwFlags = 1;
        SendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }
    public class WinInfo { public IntPtr H; public uint Pid; public string Title; public RECT R; }
    public static List<WinInfo> Windows() {
        List<WinInfo> list = new List<WinInfo>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            if (!IsWindowVisible(h)) return true;
            int len = GetWindowTextLength(h);
            if (len == 0) return true;
            StringBuilder sb = new StringBuilder(len + 1);
            GetWindowText(h, sb, sb.Capacity);
            uint pid; GetWindowThreadProcessId(h, out pid);
            RECT r; GetWindowRect(h, out r);
            WinInfo w = new WinInfo(); w.H = h; w.Pid = pid; w.Title = sb.ToString(); w.R = r;
            list.Add(w);
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
"@
[void][Probe3]::SetProcessDPIAware()

function Capture-Rect([int]$x, [int]$y, [int]$w, [int]$h, [string]$path) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}
function Type-String([string]$s) {
    foreach ($c in $s.ToCharArray()) {
        $vk = 0
        if ($c -eq ' ') { $vk = 0x20 }
        elseif ($c -eq '=') { $vk = 0xBB }
        elseif ($c -eq '.') { $vk = 0xBE }
        elseif ($c -match '[a-zA-Z0-9]') { $vk = [int][char]::ToUpper($c) }
        else { continue }
        [Probe3]::Key([uint16]$vk, $false); Start-Sleep -Milliseconds 12
        [Probe3]::Key([uint16]$vk, $true);  Start-Sleep -Milliseconds 12
    }
}

# ---------- launch ----------
$ue = "C:\Program Files\Epic Games\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe"
$proj = "C:\Users\jackw\Desktop\PoolHop\PoolHop.uproject"
$p = Start-Process -FilePath $ue -ArgumentList @($proj, "-game", "-windowed", "-ResX=1280", "-ResY=720", "-WinX=80", "-WinY=80", "-NoSplash") -PassThru
Write-Output ("PID: {0}" -f $p.Id)

$gameWin = $null
$deadline = (Get-Date).AddSeconds($BootTimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 2000
    if ($p.HasExited) { Write-Output "GAME EXITED EARLY"; exit 1 }
    $wins = [Probe3]::Windows() | Where-Object { $_.Pid -eq $p.Id }
    foreach ($w in $wins) {
        if (($w.R.R - $w.R.L) -gt 800 -and ($w.R.B - $w.R.T) -gt 500) { $gameWin = $w; break }
    }
    if ($gameWin) { break }
}
if (-not $gameWin) { Write-Output "NO WINDOW"; exit 1 }
$L = $gameWin.R.L; $T = $gameWin.R.T; $W = $gameWin.R.R - $L; $H = $gameWin.R.B - $T
Write-Output ("WINDOW: {0}x{1}" -f $W, $H)
Start-Sleep -Seconds 8

# ---------- focus ----------
[void][Probe3]::SetForegroundWindow($gameWin.H)
Start-Sleep -Milliseconds 250
[void][Probe3]::SetCursorPos($L + [int]($W/2), $T + [int]($H/2))
Start-Sleep -Milliseconds 150
[Probe3]::MouseBtn($false); Start-Sleep -Milliseconds 50; [Probe3]::MouseBtn($true)
Start-Sleep -Milliseconds 400
Write-Output ("FOREGROUND match: {0}" -f ([Probe3]::GetForegroundWindow() -eq $gameWin.H))

# ---------- enable debug overlay ----------
[Probe3]::Key(0xC0, $false); Start-Sleep -Milliseconds 40; [Probe3]::Key(0xC0, $true)
Start-Sleep -Milliseconds 350
Type-String "showdebug enhancedinput"
Start-Sleep -Milliseconds 120
[Probe3]::Key(0x0D, $false); Start-Sleep -Milliseconds 40; [Probe3]::Key(0x0D, $true)
Start-Sleep -Milliseconds 600
Capture-Rect $L $T $W $H (Join-Path $OutDir "m1_overlay.png")
Write-Output "SHOT: m1_overlay.png (contexts applied?)"

# ---------- S hold with overlay live ----------
[Probe3]::Key(0x53, $false)
Start-Sleep -Milliseconds 700
Capture-Rect $L $T $W $H (Join-Path $OutDir "m2_during_S.png")
Start-Sleep -Milliseconds 800
[Probe3]::Key(0x53, $true)
Start-Sleep -Milliseconds 400
Capture-Rect $L $T $W $H (Join-Path $OutDir "m3_after_S.png")
Write-Output "SHOT: m2_during_S.png, m3_after_S.png"

# ---------- mouse look ----------
for ($i = 0; $i -lt 10; $i++) { [Probe3]::MouseMoveRel(60, 0); Start-Sleep -Milliseconds 25 }
Start-Sleep -Milliseconds 400
Capture-Rect $L $T $W $H (Join-Path $OutDir "m4_look.png")
Write-Output "SHOT: m4_look.png"

# ---------- jump ----------
[Probe3]::Key(0x20, $false); Start-Sleep -Milliseconds 80; [Probe3]::Key(0x20, $true)
Start-Sleep -Milliseconds 350
Capture-Rect $L $T $W $H (Join-Path $OutDir "m5_jump.png")
Write-Output "SHOT: m5_jump.png"
Write-Output ("GAME RUNNING: {0}" -f (-not $p.HasExited))
Write-Output "DONE"
