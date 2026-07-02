# Pool Hop — Implementation Roadmap

*Version 0.1 — the dependency-aware, ordered build plan. Last updated 2026-06-30. Engine: Unreal Engine 5.8, Blueprints-first (C++ only where flagged).*

> **What this doc is.** The concrete, ordered, MCP-driven build plan that turns the design package (`00_Design_Bible.md` + domain docs `01`–`07` + source `Docs/00`–`07`) into editor work. It respects the locked build order (`Docs/02` §5) and the server-authority discipline (`Docs/03` §2). Each **step** lists: prerequisites, the governing design doc(s), concrete `unreal-mcp` actions, and a **Definition of Done (DoD)**. The MVP phase (Steps 0–8) is the work queue; Phases 9–12 are specified-but-parked forward work in dependency order.
>
> **How to drive it.** New agent: start from [`START_HERE.md`](START_HERE.md) then [`CANON.md`](CANON.md) — **build to CANON names/numbers, not the domain docs** (they drifted; `04`/`07`/`02` carry ⚠️ banners). Do one step at a time, in order. Commit before starting each step and after finishing it (Epic MCP safety rule, `CLAUDE.md`). After any asset batch: `save_assets([])` → `find Content -name "*.uasset" -size 0` → compile every touched Blueprint with `compile_blueprint(warnings_as_errors=true)` — and for anything load-bearing, verify in a **cold process** (restart editor / standalone launch), because in-editor saves can serialize empty (`Docs/LESSONS.md`: silent 0-byte + empty-array saves, and a non-compiling BP freezes PIE on a modal MCP can't dismiss). Read the [`unreal-mcp-session`](../../.claude/skills/unreal-mcp-session/SKILL.md) skill first, then `unreal-mcp-blueprints` / `unreal-mcp-scene-building` / `unreal-input-probe`; call `get_graph_dsl_docs` before your first `write_graph_dsl`.

---

## 0. Global prerequisites & standing rules

- **Server authority** (`Docs/03` §2): all authoritative state on GameMode/GameState/PlayerState; pawn = movement + cosmetic only. Client → request → server validates → OnRep back.
- **Replication-mode legend** (`design/06` §0): `None` = server-only/local cosmetic; `Replicated` = read-only mirror on clients; `RepNotify` = replicate + fire `OnRep_` (auto-creates the graph). **Add variable → `compile_blueprint` → then set CDO default** (order matters — LESSONS).
- **Ray tracing OFF** (`r.RayTracing=False`): no HWRT anywhere. **Never** re-enable it (re-triggers the SBT deadlock — LESSONS).
- **Naming/folders**: `Content/_Project/{Core,Characters,Components,AI,Systems,Gameplay,UI,Data,Maps}`; `BP_`/`M_`/`MI_`/`IA_`/`IMC_`/`L_`/`SB_`/`DA_`/`DT_`/`E_`/`S_`/`BB_`/`BT_`/`WBP_`/`NS_`.
- **Enums/structs before the variables that reference them; components after the state they read.**

### Build-order dependency graph (MVP)

```
Step 0  Finish/verify System 1 (movement)          ── DONE-ish, verify + commit
   │
Step 1  Data foundation (enums/structs) + framework state on GameState/PlayerState/GameMode
   │        (E_AlertState, E_PoolTier, S_LoudnessAction; score/heat/timer/detained/costume vars + stubs)
   │
   ├─────────────► Step 7  Movement polish + HUD  (binds to Step-1 stubs — can start early, in parallel)
   │
Step 2  LoudnessComponent  ────────────────────────────────┐  (needs Step 1 state)
   │                                                        │
Step 3  PoolScoring + PoolVolume + banking  ───────────────┤  (needs Step 1 score rules on GameMode)
   │                                                        │
Step 4  AI Watcher: perception + BT + states  ◄── reads loudness from Step 2 (sight-only testable earlier)
   │                                                        │
Step 5  Couple it all: AlertDirector + sensor light + caught/escape/heat  ◄── needs Steps 2+3+4
   │
Step 6  One costume/item swap (System 5)  ◄── needs Step 2 (loudness modifier hook)
   │
Step 8  Tune & playtest against Docs/02 §4  ◄── needs all of 1–7
```

**Do not build Steps 4/5/6 ahead of 2/3.** The order exists to prove the loop cheaply.

---

## PHASE 1 — SYSTEMS SANDBOX (MVP). Steps 0–8.

Target: the five systems on the grey box, all state server-authoritative, judged only on *tense and repeatable* (`Docs/02` §4).

---

### Step 0 — Finish & verify System 1 (movement)

- **Prerequisites:** none (mostly built — `CLAUDE.md` "Current state": walk/crouch/sprint/jump/vault/swim on `BP_PlayerCharacter`; Enhanced Input rebuilt; pool `PhysicsVolume` + water surface in `L_Sandbox_Movement`).
- **Governing docs:** `Docs/02` §1 System 1; `design/07` §1; `Docs/LESSONS.md`.
- **MCP actions:**
  1. Finish pool placement on confirmed-flat ground: `SceneTools.trace_world` (start high, end < 0) at each intended pool XY before dropping the `PhysicsVolume` (LESSONS: template floor has a raised mound; `ground_z = start_z − distance`).
  2. `compile_blueprint(warnings_as_errors=true)` on `BP_PlayerCharacter` and every Core BP — a leftover non-compiling template BP freezes PIE (LESSONS).
  3. `save_assets([])` → `find Content -name "*.uasset" -size 0` (catch the 0-byte corruption class).
  4. `StartPIE`; confirm every verb; if wedged, tail `Saved/Logs/*.log` by file read (not MCP) to diagnose.
- **Definition of Done:** PIE loads clean (no compile modal), pawn spawns on flat ground, all verbs work (walk/crouch/sprint/jump/vault/enter+exit pool/swim), no 0-byte assets, committed. **Input is now self-verifiable** via the [`unreal-input-probe`](../../.claude/skills/unreal-input-probe/SKILL.md) skill (real OS keystrokes on a standalone launch) — verify WASD/jump/mouse-look yourself; still get the human for final *feel* (is the movement satisfying). **Status 2026-07-01: movement VERIFIED end-to-end; only Crouch(`C`)/Sprint(`LeftShift`) IMC mappings remain (see START_HERE §2).**

---

### Step 1 — Data foundation + framework state (the authoritative backbone)

- **Prerequisites:** Step 0.
- **Governing docs:** `design/06` §6 (variable tables + repl modes) & §6.4 (enums/structs); `design/07` §3.1 (HUD stub vars); `Docs/03` §2.
- **Why first:** every component references these enums/state; building them now lets the HUD (Step 7) bind immediately against stubs.
- **MCP actions:**
  1. **Enums/structs** in `_Project/Data/`: `E_AlertState {Unaware, Suspicious, Alert, Critical}`, `E_PoolTier {Standard, HotTub, Infinity, Money}`, `S_LoudnessAction` (`InstantBump:float, bSustained:bool, SustainedBand:float, Description:string`).
  2. **`BP_PlayerGameState`** — add (per `design/06` §6.1 + `design/07` stubs): `TeamScoreBanked:int (Replicated)`, `TeamScoreAtRisk:int (RepNotify)`, `NeighborhoodHeat:float (RepNotify)`, `AlertLevel:E_AlertState (RepNotify)`, `NightTimeRemaining:float (Replicated, def 600)`, `bNightOver:bool (RepNotify)`. Add server setter function graphs (`SetNeighborhoodHeat`, `AddTeamScoreAtRisk`, `BankTeamScore`, `LoseTeamAtRisk`, `TickNight`), each `HasAuthority`-guarded.
  3. **`BP_PlayerState`** — add: `IndividualScoreAtRisk:int (RepNotify)`, `IndividualScoreBanked:int (Replicated)`, `DistinctPoolsHopped:int (Replicated)`, `CurrentLoudness:float (Replicated)` mirror, `bDetained:bool (RepNotify)`, `EquippedCostume:PrimaryDataAsset ref (RepNotify)`. Plus `design/07` §2.4 breath state: `Air:float (Replicated, def 100)`, `bIsSubmerged:bool (Replicated)`, `bBreathCritical:bool (Replicated)`, `bIsHidden:bool (Replicated)`, `DetectionAlpha:float (Replicated)`.
  4. **`BP_PlayerGameMode`** — verify CDO class refs (`gameStateClass=BP_PlayerGameState`, `playerStateClass=BP_PlayerState`, `defaultPawnClass=BP_PlayerCharacter`, `playerControllerClass=BP_PlayerController`) via `get_default_object` → `set_properties`. Stub the scoring/night/escape function graphs (bodies filled in Steps 3/5).
  5. **Order per variable:** `add_variable` → `set_variable_replication` → `compile_blueprint` → then `set_properties` for the CDO default (LESSONS: default-before-compile silently fails).
- **Definition of Done:** all three framework BPs compile clean with the tabled variables + correct replication modes; enums/struct exist and save non-zero on disk; GameMode CDO points at the right classes; committed.

---

### Step 2 — LoudnessComponent (System 2)

- **Prerequisites:** Step 1 (reads/mirrors to PlayerState).
- **Governing docs:** `design/06` §2 (full spec + MCP calls); `Docs/02` §1 System 2; noise→hearing contract §2.5.
- **MCP actions:**
  1. `BlueprintTools.create /Game/_Project/Components BP_LoudnessComponent` (parent `ActorComponent`).
  2. Variables per `design/06` §2.2: `CurrentLoudness:float (RepNotify)`; `DecayRatePerSecond=22`, `IdleFloor=5`, `MaxLoudness=100`, `NoiseReportInterval=0.25`, `NoiseReportThreshold=10`, `HearingRangeAtMaxLoudness=2500`, `LoudnessModifier=1.0` (all `None`); `bIsSprinting`/`bIsInWater:bool (None)`; `ActionLoudnessTable` (DataTable ref).
  3. Events/functions: `Server_ReportAction` (Run-on-Server, Reliable), `Server_SetSustainedSource` (RoS, Reliable), `AddLoudness`, `ReportNoise` (calls `ReportNoiseEvent` with `Loudness=CurrentLoudness/100`, `MaxRange=HearingRangeAtMaxLoudness`), `GetLoudness01`. Tick = decay + throttled report (asymmetric rise ≈ 2× decay). Guard tick with `HasAuthority`.
  4. **DataTable** `DT_LoudnessActions` (row struct `S_LoudnessAction`) with rows from §2.6: `Action.Sprint` (sustained band 55), `SplashEnter` (bump 45), `SwimMove` (band 45), `Vault` (bump 30), `SensorTrip` (bump 40), `FenceClimb` (25), `CrouchMove` (silent).
  5. **Expose the costume hook** now (forward dep from `05`/`06`): `LoudnessModifier` is the single choke-point; `AddLoudness` always multiplies by it. (`design/05` §4.3 asks for `SetFootstepMultiplier`/`SetInWaterMultiplier`; implement as thin setters on `LoudnessModifier` or per-source mults.)
  6. Attach to `BP_PlayerCharacter` as `LoudnessComp`; wire Sprint input Started/Completed → `Server_SetSustainedSource("Sprint", …)`; `TryVault` success → `Server_ReportAction("Action.Vault")`; `MOVE_Swimming` enter/exit → `Server_SetSustainedSource("Water", …)`.
  7. DSL note (LESSONS): member vars need explicit getters `(Variables|Default|GetCurrentLoudness)`; keyword pins on `ReportNoiseEvent`; compile before CDO defaults.
- **Definition of Done:** sprinting/vaulting/splashing raise `CurrentLoudness` on the server; it decays to `IdleFloor`; `ReportNoise` fires (verify via `showdebug AISENSES`/perception visualizer once an AI exists, or a debug print now); value mirrors to `PlayerState.CurrentLoudness`; compiles clean; committed.

---

### Step 3 — PoolScoring + PoolVolume + banking (System 3)

- **Prerequisites:** Steps 1 (score state + GameMode rules) & 2 (fires `Action.SplashEnter`).
- **Governing docs:** `design/06` §3 (full spec + MCP calls); `Docs/02` §1 System 3; scoring rules on GameMode §3.3.
- **MCP actions:**
  1. **`BP_PoolVolume`** (parent `Actor`, NOT PhysicsVolume — LESSONS) at `_Project/Gameplay/`. Root `BoxCollision` (`ScoringBox`, overlap-only). Variables (§3.1, all `None`): `PoolID:Name`, `BaseScorePerSecond=10`, `PoolTier:E_PoolTier`, `DecayHalfLife=8`, `DecayFloor=0.25`, `DecayRecoverPerSecond=0.15`, `CurrentDecayMult=1.0`, `OccupantPawns:Array<Pawn>`, `MaxScorePerVisit=400`. Overlap events (server-guarded) add/remove occupants + call the player's `PoolScoringComponent`. `GetEffectiveScorePerSecond` = base × decay × crew-mult; `TickDecay` (decay while occupied, recover while empty).
  2. **`BP_PoolScoringComponent`** (parent `ActorComponent`) at `_Project/Components/`. `CurrentPool:BP_PoolVolume ref (None)`, `AccrualAccumulator:float (None)`, `bIsScoring:bool (RepNotify)`. `Server_EnterPool`/`Server_ExitPool` (RoS, Reliable); server tick accrues `perSec × hopStreakMult × dt` and calls `GameMode.Server_AddScore`. Attach to `BP_PlayerCharacter` as `PoolScoreComp`.
  3. **Scoring rules on `BP_PlayerGameMode`** (§3.3): `Server_AddScore(PS, amount)` (→ PlayerState at-risk + GameState team at-risk), `GetHopStreakMultiplier(PS)` (`1 + clamp(distinct−1,0,6)×0.15`), `Server_BankAtRisk(PS)`, `Server_LoseAtRisk(PS)`.
  4. **Stash/bank zone** `BP_StashZone` (Box trigger) at `_Project/Gameplay/`: overlap → `GameMode.Server_OnReachStash → Server_BankAtRisk`. Place in `L_Sandbox_Movement`.
  5. Per-pool build (§3.6): co-locate a swim `PhysicsVolume` (`bWaterVolume=true, priority=1`) + a `BP_PoolVolume` box + the translucent `M_WaterPlaceholder` surface. Sandbox needs 4 pools: A (open, base 10), B (fenced+sensor), C (hidden), D (money, base 18).
- **Definition of Done:** entering a pool ticks at-risk score on the server (per-pool rate, decay after ~8s, hop-streak multiplier across distinct pools); reaching the stash banks at-risk → banked and resets streak; HUD (Step 7) shows both; compiles clean; committed.
- **✅ DONE (new session)** — everything above except the HUD readout (that's Step 7, separate). Verified live in PIE, not just compiled: at-risk climbs on both PlayerState and GameState while occupying `Pool_A`, banking at the stash zeroes at-risk and credits banked correctly on both. Only 1 of 4 pools placed so far (B/C/D need Step 5's fence/sensor-light dressing first). See CLAUDE.md + CANON for the exact vars/functions built and a real bug (pure-node re-evaluation) caught by the live test.

---

### Step 4 — AI Watcher: perception + BT + alert states (System 4, the priority deliverable)

- **Prerequisites:** Step 2 for hearing (sight-only path is testable earlier — `design/04` §0); Step 1 state.
- **Governing docs:** `design/04` (the canonical, full spec — §12 is the ordered MCP sequence); `Docs/03` §4; `Docs/07` §4 (readability).
- **C++ note:** none required. Use **Detect Neutrals + Tags** (`design/04` §3) instead of C++ affiliation teams — set Detect Neutrals=true on both senses, filter by `Actor.ActorHasTag("Player")` in `OnTargetPerceptionUpdated`, add tag `Player` to `BP_PlayerCharacter`.
- **MCP actions (follow `design/04` §12 verbatim):**
  1. `E_AlertState` (done Step 1) + `AIP_WatcherProfile` PrimaryDataAsset with §8 defaults (SightRadius 1400, LoseSight 1800, PeripheralHalfAngle **35°**, HearingRange 1200, DetectionFillSeconds 1.5, DetectionDecaySeconds 3.0, Patrol 180 / Investigate 300 / Chase 650, CatchRadius 120, etc.). **These become the canonical AI-perception profile for all future threats.**
  2. `BB_Watcher` (keys §6: `AlertState, TargetActor, CanSeePlayer, HeardNoise, NoiseStrength, LastKnownLocation, SearchLocation, DetectionMeter, HomeLocation, PatrolIndex`).
  3. `BP_WatcherController` (parent `AIController`) + `AIPerceptionComponent` (Sight+Hearing configs from §5, read from the profile on BeginPlay). Wire `OnTargetPerceptionUpdated` (§5.3, `HasAuthority` + tag filter).
  4. `BP_WatcherCharacter` (parent `Character`, placeholder Quinn + dark material) — `AIControllerClass=BP_WatcherController`, `AutoPossessAI=PlacedInWorldOrSpawned`; `WidgetComponent` for the overhead icon; replicated `AlertState` for visuals.
  5. Player as target: tag `Player` + `AIPerceptionStimuliSource` (Sight+Hearing) on `BP_PlayerCharacter`.
  6. BT tasks/service (`write_graph_dsl`): `BTS_UpdateDetection` (fill 1.5s / decay 3.0s, mirrors meter+state to `PlayerState.DetectionMeter`/`DetectionAlpha`+`SeenByAlertState`), `BTT_SetStateAndSpeed`, `BTT_FindNextPatrolPoint`, `BTT_RunEQSSearch`, `BTT_CatchPlayer`; optional `EQS_WatcherSearch` + `EQC_ObserverIsSelf`.
  7. `BT_Watcher`: root service + priority Selector (Alert→Suspicious→Unaware) with `AlertState ==` decorators, **Observer Aborts = Both** on Alert/Suspicious, MoveTo/Wait/EQS per §7.
  8. Place 4–6 `BP_PatrolPoint` in `L_Sandbox_Movement` threading between pools (`trace_world` each XY first).
  9. `compile_blueprint(warnings_as_errors=true)` on every new BP.
- **Definition of Done:** the Watcher patrols; a player in the cone fills the detection bar over ~1.5s; `?`(Suspicious)→`!`(Alert) icons show; louder player is heard from farther (loudness→hearing); on Alert the Watcher chases; a clean sightline-break + going quiet reliably escapes; detection resolves **server-side** (clients read replicated state); compiles clean; committed. Human verifies the *close-call feel* (§13).

---

### Step 5 — Couple it all: AlertDirector + sensor light + caught/escape/heat

- **Prerequisites:** Steps 2, 3, 4 (needs loudness to sum, scoring to penalize, detection to feed heat).
- **Governing docs:** `design/06` §5 (AlertDirector) & §6.2 (escape/detain rules); `design/04` §9 (detain flow) & §10 (sensor light).
- **MCP actions:**
  1. **`BP_AlertDirectorComponent`** (parent `ActorComponent`) at `_Project/Systems/`, added to `BP_PlayerGameMode`. Variables (§5.1, all `None`): `AccumulatedHeat`, `HeatDecayPerSecond=3`, `LoudnessHeatWeight=0.15`, `DetectionHeatBump=25`, `SuspicionHeatBump=8`, thresholds `SuspiciousThreshold=30`/`AlertThreshold=65`/`CopSpawnThreshold=90`, `bCopDispatched`. `TickHeat(dt)` sums players' loudness → heat, decays, writes `GameState.NeighborhoodHeat`+`AlertLevel`. `NotifyDetection(E_AlertState)` (called by the Watcher on state change — the detection→heat contract), `NotifySensorTrip(loc)`, `GetHeat01`.
  2. **Wire the Watcher → AlertDirector:** in `BTS_UpdateDetection`, on a state change call `GameMode.AlertDirector.NotifyDetection(newState)` (plain server-side call, no RPC).
  3. **Caught → detain** (`design/04` §9): Watcher Alert-branch overlap/reach with a `Player`-tagged actor while `AlertState==Alert` and `HasAuthority` → `GameMode.HandleDetain(PS)`: set `bDetained`, `Server_LoseAtRisk`, reset the AI's meter/state, delay `DetainRespawnDelay=2.0s`, teleport to stash, clear `bDetained`. Banked untouched.
  4. **Escape** already wired (Step 3 stash → `Server_BankAtRisk`); confirm at-risk→banked on reach and lost on catch.
  5. **`BP_SensorLight`** (`_Project/Gameplay/`, Box trigger + SpotLight off by default) per `design/04` §10: on player overlap (server) → light ON, fire a hearing noise (~0.7) + set nearest Watcher `HeardNoise`+`LastKnownLocation`, feed `NotifySensorTrip`; off after ~4s. Place one near Pool B.
- **Definition of Done:** neighborhood heat rises with loudness + detection and decays; `AlertLevel` crosses Suspicious/Alert thresholds and drives the shared badge (Step 7); tripping the sensor light routes the Watcher to Suspicious; getting caught while Alert loses at-risk points (banked safe) and respawns at the stash after 2s; reaching the stash banks; compiles clean; committed.

---

### Step 6 — One costume/item swap (System 5)

- **Prerequisites:** Step 2 (loudness modifier hook). Build **after** detection is coupled (`Docs/02` §5 order).
- **Governing docs:** `design/05` §7 (MVP slice) & §4 (costume spine); `design/06` §4.
- **MCP actions:**
  1. `DA_Costume` PrimaryDataAsset base (`_Project/Data/`) with fields `CostumeID:Name`, `DisplayName`, `MeshOverride`/`AttachMesh`/`AttachSocket`, `LoudnessModifierMult:float`, `SwimSpeedMult:float`, `bIsDefault`. Verify size on disk after `DataAssetTools.create` (LESSONS).
  2. One instance `DA_QuietShoes` (`LoudnessModifierMult=0.8`) + `DA_SwimTrunks` (`bIsDefault=true`).
  3. `BP_CostumeComponent` (parent `ActorComponent`): `Server_EquipCostume` (RoS, Reliable — validate then set `PlayerState.EquippedCostume`, apply server stat mods: `LoudnessComp.LoudnessModifier = DA.LoudnessModifierMult`), `ApplyCostumeVisual` (client+server via `OnRep_EquippedCostume` — swap mesh/attach cosmetic only), `GetEquippedCostume`. Attach to `BP_PlayerCharacter` as `CostumeComp`; on BeginPlay (server) default to `DA_SwimTrunks`.
  4. `BP_ItemPickup_QuietShoes` (`_Project/Gameplay/`): overlap → `CostumeComp.Server_EquipCostume(DA_QuietShoes)`.
- **Definition of Done:** picking up Quiet Shoes swaps a visible mesh/tint (client, via OnRep) AND measurably drops footstep loudness ~20% (server-set) → the Watcher hears you from a shorter radius; value is set server-side (authority-correct); compiles clean; committed.

---

### Step 7 — Movement polish + HUD (parallel-safe from Step 1)

- **Prerequisites:** Step 1 (binds to stub replicated vars). Can proceed alongside Steps 2–6.
- **Governing docs:** `design/07` (full spec — §4 internal order); `design/01` §2.4 (readability layer colors from `DA_ArtPalette`).
- **MCP actions:**
  1. **Art readability foundation (do first, cheap):** `DA_ArtPalette` (PrimaryDataAsset with the `design/01` §2.1 LinearColor tokens), `M_GreyboxToon` + 4 MIs, the night PP volume + moon DirectionalLight + SkyLight rig (`design/01` §2.2–2.3). Widgets pull green/amber/red **only** from `DA_ArtPalette`.
  2. **HUD stubs already exist** (Step 1). `WBP_HUD` (parent `UserWidget`) + sub-widgets (`WBP_LoudnessMeter`, `WBP_AirMeter`, `WBP_ScoreReadout`, `WBP_Wristwatch`, `WBP_AlertIcon`, `WBP_DetectionEdge`) bound to replicated sources per `design/07` §3.9. Controller creates + adds on BeginPlay. Verify each animates by poking stubs with a debug key.
  3. **`AC_BreathComponent`** on PlayerState (air drain/refill with grace, non-punitive at 0) + wire water enter/exit + `IA_Dive` (`design/07` §2.4).
  4. New input actions `IA_Interact`/`IA_Dive`/`IA_SwimUpDown` + IMC entries (gate Jump/Crouch vs swim by `MOVE_Swimming` — LESSONS on input ambiguity).
  5. `BP_BushHide` + `Server_SetHidden`/`bIsHidden` + hide pip; `BP_HedgeSqueeze` (speed lock + wobble); `DA_MovementTuning` (move all §2.6 numbers out of graphs).
  6. Close-call feedback: `M_Vignette` UI material (translucent-unlit per LESSONS) + heartbeat, driven by `PlayerState.DetectionAlpha` (Step 4 writes it; stub ramps until then).
- **Definition of Done:** every HUD element renders + animates against its replicated source (loudness meter 3-color, at-risk/banked score, `?`/`!` alert badge, wristwatch sweeping toward dawn, air meter collapsed when dry); new verbs work without fighting each other (speed resolution §2.5); the oh-no→relief vignette+heartbeat arc reads on a `DetectionAlpha` ramp; **no authoritative var lives on the character** (grep the graph — air/hidden on PlayerState, score/alert/timer on GameState); compiles clean; committed per sub-step.

---

### Step 8 — Tune & playtest (the judge)

- **Prerequisites:** Steps 0–7.
- **Governing docs:** `Docs/02` §4 (success criteria); `design/04` §13 + `design/06` §9 (tuning knobs).
- **Actions:** Human Play-In-Editor (MCP can't inject input). Tune **numbers only** in the Data Assets — primary knobs in order of impact: `DetectionFillSeconds`(1.5)/`DetectionDecaySeconds`(3.0) → cone size (`PeripheralVisionHalfAngleDeg` 35 / `SightRadius` 1400) → `HearingRange` + loudness→strength → `ChaseSpeed`(650) vs `SprintSpeed`(600) → patrol route timing → pool `DecayHalfLife` vs `HopStreak StreakStep`. Get 2–3 friends to play solo, separately.
- **Definition of Done:** a fresh playtester experiences all 5 `Docs/02` §4 criteria in a 5-min session; **criteria 3 (close call) and 5 (one-more-run) land**. If yes → concept validated, proceed to Phase 2 (netcode) / Phase 4 (Maple Court). If no → keep tuning numbers, do **not** add features (`Docs/02` §4 anti-goal). Update `DA_*` tuning assets + `Docs/LESSONS.md`.

---

## PHASES 2–3 — NETCODE + SCALE CO-OP (parked; the payoff of the discipline)

- **Governing docs:** `Docs/03` §7 (roadmap), §2 (replication gotchas); `Docs/01` §6 (co-op design).
- **Phase 2 (2p listen server):** add listen-server transport, sessions/lobby (evaluate `EnhancedOnlineSessions` + EOS/Steam OSS). Because all state is already server-authoritative (Steps 1–6), this is **layering a transport onto a correct model**, not a rewrite. Verify score/loudness/alert/heat/costume replicate correctly; test **late-join** (prefer OnRep over Multicast — every domain doc already does). Swap MVP respawn-on-catch for **detain + teammate rescue** (`design/04` §9 flags this as a behavior swap, not a rewrite).
- **Phase 3 (2→8p):** profile AI perception tick + replication bandwidth (the perf watch-item, `Docs/03` §8); tune `CrewSplashBonus` cap at scale (`design/06` §9); verify shared alert/heat social tension.
- **DoD:** two, then up to eight, players share correct alert/score/heat state over the network; social tension works; 8p stable.

---

## PHASE 4 — FIRST REAL NEIGHBORHOOD: Maple Court

- **Prerequisites:** MVP validated (Step 8). Reuses Steps 1–6 systems unchanged.
- **Governing docs:** `design/02` (full grey-box placement plan + §7 build checklist); `design/01` §5–6 (sky/MegaLights).
- **Actions (per `design/02` §7):** create `L_MapleCourt`; set GameMode override; `trace_world` the 5 ground probes; place §3 actors in order (ground/street → playground/stash → pools A–D with rates ×1.0/1.3/1.5/2.0 → verticality); apply water material; place the 6 `SB_WP*` patrol points + spawn the homeowner; relocate PlayerStart; import the Satara night HDRI + stand up the MegaLights vocabulary (streetlamps/windows/sensor floods — `design/01` §6); download the missing Kenney suburban kit for grey-box houses. Cone geometry stays fixed — difficulty is authored via route/layout/light density.
- **DoD:** a full playable Maple Court run; the money-pool (D) detour feels worth it; a close call at WP5; screenshot for the PR. Human feel-pass against `Docs/02` §4.

---

## PHASE 5 — CONTENT & THREATS (+ the Grotto)

- **Prerequisites:** Phase 4.
- **Governing docs:** `design/04` §407 note (cop/chaser reuse the canonical profile); `design/05` §5.4 (threats = costume swaps on the shared rig); `design/03` (Underground Pools).
- **Actions:** Cop + cross-yard chaser (own `AIP_*Profile` assets, **same cone geometry + 3-color state model**, reskinned BTs); cop spawns at `CopSpawnThreshold=90` heat (`design/06` §5.4). Build **The Grotto** on "The Heights" (`design/03` §9 blockout, Option A sealed chamber) — 100% system reuse + `DA_GrottoProfile` + one hatch transition actor + re-skinned caretaker. Environmental threats (dogs/sprinklers/cameras). Home-base intro scene (`design/01` §7, buildable from staged Kenney furniture). Remaining costume wardrobe + Synty Sidekick modular swap (`design/05` §3.2).
- **DoD:** the full core loop from `Docs/01`; the grotto's "the one place you *stay*" tension reads; cop escalation works; costumes swap parts on the modular rig.

### Phase 5 addition — Loot & Extraction (Trinkets + The Trophy)

- **Prerequisites:** Steps 2 (loudness modifier hook), 3 (at-risk/banked pattern), 5 (`HandleDetain` for drop-on-capture), 6 (CostumeComponent — this is a sibling component copying its pattern, not an edit to it). Do not start ahead of Step 8 (`Docs/02` §8) — same discipline as the rest of Phase 5.
- **Governing doc:** `design/11_Loot_And_Extraction.md` (full spec + cited research). Palette extension in `design/01` §2.1 (`LootUncommon`/`LootRare`/`LootMythic`); canon names in `CANON.md`'s "Loot & Extraction canon" section.
- **Actions:** `E_LootRarity` enum (human in-editor, same gap as `E_AlertState`); `DA_LootItem` PrimaryDataAsset + a handful of reference instances (speed-pants trinket + the one-of-a-kind Trophy); `BP_LootPickup` actor; `BP_LootComponent` (sibling to `BP_CostumeComponent`) on `BP_PlayerCharacter`; `PlayerState.CarriedLoot`/`BankedLoot`/`EquippedTrinkets`; `BP_LootSpawnManager` (field-loot pool + Trophy pool + pity counter) on `BP_PlayerGameMode`; wire `Server_BankCarriedLoot`/`Server_DropCarriedLoot` into the existing `BP_StashZone` and `HandleDetain` overlap paths; wire the Trophy's periodic `Server_ReportAction("Action.GnomeCarry")` into the existing loudness plumbing.
- **DoD:** field trinkets spawn from the curated pool and grant their small, situational (never dominant) buff once equipped; the Trophy spawns exactly once per night with a working pity counter, telegraphs from range, and audibly/visually spikes loudness while carried; capture drops carried loot as a recoverable pickup (never deletes it); nothing here breaks the Step 8 loop's tuning; compiles clean; committed. Two open decisions need the human before/at build time: co-op Trophy scoping (shared-team vs. per-player, `design/11` §7) and the exact trinket slot count (`design/11` §11).

---

## PHASE 6 — META & POLISH (look-dev)

- **Prerequisites:** Phase 5; loop proven and co-op shipping.
- **Governing docs:** `design/01` §3–7 (Substrate Toon, toon water, outlines); `Docs/01` §9 (meta); `Docs/05` (launch strategy).
- **Actions:** enable **Substrate** (project-wide, restart-required — do it here, never during Phase 1 tuning); build `M_ToonMaster` + `M_ToonWater` + post-process outline; per-neighborhood sky grades; leaderboards/unlocks; audio pass; photo/clip pipeline (start the Discord/clip funnel during grey-box per `Docs/05`). Launch stance: premium Early Access **$9.99–$14.99**, cosmetic-only DLC (`Docs/05` §B).
- **DoD:** shippable demo; the readability layer stays a flat, on-top, replicated-driven language distinct from world lighting (`design/01` §10 "the one thing not to get wrong").

---

## Risks & biggest unknowns

1. **Netcode (Phase 2) is the top schedule risk** (`Docs/03` §7) — co-op ~doubles complexity. *Mitigation is entirely in Phase 1 discipline:* if every authoritative value stayed on GameMode/GameState/PlayerState (verify with the Step 7 grep gate), Phase 2 is bounded, not a rewrite. **This is the single most important thing to not get wrong.**
2. **"Is it fun?" is unproven until Step 8.** The whole MVP exists to answer it cheaply. Biggest unknown: whether the *close-call arc* (criterion 3) emerges from the current tuning. If not, the fix is numbers (fill/decay, cone, chase speed), never features.
3. **MCP fragility** (LESSONS): 0-byte silent saves, hard asset references breaking on delete+recreate, non-compiling BPs freezing PIE on an un-dismissable modal, `read_graph_dsl` mis-rendering rewired nodes (trust `get_node_infos` + a clean compile), the ThirdPerson floor not being flat, HWRT re-enable deadlock. Every step's DoD includes the save/size/compile guard for this reason.
4. **Experimental features churn:** UE 5.8 Toon Shader (Substrate) and the Unreal MCP itself are Experimental — expect API drift. Keep the fake-toon `M_GreyboxToon` fallback (`design/01` §3) and don't build load-bearing automation on unstable tool signatures.
5. **AI perception perf at 8p** (Phase 3) — many perception-running AIs + replication is the profiling watch-item (`Docs/03` §8). Unknown until measured; don't optimize before Step 8.
6. **Ray tracing stays off** — a hard line. Any "we need a reflection" pressure is answered by SSR/planar/emissive (`design/01` §4.4), never by re-enabling `r.RayTracing`.
7. **Costume forward-dependencies** (`design/05` §9): System 2 must expose the loudness-modifier setter (built in Step 2), System 4 must read `BushHideBonus`, GameMode scoring must read `ScoreFlairMultiplier` — all from PlayerState. Flagged so those systems are built with the hooks in place.

---

*Follow Steps 0–8 in order for the MVP; treat Phases 2–6 as specified-but-parked until Step 8 validates the loop. The vision is fixed (`00_Design_Bible.md`); the numbers are seeds to move in playtest, stored in Data Assets so they move without touching a graph. Commit before and after every step; save + size-check + compile before you trust anything (LESSONS).*
