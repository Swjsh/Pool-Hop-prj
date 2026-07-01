---
name: unreal-input-probe
description: Self-test Unreal gameplay input end-to-end WITHOUT the MCP or computer-use — launch the game standalone, inject real OS-level keyboard/mouse via PowerShell SendInput (Enhanced Input accepts it, unlike synthetic Slate keys), drive the in-game console (showdebug / GetAll), and observe via GDI window screenshots. Use when input "doesn't work", when the unreal-mcp connection is unavailable, or whenever a change must be verified against COLD ON-DISK state rather than dirty in-editor memory.
---

# Unreal Input Probe (OS-level input injection + GDI observation)

## Why this exists

Two hard walls from earlier sessions are broken by this skill:
1. **Enhanced Input ignores synthetic Slate keys** (`SlateInspector.PressKey`) — but it fully accepts **OS-level `SendInput`** (real `WM_KEYDOWN`/raw-input, same path as a physical keyboard).
2. **computer-use cannot target the UE window** (not a registered app; masked in screenshots) — but **GDI `CopyFromScreen` captures it fine**, and a **real click at cursor position** focuses it without `SetForegroundWindow` permission.

Together: a full drive-and-observe loop for a running game from plain PowerShell — works even in sessions where the unreal-mcp never connected.

## Scripts (in this folder)

- [`probe-input.ps1`](probe-input.ps1) — launches the project standalone (`-game -windowed`), waits for the window (by **PID**, not title — an Explorer window named like the project collides), clicks into it, enables `showdebug enhancedinput`, then injects: **S held 1.5 s** (backward = away from spawn-facing obstacles; W walks you into the sandbox boxes within ~0.3 s and looks frozen), **mouse-look** (+600 px stepped relative moves), **Space** (capture ~350 ms later = mid-air). Saves before/during/after PNGs of the window rect. Read the PNGs — the third-person camera makes any movement unmissable.
- [`send-console.ps1`](send-console.ps1) — finds the running game window, clicks to focus, opens the console (tilde, VK `0xC0`), types a command (chars mapped to VKs), presses Enter. Output goes to `Saved/Logs/PoolHop.log` — grep it afterwards.

## The high-value console commands

- `showdebug enhancedinput` — on-screen truth: possessing controller/pawn classes, input mode, **applied mapping contexts and live action values**. The message *"No enhanced player input action mappings have been applied to this input"* = the rebuilt mapping set is empty (no contexts applied **or contexts with empty Mappings arrays**).
- `GetAll <Class> <Property>` — dumps any UObject property of all instances **to the log file**. **Use `GetAll InputMappingContext DefaultKeyMappings`, NOT `...Mappings`** — in this engine version `UInputMappingContext.Mappings` is a legacy/always-empty shim; the real bindings live nested at `DefaultKeyMappings.Mappings` (added for the player-remappable-key-profile system). `GetAll ... Mappings` prints `Mappings =` (empty) even on a fully healthy IMC — a false "hollow" signal. `GetAll EnhancedInputDeveloperSettings DefaultMappingContexts` shows whether config parsed.
- `obj list class=<Class>` — instance census to the log.
- **Multiple concurrent UE processes redirect the log file**: if the editor already holds `Saved/Logs/<Project>.log` open, a standalone `-game` instance's log silently goes to `<Project>_2.log` (then `_3`, etc. for further instances). Check `ls -la Saved/Logs/` for the newest one before grepping — grepping the primary log after launching a second instance finds nothing.

## Verification doctrine

- **Only a fresh process tests what's on disk.** PIE right after in-session authoring exercises dirty in-memory objects — the exact trap that hid the empty-IMC bug for days. Standalone `-game` (or editor restart, then PIE) is the disk-truth test.
- String-grepping a `.uasset` (`grep -ac "IA_Move" file.uasset`) proves a *reference exists in the import table*, **not** that an array has elements. Use runtime `GetAll` for content truth.
- Windows quirks handled by the scripts: `SetProcessDPIAware()` so coords are physical pixels; focus via click (foreground-window restrictions don't apply to real clicks); keys sent with **VK + scancode**; game window title is `<Project> (64-bit Development PCD3D_SM6)`.
- The probe moves the user's real mouse/keyboard for ~10 s — **warn the user before running it.**
- Standalone `-game` does **not** exit on focus loss (old blind-era myth) — it keeps running headless-in-background just fine (with `bThrottleCPUWhenNotForeground=False`).

## Typical session

```powershell
# 1. full end-to-end input test (launches its own game instance)
powershell -File .claude/skills/unreal-input-probe/probe-input.ps1 -OutDir <scratch>

# 2. interrogate a RUNNING game
powershell -File .claude/skills/unreal-input-probe/send-console.ps1 -Command "GetAll InputMappingContext Mappings"
Select-String Saved/Logs/PoolHop.log -Pattern "Mappings ="
```
