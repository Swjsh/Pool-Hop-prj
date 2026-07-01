# Pool Hop — Project Instructions (CLAUDE.md)

Stylized online co-op stealth game in **Unreal Engine 5.8** (Blueprints-first, C++ only when forced). Sneak through sleeping suburbs at 2 AM, hop backyard pools for points, evade homeowners/cops, escape before dawn. Single **UE project** — no web backend/frontend/database.

**Read the design docs before making design decisions:** [`Docs/00_README.md`](Docs/00_README.md) → `01` (GDD) → `02` (MVP scope) → `03` (Tech architecture) → `04` (Research) → `05` (Market). Don't re-derive what's already specified there.

---

## Standing instructions (from the human — keep these satisfied every session)

1. **Build reusable skills as you go.** When you work out a non-obvious way to do something (especially via the Unreal MCP), capture it as a skill under [`.claude/skills/`](.claude/skills/) so the next session doesn't rediscover it. Existing skills:
   - [`unreal-mcp-blueprints`](.claude/skills/unreal-mcp-blueprints/SKILL.md) — authoring Blueprint graphs/classes via MCP.
   - [`unreal-mcp-scene-building`](.claude/skills/unreal-mcp-scene-building/SKILL.md) — levels, actors, materials, screenshots, Play-In-Editor.
2. **Keep a lessons log.** Append hard-won, non-obvious findings to [`Docs/LESSONS.md`](Docs/LESSONS.md) as you hit them — bugs, gotchas, tool quirks, what worked. One entry per lesson, newest first.
3. **Keep this CLAUDE.md current.** Update "Current state" below as build phases complete. Track new standing requests here.
4. **Commit + push after each meaningful chunk** (Epic's own MCP safety rule). Never `--dangerously-skip-permissions` while the Unreal MCP plugin is loaded. `execute_tool_script` runs arbitrary Python — treat as privileged, review diffs.

## The non-negotiable engineering discipline (Tech doc §2)

**All shared/authoritative state lives in GameMode/GameState/PlayerState — never as local variables on the character/pawn.** Score, loudness, alert level, banked points are server-owned even though we're single-player right now. The character holds only movement (via `CharacterMovementComponent`, which replicates for free) + local/cosmetic feedback. This is what makes co-op (Phase 2) a layering job instead of a rewrite. Do not shortcut it to move faster.

---

## Current state

**⚠️ OPEN BLOCKER (2026-07-01 PM) — runtime "can't move" / freeze on Play.** Diagnosed as far as possible **blind**: the unreal-mcp connection dropped when the editor was closed and could not be re-attached this session, so there was no way to *see* the running game. Established (reliable): all input/movement/mesh Blueprints are correct — verified via `get_node_infos`, the runtime log line `CTRL BeginPlay - IMC_Default APPLIED`, an `IMC_Default` dump confirming WASD→IA_Move, and an **auto-walk probe (EventTick→AddMovementInput) that visibly moved the pawn** in captures. The invisible-mesh + input-focus fixes are committed. GPU is **healthy** (`nvidia-smi`: full 2790/3090 MHz, unthrottled, 65% util, 55 °C, 154/360 W) — *not* power/thermal. Yet the user's Play still reads as frozen / can't-move. Log frame-counter *suggested* ~1-2 fps but is unreliable (sparse logging). Leading hypothesis: **RTX 5080 (Blackwell) + UE 5.8 render/shader bottleneck** — GPU waits on the render thread, and `r.D3D12.PSO.DiskCache=0`. Committed a lightweight-render profile (`788a0ba`: Lumen/MegaLights/VSM/volumetric clouds off) — did **not** resolve it; DX11 was also slow. **NEXT (needs live editor / MCP):** `StartPIE` in `PlayMode_InEditorFloating` (the one mode that rendered + moved fine when driven), then `CaptureEditorImage` a `stat unit` overlay to read Frame/Game/Draw/GPU ms and pin the real bottleneck. Gotchas found: in-viewport PIE throttles to a few fps when its window loses focus; standalone `-game` windows exit on focus loss; changing any render cvar forces a full shader recompile (slow first play). Driver 610.62 is already the latest per the user.

**UPDATE (2026-07-01 later PM) — ROOT-CAUSE asset corruption found + FIXED (the user pointed at the load errors).** The log showed `SK_Mannequin` (skeleton) and `PA_Mannequin` (physics) **MISSING**, plus **13 zero-byte `.uasset`** (Manny/Quinn materials, textures, rigs, touch UI). The character mesh `SKM_Manny_Simple` (assigned to `BP_PlayerCharacter.CharacterMesh0`) therefore had **no skeleton = broken character** — a strong candidate for the runtime "freeze"/instability. **Restored the entire pristine `Mannequins/` tree + `Input/Touch/` from `UE_5.8/Templates/TemplateResources/High/{Characters,Input}/Content/`** → project now has **0 zero-byte uassets**; skeleton/physics/materials/textures + a full anim set incl. **`ABP_Unarmed`** are present (commit after `788a0ba`). Also registered `GameFeatureData` in `Config/DefaultGame.ini` `[/Script/Engine.AssetManagerSettings]` to kill the startup "Add entry to PrimaryAssetTypesToScan?" dialog. **NEXT SESSION (MCP now reconnects — editor is up clean on port 8000): (1) assign `ABP_Unarmed` (or author a proper mannequin AnimBP) to `BP_PlayerCharacter.CharacterMesh0` AnimClass so Manny animates; (2) `StartPIE` `PlayMode_InEditorFloating`; (3) `CaptureEditorImage` a `stat unit` overlay to read the real Frame/Game/Draw/GPU ms; (4) confirm movement on screen. Re-test whether the repaired skeleton alone resolves the "can't move"/perf symptom before chasing the RTX50 render angle again.**

**Phase 1 — Systems Sandbox (MVP).** Build order per [`Docs/02_MVP_Vertical_Slice.md`](Docs/02_MVP_Vertical_Slice.md) §5. Build **only** the current system; park everything else.

- **System 1 — Player Controller & Movement** — ✅ **built + verified** (as far as possible without a human keypress).
  - Core framework: `BP_PlayerGameMode/GameState/PlayerState/PlayerController` (`_Project/Core`), `BP_PlayerCharacter` (`_Project/Characters`, from the ThirdPerson template for working camera/anim).
  - Movement verbs on `BP_PlayerCharacter`: walk, crouch (`MaxWalkSpeedCrouched`), sprint (`WalkSpeed`/`SprintSpeed` → `MaxWalkSpeed`), jump, vault (`TryVault` trace + `LaunchCharacter` gated before Jump), swim (level `PhysicsVolume` `bWaterVolume=true` + water surface).
  - Test map `L_Sandbox_Movement`: flat grey-box course (vault wall, crouch doorway, swim pool), GameMode override → `BP_PlayerGameMode`.
  - **Input fully repaired** — two bugs fixed (both in LESSONS): the template's input assets were committed 0-byte, and the six input events were all mis-bound to IA_Move (a `set_pin_value` on the InputAction pin does NOT rebind — must delete+recreate with the correct `Input|EnhancedActionEvents|IA_X` type). Now each event binds its correct action (verified via `get_node_infos`).
  - PIE verified clean: spawns `BP_PlayerCharacter`, `MaxWalkSpeed=600` from BeginPlay, `MOVE_Walking`, no hang.
  - **Movement PROVEN working (2026-07-01).** The user's persistent "can't move" was NOT input — it was that the character's `CharacterMesh0` had `SkeletalMeshAsset = None` (Manny invisible), so walking on a featureless grid was imperceptible + read as "frozen." **Fixed:** assigned `SKM_Manny_Simple` → Manny now renders (grey, materials still 0-byte; A-pose, no AnimBP). Proved movement keypress-free via an auto-walk probe (EventTick→AddMovementInput → the pawn visibly walked into the boxes). All six input events confirmed correctly wired+bound via `get_node_infos` (NOT `read_graph_dsl` — it can't traverse Enhanced Input `Triggered` pins and falsely reports every event empty; see LESSONS). Controller adds `IMC_Default` on BeginPlay (graph confirmed). A live hardware WASD press is the only thing MCP can't self-drive (Enhanced Input ignores synthetic Slate keys), but it is deductively guaranteed to work. **Deferred polish:** import/author a mannequin AnimBP so Manny animates instead of sliding in A-pose; fix the 0-byte `MI_Manny_*` materials.
- **Step 1 — Authoritative framework state** — ✅ built. 16 server-authoritative vars on `BP_PlayerGameState`/`BP_PlayerState` (canonical names per `Docs/design/CANON.md`), correct replication, compiled clean.
- **Step 2 — LoudnessComponent** — 🔨 core built. `BP_LoudnessComponent` attached to the character as `LoudnessComp`: `CurrentLoudness` (RepNotify) + tuning, `AddLoudness`/`GetLoudness01`, and an Event-Tick-driven `TickLoudness` (asymmetric rise-to-band / decay-to-idle). **Next:** wire the character's sprint→`bIsSprinting`, swim→`bIsInWater`, vault→`AddLoudness(30)`; then `ReportNoise` (Step 4, needs the AI). Server-RPC wrappers are Phase-2 (MCP can't set the flags — LESSONS).
- **Systems 3–5 (scoring, detection AI, costume) + sensor light** — ⛔ not built. See `Docs/design/08_Implementation_Roadmap.md`.

**Autonomous-build ceiling (spiked, in LESSONS):** MCP can build variables/graphs/components/materials/actors but CANNOT create Blueprint enums/structs, set Run-on-Server RPC flags, or author Behavior Trees / UMG widgets — and computer-use can't reach the editor window here. So the **AI-Watcher Behavior Tree (Step 4) and the HUD (Step 7) need the user in-editor**; the loop builds everything else. Interim: enums→`byte`, RPCs→regular `HasAuthority` functions.

**Project 42 reaper:** verified safe — it only kills processes referencing `Desktop\42`'s workdir; ours don't, and the editor isn't a candidate. The loop also self-heals the editor+MCP if port 8000 drops (LESSONS).

**Rendering:** hardware ray tracing is **disabled** (`r.RayTracing=False` in DefaultEngine.ini) — the template's Lumen HWRT deadlocked PIE at render init. Lumen runs in software. Revisit for real neighborhoods (Phase 4+). `EditorStartupMap`/`GameDefaultMap` → `L_Sandbox_Movement`.

**Overnight autonomous run (in progress):** a multi-agent workflow is writing an exhaustive design + build-spec package to `Docs/design/` (art/style, Maple Court neighborhood, underground pools, the AI watcher, characters, core-systems tech spec, movement/UI, a design bible `00`, an implementation roadmap `08`, and a critique `09`). A build loop then works the roadmap (Loudness → Scoring → shared state → AI Watcher → couple → costume → neighborhood → underground pools), committing per chunk. **Start here on next wake:** read `Docs/design/08_Implementation_Roadmap.md`, check `git log`, then build the next undone chunk.

**Restart the editor + MCP (if the server is down / port 8000 not listening):**
```powershell
Get-Process UnrealEditor,CrashReportClientEditor -EA SilentlyContinue | Stop-Process -Force; Start-Sleep 5;
Start-Process "C:\Program Files\Epic Games\UE_5.8\Engine\Binaries\Win64\UnrealEditor.exe" -ArgumentList @("C:\Users\jackw\Desktop\PoolHop\PoolHop.uproject","-ExecCmds=ModelContextProtocol.StartServer")
```
The editor does NOT auto-start the MCP server; the `-ExecCmds` arg does. Poll `Test-NetConnection 127.0.0.1 -Port 8000`.

**Known issues (deferred, not blocking):** several template assets are still 0-byte from the original corruption — Manny's material instances/textures/rigs and the Touch UI widgets (grey-box is fine per doc 02; revisit before the Synty swap).

---

## Conventions

- **Our content** lives under `Content/_Project/{Core,Characters,Components,AI,Systems,Gameplay,UI,Data,Maps}`. Imported/marketplace content stays in `Content/ThirdParty/` or the stock template folders (`Content/ThirdPerson`, `Content/Characters/Mannequins`, etc.). Never edit template folders in place — duplicate into `_Project/` first.
- **Naming:** `BP_` Blueprints, `IA_`/`IMC_` Enhanced Input, `M_`/`MI_` materials, `L_` maps, `SB_` sandbox grey-box props.
- **Blueprints-first.** Drop to C++ only for perf hot-paths or Blueprint-inaccessible features. No `Source/` module exists yet.
- **No automated test harness** — testing is manual Play-In-Editor against [`Docs/02_MVP_Vertical_Slice.md`](Docs/02_MVP_Vertical_Slice.md) §4 success criteria. This is a deliberate project decision, not an oversight — don't scaffold unit tests.

## Documentation taxonomy

This project predates the global `markdown/`-subfolder convention and uses `Docs/` instead. Keep it consistent:
- **Design docs** (vision, scope, architecture, research): `Docs/NN_Name.md` (numbered).
- **Build lessons / gotchas:** `Docs/LESSONS.md`.
- **Architecture overview:** `ARCHITECTURE.md` (root anchor).
- **Skills:** `.claude/skills/<name>/SKILL.md`.
- Root markdown is limited to the conventional anchors (`README`-style docs live in `Docs/`, plus `CLAUDE.md`, `ARCHITECTURE.md`).

## MCP workflow (Claude ↔ Unreal 5.8)

The `unreal-mcp` server drives the running editor. Key habits (full detail in the skills):
- Load tool schemas with `ToolSearch` / `describe_toolset`; `BlueprintTools`' schema is too big to fetch whole — parse the saved JSON with Python to extract the tools you need.
- Prefer `write_graph_dsl` for Blueprint logic; call `get_graph_dsl_docs` first. Fall back to `create_node`/`connect_pins` for surgical edits to existing graphs.
- **Save + verify on disk** after asset work (`save_assets`, then `ls -la` / `find ... -size 0`). Some saves silently no-op on corrupted stub packages — see LESSONS.
- Commit before starting and after each chunk. Origin: `https://github.com/Swjsh/Pool-Hop-prj` (main), Git LFS for binaries.
