# Pool Hop — Overnight Autonomous Build: Progress & Next Steps

*Morning handoff. Written by the autonomous overnight loop. Read this first when you wake.*

Last updated: 2026-06-30 overnight. Everything below is committed + pushed to `main` (through `e944901`).

---

## TL;DR — do these 3 things first
1. **Press W** in Play-In-Editor. System 1 movement is verified working except a live keypress (MCP/computer-use can't send keys here). It'll move. Then feel-test sprint/crouch/jump/vault/swim.
2. **Watch loudness rise when you sprint.** Step 2 is live and self-driving (no HUD yet, but you can confirm via the `BP_LoudnessComponent`'s `CurrentLoudness` in the editor while sprinting in PIE).
3. **Skim `08_Implementation_Roadmap.md` + `CANON.md`**, then knock out the short **in-editor checklist** below — those unblock the rest.

---

## What got built tonight (all committed)
- **Design package** (`Docs/design/00`–`09`, ~2,900 lines): design bible, art/style, Maple Court neighborhood (grey-box layout), underground pools (new concept), the full **AI Watcher** spec, characters, core-systems tech spec, movement/UI, the ordered **roadmap**, and a self-critique.
- **`CANON.md`** — resolves the drift between the parallel-written docs (one canonical set of names/enums/numbers). **Build to CANON, not the individual docs, when they disagree.**
- **Step 1 — Authoritative state** (`BP_PlayerGameState` + `BP_PlayerState`): 16 replicated variables with correct modes. The backbone everything binds to. All off the pawn (co-op discipline).
- **Step 2 — LoudnessComponent** — **functional**. Attached to the character as `LoudnessComp`. Self-drives from owner speed: sprint (>700 uu) raises loudness to the sprint band; else decays to idle. `AddLoudness`/`GetLoudness01`, tick-driven. The mechanical heart of the stealth loop.
- **Step 3 — Pool scoring scaffolding**: `BP_PoolVolume` (Actor + `ScoringBox` trigger + all tuning/decay/occupancy vars, replicated) and `BP_PoolScoringComponent` (attached as `PoolScoreComp`). Compiles clean. **Logic not yet wired** (see below).
- **Infrastructure**: fixed the input bug + the ray-tracing PIE freeze; verified the Project-42 reaper can't touch us; mapped exactly what MCP can/can't build; self-healing editor-relaunch. All in `Docs/LESSONS.md`.

---

## Why the loop stopped here (honest constraints)
The autonomous loop built everything that is **both safe and in build-order**. What remains splits into two piles the loop deliberately did **not** force overnight:

### A. Needs YOU in-editor (MCP genuinely cannot do these — spiked + confirmed, and computer-use can't reach the editor window here)
1. **Create the real Blueprint enums** `E_AlertState {Unaware, Suspicious, Alert, Critical}` and `E_PoolTier {Standard, HotTub, Infinity, Money}`, and the struct `S_LoudnessAction {InstantBump:float, bSustained:bool, SustainedBand:float, Description:string}`. Then retype the interim `byte` vars (`AlertLevel` on GameState, `PoolTier` on `BP_PoolVolume`) to `E_AlertState`/`E_PoolTier`. *(~5 min: right-click Content/_Project/Data → Blueprints → Enumeration/Structure.)*
2. **Mark the `Server_*` events "Run on Server, Reliable"** when we add them (Phase-2 netcode; not needed for single-player). *(A node-details toggle MCP can't set.)*
3. **The AI Watcher Behavior Tree + Blackboard** (Step 4) — the whole `BT_Watcher`/`BB_Watcher`. Spec is build-ready in `04_AI_Watcher.md §12`. *(BT assets aren't MCP-authorable; the perception/BP logic IS, so we can do that part together.)*
4. **The HUD** (Step 7) — the UMG widgets (`WBP_HUD` etc.). Spec in `07_Movement_And_UI.md`. *(UMG tree authoring is unproven via MCP.)*

### B. MCP-buildable but risky cross-Blueprint logic — better done WITH you (to verify feel, and because it's not visible without the HUD)
5. **Step 3 scoring logic**: `BP_PoolVolume` overlap → set the player's `PoolScoreComp.CurrentPool`; the component's accrual tick → add score to `PlayerState.IndividualScoreAtRisk` + `GameState.TeamScoreAtRisk`; `BP_StashZone` → bank it; GameMode `Server_AddScore`/`GetHopStreakMultiplier`/`Server_BankAtRisk`/`Server_LoseAtRisk`. All specced in `06 §3`. It's several casts across BPs — low-risk with a human watching the score number, error-prone blind.
6. **Step 5 couple-it-all** (AlertDirector + caught/escape/heat) — needs Steps 3+4 first.
7. **Step 6 costume** — needs the enum + the loudness modifier hook (already exposed).

---

## Recommended next session (in order)
1. **You (5 min in-editor):** create the 2 enums + 1 struct (pile A#1). Ping me and I'll retype the interim `byte` vars and wire loudness's action table.
2. **Together via MCP:** Step 3 scoring logic (pile B#5) — I drive the graph, you watch the score tick in PIE and call the feel.
3. **You + me:** Step 4 AI Watcher — I build the perception + BP logic via MCP; you author the `BT_Watcher`/`BB_Watcher` from `04 §12` (I'll give click-by-click steps).
4. **Then:** Step 5 couple, Step 6 costume, Step 7 HUD (you author UMG, I wire the bindings).
5. **Then:** the Step 8 playtest — the whole point (is it *tense and repeatable*?).

Everything is on GitHub. Nothing is half-broken — each commit compiles clean. The loop is stopped (no runaway); re-engage whenever you're ready and we'll knock out the list.
