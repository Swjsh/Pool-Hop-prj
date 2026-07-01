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

**Phase 1 — Systems Sandbox (MVP).** Build order per [`Docs/02_MVP_Vertical_Slice.md`](Docs/02_MVP_Vertical_Slice.md) §5. Build **only** the current system; park everything else.

- **System 1 — Player Controller & Movement** — 🔨 in progress.
  - ✅ Core framework scaffolded: `BP_PlayerGameMode`, `BP_PlayerGameState`, `BP_PlayerState`, `BP_PlayerController` (in `_Project/Core`), `BP_PlayerCharacter` (in `_Project/Characters`, duplicated from the ThirdPerson template to keep its working camera/anim/input).
  - ✅ Movement verbs on `BP_PlayerCharacter`: walk, crouch (slower via `MaxWalkSpeedCrouched`), sprint (`WalkSpeed`/`SprintSpeed` floats drive `MaxWalkSpeed`), jump, vault (`TryVault` trace + `LaunchCharacter`, gated in front of Jump).
  - ✅ Enhanced Input repaired + rebuilt (see LESSONS — the template's input assets were committed as 0 bytes): `IA_Move/Look/MouseLook/Jump/Crouch/Sprint`, `IMC_Default`/`IMC_MouseLook`.
  - 🔨 Pool volume (enter/exit + swim) via a level-placed `PhysicsVolume` (`bWaterVolume=true`) + translucent water surface, in `L_Sandbox_Movement`.
  - ⏭ Next: finish pool placement on flat ground, then Play-In-Editor verify every verb, commit.
- **Systems 2–5 (loudness, scoring, detection AI, costume) + sensor light** — ⛔ not started (do NOT build ahead of order).

**Known issues (deferred, not blocking):** several template assets are still 0-byte from the original commit corruption — Manny's material instances/textures/rigs, and the Touch UI widgets. Grey-box rendering is fine per doc 02; revisit before the planned Synty character swap. Engine drive was low on space during setup — watch for import failures.

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
