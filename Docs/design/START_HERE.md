# Pool Hop — START HERE (session handoff for the next agent)

*The living "read this first" doc. Supersedes the old `OVERNIGHT_PROGRESS.md`. Last updated 2026-07-01 (3 PM session, by Fable). Everything below is committed + pushed to `main`.*

> **Who this is for.** A cost-conscious model (likely Sonnet) picking up the build mostly autonomously. It assumes you are NOT the model that wrote the design package. Follow the rules here literally; they encode days of already-paid-for debugging. When in doubt, do the boring safe thing (commit, verify on disk, build to CANON).

---

## 0. Read order (don't skip — 15 min saves hours)

1. **This doc** — current state + prime directives + next actions.
2. **[`CANON.md`](CANON.md)** — the single source of truth for names/enums/numbers. The domain docs drifted; **CANON wins, always.** Its "Verified drift resolutions" section is load-bearing.
3. **[`08_Implementation_Roadmap.md`](08_Implementation_Roadmap.md)** — the ordered, DoD-per-step build plan. Your work queue is Steps 0–8.
4. **The skill [`unreal-mcp-session`](../../.claude/skills/unreal-mcp-session/SKILL.md)** — how to connect to the editor, discover/call MCP tools, verify work, and run/observe the game. Then its three domain skills as needed (`unreal-mcp-blueprints`, `unreal-mcp-scene-building`, `unreal-input-probe`).
5. **[`../LESSONS.md`](../LESSONS.md)** — the gotcha log. Skim the top 3 entries at minimum.
6. Then `git log --oneline -20` to see the true latest state.

## 1. The 5 prime directives (violating these is how the project breaks)

1. **BUILD FROM CANON, not the domain docs.** `04`/`07`/`02` contain old variable names and numbers that silently break bindings (they now carry ⚠️ banners). If CANON and a domain doc disagree, CANON wins.
2. **Verify against COLD ON-DISK state, never editor memory.** The "game ignored all input" bug (fixed this session) was an asset MCP saved with empty arrays — every in-editor test passed against dirty RAM. After asset work: `save_assets([])` → `find Content -name "*.uasset" -size 0` → `compile_blueprint(warnings_as_errors=true)`. For anything load-bearing, prove it in a **fresh process** (restart editor, or standalone launch — see directive 5).
3. **All authoritative state lives on GameMode/GameState/PlayerState — NEVER on the pawn.** Score, loudness, alert, heat, timer, costume. The pawn holds movement + cosmetics only. This is what makes co-op (Phase 2) a layer instead of a rewrite. Do not shortcut it. (Grep the character graph before finishing a step: no score/alert/timer vars on it.)
4. **Commit before AND after every chunk.** MCP can delete/corrupt VCS-tracked assets in one call. Small commits = cheap recovery. Never `--dangerously-skip-permissions` while the MCP plugin is loaded.
5. **You can now self-test gameplay input** (new this session — the old docs say you can't; they're outdated). PowerShell `SendInput` drives Enhanced Input end-to-end and GDI screenshots the game window. Use the [`unreal-input-probe`](../../.claude/skills/unreal-input-probe/SKILL.md) skill to verify movement/jump/interact yourself after any input/character change — but **warn the user first** (it moves their real mouse/keyboard ~10s).

## 2. Current state — what's DONE, what's the truth right now

**System 1 — Movement: ✅ BUILT + VERIFIED END-TO-END (this session).** Walk/crouch/sprint/jump/vault/swim on `BP_PlayerCharacter`. The long-running "can't move / frozen" saga is **fully resolved**: it was never perf or focus — it was (a) an invisible/static mesh, then (b) `AnimClass=None` (statue), then (c) the real one — **input mapping assets saved with empty Mappings arrays**. All fixed. WASD + mouse-look + jump confirmed working on a cold standalone launch with real injected input. Manny renders + animates. See CLAUDE.md "Current state" and LESSONS for the full trail.
- ✅ **The key-mapping follow-up is done (new session).** **Crouch (`C`→IA_Crouch)** and **Sprint (`LeftShift`→IA_Sprint)** are mapped in `IMC_Default` and verified on a genuinely cold standalone process via `GetAll InputMappingContext DefaultKeyMappings` (note the corrected property name — the real array is nested at `DefaultKeyMappings.Mappings`, NOT the always-empty legacy `Mappings`; see LESSONS).
- ⚠️ **Still open (non-blocking):** `BP_PlayerController`'s BeginPlay chain still doesn't fire from a cold load — `compile_blueprint` ran clean but `save_assets` produced zero file diff (nothing was dirtied), and the `"CTRL BeginPlay - IMC_Default APPLIED"` print is still absent from fresh standalone logs. Harmless (input works via the config-level `DefaultMappingContexts`), but worth a real diagnosis (`get_node_infos` on the EventGraph's `Event BeginPlay` chain) rather than another no-op recompile attempt.

**Step 1 — Authoritative framework state: ✅ BUILT.** 16 replicated vars across `BP_PlayerGameState` + `BP_PlayerState` (CANON names, correct repl modes). Enums are still **`byte` interim** (real enums need the human in-editor — see §4).

**Step 2 — LoudnessComponent: 🔨 CORE BUILT, not fully wired.** `BP_LoudnessComponent` attached as `LoudnessComp`, self-drives loudness from speed (sprint raises, idle decays). Still TODO: wire sprint/swim/vault actions → loudness properly, build `DT_LoudnessActions`, and `ReportNoise` (needs the AI to exist). Spec: `06 §2`.

**Step 3 — Pool scoring: 🔨 SCAFFOLDING BUILT, logic NOT wired.** `BP_PoolVolume` (+ `ScoringBox`) and `BP_PoolScoringComponent` (`PoolScoreComp`) compile clean, but the overlap→accrue→bank logic is not connected. Spec: `06 §3`.

**Steps 4–8 (AI Watcher, couple, costume, HUD, playtest): ⛔ NOT BUILT.** Specs are build-ready (`04`, `06`, `07`).

**Infra:** Ray tracing OFF (never re-enable — SBT deadlock). Editor is currently up with MCP on port 8000. Input applied via engine-level `DefaultMappingContexts` in `Config/DefaultInput.ini` (not the controller BP).

## 3. Your next actions, in order

1. **Confirm you have MCP.** `ToolSearch "select:mcp__unreal-mcp__call_tool"`. If it returns nothing, the editor was down at your startup — see the `unreal-mcp-session` skill §1 (restart the editor with the server, then restart Claude). Port 8000 must be listening.
2. **Hand the human the in-editor checklist (§4).** The 2 enums + 1 struct block Step 1's finalization and Step 6. They take the human ~5 min; you cannot do them. Do this first so they're unblocked while you work.
3. ✅ **System 1 input done** (new session): Crouch/Sprint mapped + verified on cold disk.
4. ✅ **Step 3 scoring logic done** (new session): `BP_PoolVolume`/`BP_PoolScoringComponent`/GameMode rules/`BP_StashZone` all wired and **verified live in PIE** (score climbs in the pool, banks correctly at the stash). See CLAUDE.md "Current state" and CANON's "Step 3 variable additions." A real Blueprint bug (pure-node re-evaluation across a reset) was caught and fixed only because of the live PIE check — see LESSONS and the `unreal-mcp-blueprints` skill's new gotcha entry; keep doing live PIE reads for anything with read→reset→reread shape, not just a clean compile. Remaining: pools B/C/D (needs Step 5 dressing), `PoolID` can't be set on a placed instance via MCP (low-priority, single-pool testing unaffected).
5. ✅ **Step 2 finish done** (new session): sprint/vault/swim wired to `LoudnessComponent`, verified live (swim path). `DT_LoudnessActions` confirmed not MCP-buildable — substituted a lookup function (CANON's "Step 2 substitution").
6. 🔨 **Step 4 AI Watcher — perception done + verified, movement blocked (new session).** `BT_Watcher`/`BB_Watcher` confirmed not MCP-buildable (no surprise, but now directly confirmed rather than assumed) — built a Blueprint-state-machine substitute instead (CANON's "Step 4 substitution", full detail). Detection/alert-state is **fully verified live in PIE** and matches spec exactly. **Movement (patrol/chase) does not work** — `MoveToLocation`/`MoveToActor` return `Failed` every tick despite a present, correctly-sized NavMesh; 4 fix attempts didn't resolve it. **5th lead found + fixed, but UNTESTED: Project Settings → Navigation Mesh → Supported Agents was a completely empty array** in `Config/DefaultEngine.ini` — added a matching `Default` agent entry via `ConfigSettingsToolset`, confirmed it persisted to disk, but it did **not** take effect live via `StartPIE` without a restart (this setting is very likely process-lifetime-cached, same as this project's `r.RayTracing` cvar). **RESTARTING THE EDITOR IS THE NEXT STEP FOR YOU (a human):** restart Unreal (command in `CLAUDE.md`'s "Restart the editor + MCP" section), let a fresh Claude session reconnect MCP, then `StartPIE` and check whether the Watcher now paths — if yes, this whole issue is solved; if no, fall back to the visual NavMesh check (`P` key) and Supported-Agents-vs-RecastNavMesh mismatch check described below. See LESSONS' "UNRESOLVED" entry (5th sub-entry) for the full diagnostic trail and what NOT to re-try. Once movement works: still need EQS search (spec allows deferring it) and the cosmetic pawn `AlertState` mirror (trivial, just needs the class's cross-object accessors to be indexed — try again after a fresh save).
7. Then finish Step 4's catch/detain, roadmap Steps 5 (couple) → 6 (costume) → 7 (HUD, human authors UMG) → 8 (the playtest that decides if it's fun).

## 4. The "only the human can do this in-editor" pile (confirmed, don't waste tokens trying to MCP these)

Spiked + confirmed in LESSONS/CANON. MCP **cannot** author these, and computer-use can't reach the editor window. Hand the user a precise checklist:
1. **Create 2 Blueprint Enums + 1 Struct** in `Content/_Project/Data/` (right-click → Blueprints → Enumeration / Structure): `E_AlertState {Unaware, Suspicious, Alert, Critical}`, `E_PoolTier {Standard, HotTub, Infinity, Money}`, `S_LoudnessAction {InstantBump:float, bSustained:bool, SustainedBand:float, Description:string}`. Then ping you to retype the interim `byte` vars (`AlertLevel`, `PoolTier`) to the real enums.
2. **Mark `Server_*` events "Run on Server, Reliable"** (a node-details toggle) — only needed at Phase 2 netcode; in single-player the `HasAuthority`-guarded functions behave identically, so don't block on it.
3. **Author `BT_Watcher` + `BB_Watcher`** (Step 4) — you build everything around it; the human clicks the tree together from `04 §12`. (A Blueprint-state-machine substitute already drives patrol/chase/detect in the meantime — see CANON's "Step 4 substitution.")
4. **Author the UMG HUD widgets** (Step 7) — you wire the bindings; the human builds the widget tree.
5. **NEW — diagnose why the Watcher can't path (Step 4 blocker).** Open `L_Sandbox_Movement` in PIE, press the NavMesh show-flag (`P` in viewport, or the "Show > Navigation" menu), and look at whether the green mesh actually covers the Watcher (~100,1200) and patrol points. Also check Project Settings → Navigation Mesh → Supported Agents against the `RecastNavMesh` actor's `AgentRadius=42`/`AgentHeight=192`. Full diagnostic trail (4 exhausted hypotheses, what's untried) in LESSONS' "UNRESOLVED" entry — this is a 10-second visual check for you, versus many blind property round-trips for MCP.

## 5. If you get stuck

- **Feel/design judgment** (is the close-call fun? is the cone right?) → that's the human's call; present numbers, don't invent design.
- **A hard problem the cheap model can't crack** → the user will re-engage Fable/the bigger model. Leave a clean, specific description of exactly where you're stuck (what you tried, the evidence), not a vague "it doesn't work." Update LESSONS with anything non-obvious you learn.
- **Never** re-run a failing action hoping it works (LESSONS "debugging discipline"): read the evidence, name the mechanism, one change → one test.

---

*The plan is strong and the vision is fixed (`00_Design_Bible.md`). Your job is execution discipline: CANON names, disk verification, small commits, server authority. Build Steps 0–8 in order; the whole MVP exists to answer one question — is the loop tense and repeatable (`Docs/02 §4`)? Everything past Step 8 is earned by proving that first.*
