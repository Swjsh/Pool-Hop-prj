# Pool Hop — Design Review Punch-List (Completeness · Consistency · Buildability)

*Version 0.1 — skeptical review pass. Last updated 2026-06-30. Reviews: `Docs/design/00`–`08` against `Docs/02` (MVP scope), `Docs/03` (architecture + server authority), `CLAUDE.md`, `Docs/LESSONS.md`, and the on-disk repo state.*

> **What this doc is.** A punch-list of everything that (a) violates MVP scope / server-authority / build order / folder conventions, (b) contradicts another doc, (c) is missing or thin against what was asked for, or (d) is too vague to actually build via `unreal-mcp`. Each item cites the doc + section. Severity: **[BLOCKER]** will produce a wrong build or a broken asset; **[HIGH]** a real contradiction an engineer will hit; **[MED]** an inconsistency or gap worth fixing before the affected step; **[LOW]** polish/clarity.
>
> **Headline verdict.** The design package is unusually strong: authority discipline is correct and consistently repeated, the build order is respected everywhere, and `06`/`04`/`08` are genuinely build-ready. **The dominant risk is not vision — it is drift between docs written in parallel.** The same variable, enum, asset, and file appear under **different names and different values** across `04`/`05`/`06`/`07`. If an engineer builds each doc literally, the systems will not connect (Loudness writes `CurrentLoudness`, HUD reads `Loudness`; Watcher writes `SeenByAlertState`, HUD reads `DetectionAlpha`; etc.). Fix the naming/enum/number contradictions below **before** Step 1, because Step 1 creates the variables every later step binds to.

---

## TOP 5 — fix these first

1. **[BLOCKER] The framework-state variable names disagree across docs, so components won't connect.** `06` §6 (the authoritative table, and what `08` Step 1 builds) names them `TeamScoreBanked`/`TeamScoreAtRisk`/`NeighborhoodHeat`/`AlertLevel`/`NightTimeRemaining` on GameState and `IndividualScoreAtRisk`/`CurrentLoudness`/`EquippedCostume` on PlayerState. But `07` §3.1/§3.9 binds the HUD to `ScoreBanked`/`ScoreAtRisk`/`NeighborhoodAlert`/`NightSecondsRemaining`/`Heat`/`Loudness`/`DetectionAlpha`, and `04` §4/§8 writes `DetectionMeter`/`SeenByAlertState`/`NeighborhoodAlert`. These are the **same values under three names**. Pick one canonical set (recommend `06`'s, since `08` Step 1 already builds it) and update `04`, `05`, `07` to match. This is the single highest-leverage fix — every later step binds to these names.

2. **[BLOCKER] `E_AlertState` has 3 states in some docs and 4 in others.** `06` §6.4 and `08` Step 1 define `{Unaware, Suspicious, Alert, Critical}` (4). `04` §6 defines `{Unaware=0, Suspicious=1, Alert=2}` (3, explicitly enumerated) and its BT/service only ever uses three. `07` §3.6 lists `{Unaware, Suspicious, Alert}` (3). If the enum is built with 3 values, `06`'s `AlertLevel=Critical` at heat ≥90 (§5.4) is unassignable; if built with 4, `04`'s decorators still work but its doc is wrong. **Decide: is "Critical" a distinct `E_AlertState` member or just the top heat band?** Recommend keeping 4 in the enum (Critical is referenced by AlertDirector §5.4) and correcting `04` §6 / `07` §3.6 to list all four.

3. **[BLOCKER] The Watcher's cone geometry is contradicted between the canonical doc and the neighborhood doc.** `04` §5.1/§8 and `06`/`08` fix the "canonical AI-perception profile" at **`PeripheralVisionHalfAngle=35°` (70° cone), `LoseSightRadius=1800`**. But `02` §4 (Maple Court) hardcodes **`PeripheralVisionHalfAngle=45°` (90° cone), `LoseSightRadius=1700`**, and even says "these are the sandbox values — do not re-tune per map." They are **not** the sandbox values. `01` §2.4(a) also uses "45°" as its cone-mask example. Since `04` is declared canonical and every doc claims cones are identical across all AI, `02` and `01`'s cone numbers are a direct violation. Fix `02` §4 to 35°/1800 (or, if 45° is actually wanted, change the canonical `04` and propagate — but pick one).

4. **[HIGH] The Watcher body/BP path and class name are inconsistent across `04`, `05`, `03`, and `08`.** `04` §4/§8 builds `BP_WatcherCharacter` + `BP_WatcherController` under `_Project/AI/Watcher/`. `05` §5.1 builds `BP_Watcher` (single actor) at `_Project/AI/BP_Watcher` and also calls it `BP_Homeowner` (§8 checklist) and `BP_HomeownerCharacter`. `02` §4 references `BP_HomeownerCharacter`. `03` §8 reuses "`BP_Homeowner`". Four names (`BP_WatcherCharacter`, `BP_Watcher`, `BP_Homeowner`, `BP_HomeownerCharacter`) for one actor, in three folders. Pick one canonical path+name (recommend `04`'s `_Project/AI/Watcher/BP_WatcherCharacter` + `BP_WatcherController`) and update `02`, `03`, `05`.

5. **[HIGH] Input-action folder path conflicts with the existing on-disk convention.** `07` §2.1 says create new Input Actions under `Content/_Project/Core/Input/Actions/`. But the existing System-1 input assets (per `CLAUDE.md` "Current state" and LESSONS) live at `Content/Input/…` (`IA_Move`, `IMC_Default`, etc.), and `ARCHITECTURE.md`/`03` §6 don't define a `Core/Input/` home. Building `IA_Interact/Dive/SwimUpDown` in a *new* second location while `IMC_Default` lives elsewhere risks the same "which asset is real" confusion that caused the LESSONS input bugs. Decide one input home and state it in `CLAUDE.md`/`ARCHITECTURE.md`; update `07` §2.1 to match where `IMC_Default` actually lives.

---

## A. MVP-scope / build-order / server-authority / folder violations

- **[MED] `07` puts the air/breath tick location ambiguously "on PlayerState OR a component" and the component's owner is unusual.** `07` §2.4 and §3.9 say `AC_BreathComponent` is "added to PlayerState." Adding an `ActorComponent` to a `PlayerState` actor is legal but non-obvious (PlayerState is not a pawn); several MCP `add_component` flows assume an Actor/Character. This is authority-correct (air is per-player survival state, belongs off the pawn) but **under-specified for MCP** — name the exact tool call and confirm the component ticks on the server only. Flag as buildability, not authority.

- **[MED] Costume `SwimSpeedMult` / `MoveSpeedMultiplier` edits `MaxSwimSpeed` on the pawn — verify this isn't "gameplay truth on the pawn."** `06` §4.2 and `05` §4 apply a swim-speed multiplier to `CharacterMovementComponent.MaxSwimSpeed`. This is defensible (movement lives on the pawn via CharMoveComp, which replicates), but the **source of truth** (the costume's multiplier) is on PlayerState and the *application* is a server-set on the pawn's movement component. Spell out that the server sets it and it's a movement value (allowed), not an authoritative gameplay value — otherwise a reviewer applying the authority grep gate (`07` §5) will flag it. Minor, but the docs should preempt it.

- **[LOW] `05` §5.1 gives the Watcher body path `_Project/AI/BP_Watcher` (flat), but `04` uses `_Project/AI/Watcher/…` (subfolder) and `03` uses `_Project/AI/Grotto/…`.** Consistent with finding #4; folder nesting should be declared once.

- **[LOW] `01` §9 introduces `_Project/Art/Materials/` and `_Project/Gameplay/Materials/` and `_Project/UI/FX/` — new subfolders not in `ARCHITECTURE.md` §1 / `03` §6.** These are reasonable, but `ARCHITECTURE.md`'s canonical folder list (`Core,Characters,Components,AI,Systems,Gameplay,UI,Data,Maps`) doesn't mention `Art`. Either add `Art/` to the canonical list or move `M_ToonMaster` under `Gameplay/Materials`. Right now `08` Step 7 says `M_GreyboxToon` lives at `_Project/…` without a path while `01` §2.2 says `_Project/Gameplay/Materials/M_GreyboxToon` and `01` §9 says `Gameplay/Materials/` — internally consistent within `01`, but not reconciled with the top-level architecture doc.

- **[LOW] No doc violates the "build only the current system" rule in *sequencing*** — every forward-looking doc (`01` §3–7, `02`, `03`) correctly tags itself Phase 4+/parked. Good. The violations above are naming/number drift, not scope creep.

---

## B. Contradictions between docs (values & facts)

- **[BLOCKER] Loudness→hearing numbers disagree between the canonical Loudness spec and the canonical AI spec.** `06` §2.2/§2.5 sets `HearingRangeAtMaxLoudness = 2500` (25 m at loudness 100) and tells the AI side to set `HearingRange = 2500`. `04` §5.2 sets the Watcher's `HearingRange = 1200` (12 m) baseline and its worked example ("sprinting ~8.4 m, splash ~12 m") assumes 1200. These are the two halves of the same contract (`06` §2.5 explicitly says "tune these two numbers together, never one alone") and they are set to **different numbers in the two docs**. `08` Step 4 propagates `04`'s 1200. **Pick one** hearing range and make `06` §2.5 and `04` §5.2/§8 agree, or the "mechanical heart of the stealth loop" is mistuned from day one.

- **[HIGH] Detection fill/decay timing differs between the canonical AI doc and the neighborhood doc.** `04` §7.3/§8 (canonical): fill **1.5 s**, decay **3.0 s**. `02` §4: "Detection bar fill ~**1.2 s** in-cone; cools in ~**2 s**." Again `02` claims these are "the sandbox values" when they aren't. Correct `02` to 1.5/3.0.

- **[HIGH] Loudness action bump for Vault/Splash disagrees between `06` and `07`.** `06` §2.6 `DT_LoudnessActions`: `Action.Vault InstantBump=30`, `Action.SplashEnter=45`. `07` §2.6 movement tuning: `VaultNoise=35`, `WaterEntryNoise (splash)=55`, `SqueezeNoise=20` (squeeze has no row in `06`'s table at all). Two docs seed the same loudness event with different magnitudes, and `07` adds a `FenceClimb`/squeeze source `06` doesn't table. Reconcile the loudness values into the single `DT_LoudnessActions` table (`06` §2.6 should be the source of truth; `07`'s per-verb "noise" numbers are stubs that must equal the DT rows).

- **[HIGH] Night length is stated three ways.** `06` §6.1: `NightTimeRemaining` default **600** (10 min). `07` §3.1: `NightSecondsRemaining` default **600**. `06` §6.1 note: "8–12 min night (Docs/01 §7)." `04`? n/a. These are consistent at 600 but the *variable name* differs (finding #1) and the "8–12 min" prose invites someone to change one default and not the other. Lock the name and the number.

- **[MED] Player `SprintSpeed` vs Watcher `ChaseSpeed` relationship is asserted but the numbers are only equal by luck.** `04` §7 sets `ChaseSpeed=650` "just above player SprintSpeed ≈ 600"; `07` §2.6 sets `SprintSpeed=600`. Consistent today — but they live in two different Data Assets (`AIP_WatcherProfile` vs `DA_MovementTuning`) with no cross-reference enforcing "chase must stay ~50 above sprint." Add a note in both that these two knobs are a *pair* (like the loudness/hearing pair) so a playtest tweak to one doesn't silently break the "escape must be reliable" rule (`04` §13 knob 4).

- **[MED] Pool base-score numbers: `06`/`08` say money pool base **18**/s; `03` (grotto) says **30**/s; `02` expresses pools as **multipliers** (×1.0/1.3/1.5/2.0) not absolute rates.** These aren't strictly contradictory (grotto is a different zone; Maple Court uses multipliers on a base), but `02`'s ×2.0 money pool on a base 10 = 20/s, while `06`'s sandbox money pool D is authored at absolute **18**/s. Decide whether pools are tuned by **absolute `BaseScorePerSecond`** (as `BP_PoolVolume` §3.1 actually implements) or by a **multiplier** (as `02` describes) — the `BP_PoolVolume` has no "multiplier" field, so `02`'s ×N language doesn't map to a real property. Fix `02` to set absolute `BaseScorePerSecond` per pool (10/13/15/20) to match the actual variable.

- **[MED] `bDetained` / detain-respawn target differs.** `04` §9 respawns the caught player at "the stash/start zone" via `TeleportPlayerToStashZone`. `02` §4 and `06` §6.2 say "respawn at start / PlayerStart." Stash zone and PlayerStart are the same location in Maple Court (§3.1 playground) but *not* necessarily in the sandbox. Name the single respawn target (recommend the stash zone actor, since it exists by Step 3) and use it everywhere.

- **[LOW] `01` §2.4(a) vision-cone `SightRadius` example uses "1200 uu" while the canonical is 1400.** Cosmetic (it's an illustrative material comment) but since `01`'s decal is supposed to *equal* the perception radius, the example should read 1400 to avoid a copy-paste that desyncs art from truth.

- **[LOW] `05` §5.3 flashlight `AttenuationRadius ~1200` vs canonical `SightRadius 1400`.** The flashlight cone is supposed to visually equal the sight cone (`05` §5.3 says so explicitly). 1200 ≠ 1400. Set the flashlight attenuation to 1400.

---

## C. Requested-but-missing or thin coverage

The user asked for whole-game design, style, neighborhood, underground pools, AI watcher, characters, and one level/map. Coverage is broadly **complete** — every requested area has a dedicated build-ready doc. Gaps within them:

- **[HIGH] There is no single "whole-game design" doc that supersedes the source GDD — the Design Bible (`00`) synthesizes but defers the actual game vision to `Docs/01_Game_Design_Document.md`, which is *outside* the `design/` folder the review was scoped to.** `00` §1–3 is a good synthesis, but the full loop (Home Base → neighborhoods → meta/upgrades → virality) lives in the source `Docs/01` GDD and `Docs/05` market doc, not in `design/`. This is fine *if intentional*, but a reader told "the whole-game design is in `design/`" will find only the MVP-facing slice fleshed out. **Recommend `00` explicitly point to `Docs/01` §4/§9 as the canonical full-loop/meta spec** so nothing reads as missing.

- **[MED] The map/level deliverable is split and the *sandbox* map (the one actually being built now) has no placement doc.** `02` is a full grey-box plan — but for **Maple Court (Phase 4)**, not for `L_Sandbox_Movement` (the map Systems 2–5 are being built and tuned on *now*). `08` Steps 3–5 place pools/patrol points/stash/sensor "in `L_Sandbox_Movement`" with only the loose ASCII sketch from `Docs/02` §3 and no coordinates. **The near-term buildable level (sandbox) is the one lacking a coordinate plan** — the thoroughly-specced level is the one that's parked. Add a short coordinate table for the sandbox pools A–D + stash + sensor + patrol points (reuse `02`'s style), or explicitly say "sandbox pool placement is ad-hoc, trace-and-drop, no authored coords."

- **[MED] Characters doc is thin on the *player's* visual identity and animation-state details for the sandbox.** `05` is strong on the costume spine and skeleton decision, but the actual **`ABP_PoolHopCharacter` state machine** (§6.4) is one paragraph, and the swim/underwater/vault/caught montage wiring — which Systems 2–4 need — is deferred to "when the milestone lands" without a build spec. For a doc that's otherwise build-ready, the anim graph is the thinnest part. Acceptable (anims are placeholder-first) but flag it so no one expects §6.4 to be buildable as written.

- **[MED] No audio spec anywhere, though multiple docs depend on audio cues.** `07` §3.8 (heartbeat, relief cue, gasp), `04` §11 (chase sting), `01` §6 (TV flicker audio), `03` §6.2 (echo) all call for specific SFX, and `01` §0 confirms `kenney_impact-sounds` is staged — but no doc maps cue → asset → trigger. MVP scope (`Docs/02` §2) explicitly parks "audio polish," so this is *correctly* out of scope, but the close-call feedback (`07` §3.8) is load-bearing for success-criterion 3 and leans on a heartbeat SFX with no source named. **Name the one placeholder heartbeat/splash/footstep asset** from the staged Kenney pack so the close-call arc is testable, per `Docs/02` §2's "one placeholder splash + one footstep is enough."

- **[LOW] "Neighborhood" as a system (map screen, multiple neighborhoods, The Heights) is named but not designed.** `03` assumes "The Heights" exists (Doc 01 §8) but there is no Heights blockout — only Maple Court. This is correctly parked (Phase 5), but if the user expected a *second* neighborhood spec, it's not here. Confirm scope.

- **[LOW] Win/lose + end-of-run/results screen is under-specified.** `06` §6.1 `bNightOver → results screen` and §6.2 "force everyone to results" reference a results/end screen that no doc designs (not even a stub). `07` §3 explicitly parks menus. Fine for MVP (there's a bare start/restart per `Docs/02` §2), but the dawn/night-over path has a dangling "results screen" with no owner.

---

## D. Too vague to build via unreal-mcp (name them)

These are places where an MCP-driving engineer would have to invent specifics the doc should have pinned:

- **[HIGH] Enum/struct creation has no named MCP tool.** `06` §6.5 and `08` Step 1 say "create `E_AlertState`, `E_PoolTier`, `S_LoudnessAction` via the enum/struct creation tool" but never name it (unlike every other asset, which names `BlueprintTools.create`/`DataAssetTools.create`/`MaterialTools.create_material`). Blueprint Enumerations and Structs are created by a *different* mechanism than Blueprint classes. **Name the exact tool** (or flag that it may require `execute_tool_script` Python if no first-class tool exists) — this is Step 1, the very first build action, and it's the least-specified.

- **[HIGH] Marking an event "Run on Server, Reliable" is described as a manual node-details toggle with no MCP call.** `06` §2.8 says `add_event(bp,"Server_ReportAction") # then mark Run-on-Server + Reliable in node details`; `04`/`05` do the same. Setting an event's replication flags (RPC type + reliability) via MCP is not a documented `BlueprintTools` operation in the skills. **This is a load-bearing gap** — every `Server_*` RPC in the package (Loudness, Scoring, Costume, Hide, Dive) depends on it. Confirm the MCP path (property-set on the K2Node? `execute_tool_script`?) or the whole "client → request → server" contract can't be built as specced. Add a LESSONS entry once solved.

- **[HIGH] Setting a `RepNotify` variable and getting the auto-`OnRep_` graph is asserted but the array/soft-ref cases are unspecified.** `06` §0 says `set_variable_replication(bp,name,"RepNotify")` auto-creates `OnRep_`. But several variables are **soft object refs** (`EquippedCostume : DA_Costume soft ref`) or **arrays** (`OccupantPawns : Array<Pawn>`), and `06` §3.7 itself notes you `add_object_variable` then "flip to Array in details" — another manual step with no MCP call named. Pin how arrays and soft-refs are created + replicated via MCP.

- **[MED] `AIPerceptionComponent` sense configs "read from the profile on BeginPlay and apply" — the apply is hand-waved.** `04` §5/§8 says the controller reads `AIP_WatcherProfile` and "applies §5.1/§5.2 values (Detect Neutrals=true on both)." Programmatically configuring `AISense_Sight`/`AISense_Hearing` configs on an `AIPerceptionComponent` at runtime (vs. authoring them in the component's Details) is fiddly in Blueprint. Specify whether the senses are **authored in the component (static)** or **set in BeginPlay from the DA (dynamic)** — the doc implies dynamic but that's the harder path and needs a named node sequence.

- **[MED] EQS assets (`EQS_WatcherSearch`, `EQC_ObserverIsSelf`) have no MCP creation path.** `04` §7.4/§8 specs the query generator/tests/context in detail, but EQS assets and `EnvQueryContext_BlueprintBase` subclasses may not be creatable via the current `BlueprintTools`/`DataAssetTools`. `04` §7.4 *does* offer a fallback ("start WITHOUT EQS, hand-author search offsets") — good — but the primary path's buildability via MCP is unconfirmed. Mark EQS as "if MCP can't create it, use the hand-authored fallback" in the DoD.

- **[MED] Behavior Tree authoring via MCP is assumed but not demonstrated.** `04` §7/§8 and `08` Step 4 describe the full `BT_Watcher` node tree (Selector, decorators with Observer-Aborts=Both, MoveTo/Wait/RunEQS, Services) and say "build per §7." The skills cover Blueprint *graphs* (`write_graph_dsl`) but not **Behavior Tree / Blackboard asset authoring** (a different asset type with its own node model). This is the single biggest buildability unknown in the priority deliverable. **Flag explicitly**: confirm the MCP toolset can create BT/BB assets and wire decorators/services, or plan for `execute_tool_script`. Recommend a spike before Step 4.

- **[MED] Niagara systems (`NS_NoiseRing`, `NS_PoolSplash`) are specced visually but Niagara authoring via MCP is unaddressed.** `01` §2.4(b)/§4 give burst/color/lifetime detail, but creating and configuring a Niagara system is almost certainly outside `MaterialTools`/`BlueprintTools`. Since these ship "with System 4" and are readability-critical, either confirm an MCP path or downgrade the first pass to a simple decal/material ring (which the material recipe *can* build) and defer real Niagara to look-dev.

- **[MED] `WidgetComponent` overhead icon + UMG widget authoring depth.** `04` §11, `01` §2.4(c), `07` §3 spec a rich UMG tree (nested Canvas/Overlay/ProgressBar/WidgetAnimation). The skills demonstrate materials/Blueprints/scene but **not UMG widget-tree construction via MCP** (adding widgets to a `UserWidget`, binding properties, authoring `WidgetAnimation`s). `07` is entirely HUD. **Confirm the MCP UMG authoring path** or flag the HUD as the second big buildability spike alongside BTs.

- **[LOW] Deferred-decal vision cone (`M_VisionCone`, `MD_DeferredDecal`) polar-angle masking.** `01` §2.4(a) says "convert decal-space UV to polar, mask abs(angle) < half-angle." Buildable via `MaterialTools.add_expression`, but the exact node chain (UV → centered → atan2 → compare) isn't given, and `atan2`/polar in the material graph is non-trivial. Provide the node list or accept a simpler triangular-mask first pass.

- **[LOW] `BTS_UpdateDetection` writes to `TargetActor.PlayerState.DetectionMeter` — the cast/getter chain from a BT service to the player's PlayerState isn't spelled out.** `04` §7.3 pseudocode does `TargetActor.PlayerState.DetectionMeter = …`. From a `BTTask/Service` graph, getting the possessed target's PlayerState and setting a replicated var is a specific node chain (GetBlackboardValueAsObject → Cast to PlayerCharacter → GetPlayerState → Cast to BP_PlayerState → Set). Name it, given the DSL "member vars need explicit getters" LESSON.

---

## E. Positive notes (what NOT to change)

- Server-authority discipline is **correct and consistently stated** in every doc (`00` §6, `01` §0, `04` §2, `05` §9, `06` §0, `07` §0, `03` §7). No doc puts authoritative state on the pawn. This is the hardest thing to get right and the package gets it right.
- Build order (Loudness → Scoring → Detection → couple → costume) is respected and repeated everywhere; all forward-looking work is explicitly parked with phase tags.
- `08` Implementation Roadmap is genuinely dependency-ordered and each step has a real Definition of Done with the save/size/compile guard baked in (LESSONS-aware).
- The LESSONS gotchas (0-byte saves, hard-ref breakage, non-compiling BP freezes PIE, non-flat floor, HWRT-off) are threaded through every build sequence. Good institutional memory.
- The grotto doc (`03` §10) earning its keep by *pressure-testing* the data-driven seams of Scoring/Loudness/Heat is exactly the right justification for speccing parked work.

---

## Suggested fix order

1. **Reconcile the canonical name/enum/number tables first** (findings #1, #2, TOP-5) — do this as an edit pass on `06` (make it the single source of truth for state + loudness table), then propagate names into `04`/`05`/`07`. This unblocks `08` Step 1 cleanly.
2. **Reconcile the AI numbers** (cone 35°, hearing range, fill/decay) across `04`/`02`/`01` — `04` wins.
3. **Pin the Watcher BP name/path and the input-actions folder** (findings #4, #5) in `CLAUDE.md`/`ARCHITECTURE.md`, then fix the docs.
4. **Run the buildability spikes** (Section D: BT/BB, UMG, Niagara, enum/struct creation, Server-RPC flags via MCP) *before* committing to Step 4/Step 7 — these are the real unknowns, and a 30-minute MCP probe each will either confirm the plan or send you to `execute_tool_script`. Log each result in LESSONS.
5. Everything else is MED/LOW and can be fixed in-step.

*Nothing here changes the vision or the architecture — the package's bones are sound. The work is de-drifting the parallel-authored docs into one consistent set of names, enums, and numbers, and de-risking the handful of MCP asset types (Behavior Trees, UMG, Niagara, enums) the skills haven't yet exercised.*
