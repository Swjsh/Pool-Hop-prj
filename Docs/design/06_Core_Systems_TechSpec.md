# Pool Hop — Core Systems Build-Ready Tech Spec

*Version 0.1 — the build blueprint for the next several sessions. Last updated 2026-06-30. Engine: Unreal Engine 5.8, Blueprints-first.*

> **What this doc is.** The concrete, build-ready specification for the four reusable, server-authoritative systems from `Docs/03_Technical_Architecture.md` §3 — **LoudnessComponent, PoolScoringComponent + PoolVolume, CostumeComponent, AlertDirector** — plus the framework state that must live on **GameState / GameMode / PlayerState**. Every system lists its parent class, exact `Content/_Project` path, member variables (name : type : replication mode), functions, delegates, how it attaches to the existing `BP_PlayerCharacter` / Core scaffolding, concrete tuning numbers, and the `unreal-mcp` `BlueprintTools` calls to build it.
>
> **What this doc is NOT.** It is not a departure from the MVP build order (`Docs/02` §5): **System 1 (movement) is DONE. Build order from here is Loudness → Scoring → Detection AI → couple it → costume/item.** Detection AI (Behavior Tree / Blackboard / perception config) is specced only where the reusable components must hand off to it (the noise-event contract, the heat contract); the full BT/EQS spec is a separate detection-tuning doc when we reach System 4. Do not build ahead of order — this doc is a *map*, not a work queue.

---

## 0. Ground rules this spec obeys (do not violate)

1. **Server authority (Docs/03 §2).** Every piece of shared/authoritative state — score, loudness, alert level, banked points, night timer, heat, detained — lives in **GameMode** (rules, never replicated) / **GameState** (replicated shared truth) / **PlayerState** (replicated per-player). **Never** on the character/pawn. The pawn holds movement (`CharacterMovementComponent`, replicates for free) + cosmetic/local feedback only.
2. **Client → request → server validates → server mutates authoritative state → replicates back** via replicated variables + `OnRep_`/RepNotify. Player input is a *request*, never a self-report of outcome.
3. **Prefer `OnRep` state over Multicast RPCs** so a late-joiner (Phase 2 co-op) syncs correct world state. Multicasts fire once and are lost to anyone who joins after.
4. **Blueprints first.** Everything below is Blueprint-authorable. The only spot C++ is even *considered* is AI affiliation/teams (flagged in §5); the MVP avoids it.
5. **Ray tracing is OFF** (`r.RayTracing=False`, see `Docs/LESSONS.md`) — assume Lumen software / simple lighting. No system here depends on HWRT.
6. **Folder + naming convention.** Our content under `Content/_Project/{Core,Characters,Components,AI,Systems,Gameplay,UI,Data,Maps}`. `BP_` Blueprints, `M_`/`MI_` materials, `IA_`/`IMC_` input, `L_` maps, `DT_` Data Tables, `DA_` Data Assets, `E_` enums, `S_` structs, `BB_` blackboard, `BT_` behavior tree.

### Replication-mode legend (used in every variable table)
| Mode | Meaning | Where it belongs |
|---|---|---|
| **None** | Not replicated. Server-only rule state, or a purely local/cosmetic value. | GameMode; local cosmetic vars on components |
| **Replicated** | Server → clients, no notify. Read-only on clients. | GameState/PlayerState values HUD just displays |
| **RepNotify** | Server → clients + fires `OnRep_<Var>` on receipt. Use when a client must *react* (update HUD, play FX, refresh a cone). In Blueprint, `OnRep` fires on server-set-then-replicate AND on clients — code accordingly. | GameState/PlayerState values that drive UI/FX reactions |

> **MCP note:** `set_variable_replication(bp, name, "Replicated"|"RepNotify"|"None")`. `RepNotify` auto-creates the `OnRep_<Var>` function graph. New member variables are **not settable on the CDO until the BP compiles** — add variable → `compile_blueprint` → then `set_properties` its default. Order matters (see `unreal-mcp-blueprints` skill).

---

## 1. System map & ownership (where every value lives)

```
                 GameMode  (BP_PlayerGameMode)  — server-only RULES, never replicated
                 ├─ AlertDirector logic (heat aggregation + escalation)   [§5]
                 ├─ scoring rules (rates, decay curves, multiplier tables) [§3]
                 └─ escape/detain/respawn rules                            [§6]
                          │ writes ▼            ▲ reads
                 GameState (BP_PlayerGameState) — REPLICATED shared truth   [§6]
                 ├─ TeamScoreBanked, TeamScoreAtRisk
                 ├─ NeighborhoodHeat (0–100), AlertLevel (enum)
                 └─ NightTimeRemaining, bNightOver
                          ▲ per-player contributions
                 PlayerState (BP_PlayerState)   — REPLICATED per player     [§6]
                 ├─ IndividualScoreAtRisk / Banked, DistinctPoolsHopped
                 ├─ CurrentLoudness (mirror for HUD), bDetained
                 └─ EquippedCostume (DA ref), Loadout
                          ▲ owns/attaches
   BP_PlayerCharacter (pawn) — movement (CharMoveComp) + LOCAL/COSMETIC only
   ├─ LoudnessComponent   [§2] → ReportNoiseEvent → AI hearing            
   ├─ PoolScoringComponent[§3] → overlaps PoolVolume → requests score
   └─ CostumeComponent    [§4] → swaps mesh + applies modifier DA
                          
   PoolVolume (BP_PoolVolume, level actor) [§3] — overlap trigger + tuning
   AI threat (BP_HomeownerController + BT/BB) [§5-handoff] — consumes noise, writes detection → heat
```

**The one coupling that makes the game tick:** `LoudnessComponent` value → scales `ReportNoiseEvent` loudness → `AIPerceptionComponent (Hearing)` effective range → detection → `AlertDirector` heat → escalation. Build the pieces so that contract is honored even in single-player (the "server" is the local listen host).

---

## 2. LoudnessComponent

**Purpose.** Track a per-player 0–100 loudness value, raise it from tagged actions (sprint / splash / vault / sensor trip), decay it over time, and fire `AISense_Hearing` noise events scaled by the value so louder players are heard from farther away. This is System 2 in the build order — **build this first.**

- **Parent class:** `ActorComponent` (`/Script/Engine.ActorComponent`). Not SceneComponent — it has no transform of its own; it reads the owner's location for noise events.
- **Asset:** `BP_LoudnessComponent`
- **Path:** `Content/_Project/Components/BP_LoudnessComponent`  → object path `/Game/_Project/Components/BP_LoudnessComponent.BP_LoudnessComponent_C`
- **Ticks:** yes (enable `ComponentTickEnabled`), used only for decay + throttled noise reporting. Keep the tick cheap.

### 2.1 Authority model
Loudness is **authoritative on the server**. The character's input handlers call `Server_ReportAction` (a request); the server validates and mutates `CurrentLoudness`. `CurrentLoudness` is **RepNotify** so the owning client's HUD reacts. In single-player the local host *is* the server, so this path runs locally — but it is already the correct networked shape (Phase 2 = free).

> **Why not compute loudness on the client?** Because loudness feeds detection, which feeds heat/score — all outcome-affecting. A client that self-reported "I'm silent" would cheat detection. Server owns it (Docs/03 §2, §4).

### 2.2 Member variables

| Name | Type | Repl | Default | Notes |
|---|---|---|---|---|
| `CurrentLoudness` | float | **RepNotify** | 0.0 | 0–100. The live value. `OnRep_CurrentLoudness` → update HUD + optional ripple VFX. Server-authoritative. |
| `DecayRatePerSecond` | float | None | 22.0 | Units/sec the value falls toward `IdleFloor` when no loud action is sustained. Tuned so a sprint burst (to ~60) cools to idle in ~2.5 s. |
| `IdleFloor` | float | None | 5.0 | Loudness never decays below this while moving-crouched/idle (ambient presence). 0 only when fully still could be added later. |
| `MaxLoudness` | float | None | 100.0 | Clamp ceiling. |
| `NoiseReportInterval` | float | None | 0.25 | Seconds between `ReportNoiseEvent` calls while loudness > `NoiseReportThreshold`. Throttle so we don't spam the perception system every tick. |
| `NoiseReportThreshold` | float | None | 10.0 | Below this, don't bother reporting noise (silent enough that no AI should hear). |
| `HearingRangeAtMaxLoudness` | float | None | 2500.0 | cm. The effective world radius a `Loudness=100` event should be heard at. Loudness scales the `Loudness` param of `ReportNoiseEvent` (0–1), and the AI's `Hearing` sense `HearingRange` is set so that `1.0` = this distance. See §2.5. |
| `ActionLoudnessTable` | DataTable ref (`DT_LoudnessActions`) | None | — | Maps an action tag → instant loudness bump + optional sustained rate. Data-driven tuning (see §2.6). Costume modifiers multiply the looked-up value. |
| `LoudnessModifier` | float | None | 1.0 | Multiplier applied to every action bump. Set by `CostumeComponent` (e.g. quiet-shoes = 0.8). Server reads it when applying a bump. |
| `bIsSprinting` | bool | None | false | Sustained-source flag; while true the server keeps loudness topped up to the sprint band each tick (so holding sprint stays loud, not one bump). Mirror of movement state, set via `Server_SetSustainedSource`. |
| `bIsInWater` | bool | None | false | Sustained-source flag for splashing while swimming/moving in a pool. |

> **Design intent for the two `bIs...` sustained flags:** most loud actions are *impulses* (a vault, a single splash entry). Sprinting and thrashing in water are *sustained* — they should hold loudness elevated, not decay while active. The tick logic (§2.4) treats sustained sources as a floor.

### 2.3 Functions & events

| Name | Kind | Signature | Runs on | Purpose |
|---|---|---|---|---|
| `Server_ReportAction` | Custom Event (Run on Server, Reliable) | `(ActionTag : GameplayTag or Name, WorldLocationOverride : Vector [opt])` | Server | Entry point for an impulse action. Looks up `ActionLoudnessTable`, applies `bump × LoudnessModifier`, clamps, updates `CurrentLoudness`. Immediately fires a noise event (don't wait for the throttle) so a splash is heard *now*. |
| `Server_SetSustainedSource` | Custom Event (Run on Server, Reliable) | `(SourceTag : Name {"Sprint","Water"}, bActive : bool)` | Server | Sets `bIsSprinting` / `bIsInWater`. Tick then holds the matching band. |
| `AddLoudness` | Function (pure-ish, server-internal) | `(Amount : float)` | Server | `CurrentLoudness = Clamp(CurrentLoudness + Amount × LoudnessModifier, 0, MaxLoudness)`. Single choke-point so the modifier is always applied. |
| `TickDecay` | (in `ReceiveTick`) | `(DeltaSeconds : float)` | Server | If a sustained source is active, raise loudness toward its band; else decay toward `IdleFloor` at `DecayRatePerSecond`. Server-only guard (`HasAuthority`). |
| `ReportNoise` | Function | `()` | Server | Computes `NormalizedLoudness = CurrentLoudness / MaxLoudness`, and calls `AIModule → ReportNoiseEvent(WorldContext, Location=OwnerLocation, Loudness=NormalizedLoudness, Instigator=OwnerPawn, MaxRange=HearingRangeAtMaxLoudness, Tag="PlayerNoise")`. Throttled by `NoiseReportInterval`. |
| `GetLoudness01` | Function (pure) | `→ float` | Any | `CurrentLoudness / MaxLoudness`. For HUD fill + AlertDirector reads. |
| `OnRep_CurrentLoudness` | RepNotify (auto) | `()` | Owning client + server | Fire `OnLoudnessChanged`. HUD binds here. |

**Delegates (dynamic multicast, for HUD/VFX decoupling):**
- `OnLoudnessChanged(NewLoudness : float, Normalized01 : float)` — HUD widget subscribes; drives the meter fill + color band.
- `OnLoudSpike(ActionTag : Name)` — for a one-shot ripple VFX / SFX cue on a big impulse (splash, vault). Cosmetic, client-side.

### 2.4 Tick logic (pseudocode)
```
event ReceiveTick(dt):
  if not HasAuthority(): return               // server owns the value
  band = 0
  if bIsSprinting: band = max(band, SprintBand)   // e.g. 55
  if bIsInWater:   band = max(band, WaterBand)    // e.g. 45 idle-in-water, splash impulses stack on top
  if band > 0:
     CurrentLoudness = FInterpConstantTo(CurrentLoudness, band, dt, DecayRatePerSecond*2)  // rise faster than decay
  else:
     CurrentLoudness = FInterpConstantTo(CurrentLoudness, IdleFloor, dt, DecayRatePerSecond)
  CurrentLoudness = Clamp(CurrentLoudness, 0, MaxLoudness)
  // throttled noise report
  NoiseAccumulator += dt
  if CurrentLoudness >= NoiseReportThreshold and NoiseAccumulator >= NoiseReportInterval:
     NoiseAccumulator = 0
     ReportNoise()
```
Note the **asymmetric rise/decay** (rise ≈ 2× decay) — matches `Docs/07` §1 "asymmetric velocity curves / weight reads through slower deceleration." Loud fast, quiet slow.

### 2.5 The noise → hearing contract (hand-off to System 4)
`ReportNoiseEvent` publishes a stimulus with `Loudness ∈ [0,1]` and `MaxRange`. UE's `AISense_Hearing` hears it if the listener is within `MaxRange × Loudness`-ish (the sense also has its own `HearingRange`). Concretely:
- The **player side** (this component) sets `MaxRange = HearingRangeAtMaxLoudness (2500 cm)` and `Loudness = CurrentLoudness/100`.
- The **AI side** (§5-handoff, built at System 4) configures `AISense_Hearing` with `HearingRange = 2500` and `bUseLoSHearing = false`. Net effect: at loudness 100 the homeowner hears you at 25 m; at loudness 25 (crouch-walking) only ~6 m. **This is the mechanical heart of the stealth loop** — tune these two numbers together, never one alone.

### 2.6 Data: `DT_LoudnessActions` (Data Table)
- **Row struct:** `S_LoudnessAction` (`Content/_Project/Data/S_LoudnessAction`) — `InstantBump : float`, `bSustained : bool`, `SustainedBand : float`, `Description : string`.
- **Path:** `Content/_Project/Data/DT_LoudnessActions`
- **Starter rows (tuning — iterate in playtest):**

| Row (ActionTag) | InstantBump | bSustained | SustainedBand | Fires from |
|---|---|---|---|---|
| `Action.Sprint` | 0 | true | 55 | movement: sprint pressed/released → `Server_SetSustainedSource("Sprint", …)` |
| `Action.SplashEnter` | 45 | false | — | `PoolScoringComponent` on begin-overlap (dive/jump-in) |
| `Action.SwimMove` | 0 | true | 45 | in-water + moving (splashing) |
| `Action.Vault` | 30 | false | — | `TryVault` success on the character |
| `Action.SensorTrip` | 40 | false | — | motion-sensor light volume overlap |
| `Action.FenceClimb` | 25 | false | — | noisy fence climb (later) |
| `Action.CrouchMove` | 0 | false | — | intentionally silent (relies on IdleFloor) |

### 2.7 Attach to `BP_PlayerCharacter`
1. Add `BP_LoudnessComponent` as a component on `BP_PlayerCharacter` (in the character's Components list; name it `LoudnessComp`).
2. In the character's existing **Sprint** input handler (already built, System 1): on Started → `LoudnessComp → Server_SetSustainedSource("Sprint", true)`; on Completed → `false`. (These are already server-bound requests conceptually; wrap in the character's existing `Server_` input path if one exists, else the component's own Server event handles authority.)
3. In **`TryVault`** (already exists): on successful launch → `LoudnessComp → Server_ReportAction("Action.Vault")`.
4. Swim state: when `CharacterMovementComponent.MovementMode` becomes `MOVE_Swimming` → `Server_SetSustainedSource("Water", true)`; on exit → `false`. (`PoolScoringComponent` also fires `Action.SplashEnter` on the entry impulse — §3.7.)
5. HUD binds `OnLoudnessChanged` → loudness meter (§7).

### 2.8 unreal-mcp build calls (LoudnessComponent)
```
BlueprintTools.create(folder_path="/Game/_Project/Components", asset_name="BP_LoudnessComponent",
                      asset_type={refPath:"/Script/Engine.ActorComponent"})
# variables
add_variable(bp, "CurrentLoudness", "float");        set_variable_replication(bp, "CurrentLoudness", "RepNotify")
add_variable(bp, "DecayRatePerSecond", "float")      # + IdleFloor, MaxLoudness, NoiseReportInterval,
add_variable(bp, "NoiseReportThreshold", "float")    #   NoiseReportThreshold, HearingRangeAtMaxLoudness,
add_variable(bp, "HearingRangeAtMaxLoudness","float") #  LoudnessModifier  — all "None"
add_variable(bp, "bIsSprinting", "bool");  add_variable(bp, "bIsInWater", "bool")
add_object_variable(bp, "ActionLoudnessTable", "/Script/Engine.DataTable")
# functions / events
add_event(bp, "Server_ReportAction")           # then mark Run-on-Server + Reliable in node details
add_event(bp, "Server_SetSustainedSource")
add_function_graph(bp, "AddLoudness");   add_function_param("...:AddLoudness", "Amount", "float", input_param=true)
add_function_graph(bp, "ReportNoise")
add_function_graph(bp, "GetLoudness01");  add_function_param("...:GetLoudness01", "ReturnValue", "float", input_param=false)
compile_blueprint(bp, warnings_as_errors=true)   # BEFORE setting CDO defaults
# then set_properties on the CDO for DecayRatePerSecond=22, IdleFloor=5, MaxLoudness=100, etc.
# graph bodies via write_graph_dsl (get_graph_dsl_docs first); ReportNoiseEvent lives under the AI/AISense category
```
> **Gotcha (LESSONS):** member vars need explicit getters in DSL — `(Variables|Default|GetCurrentLoudness)`, not bare `CurrentLoudness`. Use keyword pins on multi-input nodes (`ReportNoiseEvent`). Compile before CDO defaults.

---

## 3. PoolScoringComponent + PoolVolume

**Purpose (System 3, build second).** While a player is inside a pool volume, the **server** accrues "time-in-water" score into that player's *at-risk* pool, with (a) **per-pool decay** (diminishing returns for camping one pool), (b) a **distinct-pool hop-streak multiplier** (reward moving), and (c) a **crew-splash bonus** (all players in the same pool together). At-risk score only becomes *banked* at the stash/exit zone (§6). Getting caught loses at-risk score (Docs/01 §5.1).

Two pieces:
- **`PoolVolume`** — a level-placed actor with an overlap trigger + per-pool tuning + per-pool decay state. It is the *thing in the world*.
- **`PoolScoringComponent`** — on the player; detects which pool it's overlapping and drives the server request each tick. It is the *player's relationship to pools*.

### 3.1 PoolVolume

- **Parent class:** `Actor` (`/Script/Engine.Actor`). (Not `PhysicsVolume` — that can't be a Blueprint parent, per LESSONS. The *swim physics* volume is a separate level `PhysicsVolume` brush placed by `SceneTools`; `BP_PoolVolume` is the *scoring* trigger that co-locates with it. Keep them as two overlapping actors: the physics brush makes you swim, the BP box makes you score.)
- **Asset:** `BP_PoolVolume`
- **Path:** `Content/_Project/Gameplay/BP_PoolVolume` → `/Game/_Project/Gameplay/BP_PoolVolume.BP_PoolVolume_C`
- **Components:** `BoxCollision` (root, `ScoringBox`) sized to the pool footprint; overlap only, `GenerateOverlapEvents=true`, collision preset `OverlapAllDynamic`. Optional: a `BillboardComponent` for editor visibility.
- **Replication:** the actor replicates (`bReplicates=true`); its **occupancy set is server-owned**. Clients don't need per-pool decay state — they read score from PlayerState/GameState. So most PoolVolume state is **None** (server-only).

**PoolVolume member variables:**

| Name | Type | Repl | Default | Notes |
|---|---|---|---|---|
| `PoolID` | Name | None | (unique per instance) | Stable identity for hop-streak "distinct pools" tracking. Set per-placement. |
| `BaseScorePerSecond` | float | None | 10.0 | Points/sec before decay & multipliers. The "money pool" (D) can raise this. |
| `PoolTier` | enum `E_PoolTier` {Standard, HotTub, Infinity, Money} | None | Standard | Cosmetic/score flavor; higher tiers raise base or cap. |
| `DecayHalfLife` | float | None | 8.0 | Seconds of continuous occupancy after which per-second score halves (diminishing returns). Drives `CurrentDecayMult`. |
| `DecayFloor` | float | None | 0.25 | Score-per-sec never decays below 25% of base — camping is bad, not worthless. |
| `DecayRecoverPerSecond` | float | None | 0.15 | When empty, the pool's decay multiplier recovers toward 1.0 (leave & come back = fresh-ish). |
| `CurrentDecayMult` | float | None | 1.0 | Server-updated 0.25–1.0. Falls while occupied, recovers while empty. |
| `OccupantPawns` | Array<Pawn ref> | None | [] | Server set of players currently inside. Size drives crew-splash bonus. |
| `MaxScorePerVisit` | float | None | 400.0 | Optional cap so one pool can't be farmed indefinitely even at floor. |

**PoolVolume functions/events:**

| Name | Kind | Runs on | Purpose |
|---|---|---|---|
| `OnComponentBeginOverlap (ScoringBox)` | Event | Server (guard `HasAuthority`) | If overlapping actor is a player pawn: add to `OccupantPawns`, call that pawn's `PoolScoringComponent → Server_EnterPool(self)`, fire `Action.SplashEnter` loudness. |
| `OnComponentEndOverlap (ScoringBox)` | Event | Server | Remove from `OccupantPawns`, call `PoolScoringComponent → Server_ExitPool(self)`. |
| `TickDecay` | Event (server) | Server | If `OccupantPawns.Num()>0`: decay `CurrentDecayMult` toward `DecayFloor` per `DecayHalfLife`; else recover toward 1.0 at `DecayRecoverPerSecond`. |
| `GetEffectiveScorePerSecond` | Function (pure) | Server | `BaseScorePerSecond × CurrentDecayMult × CrewMult(OccupantPawns.Num())`. Called by the scoring component / GameMode each accrual tick. |
| `GetCrewMultiplier` | Function (pure) | Server | `1.0 + (Occupants-1) × CrewSplashBonusPerExtra` (e.g. +25% each extra player, capped). Single-player = 1.0. |

### 3.2 PoolScoringComponent

- **Parent class:** `ActorComponent` (`/Script/Engine.ActorComponent`).
- **Asset:** `BP_PoolScoringComponent`
- **Path:** `Content/_Project/Components/BP_PoolScoringComponent` → `/Game/_Project/Components/BP_PoolScoringComponent.BP_PoolScoringComponent_C`
- **Ticks:** yes, server-only accrual tick while `CurrentPool` is set.

**Member variables:**

| Name | Type | Repl | Default | Notes |
|---|---|---|---|---|
| `CurrentPool` | `BP_PoolVolume` ref | None | null | The pool the player is currently scoring in (server). |
| `AccrualAccumulator` | float | None | 0.0 | Fractional-point carry so per-tick rounding doesn't lose score. |
| `bIsScoring` | bool | **RepNotify** | false | For HUD "you're earning" pulse + water SFX. `OnRep` → HUD. |

> **All the *score numbers* live on PlayerState/GameState (§6), not here.** This component is just the pump: it decides *when* and *how fast* to ask the server to add score. `DistinctPoolsHopped` and the streak multiplier live on **PlayerState** (per player) and the rules live on **GameMode**.

**Functions/events:**

| Name | Kind | Runs on | Purpose |
|---|---|---|---|
| `Server_EnterPool` | Custom Event (Run on Server, Reliable) | Server | Set `CurrentPool`. Ask GameMode: is `PoolID` new for this PlayerState? If yes → `PlayerState.DistinctPoolsHopped++` and recompute streak multiplier (GameMode rule). Fire `Action.SplashEnter` on `LoudnessComp`. Set `bIsScoring=true`. |
| `Server_ExitPool` | Custom Event (Run on Server, Reliable) | Server | Clear `CurrentPool`, flush `AccrualAccumulator`, `bIsScoring=false`. |
| `TickAccrue` (in `ReceiveTick`) | — | Server | If `CurrentPool` valid: `perSec = CurrentPool.GetEffectiveScorePerSecond()`; `streakMult = GameMode.GetHopStreakMultiplier(PlayerState)`; `AccrualAccumulator += perSec × streakMult × dt`; when ≥ 1 point → call `GameMode.Server_AddScore(PlayerState, floor(acc))`, subtract. |
| `GetIsScoring` | Function (pure) | Any | For HUD. |

**Delegates:** `OnScoringStateChanged(bScoring : bool)` (HUD/VFX).

### 3.3 Scoring rules on GameMode (server-only)
These are *rules*, so they live on **`BP_PlayerGameMode`**, not the component (Docs/03 §2):

- `Server_AddScore(PS : PlayerState, Amount : int)` — adds to `PS.IndividualScoreAtRisk` **and** `GameState.TeamScoreAtRisk` (both replicate down). Single choke-point for all score.
- `GetHopStreakMultiplier(PS) → float` — `1.0 + Clamp(PS.DistinctPoolsHopped - 1, 0, StreakCap) × StreakStep`. Starter: `StreakStep=0.15`, `StreakCap=6` → up to +90% for hitting 7 distinct pools in a run. Reset on catch/bank per §6.
- `Server_BankAtRisk(PS)` — at the stash zone: move `PS.IndividualScoreAtRisk → Banked` and `GameState.TeamScoreAtRisk → TeamScoreBanked`, zero the at-risk, reset streak. (§6)
- `Server_LoseAtRisk(PS)` — on caught/detained: zero `IndividualScoreAtRisk` (and remove its contribution from `TeamScoreAtRisk`), reset streak. Roguelike sting (Docs/01 §5.1).

### 3.4 Tuning summary (starter numbers)
| Knob | Value | Rationale |
|---|---|---|
| BaseScorePerSecond (standard) | 10 /s | A ~6 s dip ≈ 60 pts before decay. |
| Money pool base | 18 /s | The "money pool" (D) is worth camping-risk. |
| DecayHalfLife | 8 s | Optimal play = hop before ~8 s; camping halves your rate. |
| DecayFloor | 0.25× | Camping never fully worthless. |
| CrewSplashBonusPerExtra | +25% each | 2 players together = 1.25×, 4 = 1.75× (capped ~2.0×). Rewards §6 co-op. |
| HopStreak StreakStep / Cap | +15% / 6 | Distinct-pool tour is the skill expression. |
| MaxScorePerVisit | 400 | Anti-degenerate cap. |

### 3.5 attach to `BP_PlayerCharacter`
Add `BP_PoolScoringComponent` as a component (name `PoolScoreComp`). It needs no input wiring — it's driven by `PoolVolume` overlap events calling its Server events. HUD binds `OnScoringStateChanged`. The **swim physics** still comes from the co-located level `PhysicsVolume (bWaterVolume=true)` (already used in L_Sandbox_Movement).

### 3.6 Building a pool in the map (per instance)
1. Place the swim `PhysicsVolume` brush (`SceneTools.add_to_scene_from_class /Script/Engine.PhysicsVolume`), scale to footprint, `set_properties {bWaterVolume:true, priority:1}`.
2. Place `BP_PoolVolume` (`SceneTools.add_to_scene_from_asset /Game/_Project/Gameplay/BP_PoolVolume.BP_PoolVolume`) at the same spot, box sized to match. Set `PoolID` (e.g. `Pool_A`), `BaseScorePerSecond`, `PoolTier`.
3. Add the translucent water surface plane on top (existing `M_WaterPlaceholder`, collision off).
4. Sandbox needs 4 pools: `Pool_A` (open/easy), `Pool_B` (past fence + sensor light), `Pool_C` (hidden), `Pool_D` (money pool, base 18).

### 3.7 unreal-mcp build calls (scoring)
```
# PoolVolume
BlueprintTools.create("/Game/_Project/Gameplay","BP_PoolVolume",{refPath:"/Script/Engine.Actor"})
# add BoxComponent as root (ActorTools/PrimitiveTools add component), set collision to overlap
add_variable(bp,"PoolID","name"); add_variable(bp,"BaseScorePerSecond","float")
add_variable(bp,"DecayHalfLife","float"); add_variable(bp,"CurrentDecayMult","float")   # None
add_object_variable(bp,"OccupantPawns","/Script/Engine.Pawn")   # then flip to Array in details
add_event(bp,"ReceiveActorBeginOverlap"); add_event(bp,"ReceiveActorEndOverlap")
add_function_graph(bp,"GetEffectiveScorePerSecond"); add_function_graph(bp,"GetCrewMultiplier")
compile_blueprint(bp, warnings_as_errors=true)

# PoolScoringComponent
BlueprintTools.create("/Game/_Project/Components","BP_PoolScoringComponent",{refPath:"/Script/Engine.ActorComponent"})
add_object_variable(bp,"CurrentPool","/Game/_Project/Gameplay/BP_PoolVolume.BP_PoolVolume_C")
add_variable(bp,"AccrualAccumulator","float")   # None
add_variable(bp,"bIsScoring","bool"); set_variable_replication(bp,"bIsScoring","RepNotify")
add_event(bp,"Server_EnterPool"); add_event(bp,"Server_ExitPool")   # Run-on-Server, Reliable
compile_blueprint(bp, warnings_as_errors=true)

# Scoring RULES on GameMode
add_event("/Game/_Project/Core/BP_PlayerGameMode...", "Server_AddScore")
add_function_graph(gm,"GetHopStreakMultiplier"); add_function_graph(gm,"Server_BankAtRisk"); add_function_graph(gm,"Server_LoseAtRisk")
```

---

## 4. CostumeComponent

**Purpose (System 5, build last in the MVP after detection is coupled).** Prove the item/costume plumbing: swap **one** cosmetic mesh part and apply **one** small stat modifier (e.g. quiet-shoes = −20% footstep loudness). Costumes are **90% flex, 10% function** (Docs/01 §5.6). Data-driven so the wardrobe scales later without new code.

- **Parent class:** `ActorComponent` (`/Script/Engine.ActorComponent`).
- **Asset:** `BP_CostumeComponent`
- **Path:** `Content/_Project/Components/BP_CostumeComponent` → `/Game/_Project/Components/BP_CostumeComponent.BP_CostumeComponent_C`

### 4.1 Authority model
The **equipped costume is authoritative on `PlayerState`** (`EquippedCostume : DA ref`, RepNotify) — it's per-player loadout that must survive respawn and be visible to others in co-op. The component **reads** PlayerState's equipped costume and (a) applies the visual on every client via `OnRep`, (b) applies the **stat modifier** on the server only (modifiers affect outcomes → server). A client requests a swap via `Server_EquipCostume`; the server validates ownership/unlock and sets PlayerState.

### 4.2 Costume Data Asset

- **Class:** `PrimaryDataAsset` (`/Script/Engine.PrimaryDataAsset`) → `DA_Costume` blueprint base, instances per costume.
- **Path (base):** `Content/_Project/Data/DA_Costume`; instances e.g. `Content/_Project/Data/Costumes/DA_QuietShoes`, `DA_SwimTrunks` (default), `DA_FlamingoRing`.

**DA_Costume fields:**

| Name | Type | Notes |
|---|---|---|
| `CostumeID` | Name | Unlock key / save id. |
| `DisplayName` | Text | UI. |
| `MeshOverride` | SkeletalMesh (soft ref) | Full-body swap (later); MVP can use a `MeshPart` decal/attach. |
| `AttachMesh` | StaticMesh (soft ref) | e.g. flamingo ring / shoes — attached to a socket. |
| `AttachSocket` | Name | e.g. `foot_l`/`spine_03`. |
| `LoudnessModifierMult` | float | 1.0 = neutral; QuietShoes = 0.8; FlamingoRing = 1.2 (loud but funny). Applied to `LoudnessComponent.LoudnessModifier`. |
| `SwimSpeedMult` | float | Wetsuit = 1.1; default 1.0. Applied to CharMoveComp `MaxSwimSpeed` (cosmetic-adjacent but small perk). |
| `bIsDefault` | bool | Swim trunks. |

> **Keep perks tiny** (Docs/01 §5.6): one or two small multipliers max per costume. Do not add combat/utility stats.

### 4.3 CostumeComponent members

| Name | Type | Repl | Notes |
|---|---|---|---|
| `EquippedCostumeCache` | `DA_Costume` soft ref | None | Local cache of what's currently applied (to diff on `OnRep`). |
| `AttachedMeshComp` | StaticMeshComponent ref | None | The spawned attach mesh, so a re-equip can destroy/replace it. |

*(The authoritative equipped costume lives on PlayerState — see §6 — not here.)*

### 4.4 Functions/events

| Name | Kind | Runs on | Purpose |
|---|---|---|---|
| `Server_EquipCostume` | Custom Event (Run on Server, Reliable) | Server | Validate the costume is unlocked for this player → set `PlayerState.EquippedCostume` (RepNotify). Apply the server-side stat modifiers: `LoudnessComp.LoudnessModifier = DA.LoudnessModifierMult`; CharMoveComp swim speed × `DA.SwimSpeedMult`. |
| `ApplyCostumeVisual` | Function | Client + server (called from PlayerState `OnRep_EquippedCostume`) | Async-load the DA soft refs; swap `MeshOverride` on the character mesh and/or destroy old `AttachedMeshComp` + spawn new attach mesh at `AttachSocket`. Purely cosmetic. |
| `GetEquippedCostume` | Function (pure) | Any | Reads PlayerState. |

**Delegate:** `OnCostumeChanged(NewCostume : DA_Costume)` (UI/preview).

### 4.5 The MVP proof (System 5 minimal)
For the sandbox, build exactly **one** swap: a pickup actor `BP_ItemPickup_QuietShoes` (in `Content/_Project/Gameplay/`) — on player overlap → `CostumeComp.Server_EquipCostume(DA_QuietShoes)`. Verify: (1) an attach mesh appears (or material tint if no mesh handy), and (2) footstep/sprint loudness drops ~20% (read the loudness meter). That proves attach-mesh + modifier plumbing; the full wardrobe is parked.

### 4.6 attach to `BP_PlayerCharacter`
Add `BP_CostumeComponent` (name `CostumeComp`). On `BeginPlay` (server) → if `PlayerState.EquippedCostume` is null, equip `DA_SwimTrunks` (default). Bind PlayerState `OnRep_EquippedCostume → CostumeComp.ApplyCostumeVisual`.

### 4.7 unreal-mcp build calls (costume)
```
BlueprintTools.create("/Game/_Project/Data","DA_Costume",{refPath:"/Script/Engine.PrimaryDataAsset"})
add_variable + fields above (CostumeID name, LoudnessModifierMult float, SwimSpeedMult float, bIsDefault bool)
# create instances via DataAssetTools.create at /Game/_Project/Data/Costumes/DA_QuietShoes etc.
BlueprintTools.create("/Game/_Project/Components","BP_CostumeComponent",{refPath:"/Script/Engine.ActorComponent"})
add_event(bp,"Server_EquipCostume")   # Run-on-Server Reliable
add_function_graph(bp,"ApplyCostumeVisual"); add_function_graph(bp,"GetEquippedCostume")
compile_blueprint(bp, warnings_as_errors=true)
```

---

## 5. AlertDirector (on GameMode)

**Purpose.** Aggregate every player's loudness and every AI's detection into a single neighborhood **HEAT** value (0–100), decay it over time, and fire **escalation** at thresholds (Suspicious → Alert neighborhood state; eventually "spawn the cop" at Phase 5). Heat is the game's tension dial (Docs/01 §5.3, Docs/03 §3). **This is not a separate build step in the MVP order** — it's built *as part of "couple it all" (step 5)*, once Loudness and Detection AI exist to feed it. It is specced here because it is one of the four reusable core pieces.

- **Where it lives:** **on `BP_PlayerGameMode`** (server-only rules), *not* a separate actor. Implement as a set of functions + a small struct of state on the GameMode, OR (cleaner) as an `ActorComponent` `BP_AlertDirectorComponent` **attached to the GameMode** so the logic is encapsulated but still server-only. **Recommended: the component form** (`Content/_Project/Systems/BP_AlertDirectorComponent`, parent `ActorComponent`), added to `BP_PlayerGameMode`. GameMode is never replicated, so the director's working state is naturally server-only; it **writes results to GameState** (`NeighborhoodHeat`, `AlertLevel`) which replicate to clients for the HUD.

### 5.1 Member variables (on the director component — all server-only, None)

| Name | Type | Repl | Default | Notes |
|---|---|---|---|---|
| `AccumulatedHeat` | float | None | 0.0 | 0–100 internal. Mirrored to `GameState.NeighborhoodHeat` (Replicated) each update for HUD. |
| `HeatDecayPerSecond` | float | None | 3.0 | Heat cools when nothing loud/seen is happening. |
| `LoudnessHeatWeight` | float | None | 0.15 | Per-second heat added = Σ(player loudness/100) × this. All players sprinting adds heat fast. |
| `DetectionHeatBump` | float | None | 25.0 | Instant heat added when any AI transitions to **Alert** (spotted). |
| `SuspicionHeatBump` | float | None | 8.0 | Instant heat when any AI goes **Suspicious**. |
| `SuspiciousThreshold` | float | None | 30.0 | Heat ≥ → neighborhood `AlertLevel = Suspicious`. |
| `AlertThreshold` | float | None | 65.0 | Heat ≥ → `AlertLevel = Alert`. |
| `CopSpawnThreshold` | float | None | 90.0 | Heat ≥ → escalation event (Phase 5: spawn cop). MVP: just flag + optional homeowner speed-up. |
| `bCopDispatched` | bool | None | false | Latch so we escalate once. |

### 5.2 Functions/events (server-only)

| Name | Kind | Purpose |
|---|---|---|
| `TickHeat(dt)` | Event (server) | `loudSum = Σ over players (LoudnessComp.GetLoudness01())`; `AccumulatedHeat += loudSum × LoudnessHeatWeight × dt` minus `HeatDecayPerSecond × dt`; clamp 0–100. Push to `GameState.SetNeighborhoodHeat`. Re-evaluate `AlertLevel` against thresholds; if it changed → `GameState.SetAlertLevel` (RepNotify → HUD). Fire escalation if crossing `CopSpawnThreshold` and not `bCopDispatched`. |
| `NotifyDetection(NewState : E_AlertState)` | Function (server) | Called by an AI controller when its own state changes: add `DetectionHeatBump` (Alert) or `SuspicionHeatBump` (Suspicious). This is the **detection → heat** contract from System 4. |
| `NotifySensorTrip(WorldLoc)` | Function (server) | Motion-sensor light adds a local heat bump + can push nearest AI toward Suspicious. |
| `GetHeat01() → float` | pure | HUD / music intensity. |

**Delegate:** `OnEscalation(NewLevel : E_AlertState)` — GameMode subscribes to trigger spawn/dispatch rules; music system subscribes for the chase sting (Docs/01 §11).

### 5.3 The two contracts AlertDirector depends on
1. **Loudness contract (from §2):** every player's `LoudnessComponent.GetLoudness01()` is readable server-side (they are; server owns loudness). Director sums them each tick.
2. **Detection contract (to be honored by System 4's AI):** when a threat's Behavior Tree flips its alert state, its controller calls `AlertDirector.NotifyDetection(newState)`. Spec the AI controller (System 4) to make this call — that's the single integration point. Keep it a plain function call (both are server-side); no RPC needed.

### 5.4 Escalation table (MVP → forward-looking)
| Heat | AlertLevel | MVP behavior | Phase 5+ |
|---|---|---|---|
| 0–29 | Unaware | Homeowner patrols normally. | Windows dark. |
| 30–64 | Suspicious | Homeowner investigates last-known noise faster; `?` icons. | More windows lit. |
| 65–89 | Alert | Homeowner chases; music sting; sensor lights more sensitive. | Neighbors wake. |
| 90–100 | Critical | (MVP) homeowner move-speed +15%, flag `bCopDispatched`. | **Cop spawns** (car, street flashlight). |

### 5.5 unreal-mcp build calls (AlertDirector)
```
BlueprintTools.create("/Game/_Project/Systems","BP_AlertDirectorComponent",{refPath:"/Script/Engine.ActorComponent"})
add_variable(bp,"AccumulatedHeat","float")  # + HeatDecayPerSecond, weights, thresholds — all "None"
add_variable(bp,"bCopDispatched","bool")
add_event(bp,"TickHeat")   # server-only; guard HasAuthority
add_function_graph(bp,"NotifyDetection"); add_function_param(...,"NewState","E_AlertState",input_param=true)
add_function_graph(bp,"NotifySensorTrip"); add_function_graph(bp,"GetHeat01")
compile_blueprint(bp, warnings_as_errors=true)
# then add BP_AlertDirectorComponent as a component on BP_PlayerGameMode; it writes to GameState setters (§6)
```

---

## 6. Framework state: GameState / GameMode / PlayerState

This is the **non-negotiable discipline** (Docs/03 §2, CLAUDE.md). The scaffolding BPs already exist in `Content/_Project/Core/`:
- `BP_PlayerGameMode` (`/Game/_Project/Core/BP_PlayerGameMode`)
- `BP_PlayerGameState` (`/Game/_Project/Core/BP_PlayerGameState`)
- `BP_PlayerState` (`/Game/_Project/Core/BP_PlayerState`)
- `BP_PlayerController` (`/Game/_Project/Core/BP_PlayerController`)

Below is exactly what state must move onto each, with replication mode. **None of this lives on `BP_PlayerCharacter`.**

### 6.1 GameState — `BP_PlayerGameState` (replicated shared truth)

| Variable | Type | Repl | Default | Notes |
|---|---|---|---|---|
| `TeamScoreBanked` | int | Replicated | 0 | Safe points (survived escape). HUD reads. |
| `TeamScoreAtRisk` | int | **RepNotify** | 0 | Unbanked pooled score. `OnRep` → HUD "at-risk" pulse. Lost on team wipe. |
| `NeighborhoodHeat` | float | **RepNotify** | 0.0 | 0–100 from AlertDirector. `OnRep` → heat bar + music intensity. |
| `AlertLevel` | enum `E_AlertState` {Unaware, Suspicious, Alert, Critical} | **RepNotify** | Unaware | Neighborhood-wide alert. `OnRep` → shared team alert badge (Docs/07 §4 original-design note). |
| `NightTimeRemaining` | float | Replicated | 600.0 | Seconds (8–12 min night, Docs/01 §7). GameMode ticks it down. HUD wristwatch. |
| `bNightOver` | bool | **RepNotify** | false | Dawn reached → end-of-run. `OnRep` → results screen. |

**GameState functions (server setters, so only the server writes):** `SetNeighborhoodHeat`, `SetAlertLevel`, `AddTeamScoreAtRisk`, `BankTeamScore`, `LoseTeamAtRisk`, `TickNight`. Each guarded by `HasAuthority`.

### 6.2 GameMode — `BP_PlayerGameMode` (server-only rules, never replicated)

| Responsibility | Function | Notes |
|---|---|---|
| Scoring rules | `Server_AddScore(PS,Amount)`, `GetHopStreakMultiplier(PS)`, `Server_BankAtRisk(PS)`, `Server_LoseAtRisk(PS)` | §3.3. Single choke-points; write to PlayerState + GameState. |
| Heat/escalation | `BP_AlertDirectorComponent` (attached) + `OnEscalation` handler | §5. Spawns/dispatches on threshold (Phase 5). |
| Night timer | `TickNight(dt)` | Decrement `GameState.NightTimeRemaining`; at 0 → `bNightOver=true`, force everyone to results (unbanked at-risk lost unless already at stash). |
| Escape / detain / respawn | `Server_OnReachStash(PS)` → `Server_BankAtRisk`; `Server_OnCaught(PS)` → set `PS.bDetained=true`, `Server_LoseAtRisk(PS)`, respawn at start after delay | Docs/01 §6, §6 co-op detain/rescue. MVP: solo caught = respawn at start, lose at-risk. |
| Config refs | `DefaultPawnClass=BP_PlayerCharacter`, `GameStateClass=BP_PlayerGameState`, `PlayerStateClass=BP_PlayerState`, `PlayerControllerClass=BP_PlayerController` | Already scaffolded; verify on CDO. |

> GameMode exists **only on the server** (in a listen server, only the host has it). Never store anything clients must read on GameMode — put it on GameState.

### 6.3 PlayerState — `BP_PlayerState` (replicated, per player)

| Variable | Type | Repl | Default | Notes |
|---|---|---|---|---|
| `IndividualScoreAtRisk` | int | **RepNotify** | 0 | This player's unbanked contribution. `OnRep` → personal score HUD. |
| `IndividualScoreBanked` | int | Replicated | 0 | This player's safe total. |
| `DistinctPoolsHopped` | int | Replicated | 0 | For hop-streak multiplier (§3.3). GameMode reads/increments. |
| `CurrentLoudness` | float | Replicated | 0.0 | **Mirror** of the pawn's `LoudnessComponent.CurrentLoudness`, copied up so it survives on the player-identity object and is trivially readable by AlertDirector/other clients. (The component stays the authority; this is a convenience mirror the server sets. Optional — AlertDirector can read the component directly. Include only if HUD/co-op needs per-player loudness on the roster.) |
| `bDetained` | bool | **RepNotify** | false | Caught state. `OnRep` → "detained" overlay + (co-op) rescue prompt. |
| `EquippedCostume` | `DA_Costume` soft ref | **RepNotify** | DA_SwimTrunks | §4. `OnRep_EquippedCostume` → `CostumeComp.ApplyCostumeVisual`. |
| `LoadoutGadget` | `DA_Gadget` soft ref | **RepNotify** | null | Forward-looking; not built in MVP. One slot. |

**PlayerState functions:** `OnRep_IndividualScoreAtRisk`, `OnRep_bDetained`, `OnRep_EquippedCostume` (auto-created by RepNotify). Setters are called by GameMode only.

### 6.4 Enums / structs to create first
- `E_AlertState` (`Content/_Project/Data/E_AlertState`) : {Unaware, Suspicious, Alert, Critical} — used by GameState, AlertDirector, AI.
- `E_PoolTier` (`Content/_Project/Data/E_PoolTier`) : {Standard, HotTub, Infinity, Money}.
- `S_LoudnessAction` (`Content/_Project/Data/S_LoudnessAction`) — DT row struct (§2.6).

### 6.5 unreal-mcp build calls (framework state)
```
# enums/structs first (so variables can reference them)
# E_AlertState, E_PoolTier via the enum/struct creation tool; S_LoudnessAction as a struct

# GameState
add_variable(gs,"TeamScoreBanked","int");   set_variable_replication(gs,"TeamScoreBanked","Replicated")
add_variable(gs,"TeamScoreAtRisk","int");    set_variable_replication(gs,"TeamScoreAtRisk","RepNotify")
add_variable(gs,"NeighborhoodHeat","float"); set_variable_replication(gs,"NeighborhoodHeat","RepNotify")
add_variable(gs,"AlertLevel","E_AlertState");set_variable_replication(gs,"AlertLevel","RepNotify")
add_variable(gs,"NightTimeRemaining","float");set_variable_replication(gs,"NightTimeRemaining","Replicated")
add_variable(gs,"bNightOver","bool");        set_variable_replication(gs,"bNightOver","RepNotify")
add_function_graph(gs,"SetNeighborhoodHeat"); add_function_graph(gs,"AddTeamScoreAtRisk"); ...
compile_blueprint(gs, warnings_as_errors=true)

# PlayerState
add_variable(ps,"IndividualScoreAtRisk","int"); set_variable_replication(ps,"IndividualScoreAtRisk","RepNotify")
add_variable(ps,"IndividualScoreBanked","int"); set_variable_replication(ps,"IndividualScoreBanked","Replicated")
add_variable(ps,"DistinctPoolsHopped","int");   set_variable_replication(ps,"DistinctPoolsHopped","Replicated")
add_variable(ps,"bDetained","bool");            set_variable_replication(ps,"bDetained","RepNotify")
add_object_variable(ps,"EquippedCostume","/Script/Engine.PrimaryDataAsset"); set_variable_replication(ps,"EquippedCostume","RepNotify")
compile_blueprint(ps, warnings_as_errors=true)

# GameMode: add BP_AlertDirectorComponent as a component; add scoring/night/escape function graphs (§3.3, §6.2)
# verify CDO class refs: get_default_object(gm) → set_properties {gameStateClass, playerStateClass, defaultPawnClass, playerControllerClass}
```
> **Build order reminder:** enums/struct → GameState/PlayerState vars → compile → set CDO defaults → then the components that read them. Adding a var and setting its CDO default before compile silently fails (LESSONS).

---

## 7. HUD hooks (System 2/3 read-out — minimal, non-diegetic per Docs/07 §5)

Not a core "system" but the components are useless without a read-out. Build a single `WBP_HUD` (`Content/_Project/UI/WBP_HUD`) that binds to delegates/OnReps — **no polling**:
- **Loudness meter** (0–100 fill + 3-color band green/yellow/red per Docs/07 §4): bind `LoudnessComponent.OnLoudnessChanged`.
- **Score** (banked + at-risk, at-risk shown "unsafe"): bind `PlayerState.OnRep_IndividualScoreAtRisk` / `GameState.OnRep_TeamScoreAtRisk`.
- **Heat / neighborhood alert badge** (shared, team-visible — the original-design opportunity from Docs/07 §4): bind `GameState.OnRep_NeighborhoodHeat` + `OnRep_AlertLevel`.
- **Wristwatch / night timer:** read `GameState.NightTimeRemaining`.

Keep it cheap and reliable (the "Minimal HUD Paradox" warning, Docs/07 §5). Diegetic tells (wet footprints, sensor glow, head-turns) are a later polish layer, not MVP.

---

## 8. Build sequence for these systems (respecting Docs/02 §5 order)

| Step | System | This spec | Depends on |
|---|---|---|---|
| (done) | Movement | — | — |
| **A** | Enums/structs + GameState/PlayerState vars | §6.4, §6.1, §6.3 | nothing — do first so components can reference them |
| **B** | **LoudnessComponent** | §2 | GameState/PS scaffolding; attach to character |
| **C** | **PoolScoringComponent + PoolVolume** | §3 | GameMode score rules (§3.3), PlayerState score vars |
| **D** | Detection AI (System 4 — separate detection-tuning doc) | §2.5, §5.3 contracts only | LoudnessComponent noise events |
| **E** | **AlertDirector** (couple it) | §5 | Loudness (B) + Detection (D) to feed heat |
| **F** | **CostumeComponent** + one pickup | §4 | LoudnessComponent (for the modifier proof) |
| **G** | HUD + tune + playtest | §7 | all of the above |

> **Do not build D/E/F ahead of B/C.** The MVP order exists to prove the loop cheaply. This doc gives forward-looking specs (cop escalation, gadgets, co-op crew bonus) so we don't paint ourselves into a corner — but the *work queue* is still Loudness → Scoring → Detection → couple → costume.

---

## 9. Open tuning questions (resolve in playtest, not now)
- Loudness `DecayRatePerSecond` vs `HearingRangeAtMaxLoudness` — tune together; the "close call" feeling (Docs/02 §4 criterion 3) lives in this pair.
- Pool `DecayHalfLife` vs `HopStreak StreakStep` — do players *feel* pushed to keep moving, or do they camp? Adjust the ratio.
- CrewSplashBonus cap — with 8 players a single pool could trivialize scoring; cap and test at co-op scale (Phase 3).
- Heat `LoudnessHeatWeight` — one loud friend should raise the block's heat for everyone (Docs/01 §6) without being unfair. Tune at 2p first (Phase 2).

---

*This is the reusable, server-authoritative core. Everything here honors the one discipline that makes Phase 2 co-op a layering job, not a rewrite: authoritative state on GameMode/GameState/PlayerState, the pawn cosmetic-only. Build in the §8 order.*
