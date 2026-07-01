# send-console.ps1 — type a console command into the RUNNING PoolHop game via real OS input.
# Output of log-emitting commands (GetAll, obj list) lands in Saved/Logs/PoolHop.log.
param([string]$Command = "showdebug enhancedinput")
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class Probe4 {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder sb, int max);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
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
[void][Probe4]::SetProcessDPIAware()

function Type-String([string]$s) {
    foreach ($c in $s.ToCharArray()) {
        $vk = 0
        if ($c -eq ' ') { $vk = 0x20 }
        elseif ($c -eq '=') { $vk = 0xBB }
        elseif ($c -eq '.') { $vk = 0xBE }
        elseif ($c -match '[a-zA-Z0-9]') { $vk = [int][char]::ToUpper($c) }
        else { continue }
        [Probe4]::Key([uint16]$vk, $false); Start-Sleep -Milliseconds 12
        [Probe4]::Key([uint16]$vk, $true);  Start-Sleep -Milliseconds 12
    }
}
function Send-Console([string]$cmd) {
    [Probe4]::Key(0xC0, $false); Start-Sleep -Milliseconds 40; [Probe4]::Key(0xC0, $true)
    Start-Sleep -Milliseconds 350
    Type-String $cmd
    Start-Sleep -Milliseconds 120
    [Probe4]::Key(0x0D, $false); Start-Sleep -Milliseconds 40; [Probe4]::Key(0x0D, $true)
    Start-Sleep -Milliseconds 400
}

$gameWin = $null
foreach ($w in [Probe4]::Windows()) {
    if ($w.Title -like 'PoolHop (64-bit*') { $gameWin = $w; break }
}
if (-not $gameWin) { Write-Output "GAME WINDOW NOT FOUND"; exit 1 }
$L = $gameWin.R.L; $T = $gameWin.R.T; $W = $gameWin.R.R - $L; $H = $gameWin.R.B - $T

[void][Probe4]::SetForegroundWindow($gameWin.H)
Start-Sleep -Milliseconds 250
[void][Probe4]::SetCursorPos($L + [int]($W/2), $T + [int]($H/2))
Start-Sleep -Milliseconds 150
[Probe4]::MouseBtn($false); Start-Sleep -Milliseconds 50; [Probe4]::MouseBtn($true)
Start-Sleep -Milliseconds 400

Send-Console $Command
Write-Output ("SENT: {0}" -f $Command)
