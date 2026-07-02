---
name: unreal-mcp-session
description: START HERE for any Unreal work on Pool Hop. The orientation layer — how to connect to the running editor via the unreal-mcp server (and what to do when it's NOT connected), discover and call tools, verify work against COLD ON-DISK state (not dirty editor memory), run and observe the game two different ways (MCP Play-In-Editor vs. the standalone + real-input probe), and the safety rules. Read this before the three domain skills (unreal-mcp-blueprints, unreal-mcp-scene-building, unreal-input-probe).
---

# Unreal MCP — Session Orientation (read first)

This is the map. The territory is in three domain skills: **[unreal-mcp-blueprints](../unreal-mcp-blueprints/SKILL.md)** (Blueprint graphs/classes/variables/DSL), **[unreal-mcp-scene-building](../unreal-mcp-scene-building/SKILL.md)** (levels/actors/materials/PIE/screenshots), **[unreal-input-probe](../unreal-input-probe/SKILL.md)** (self-testing real keyboard/mouse input). Load the domain skill for the task; this file tells you how to get connected, how to trust your work, and how to see the game.

---

## 1. Connecting — the reconnect story is more nuanced than earlier sessions assumed

**CORRECTED 2026-07-02 (see `Docs/LESSONS.md` for the full empirical trail): in-session reconnect DOES work, at least in this specific proven scenario.** The long-standing "no in-session reconnect, must restart Claude Code" claim below was the established doctrine for most of this project's history and drove real caution (e.g. the MegaLights/Lumen re-test being deferred specifically to avoid this risk) — but it was **empirically falsified** this session: the editor was closed (clean shutdown), stayed down for several cycles (confirmed via `Test-NetConnection`/process checks — `unreal-mcp` calls failed with a connection error the whole time), then got restarted externally: once WITHOUT the MCP flag (port 8000 stayed down, tool calls kept failing), then again WITH it. The moment port 8000 came back up (caught via a persistent `Monitor` polling it), **the SAME already-running Claude session's very next `unreal-mcp` tool call succeeded immediately** — no Claude Code restart needed. Verified stable with a second, independent call right after (not a fluke).

**Best current understanding of the mechanism:** the transport is plain HTTP (`http://127.0.0.1:8000/mcp`, see below) — each tool call is plausibly a fresh, stateless HTTP request rather than a persistent handshake/session your Claude process holds open. If that's right, reconnection succeeding is less "special recovery magic" and more "there was simply nothing listening on the port before, and now there is" — which would mean the original claim may have been over-generalized from a different, earlier failure mode (or was accurate for a different transport at the time it was written) rather than a fundamental limit of this specific setup.

**What to actually do now, given the uncertainty:**
- The old advice ("if you find yourself with no unreal tools, make sure the editor+server are up, then restart Claude Code") is **no longer the ONLY path** — trying a real tool call first (not just `ToolSearch`, which can return cached schemas without proving connectivity) is now the right first move once the server's back, since it might just work.
- **Still don't treat this as a green light to casually restart the editor mid-session** (e.g., to test the MegaLights/Lumen change) purely because reconnection worked once for an *externally-triggered* restart. That specific scenario (an already-connected session deliberately triggering its own server's shutdown+relaunch, e.g. via `StopPIE`-adjacent process control) has not been tested — only "the server died and came back while I was idle, unrelated to my own actions" has. Re-verify with a fresh, deliberate test before fully retiring that caution.
- If a real tool call fails with a connection error, the old fallback (restart Claude Code once the editor+server are confirmed up) is still the safe, always-works path.

**Server facts (still accurate, not documented in the domain skills — anchor them here):**
- Transport: HTTP MCP on **`http://127.0.0.1:8000/mcp`** (port **8000**). No auth — localhost is not a trust boundary; never expose the port.
- The editor does **not** auto-start the server. The `-ExecCmds` arg does. **Start editor + server:**
  ```powershell
  Get-Process UnrealEditor,CrashReportClientEditor -EA SilentlyContinue | Stop-Process -Force; Start-Sleep 5;
  Start-Process "C:\Program Files\Epic Games\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe" -ArgumentList @("C:\Users\jackw\Desktop\PoolHop\PoolHop.uproject","-ExecCmds=ModelContextProtocol.StartServer")
  ```
- **Verify ready:** poll `Test-NetConnection 127.0.0.1 -Port 8000` until `TcpTestSucceeded=True`. Boot takes ~1–3 min (shader/asset load). A **"Restore Packages" modal on boot blocks the MCP game thread** — if you force-killed the editor, delete `Saved/Autosaves/PackageRestoreData.json` before relaunching, or the next agent's MCP calls hang behind the modal.
- Requires the `ModelContextProtocol` **and** `AllToolsets` plugins enabled (they are, in `PoolHop.uproject`). Without AllToolsets the server exposes zero tools.

## 2. Discovering & calling tools

Unreal tools are **deferred** — their schemas aren't loaded until you fetch them. Load in bulk:
```
ToolSearch  "select:mcp__unreal-mcp__call_tool"       # the main entry point
ToolSearch  "unreal blueprint"                          # keyword search across the server
```
Almost everything routes through **`mcp__unreal-mcp__call_tool`** with `toolset_name` + `tool_name` + args. The foundational toolsets:

| Toolset | For |
|---|---|
| `editor_toolset.toolsets.blueprint.BlueprintTools` | create BPs, variables, functions, events, `write_graph_dsl`, `compile_blueprint` |
| `SceneTools` / `ActorTools` / `PrimitiveTools` | levels, place/transform actors, `trace_world`, tags |
| `ObjectTools` | `get_properties` / `set_properties` (CDO defaults, component props) — **`values` is a JSON-encoded STRING** |
| `MaterialTools` | create/edit materials, expressions, recompile |
| `EditorToolset.EditorAppToolset` | camera, `CaptureViewport` / `CaptureEditorImage`, `StartPIE` / `IsPIERunning` / `StopPIE` |
| `DataAssetTools` / `DataTableTools` | PrimaryDataAssets, Data Tables |

**Schema loading:** `describe_toolset("...BlueprintTools")` is ~72k chars and overflows the tool-result limit → it spills to a `tool-results/*.txt` file. Parse it with Python (`json.load`, extract the tool objects by short name) rather than reading it whole. Before your first `write_graph_dsl`, call `get_graph_dsl_docs()` — the DSL grammar is not inlined anywhere; that tool is the reference.

## 3. The verification discipline — trust disk, not the editor

**This is the rule that would have saved days.** The "game ignores all input" bug (2026-07-01, `Docs/LESSONS.md`) was IMC assets that MCP saved with **empty Mappings arrays** — the bindings existed only in that editor session's memory. Every in-editor "verified" test passed against dirty RAM; every cold load from disk had nothing.

- **After any asset work:** `AssetTools.save_assets([])` → `find Content -name "*.uasset" -size 0` (catch the 0-byte silent-corruption class) → `compile_blueprint(warnings_as_errors=true)` on every touched BP (a non-compiling BP freezes PIE on a modal MCP can't dismiss).
- **`save_assets` can silently no-op** on corrupted stub packages (returns success, writes nothing). If a file stays 0-byte, `AssetTools.delete` the stub and re-create it fresh.
- **String-grepping a `.uasset` proves a *reference* exists, NOT that an array has *elements*.** `grep -ac IA_Move IMC.uasset` returning >0 means only that the import table names it.
- **Only a FRESH PROCESS tests on-disk truth.** PIE right after authoring exercises in-memory objects. The honest test of "did it actually save correctly" is: restart the editor, or launch the game standalone (§4b), then read the state back. Make this reflex for anything load-bearing (input assets, CDO defaults, replication).
- **`read_graph_dsl` lies** about freshly-rewired nodes and cannot traverse Enhanced Input `Triggered`/`Started` exec pins (renders them empty). Trust `get_node_infos` (pin-level) + a clean compile, never the DSL round-trip, for input wiring.
- **`ObjectTools.set_properties` with MULTIPLE properties in one call can silently apply only the first one**, still returning `true` overall. Caught fixing `BP_BushHide.BushMesh`: one call set both `bodyInstance` and `overrideMaterials` — only `bodyInstance` took, `overrideMaterials` stayed unchanged (`Docs/LESSONS.md` 2026-07-02). When setting more than one property on the same object, either issue separate calls or verify every property in the `values` dict via a follow-up `get_properties`, not just one of them.

## 4. Running & observing the game — two channels, pick deliberately

### (a) MCP Play-In-Editor — fast, but input-blind
`EditorAppToolset.StartPIE(options={bSimulate:false, playMode:"PlayMode_InViewPort", warmupSeconds:1})` → `IsPIERunning()` → inspect → `StopPIE()`. Good for: spawn/possession/GameMode-load verification, reading replicated state, `CaptureEditorImage`. **Cannot inject player input** (Enhanced Input ignores synthetic Slate keys), so it can't feel-test verbs. Prove movement without input via a temporary `EventTick → AddMovementInput` probe, then delete it. Measure fps by a **<1 s** frame-counter delta or a frame-to-frame pixel diff — never a long-gap counter read (it wraps at 1000). The in-viewport window throttles to a few fps when it loses OS focus; that's not a perf bug.

### (b) Standalone + real OS input — the self-test channel (NEW, no MCP needed)
The long-standing "only a human can press W" wall is **broken**: **PowerShell `SendInput` drives Enhanced Input end-to-end** (real hardware-path input), and **GDI `CopyFromScreen` captures the game window** (computer-use can't). This works even with the MCP disconnected. Full recipe + scripts: **[unreal-input-probe](../unreal-input-probe/SKILL.md)**. Use it to:
- Self-verify movement/jump/interact after any input or character change (WASD, mouse-look, Space — all injectable + screenshot-able).
- Drive the **in-game tilde `~` console** (open with VK `0xC0`, type command as VKs, Enter) — this is the "menu" that reads runtime truth:
  - `showdebug enhancedinput` → on-screen: possessed pawn/controller, input mode, **applied mapping contexts + live action values** ("No enhanced player input action mappings have been applied" = empty/missing contexts).
  - `GetAll <Class> <Property>` → dumps any UObject property of all instances to `Saved/Logs/PoolHop.log` (e.g. `GetAll InputMappingContext Mappings` = read asset content at runtime).
- **Warn the user first** — it moves their real mouse/keyboard for ~10 s.

Standalone launch: `UnrealEditor.exe <proj> -game -windowed -ResX=1280 -ResY=720 -WinX=80 -WinY=80 -NoSplash`. It does **not** exit on focus loss (old myth). Find its window by **PID** (title `PoolHop (64-bit Development PCD3D_SM6)`), focus by real click.

## 5. Safety (Epic's rules — non-negotiable)

- **Commit before starting and after each chunk.** MCP mutates/deletes live VCS-tracked assets in one call. Origin `https://github.com/Swjsh/Pool-Hop-prj` (main), Git LFS for binaries.
- **Never `--dangerously-skip-permissions`** while the plugin is loaded — it removes the per-tool approval gate.
- **`execute_tool_script` runs arbitrary editor Python** with full disk access — treat every call as privileged; review the diff. (It also can't `import unreal` — only stdlib + `execute_tool()`.)
- The MCP is **Experimental** — expect API drift; don't build load-bearing automation on unstable tool signatures.

## 6. What MCP CANNOT build (hard ceiling — plan around it)

Spiked + confirmed (`Docs/LESSONS.md`, `Docs/design/CANON.md` §"Known MCP buildability gaps"). MCP **cannot** create: **Blueprint Enums/Structs**, **Run-on-Server/Reliable RPC flags**, **Behavior Trees/Blackboards**, **IK Rig/IK Retargeter assets** (2026-07-02 — the `IKRetargeter`/`IKRigDefinition` classes exist via `search_subclasses`, confirming the plugin is enabled, but no dedicated toolset wraps them and no generic "create arbitrary asset" tool covers this type either; needed for retargeting animations across different skeletons, e.g. Mixamo→UE Mannequin), and (unconfirmed) EQS. Interim substitutes are canon: enums → `byte`, `Server_*` RPCs → regular `HasAuthority`-guarded functions, BT → **needs the user in-editor** (leave a click-by-click checklist). computer-use also can't reach the editor window here, so there's no GUI-automation fallback for these — they genuinely need the human.

**UMG widget trees are NOW MCP-buildable (2026-07-01)** — earlier sessions had this wrong. A live `UMGToolSet.UMGToolSet` toolset (`CreateWidgetBlueprint`, `AddWidget`, `CompileWidgetBlueprint`, `BindToEventProperty`, etc.) genuinely authors widget trees; verified end-to-end incl. a non-zero-byte on-disk save (`Docs/LESSONS.md` 2026-07-01 entry). Workflow: `ObjectTools.list_properties(widget)` before `set_properties` (names are per-class and not guessable) — same discipline as everything else. After `CreateWidgetBlueprint`, use `AssetTools.save_assets([])` (empty array) to persist it; a targeted-path save/exists/delete call fails on a same-session just-created widget BP until that first empty-array save runs.

**Niagara IS also MCP-buildable (2026-07-02)** — `NiagaraToolsets.NiagaraToolset_System` (`CreateNiagaraSystem`, `AddEmitter`, `AddModule`, `AddRenderer`, `SetStackInputData`, etc.) is real and functional; verified end-to-end (`NS_NoiseRing`, `Docs/LESSONS.md` 2026-07-02 entry). Both `CreateNiagaraSystem`/`AddEmitter` require a `templateSystem`/`templateEmitter` (no blank-slate option) — **pick a template that's a complete effect and prune with `RemoveEmitter`/`RemoveModule`, don't start from an ultra-minimal template and try to build up**; a too-minimal template (`MinimalLightweight`) has no script stages for `AddModule` to target at all, and there's no tool to create a missing stage.
