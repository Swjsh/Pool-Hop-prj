# Pool Hop — Canonical Decisions (drift resolutions)

*The single source of truth when the parallel-authored design docs disagree. Established from `09_Design_Review_Punchlist.md`. When a domain doc conflicts with this file, THIS FILE WINS. Update here first, then propagate.*

Last updated: 2026-06-30 (overnight build loop).

---

## Why this exists
The 10 design docs were authored in parallel and drifted: the same state variable, enum, asset, and number appear under different names/values. `09` (the critique) flagged this as the dominant risk — if each doc is built literally, the systems won't connect. This file pins one canonical set. `06_Core_Systems_TechSpec.md` is the source of truth for **state + loudness**; `04_AI_Watcher.md` is the source of truth for **AI numbers**.

## Naming / path canon
- **Framework-state variable names → `06` (see tables below).** `07`'s HUD binds to these exact names; `04` writes to these exact names.
- **`E_AlertState` = 4 states: `Unaware(0), Suspicious(1), Alert(2), Critical(3)`.** Critical is a real member (AlertDirector §5.4 assigns it at heat ≥ 90). **Interim: no MCP tool can create a Blueprint enum, so the variable is built as `byte` (0–3) for now** — swap to the real `E_AlertState` enum in-editor later (2-min manual step), then retype the vars. Any code comparing states uses the integer values above.
- **`E_PoolTier` = `Standard(0), HotTub(1), Infinity(2), Money(3)`** — same `byte` interim.
- **Watcher actor = `BP_WatcherCharacter` (parent `Character`) + `BP_WatcherController` (parent `AIController`), both under `Content/_Project/AI/Watcher/`.** NOT `BP_Watcher`/`BP_Homeowner`/`BP_HomeownerCharacter`, NOT flat `_Project/AI/`.
- **Input assets stay in `Content/Input/`** (where `IA_Move`/`IMC_Default` already live). New actions (`IA_Interact`/`IA_Dive`/`IA_SwimUpDown`) go there too — NOT a new `Content/_Project/Core/Input/`. (Avoids the "which asset is real" class of bug from LESSONS.)
- **Materials** live under `Content/_Project/Gameplay/Materials/` (e.g. `M_GreyboxToon`, `M_WaterPlaceholder`). `Art/` is not a canonical folder.

## Number canon (the tuned pairs — move together, never one alone)
- **Watcher cone: `PeripheralVisionHalfAngle = 35°` (70° cone), `SightRadius = 1400`, `LoseSightRadius = 1800`.** (`04`. `02`/`01`'s 45°/1700/1200 are wrong.) The flashlight decal + vision-cone material use `SightRadius=1400` so art == truth.
- **Hearing: `HearingRange = 1200` baseline** (`04` wins for AI numbers). Loudness scales effective range up toward this; the loudness/hearing pair is tuned together (`06` §2.5).
- **Detection: fill `1.5s`, decay `3.0s`** (`04`). (`02`'s 1.2/2.0 are wrong.)
- **Chase vs Sprint pair: `ChaseSpeed = 650`, player `SprintSpeed = 600`** — keep chase ~50 above sprint so escape is reliable (`04` §13 knob 4). These two knobs are a pair across `AIP_WatcherProfile` and `DA_MovementTuning`.
- **Night length: `NightTimeRemaining` default `600`** (10 min).
- **Loudness magnitudes → the single `DT_LoudnessActions` table in `06` §2.6 is the source of truth** (Vault bump 30, SplashEnter 45, Sprint sustained band 55, SwimMove band 45, SensorTrip 40, FenceClimb 25, CrouchMove silent). `07`'s per-verb "noise" numbers must equal these rows.
- **Pools use absolute `BaseScorePerSecond`** (the real field on `BP_PoolVolume`), NOT multipliers: sandbox A/B/C/D = `10 / 13 / 15 / 20` per second.
- **Detain respawn target = the stash-zone actor** (`BP_StashZone`, exists by Step 3), everywhere.

## Verified drift resolutions (2026-07-01 audit — a fresh model MUST build from these, not the domain docs)

A doc audit confirmed the parallel-authored docs `04`/`07`/`02` still contain **old names and numbers that silently break bindings**. These are the rulings; the offending docs carry a banner pointing here.

**1. HUD / framework-state variable names — `07` is WRONG, build the names in the Step-1 tables below.** `07_Movement_And_UI.md` binds the HUD to short names that DO NOT EXIST after Step 1. Use this translation:

| `07` says (WRONG) | Actual canonical var (build + bind THIS) | Lives on |
|---|---|---|
| `ScoreBanked` | `TeamScoreBanked` | GameState |
| `ScoreAtRisk` | `TeamScoreAtRisk` (shared) / `IndividualScoreAtRisk` (per-player) | GameState / PlayerState |
| `NeighborhoodAlert` | `AlertLevel` | GameState |
| `NightSecondsRemaining` | `NightTimeRemaining` | GameState |
| `Heat` | `NeighborhoodHeat` | GameState |
| `Loudness` | `CurrentLoudness` | PlayerState |
| `DetectionAlpha` | `DetectionAlpha` ✓ (this one matches) | PlayerState |

`04_AI_Watcher.md` writes detection to PlayerState: the canonical field is **`DetectionAlpha`** (0–1 fill). If `04` also names `DetectionMeter`/`SeenByAlertState`, treat those as the same `DetectionAlpha` + `AlertLevel` unless you deliberately add a separate raw-meter var.

**2. `E_AlertState` has FOUR members: `Unaware(0), Suspicious(1), Alert(2), Critical(3)`.** `04 §6/§11` and its pseudocode show only 3 (omit `Critical`) — **stale**. `Critical` is real (AlertDirector assigns it at heat ≥ 90, `06 §5.4`). Build 4.

**3. Hearing range = `1200` (both fields, one number).** `04` says `HearingRange = 1200`; `06 §2.2/§2.5` says `HearingRangeAtMaxLoudness = 2500` — **conflict**. Ruling: use **1200** everywhere (the AI sense `HearingRange` AND the LoudnessComponent's `HearingRangeAtMaxLoudness` both = `1200`). It's one tuned pair; `06`'s 2500 is superseded. (Playtest may move it — but move both together.)

**4. Watcher cone geometry = `35° / 1400 / 1800`, fill `1.5s` / decay `3.0s`.** `02 §"Detection tuning"` hardcodes `45° / 1700 / 900 / 1.2s / 2.0s` and even says "do not re-tune per map" — **all wrong, ignore that whole block**. `04` (which CANON already blesses for AI numbers) is right. Difficulty per map = route/dwell/light, never cone size.

**5. Watcher actor name = `BP_WatcherCharacter` + `BP_WatcherController` under `Content/_Project/AI/Watcher/`.** `05`/`02`/`03` variously call it `BP_Watcher`/`BP_Homeowner`/`BP_HomeownerCharacter` — all wrong, use the `04` name everywhere.

## Canonical Step-1 variable tables (what the build creates)
Replication legend: `None` = server-only/local; `Rep` = Replicated (read-only mirror on clients); `RepNotify` = replicate + `OnRep_`.

**`BP_PlayerGameState`** (shared truth):
| var | type | repl | default |
|---|---|---|---|
| `TeamScoreBanked` | int | Rep | 0 |
| `TeamScoreAtRisk` | int | RepNotify | 0 |
| `NeighborhoodHeat` | float | RepNotify | 0 |
| `AlertLevel` | byte *(→E_AlertState)* | RepNotify | 0 |
| `NightTimeRemaining` | float | Rep | 600 |
| `bNightOver` | bool | RepNotify | false |

**`BP_PlayerState`** (per-player):
| var | type | repl | default |
|---|---|---|---|
| `IndividualScoreAtRisk` | int | RepNotify | 0 |
| `IndividualScoreBanked` | int | Rep | 0 |
| `DistinctPoolsHopped` | int | Rep | 0 |
| `CurrentLoudness` | float | Rep | 0 |
| `bDetained` | bool | RepNotify | false |
| `Air` | float | Rep | 100 |
| `bIsSubmerged` | bool | Rep | false |
| `bBreathCritical` | bool | Rep | false |
| `bIsHidden` | bool | Rep | false |
| `DetectionAlpha` | float | Rep | 0 |

Deferred to their systems (not Step 1): `EquippedCostume` (soft DataAsset ref → Step 6, and soft-ref-via-MCP is unconfirmed — see LESSONS), the DataTable/struct-typed vars (Step 2).

## Step 3 variable additions (pool scoring — not in the original Step-1 tables, added when building `06 §3`)
`06`'s spec text implies these as tuning knobs/bookkeeping but doesn't list them in a variable table; canonizing here so they aren't re-invented differently next time:

| Var | Type | Repl | Default | Lives on | Purpose |
|---|---|---|---|---|---|
| `CrewSplashBonusPerExtra` | float | None | 0.25 | `BP_PoolVolume` | Per-extra-occupant crew multiplier bonus, used by `GetCrewMultiplier` (§3.4 knob). |
| `StreakStep` | float | None | 0.15 | `BP_PlayerGameMode` | Hop-streak multiplier step, used by `GetHopStreakMultiplier` (§3.4 knob). |
| `StreakCap` | int | None | 6 | `BP_PlayerGameMode` | Hop-streak clamp cap (§3.4 knob). |
| `VisitedPoolIDs` | Array\<Name\> | None | [] | `BP_PlayerState` | Server-only bookkeeping so `Server_RegisterPoolVisit` can tell whether a `PoolID` is new for this run; cleared on bank (`Server_BankAtRisk`) and on catch (`Server_LoseAtRisk`) alongside `DistinctPoolsHopped` reset. Not in `06`'s PlayerState table — needed because the spec's "is PoolID new for this PlayerState?" check has nothing else to check against. |

**Scoring rule functions built as regular Functions (not Custom Events)**, per the existing `Server_*` → `HasAuthority`-guarded-function interim convention: `Server_AddScore`, `GetHopStreakMultiplier`, `Server_BankAtRisk`, `Server_LoseAtRisk`, `Server_RegisterPoolVisit` (new — not named in `06`, needed to back the "is this pool new" check), `Server_OnReachStash` (thin wrapper → `Server_BankAtRisk`, per the roadmap's Step 3 sequencing) — all on `BP_PlayerGameMode`. `BP_PoolScoringComponent.Server_ExitPool` does **not** null `CurrentPool` (spec says "clear") — it only resets `AccrualAccumulator`/`bIsScoring`; the tick gate uses `bIsScoring`, not `IsValid(CurrentPool)`, sidestepping an unresolved "how do you DSL-author a null object literal" question. Functionally equivalent; revisit only if something ever needs to read a scoring component's `CurrentPool` while `bIsScoring` is false and expects `None`.

## Step 2 substitution (loudness actions — `DT_LoudnessActions` is human-only)
`06 §2.6`'s `DT_LoudnessActions` + `S_LoudnessAction` struct **cannot be built via MCP**: `DataTableTools.create`/`import_file` both require an *already-existing* row struct, and creating a new Blueprint struct isn't MCP-buildable (same wall as the enums — see LESSONS). **Built instead:** `BP_LoudnessComponent.GetActionInstantBump(ActionTag: Name) -> float`, a plain if/elif lookup with the exact starter values from `06 §2.6`'s table (`Action.SplashEnter`=45, `Action.Vault`=30, `Action.SensorTrip`=40, `Action.FenceClimb`=25, else 0). Called from the new `Server_ReportAction(ActionTag)`. The two sustained actions (`Action.Sprint`, `Action.SwimMove`) don't go through this lookup at all — they're driven directly by `Server_SetSustainedSource(SourceTag: "Sprint"|"Water", bActive)` setting `bIsSprinting`/`bIsInWater`, which `TickLoudness` (pre-existing) already reads. **When the human creates `S_LoudnessAction` + `DT_LoudnessActions`:** swap `GetActionInstantBump`'s body to a `DataTableTools.get_rows` lookup; the calling convention (`Server_ReportAction(ActionTag)`) doesn't need to change.

`BP_PlayerCharacter` wiring: Sprint Started/Completed (already-existing input events, `then` pins were dangling — inserted here) → `Server_SetSustainedSource("Sprint", true/false)`. `TryVault`'s success path (after `LaunchCharacter`, before `return true`) → `Server_ReportAction("Action.Vault")`. New `EventOnMovementModeChanged` override → `Server_SetSustainedSource("Water", ...)` on entering/leaving `MOVE_Swimming` (fanned out via a `Sequence` node since checking both `NewMovementMode` and `PrevMovementMode` needs two independent `SwitchOnEMovementMode` branches — see LESSONS for why they can't just be two sequential DSL statements).

## Step 4 substitution (AI Watcher — `BT_Watcher`/`BB_Watcher` are human-only)
`04`'s Behavior Tree + Blackboard cannot be built via MCP (`BehaviorTreeTools` is inspect-only, no Blackboard-creation tool exists at all — confirmed directly this session, see LESSONS). **Built instead of the BT:** `BP_WatcherController.TickBrain(DeltaSeconds)`, a single Blueprint function running every controller tick that replicates `04 §7.3`'s `BTS_UpdateDetection` (fill/decay meter, hysteresis Unaware↔Suspicious↔Alert transitions) AND `04 §7`'s Selector's per-state movement (Alert → `MoveToActor`(player) or `MoveToLocation`(last-known) if sight lost; Suspicious → `MoveToLocation`(last-known); Unaware → cycles an ordered `TargetPoint` array gathered by tag `"PatrolPoint"` at `BeginPlay`). No EQS search yet (spec explicitly allows starting without it — `04 §7.4`).

**Controller variables mirror `06`'s Blackboard key list 1:1** so a future BT/BB port is mechanical, not a rewrite: `AlertState` (byte, Unaware=0/Suspicious=1/Alert=2, matches `E_AlertState`'s interim byte pattern), `TargetActor`, `bCanSeePlayer`, `bHeardNoise`, `NoiseStrength`, `LastKnownLocation`, `SearchLocation` (unused until EQS lands), `DetectionMeter`, `HomeLocation`, `PatrolIndex`, plus `WatcherProfile` (ref to the tuning asset, not a `04` Blackboard key) and `PatrolPoints`/`PatrolWaitTimer` (bookkeeping for the patrol substitute, also not `04` keys).

**Shared tuning asset, built as `04 §8` describes:** a reusable Blueprint class `DA_AIPerceptionProfile` (parent `PrimaryDataAsset`) holding all of `04 §8`'s fields at its spec defaults, instantiated once as `AIP_WatcherProfile`. Future AI (cop/chaser) create their own instance of the *same class*, per the doc's own stated intent — don't create a second profile class.

**`OnTargetPerceptionUpdated` logic lives in a helper function (`HandlePerceptionUpdate`), not inline on the bound event** — DSL cannot author onto an existing `K2Node_ComponentBoundEvent` (see LESSONS); the bound event just calls the helper. Sense-type branching (Sight vs Hearing) uses `AI|Perception|GetSenseClassForStimulus` + `Utilities|ClassIsChildOf` (not `==` — see LESSONS' enum/class-comparison gotcha, now hit a third time).

**Cosmetic AlertState mirror to the pawn (`BP_WatcherCharacter.AlertState`, replicated) is wired as a variable but NOT yet written by the controller** — the cross-object setter wasn't indexed by `find_node_types` yet when this was attempted (fresh-asset DB-refresh timing, see LESSONS); low priority, revisit alongside the Step 7 HUD/`?`/`!` icon work.

**✅ RESOLVED (next session) — pathfinding now works.** The `MoveToLocation`/`MoveToActor` "always Failed" issue described below is **fixed**. Live PIE observation found the Watcher had moved from its spawn point (100,1200,90 → 1306,844,90) and was actively patrolling between checks. Likely cause: the 5th-attempt `SupportedAgents` config fix (below) finally took effect via an editor restart between sessions. **Do not re-investigate this** — see LESSONS "MAJOR STATUS CHANGE" entry. Chase/caught-detain can now be verified against real movement.

~~**⚠️ KNOWN OPEN ISSUE — pathfinding (`MoveToLocation`/`MoveToActor`) returns `Failed` every tick; the Watcher never physically moves**~~ (historical, resolved — kept for context). Despite perception/detection being fully verified live (sight detects the player, meter fills, alert state flips, target locks correctly — all proven via direct PIE property reads), a `NavMeshBoundsVolume` + `RecastNavMesh` exist and are correctly sized/positioned; four independent fix attempts (undersized-then-resized bounds volume, `TilePoolSize`/`TileSizeUU` bump, `AgentRadius`/`AgentHeight` correction to match the pawn's real capsule) each showed evidence of taking effect but did **not** fix the `Failed` result at the time.

**5th attempt — found + fixed an empty `Config/DefaultEngine.ini` `SupportedAgents` array (Project Settings → Navigation Mesh → Supported Agents) — this was the fix.** This is a separate config surface from the `RecastNavMesh` instance properties already tried (it's process-lifetime-cached, same class of setting as this project's `r.RayTracing` cvar). Added a matching `Default` agent entry (`AgentRadius=34`, `AgentHeight=192`, matching the Watcher's capsule) via `ConfigSettingsToolset.SetSectionProperties`; confirmed it persisted to disk. Needed an editor restart to take effect (process-lifetime-cached), which happened between sessions — confirmed working now.

## Step 5 substitution (AlertDirector + sensor light + caught/escape/heat)

**`BP_AlertDirectorComponent`** (`_Project/Systems/`, attached to `BP_PlayerGameMode` as `AlertDirector`) built per `06 §5`: vars `AccumulatedHeat`, `HeatDecayPerSecond=3`, `LoudnessHeatWeight=0.15`, `DetectionHeatBump=25`, `SuspicionHeatBump=8`, `SuspiciousThreshold=30`, `AlertThreshold=65`, `CopSpawnThreshold=90`, `CopDispatched`(bool), `LastSeenWatcherAlertState`(byte, internal bookkeeping, not a `06` field). Functions: `TickHeat(DeltaSeconds)` (decay + player-loudness contribution, called every component tick, `HasAuthority`-guarded), `NotifyDetection(NewAlertState)`, `NotifySensorTrip(Location)`, `GetHeat01()`, `PushHeatToGameState()` (writes `GameState.NeighborhoodHeat`/`AlertLevel` from thresholds — the shared internal helper all three "something changed" paths call).

**Watcher→AlertDirector wiring is POLL-based, not push-based — a deliberate substitution forced by the "frozen per-graph accessor index" limitation (see LESSONS).** The natural design (Watcher's `TickBrain` calls `GameMode.Server_NotifyDetection(newState)` on a state change) could not be built: `BP_WatcherController`'s graphs were already touched earlier in the session and permanently couldn't see the brand-new `BP_PlayerGameMode` functions needed to receive the push, no matter how many times either side was saved/recompiled/waited-on. **Substitute:** `BP_AlertDirectorComponent.PollWatcherAndPush` (called every tick from `TickHeat`) reaches OUT to `BP_WatcherController.GetAlertState` (an old, pre-existing accessor, so it resolves fine) and diffs against its own `LastSeenWatcherAlertState` to detect a transition, calling its own (self-context) `NotifyDetection` when one occurs. Functionally equivalent to a push notification, just inverted in direction — document this pattern for any future "new class needs to react to an old class's state change" wiring.

**Caught → detain (`04 §9`)**: `BP_WatcherCharacter.EventActorBeginOverlap` (HasAuthority + `"Player"` tag + own controller's `AlertState==2`) → casts the overlapping actor to `BP_PlayerCharacter` → gets its `PlayerState` → calls `GameMode.HandleDetain(PS, RespawnDelay)` (delay read from `WatcherProfile.GetDetainRespawnDelay` — this field already existed on `DA_AIPerceptionProfile` from the Step 4 `04 §8` seed, no new var needed) → resets its OWN controller's `DetectionMeter`/`AlertState` to 0 (the "AI's meter/state reset" the spec calls for; done by the Watcher itself, not by GameMode, since the Watcher already has the reference). `GameMode.HandleDetain` sets `PlayerState.bDetained=true`, calls `Server_LoseAtRisk`, and — **since Unreal's built-in `Delay` node could not be created via MCP** (`create_node`/`write_graph_dsl` both report `"Utilities|FlowControl|Delay does not exist"`, a new MCP-buildability gap, same family as the component-bound-event issue — see LESSONS) — **substitutes `Utilities|Time|SetTimerbyFunctionName`** (a plain UFUNCTION call, always creatable) plus a new `PendingDetainPS` GameMode member var to carry the PlayerState reference across the timer gap, calling a new `FinishDetain()` function after `RespawnDelay` that teleports the pawn to `BP_StashZone` and clears `bDetained`.

**⚠️ Caught→detain is built and structurally correct, but currently UNREACHABLE in play: the Watcher loses sight of the player at close range before the chase can physically close to touching distance.** Confirmed via live chase (not a teleport artifact): even after fixing `TickBrain`'s `MoveToActor` `AcceptanceRadius` (was `120`, larger than the ~68 catch range — lowered to `55`), the Watcher chases to within ~69 units and `AlertState` drops to `0` before contact, because `bCanSeePlayer` apparently goes false at very close range (self-occlusion or a near-zero-distance raycast edge case) and `TickBrain`'s hysteresis has no grace window for "mid-chase, about to touch." **This needs a design decision, not just an MCP fix** — see LESSONS for the three candidate fixes (chase grace window / distance-to-last-known-location instead of raw sight / tune the sight sense's near-range behavior directly).

**`BP_SensorLight`** (`_Project/Gameplay/`, one placed near the sandbox's existing pool/Watcher area — Pool B doesn't exist yet per Step 3, so it's not literally "near Pool B" yet, revisit once Step 5's fence dressing adds Pool B) per `04 §10`: `TriggerBox` (BoxComponent, collision profile `OverlapAllDynamic` — matched to the known-working `BP_StashZone`/`BP_PoolVolume` profile, not `Trigger`) + `SensorSpotLight` (SpotLightComponent, off by default via `bVisible=false`). On player overlap (HasAuthority + tag check, logic lives in a dedicated `HandleSensorOverlap` function called by a one-line event dispatcher — see LESSONS' `write_graph_dsl`-accumulation entry for why): light on, nearest Watcher gets `bHeardNoise=true`+`LastKnownLocation`, `GameMode.Server_NotifySensorTrip(Location)` (a thin wrapper reaching `AlertDirector.NotifySensorTrip`), `SetTimerByFunctionName` → `TurnOffLight` after `LightOnDuration=4.0s`. **Verified working: the Watcher-alert and heat-bump side effects.** **Not resolved: the light itself never visibly turns on** (`SetVisibility(true)` is provably reached and executed — everything after it in the same exec chain runs correctly — yet `bVisible` reads `false` immediately after; root cause not found, low-priority cosmetic-only issue, see LESSONS).

**✅ Heat bump magnitude VERIFIED.** Both tiers confirmed correct: with `HeatDecayPerSecond` temporarily slowed to 0.05 for testing (to eliminate decay-vs-round-trip-latency race — see LESSONS), a fresh Suspicious→Alert transition produced `AccumulatedHeat≈32.55`, matching the expected `SuspicionHeatBump(8) + DetectionHeatBump(25) = 33` almost exactly. The earlier "magnitude looks wrong" readings were a measurement artifact (decay eating the bump between the transition and the read, not a code bug) — see LESSONS for the full resolution and the general testing lesson about decay-rate-vs-round-trip-latency races (this same technique also resolved an apparent "SensorLight doesn't bump heat" false alarm).

## Known MCP buildability gaps (from the spikes — see LESSONS)
- **Enum/struct creation: NOT possible via MCP** (`execute_tool_script` can't import `unreal`; no enum/struct tool). Use `byte`/`int` interim; create real enums/structs in-editor.
- **"Run-on-Server / Reliable" RPC flags: unconfirmed via MCP** — gates every `Server_*` request (Step 2+). Spike before Step 2; may need in-editor.
- **Behavior Tree / Blackboard authoring: inspect-only toolset** — Step 4's BT likely needs in-editor authoring or a future tool.
- ~~**UMG widget-tree authoring: unconfirmed** — Step 7 HUD.~~ **RESOLVED 2026-07-01: CONFIRMED POSSIBLE.** A live `UMGToolSet.UMGToolSet` toolset (`CreateWidgetBlueprint`/`AddWidget`/`CompileWidgetBlueprint`/etc.) authors real widget trees — verified end-to-end including a non-zero-byte on-disk save. See `Docs/LESSONS.md` 2026-07-01 "MAJOR CAPABILITY UPGRADE" entry. Step 7's `WBP_HUD`/`WBP_AlertIcon` no longer need the human by default — attempt via MCP first.
- **The built-in `Delay` node cannot be created via MCP** (`Utilities|FlowControl|Delay` — `create_node`/`write_graph_dsl` both report "does not exist" despite `find_node_types` listing it as a valid type_id). Same family as the earlier component-bound-event gap — some special/macro K2 node classes aren't creatable through the generic node factory even when discoverable. **Substitute:** `Utilities|Time|SetTimerbyFunctionName` (plain UFUNCTION, always creatable) + a member variable to carry any state across the gap, calling a separate follow-up function by name.
- **`ObjectTools.set_properties` cannot write to any live PIE actor/component instance** (reads work fine) — see LESSONS. Verify runtime behavior only by driving real gameplay triggers, never by poking a live instance's properties directly.
- **Niagara, EQS: unconfirmed** — use material/decal + hand-authored fallbacks first.
