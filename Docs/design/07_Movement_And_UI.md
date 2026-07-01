# Pool Hop — Movement Polish + UI/HUD Build Spec

*Design/build spec. Version 0.1 — 2026-06-30. Engine: Unreal Engine 5.8, Blueprints-first.*

This document specifies two deliverables, both build-ready for an engineer driving the editor via the `unreal-mcp` plugin:

1. **Movement Polish** — extends the already-built System 1 on `BP_PlayerCharacter` with hide-in-bush, underwater breath-hold (air meter), hedge-squeeze, plus consolidated tuning tables (speeds, crouch height, vault trace, buoyancy/swim).
2. **UI / HUD** — a UMG HUD (loudness meter, at-risk vs banked score, `?`/`!` alert icons + screen-edge detection indicator, diegetic wristwatch/night timer, multi-channel close-call feedback).

It is grounded in `Docs/07_Movement_Physics_UI_Research.md` (feel/UI research), `Docs/01_Game_Design_Document.md` §5 (mechanics), `Docs/02_MVP_Vertical_Slice.md` (scope/build order), `Docs/03_Technical_Architecture.md` §2 (server authority), and `Docs/LESSONS.md` (MCP gotchas).

> ⚠️ **CANON OVERRIDE ([CANON.md](CANON.md) wins) — this doc's HUD binds to variable names that DO NOT EXIST after Step 1.** `ScoreBanked`→`TeamScoreBanked`, `ScoreAtRisk`→`TeamScoreAtRisk`/`IndividualScoreAtRisk`, `NeighborhoodAlert`→`AlertLevel`, `NightSecondsRemaining`→`NightTimeRemaining`, `Heat`→`NeighborhoodHeat`, `Loudness`→`CurrentLoudness`. Bind to the **canonical** names (CANON §"Verified drift resolutions" has the full table) or every HUD element silently reads 0.

---

## 0. Ground Rules (do not violate)

- **Server authority (Tech doc §2).** Every authoritative/shared value — loudness, score (at-risk + banked), alert level, night timer, heat, air/breath — is owned by GameMode (rules) / GameState (replicated shared truth) / PlayerState (replicated per-player). **The character/pawn holds movement (via `CharacterMovementComponent`) + cosmetic/local feedback ONLY.** The HUD **reads replicated state**, never local gameplay variables.
   - *Exception, explicitly allowed:* the **air/breath meter** is per-player survival state → it lives on **PlayerState** (replicated, per-player), not the pawn. The pawn only *requests* "I am submerged / surfaced"; the server ticks the air value down/up and replicates it. This keeps co-op a layering job.
- **MVP scope (MVP doc §5).** System 1 (movement) is DONE. Build order is Loudness → Scoring → Detection AI → couple → costume. **This spec is the movement-polish + UI slice** that supports that loop. Where a HUD element reads a value a later system owns (score, alert, loudness), the spec names the **binding source and a safe placeholder** so the widget builds and animates now against stub GameState/PlayerState values, then goes live when the owning system lands. Nothing here blocks on Systems 2–4.
- **Folder convention.** Our content under `Content/_Project/{...}`. Prefixes: `BP_`, `WBP_` (widget blueprints), `M_`/`MI_`, `IA_`/`IMC_`, `L_`, `SB_` (sandbox grey-box props), `DT_`/`DA_` (data table/asset).
- **Ray tracing is OFF** (`r.RayTracing=False`, see LESSONS) — assume Lumen software / simple lighting. No HUD/feedback effect may depend on HWRT (e.g. no ray-traced reflections in the vignette material).
- **Prefer Blueprint.** C++ is flagged explicitly where it would help but is **not required** for the MVP.

---

## 1. Current Movement State (baseline — already built)

Per `CLAUDE.md` "Current state", `BP_PlayerCharacter` (in `_Project/Characters`, parented off the ThirdPerson template) already has:

- **Walk / Crouch / Sprint / Jump / Vault / basic Swim.**
- Variables (on the character, movement-cosmetic only — allowed): `WalkSpeed`, `SprintSpeed` (floats driving `CharacterMovement.MaxWalkSpeed`); crouch uses `MaxWalkSpeedCrouched`; `TryVault` does a forward trace + `LaunchCharacter`, gated ahead of Jump.
- Swim works because the pool is a level-placed `PhysicsVolume` with `bWaterVolume=true` → `CharacterMovementComponent` auto-switches to `MOVE_Swimming` when the capsule center enters (see LESSONS: "PhysicsVolume cannot be a content-Blueprint parent").
- Enhanced Input rebuilt: `IA_Move/Look/MouseLook/Jump/Crouch/Sprint`, `IMC_Default`, `IMC_MouseLook`.

**This spec ADDS to that baseline. It does not rebuild it.** New input actions, new components, new states, new tuning — layered on.

---

## 2. Movement Polish — New Verbs & Feel

### 2.1 New Input Actions

Create under `Content/_Project/Core/Input/Actions/` (via `DataAssetTools.create`, `InputAction` class — see LESSONS on the 0-byte gotcha: after create, `save_assets([])` then `find ... -size 0` before trusting):

| Asset | Value Type | Default Key | Purpose |
|---|---|---|---|
| `IA_Interact` | Digital (bool) | `E` | Enter/exit bush hide; grab/context (also reused later for pickups). |
| `IA_Dive` | Digital (bool) | `Left Ctrl` (context: while swimming) | Submerge / surface toggle while in a water volume. |
| `IA_SwimUpDown` | Axis1D (float) | `Space` (+1) / `Left Ctrl` (−1) | Direct vertical swim axis (research §3: Subnautica-style up/down, NOT pitch-and-thrust). |

Add these to `IMC_Default` (mapping JSON shape per LESSONS "Enhanced Input mapping JSON shape"). `IA_SwimUpDown`: bind `Space` plain (+1), `Left Ctrl` with `InputModifierNegate` (−1). Because `Space` is already Jump and `Left Ctrl` already Crouch, **gate by movement mode**: the Jump/Crouch handlers early-out when `CharacterMovement.MovementMode == MOVE_Swimming`, and the swim handlers early-out when NOT swimming. (Same physical keys, mode-switched meaning — cheaper than a separate swim IMC, and avoids the multi-context ambiguity that bit us in LESSONS.)

### 2.2 Verb: Hide-in-Bush (crouch-in-bush hide)

Research basis: GDD §5.5 (hide in bushes), research §4 (stealth legibility), §5 (diegetic-first). Ghillie/bush interplay noted for later costume (GDD §5.6) — **do not build the costume perk now**, just the hide state + hook.

**Bush actor** — `Content/_Project/Gameplay/BP_BushHide` (parent `Actor`):
- Components: `StaticMeshComponent` (`SB_Bush` grey-box mesh or a scaled cube for MVP) + a `BoxComponent` named `HideVolume` (overlap only, `collisionEnabled = QueryOnly`, object type `WorldDynamic`, generate overlap events true). Box ~150×150×180 cm.
- Variables: `ConcealmentStrength` (float, default `1.0`, 0–1) — how fully it hides (feeds Detection AI later); `bBlocksSightWhenStill` (bool, default true).
- **No authoritative state on the bush.** It only reports overlap; whether the player is "hidden" for detection purposes is resolved server-side later by the Detection AI reading `bIsHidden` off PlayerState.

**Player-side (character, cosmetic request only):**
- New **bool `bIsInBushVolume`** (character-local, NOT replicated — it's a raw overlap fact) set by `HideVolume` begin/end overlap.
- On `IA_Interact` while `bIsInBushVolume && !swimming`: call server RPC **`Server_SetHidden(true)`** (validated on `BP_PlayerState`). Server sets replicated **`bIsHidden`** on PlayerState and (later) tells the LoudnessComponent to apply a **hide loudness cap** (loudness cannot exceed ~15 while hidden and still). Leaving the volume or moving faster than the crouch-walk threshold calls `Server_SetHidden(false)`.
- Cosmetic: on `OnRep_bIsHidden`, play a rustle SFX + brief camera dip; spawn a subtle leaf-VFX (deferred, optional). The **HUD "hidden" pip** (see §3.7) reads `PlayerState.bIsHidden`.

> Authority note: the character NEVER decides it is safe. It requests hidden; PlayerState (server) owns `bIsHidden`; Detection AI (later) reads that replicated bool. This is why hide is a PlayerState value, not a pawn bool.

### 2.3 Verb: Hedge-Squeeze

Research basis: research §1 (physics-reactive traversal beats canned prompts), GDD §5.5 (hedge-squeezing as connective tissue between yards). MVP scope: a **bounded, controlled squeeze**, not full physics ragdoll (research §2 "controllability ceiling").

**Hedge actor** — `Content/_Project/Gameplay/BP_HedgeSqueeze` (parent `Actor`):
- Components: two `StaticMeshComponent` hedge halves + a central `BoxComponent` `SqueezeChannel` (~80 cm wide gap, overlap only) + arrow `EntryDir` marking the pass-through axis.
- Variables: `SqueezeSpeedScale` (float, default `0.45`), `SqueezeNoise` (float, default `20` — a loudness bump on entry, feeds Loudness later), `bTwoWay` (bool, default true).

**Player-side (movement modifier, no authoritative state on pawn):**
- On overlap begin with `SqueezeChannel` while the input vector roughly aligns with `EntryDir` (dot > 0.5): set a **local** `float SqueezeSpeedMultiplier = SqueezeSpeedScale`, auto-crouch (so capsule shrinks — reuse existing crouch), and soft-lock lateral input to the channel axis (project input onto `EntryDir`) so the player slides through cleanly rather than jittering on collision. This is the "bounded chaos" cap.
- On overlap begin, fire **one** `Server_ReportNoise(SqueezeNoise)` request (stub now; LoudnessComponent consumes it later). Leaves fire nothing.
- On overlap end: restore `SqueezeSpeedMultiplier = 1.0`, release the input lock, un-crouch only if the player wasn't already crouched on entry (remember pre-squeeze crouch state in a local bool).
- Cosmetic: leaf rustle SFX + hedge-part wobble (simple timeline rotation on the two halves, ±3°) — the "physics-reactive" read without real physics.

`MaxWalkSpeed` while squeezing = `WalkSpeed * SqueezeSpeedMultiplier` (applied in the movement update, alongside sprint/crouch selection — see §2.5 speed resolution).

### 2.4 Verb: Underwater Breath-Hold (Air Meter) + Dive

Research basis: research §3 (Sneaky Sasquatch forgiving oxygen meter, grace period, direct up/down axis; avoid BotW punishment / LittleBigPlanet floatiness), GDD §5.5 (underwater breath-hold to break sightline).

**Authority: AIR IS A PLAYERSTATE VALUE (replicated, per-player). Not on the pawn.**

On `BP_PlayerState` add:
| Variable | Type | Replication | Default | Notes |
|---|---|---|---|---|
| `Air` | float | Replicated + `OnRep_Air` | `100.0` | 0–100. Server ticks it. |
| `bIsSubmerged` | bool | Replicated + `OnRep_bIsSubmerged` | `false` | Server-owned truth of "head underwater". |
| `bBreathCritical` | bool | Replicated + `OnRep_bBreathCritical` | `false` | True when `Air <= AirCriticalThreshold` (drives red air-meter + gasp). |

Server logic (put the tick in `BP_PlayerState` or, cleaner, a small **`AC_BreathComponent`** added to PlayerState — a reusable `ActorComponent` so it ports to co-op unchanged):
- While `bIsSubmerged`: `Air -= AirDrainPerSec * DeltaTime`, clamped at 0.
- While surfaced: after `AirRefillDelay` grace, `Air += AirRefillPerSec * DeltaTime`, clamped at 100 (fast refill — forgiving, per research).
- **Grace period:** submerging does NOT immediately drain; `Air` only starts dropping after `AirGraceOnSubmerge` seconds underwater. Misjudging a quick dive costs nothing (research: "funny close call, not a hard fail").
- At `Air == 0`: **non-punitive fail** — server forces surface (auto-swim-up), sets a brief `bWinded` (slower for `WindedDuration`), NO damage/death in MVP. (GDD §12 tone: worst case is a close call, never mean.)

Pawn/client side (request + cosmetic only):
- Entering/leaving the water `PhysicsVolume` → character sends `Server_SetInWater(bool)`.
- `IA_Dive` toggles a request `Server_SetSubmergeIntent(bool)`; server sets `bIsSubmerged` only if actually in water. `IA_SwimUpDown` / `IA_Dive` also drive vertical velocity via `AddMovementInput(FVector::UpVector * axis)` (direct up/down, research §3) — this is pure movement, stays on the pawn.
- Cosmetic on `OnRep`: underwater post-process (blue tint + slight blur, a `M_UnderwaterPP` material added to camera's post-process settings, toggled), muffled-audio submix, bubble VFX. On `OnRep_bBreathCritical == true`: heartbeat SFX + the air meter goes red (§3.4).

### 2.5 Speed Resolution (how all modifiers combine)

Every tick (or on state change), compute `MaxWalkSpeed` deterministically so states never fight:

```
base =  bIsSprinting ? SprintSpeed
      : bIsCrouched  ? CrouchSpeed        // == MaxWalkSpeedCrouched
      :                WalkSpeed
final = base * SqueezeSpeedMultiplier * HideStillMultiplier * CostumeSpeedMod
```
- `HideStillMultiplier` = `1.0` normally; when `bIsHidden` and trying to stay hidden, moving is allowed but fast movement breaks hide (handled in §2.2), so no separate slowdown is needed for MVP → keep at `1.0`.
- `CostumeSpeedMod` = `1.0` for MVP (System 5 sets it later; leave the multiply in so the plumbing exists).
- **Sprinting is disabled while crouched, submerged, or squeezing** (clamp the intent bool).
- **Swim speed** is separate: set `CharacterMovement.MaxSwimSpeed` (see tuning table).

### 2.6 Tuning Tables (put in a Data Asset, don't hardcode)

Create `Content/_Project/Data/DA_MovementTuning` (a `PrimaryDataAsset` Blueprint, or a `DataTable` row struct `S_MovementTuning`). Character reads these on BeginPlay into its working vars. This satisfies the "tuning lives in data, not hardcoded" rule (Tech doc §1).

**Ground movement**
| Key | Value | Unit | Notes |
|---|---|---|---|
| `WalkSpeed` | 300 | cm/s | Quiet baseline. Asymmetric accel/decel (research §1). |
| `CrouchSpeed` (`MaxWalkSpeedCrouched`) | 165 | cm/s | Slow + quiet. |
| `SprintSpeed` | 600 | cm/s | Fast + loud. |
| `MaxAcceleration` | 1500 | cm/s² | Snappy ramp-up. |
| `BrakingDecelerationWalking` | 900 | cm/s² | Slower than accel → weighty stop (research §1 asymmetric curve). |
| `BrakingFrictionFactor` | 1.4 | – | Slight overshoot for feel. |
| `CrouchedHalfHeight` | 55 | cm | `CharacterMovement.CrouchedHalfHeight`; standing capsule stays 88. |
| `JumpZVelocity` | 420 | cm/s | Modest hop; vault handles fences. |
| `AirControl` | 0.35 | – | Some mid-air steer, not floaty. |

**Vault (extends existing `TryVault` trace)**
| Key | Value | Unit | Notes |
|---|---|---|---|
| `VaultTraceForward` | 90 | cm | Forward reach of the ledge trace. |
| `VaultTraceHeight` | 130 | cm | Max fence/ledge height vaultable. |
| `VaultMinHeight` | 40 | cm | Below this = just step, no vault. |
| `VaultLaunchForward` | 500 | cm/s | `LaunchCharacter` forward component. |
| `VaultLaunchUp` | 450 | cm/s | Up component; enough to clear `VaultTraceHeight`. |
| `VaultNoise` | 35 | 0–100 | Loudness bump on vault (stub → Loudness later). |
| `VaultCooldown` | 0.4 | s | Prevent spam-vault. |

**Swim / buoyancy (the water `PhysicsVolume`)**
| Key | Value | Unit | Notes |
|---|---|---|---|
| `MaxSwimSpeed` | 260 | cm/s | Horizontal swim. Not floaty (research §3). |
| `SwimVerticalSpeed` | 200 | cm/s | Applied via `IA_SwimUpDown`/`IA_Dive`. |
| `Buoyancy` (`PhysicsVolume.FluidFriction` / brush) | 0.3 | – | Gentle float-up when idle at surface. |
| `WaterEntryNoise` (splash) | 55 | 0–100 | Loudness spike on entering water fast (stub → Loudness). |
| `SwimBrakingDecel` | 400 | cm/s² | So swim stops feel controlled, not sliding. |

**Air / breath (owned by PlayerState / `AC_BreathComponent`)**
| Key | Value | Unit | Notes |
|---|---|---|---|
| `AirMax` | 100 | – | Full lungs. |
| `AirGraceOnSubmerge` | 1.5 | s | No drain for this long after submerging (forgiving dive). |
| `AirDrainPerSec` | 12 | /s | ~8 s of usable breath after grace. |
| `AirRefillDelay` | 0.5 | s | Grace after surfacing before refill. |
| `AirRefillPerSec` | 40 | /s | Fast recovery (~2.5 s to full). |
| `AirCriticalThreshold` | 25 | – | Below → `bBreathCritical` true (red meter + heartbeat). |
| `WindedDuration` | 2.0 | s | Post-empty slow window. |
| `WindedSpeedMod` | 0.6 | – | Multiplier while winded. |

**Hide / squeeze**
| Key | Value | Unit | Notes |
|---|---|---|---|
| `HideLoudnessCap` | 15 | 0–100 | Max loudness while hidden + still. |
| `HideBreakSpeed` | 180 | cm/s | Moving faster than this breaks hide. |
| `SqueezeSpeedScale` | 0.45 | – | Speed multiplier in a hedge. |
| `SqueezeNoise` | 20 | 0–100 | Loudness on squeeze entry (stub → Loudness). |

*(Numbers are first-pass, tuned to MVP doc §4 "close call" feel. Expect the playtest pass to move them — that's why they live in a Data Asset.)*

---

## 3. UI / HUD (UMG)

### 3.1 Architecture & Data Flow

- **One root HUD widget:** `Content/_Project/UI/WBP_HUD` (parent `UserWidget`). Created and added to viewport by `BP_PlayerController` on `BeginPlay` (`Create Widget` → `Add to Viewport`, Z-order 0). One instance per local player.
- **Bindings read replicated state ONLY** (Ground Rule, §0). Resolve sources once per frame in `WBP_HUD` `Tick` (or via OnRep-driven event dispatchers where available — preferred for values that change rarely):
  - `PlayerController → GetPlayerState<BP_PlayerState>()` → per-player: **at-risk score, air, bIsHidden, detained** (later).
  - `GetGameState<BP_PlayerGameState>()` → shared truth: **banked score, neighborhood alert level, night timer, heat, loudness** (loudness is per-player conceptually but for single-player MVP reads from the player's LoudnessComponent value mirrored to PlayerState; spec it on **PlayerState.Loudness** replicated so co-op shows each player their own).
- **Placeholders so it builds now:** until Systems 2–4 land, add stub replicated vars with sensible defaults on GameState/PlayerState:
  - `BP_PlayerState`: `Loudness` (float 0), `ScoreAtRisk` (int 0), `Air` (float 100), `bIsHidden` (bool false), `DetectionAlpha` (float 0, per-threat 0–1 detection fill).
  - `BP_PlayerGameState`: `ScoreBanked` (int 0), `NeighborhoodAlert` (enum, default `Unaware`), `NightSecondsRemaining` (float, default `600`), `Heat` (float 0).
  All are `Replicated` with `OnRep_` notifies. The HUD binds to these today; the owning system just starts *writing* them later. **No HUD rebuild needed when systems land.**
- **MVP scope discipline:** build the widgets + bindings + animations listed below. Do NOT build menus, minimap, co-op crew roster, or photo mode (all parked per MVP doc §2).

### 3.2 WBP_HUD Widget Tree (layout)

```
WBP_HUD (Canvas Panel, full screen)
├── Safe_Overlay (Overlay, anchored full — holds edge indicators so they sit above everything)
│   └── DetectionEdge_Container (Canvas) ......... §3.6 screen-edge detection arcs
├── TopBar (Horizontal Box, anchor top-center, pad 24)
│   ├── WBP_Wristwatch ........................... §3.5 diegetic night timer
│   └── AlertBadge (Overlay) ..................... §3.6 neighborhood alert icon (?/!)
├── BottomLeft (Vertical Box, anchor bottom-left, pad 32)
│   ├── WBP_LoudnessMeter ........................ §3.3
│   └── WBP_AirMeter (Collapsed unless in water) . §3.4
├── BottomRight (Vertical Box, anchor bottom-right, pad 32)
│   └── WBP_ScoreReadout .......................... §3.7  (at-risk vs banked)
├── HidePip (Image, anchor bottom-center) ........ §3.7  ("hidden" leaf icon, hidden by default)
├── Vignette (Image, full-screen, Z-top, HitTestInvisible) . §3.8 close-call vignette
└── (no photo/menu/minimap — parked)
```

Each sub-widget is its **own `WBP_`** (many small widgets > one big one) so they're reusable and testable in isolation:
`WBP_LoudnessMeter`, `WBP_AirMeter`, `WBP_ScoreReadout`, `WBP_Wristwatch`, `WBP_AlertIcon`, `WBP_DetectionEdge`, plus the vignette as a plain Image on the root.

### 3.3 Loudness Meter (0–100)

Research basis: research §4 (Invisible Inc. instant-color + cumulative read; Splinter Cell simpler-is-faster; keep it a cheap non-diegetic fallback per §5 "Minimal HUD Paradox").

**`WBP_LoudnessMeter`:**
- **Tree:** `SizeBox` (240×28) → `Overlay` → [`Image Track` (dark rounded bar, bg)] + [`ProgressBar Fill`] + [3 thin `Image` tick marks at 33/66/90%] + [`TextBlock Label` "NOISE"].
- **Binding source:** `PlayerState.Loudness` (0–100) → `ProgressBar.Percent = Loudness/100`.
- **Color by zone** (instant read, research §4 Splinter Cell 3-color):
  - 0–40 → green `#3FBF6A` (quiet/safe)
  - 40–75 → amber `#E8B23A` (audible)
  - 75–100 → red `#E24A3A` (loud — threats hear far)
  Drive `ProgressBar.FillColorAndOpacity` from a small `Select`/curve on the value.
- **Feel:** the fill **snaps up** on a spike (loud action) and **eases down** on decay — mirror the LoudnessComponent's own snap-up/decay-down; interpolate the *displayed* value toward the real value with `FInterpTo` (interp speed ~8) so the bar isn't jittery but spikes still read.
- **Peak marker:** a thin bright tick that jumps to the current value on a spike and slowly falls (holds the "how loud was that" read for ~0.5 s) — cheap, adds a lot of legibility.
- MVP: no segmented "heat number"; the 3-color bar is the whole thing (research: simpler read wins).

### 3.4 Air Meter (breath-hold)

**`WBP_AirMeter`:** shown only while in water (`Visibility` bound to `PlayerState.bIsSubmerged || InWater`; `Collapsed` otherwise so it never clutters the dry HUD).
- **Tree:** `SizeBox` (200×22) → `Overlay` → [`Image` lung/bubble icon] + [`ProgressBar Fill`] .
- **Binding:** `ProgressBar.Percent = PlayerState.Air / AirMax`.
- **Color:** blue `#4FA3E3` normally → lerp to red `#E24A3A` as `Air` crosses `AirCriticalThreshold` (25). Drive off `PlayerState.bBreathCritical` for the hard red + a **pulse animation** (`WidgetAnimation` scaling the bar 1.0↔1.06 at ~2 Hz while critical) — the "get out of the water" tell.
- On `Air==0`: brief full-red flash + the winded state (§2.4). Non-punitive, matches research §3.

### 3.5 Wristwatch / Night Timer (diegetic)

Research basis: GDD §7 (the wristwatch is a diegetic HUD element; night on a clock, ~8–12 min), research §5 (diegetic-first but keep it cheap; Minimal HUD Paradox warning → do the *2D diegetic-styled* version now, not a 3D world-space watch).

**`WBP_Wristwatch`:** a small stylized watch face in the HUD corner (2D "diegetic-styled" — reads as an object, but it's a screen widget, cheap; a true 3D wrist-mounted watch is parked to a later polish pass to avoid the Paradox trap).
- **Tree:** `Overlay` (96×96) → [`Image` watch-face bezel] + [`Image` hour-hand (pivot center)] + [`Image` minute-hand] + [optional small `TextBlock` "TIME LEFT" digital readout under it].
- **Binding source:** `GameState.NightSecondsRemaining`.
  - Map remaining/total to a **dawn dial**: hand rotation = `Lerp(midnight_angle, dawn_angle, 1 - remaining/total)`. So the watch visibly sweeps toward dawn over the run (GDD §7 "racing the dawn").
  - Digital readout = `MM:SS` from `NightSecondsRemaining`.
- **Escalation tell:** when `NightSecondsRemaining < 120`, tint the face amber + a slow tick-pulse animation (soft time pressure, GDD §7). No hard fail on the HUD side — the GameMode owns the dawn/lose condition.
- **Compass hook (deferred):** GDD §7 mentions a compass to the staging point — leave a `Image CompassNeedle` component in the tree, `Collapsed`, bound to nothing yet. Placeholder only; the Scoring/Stash system wires it later.

### 3.6 Alert Icons (`?`/`!`) + Screen-Edge Detection Indicator

Research basis: research §4 (Mark of the Ninja legibility, Shadow Tactics identical geometry across enemies, Invisible Inc. two-color seen/in-range), GDD §5.3 (three alert states, `?` suspicious / `!` spotted). Shared-team alert is called out as an original-design opportunity (research §4) — the neighborhood-alert badge below is the single-player seed of that.

Two distinct things, both fed by replicated state:

**(a) Neighborhood alert badge — `WBP_AlertIcon` (in `TopBar`, next to the watch):**
- **Binding:** `GameState.NeighborhoodAlert` enum → `{ Unaware, Suspicious, Alert }`.
- Visual per state (identical geometry, only color/glyph change — research §4 consistency):
  - `Unaware` → icon hidden (or a faint dim "z" moon). No clutter when calm.
  - `Suspicious` → amber **`?`** glyph, gentle pulse.
  - `Alert` → red **`!`** glyph, faster pulse + a one-shot "pop" scale-in animation on entering Alert.
- This is the **shared/team** read (whole crew sees it in co-op — it reads `GameState`, so it's already co-op-correct). This is the "shared team-visible alert indicator" research flagged as underserved — we get it for free by sourcing from GameState.

**(b) Per-threat screen-edge detection indicator — `WBP_DetectionEdge` (spawned into `DetectionEdge_Container`):**
- Purpose: when a threat is filling your detection bar (seeing you) but is **off-screen or peripheral**, an arc/arrow at the screen edge points toward it and fills with the detection amount — the "who is spotting me and from where" read. On-screen threats show a small over-head `?`/`!` on the AI itself (that widget lives on the AI actor, built with Detection AI later — noted, not built here).
- **Binding source:** `PlayerState.DetectionAlpha` (0–1, highest current detector) + the detector's world location (from the replicated perception result later). For MVP, spec the widget to accept `{DetectionAlpha, WorldDirectionToThreat}` and drive:
  - **Position:** project `WorldDirectionToThreat` to screen edge; clamp to a ring near the viewport border.
  - **Fill/opacity:** `= DetectionAlpha`. At `1.0` it's a solid red `!` arc (spotted); mid values amber (in-range-but-not-yet, research §4 two-color).
- **MVP build-now behavior:** since Detection AI isn't built yet, wire the widget to the stub `PlayerState.DetectionAlpha` (default 0 → widget invisible). It animates correctly the moment Detection AI starts writing `DetectionAlpha` + threat direction. **No rebuild needed.**
- **Consistency rule (research §4 / Tech doc §4):** the edge indicator geometry + fill speed is identical regardless of threat type (homeowner/chaser/cop) — only the source stats differ. Bake that into the widget, not per-threat.

### 3.7 Score Readout (at-risk vs banked) + Hide Pip

Research basis: GDD §5.1 (at-risk vs banked, the tension engine), MVP doc §1 System 3.

**`WBP_ScoreReadout` (bottom-right):**
- **Tree:** `Vertical Box` → [`Horizontal Box`: `TextBlock "BANKED"` + `TextBlock BankedValue`] + [`Horizontal Box`: `TextBlock "AT RISK"` + `TextBlock AtRiskValue`] + [optional `TextBlock HopStreak` "x3 pools"].
- **Bindings:**
  - `BankedValue` ← `GameState.ScoreBanked` (shared/team truth, replicated).
  - `AtRiskValue` ← `PlayerState.ScoreAtRisk` (this player's unbanked run points).
  - `HopStreak` ← `PlayerState.HopStreak` (int, stub 0 now; Scoring writes later).
- **Feel:** at-risk value in amber; **flashes red + shakes** (small `WidgetAnimation` translate ±4px) when the player takes a detection hit / is at risk of losing it (drive off `bBreathCritical`/`DetectionAlpha > 0.6`). Banked value in calm green, plays a quick count-up + green pop when a bank event fires (`GameState` banked delta) — the satisfying "you kept it" beat (GDD §5.5 The Getaway).
- MVP: no per-pool decay readout, no crew-splash bonus UI (parked); just banked vs at-risk + optional streak.

**Hide Pip (`HidePip` on root):** a small leaf/eye-slash icon, `Collapsed` by default, `Visible` when `PlayerState.bIsHidden`. Tells the player "you're concealed right now" (pairs with §2.2). Cheap, one Image, one binding.

### 3.8 Close-Call Feedback (multi-channel: audio pulse + vignette)

Research basis: research §5 (diegetic-first, multi-channel feedback), MVP doc §4 (the "close call" is THE feeling the whole build is judged on), GDD §11 (heartbeat rising with detection, release cue on escape).

This is the payoff layer that makes the loop *feel* tense. All channels are driven by **one replicated input**: the current highest detection / near-miss intensity `T` in 0–1, computed from `PlayerState.DetectionAlpha` (and later `Heat`).

**Channel 1 — Vignette (`Vignette` Image on root, HitTestInvisible):**
- Full-screen soft-edged dark-red vignette; `RenderOpacity` (or a material param) driven by `T`:
  - `T < 0.3` → invisible.
  - `0.3–0.8` → vignette fades in (edges darken red), opacity `Lerp(0, 0.5, remap(T))`.
  - `> 0.8` → strong red vignette + slow "breathe" pulse animation.
- Implemented as a UMG Image with a **`M_Vignette` UI material** (radial gradient, emissive-style, unlit; per LESSONS "Material-from-scratch via MCP (translucent unlit)" — NO ray tracing needed). Param `Intensity` set from `T` each frame.
- On a **clean break of sightline** (T drops from high to ~0 quickly) → a brief cool-blue "relief" flash then clear (GDD §11 "sweet release cue"). This is the "oh no → break sightline → relief" arc from MVP doc §4 success criterion 3.

**Channel 2 — Audio pulse (heartbeat):**
- A looping heartbeat SFX on the local player (2D sound, `UGameplayStatics::SpawnSound2D` or an `AudioComponent` on the controller — client-local cosmetic, fine on the pawn/controller):
  - Volume + playback-rate scale with `T` (faster/louder heart as detection climbs — GDD §11 pulse rising with detection).
  - Muted at `T < 0.3`; a single sharp "sting" one-shot when the alert badge hits `Alert` / `T` crosses 0.9.
  - On clean escape → stop heartbeat, play the release cue.
- Also drives the underwater muffle interplay (§2.4): while submerged, duck the heartbeat through the muffled submix so hiding underwater *sounds* like relief.

**Channel 3 (bonus, cheap) — Controller rumble:** on `Alert` entry, a short force-feedback pulse via the PlayerController (`Client_PlayForceFeedback`). Client-local, optional.

> All three are **cosmetic/local** and correctly live on the client (controller/pawn), driven by **replicated** `DetectionAlpha`/alert state — the server owns whether you're detected; the client owns how scared the screen *feels* about it. This is authority-correct.

### 3.9 HUD Binding Summary (source of truth for each element)

| HUD element | Reads | Owner (authoritative) | Stub default (build-now) |
|---|---|---|---|
| Loudness meter | `PlayerState.Loudness` | LoudnessComponent → PlayerState (System 2) | 0 |
| Air meter | `PlayerState.Air`, `bIsSubmerged`, `bBreathCritical` | `AC_BreathComponent` on PlayerState (this spec) | 100 / false |
| Wristwatch / timer | `GameState.NightSecondsRemaining` | GameMode night clock | 600 |
| Neighborhood alert `?`/`!` | `GameState.NeighborhoodAlert` | AlertDirector on GameMode (System 4) | `Unaware` |
| Screen-edge detection | `PlayerState.DetectionAlpha` + threat dir | Detection AI → PlayerState (System 4) | 0 |
| Score (banked) | `GameState.ScoreBanked` | Scoring rules on GameMode (System 3) | 0 |
| Score (at-risk) | `PlayerState.ScoreAtRisk`, `HopStreak` | Scoring → PlayerState (System 3) | 0 |
| Hide pip | `PlayerState.bIsHidden` | PlayerState (this spec) | false |
| Vignette + heartbeat | `PlayerState.DetectionAlpha` (→ `T`) | Detection AI (System 4); cosmetic local | 0 |

**Every HUD element has a replicated source and a safe stub — the HUD is fully buildable and animatable NOW, before Systems 2–4 exist.**

---

## 4. Build Order (this deliverable's internal sequence)

Do it in this order so each step verifies via Play-In-Editor before the next (MVP doc §4 manual-test discipline; no unit harness per CLAUDE.md):

1. **Stub replicated vars** on `BP_PlayerState` + `BP_PlayerGameState` (§3.1) — so the HUD has sources. Compile clean (LESSONS: a non-compiling BP freezes PIE).
2. **`WBP_HUD` + sub-widgets** (§3.2–3.8) bound to the stubs. Controller creates + adds it. Verify every element renders and animates by temporarily poking the stub values (e.g. a debug key that ramps `Loudness`, `DetectionAlpha`, `Air`).
3. **`AC_BreathComponent` on PlayerState** + `Air`/`bIsSubmerged` replication (§2.4). Wire water-volume enter/exit + `IA_Dive`. Verify air meter drains/refills with grace, non-punitive at 0.
4. **New input actions** `IA_Interact/Dive/SwimUpDown` + IMC entries (§2.1). Verify swim up/down + dive toggle.
5. **Hide-in-bush** (`BP_BushHide`, `Server_SetHidden`, `bIsHidden`, hide pip) (§2.2).
6. **Hedge-squeeze** (`BP_HedgeSqueeze`, speed lock, wobble) (§2.3).
7. **`DA_MovementTuning`** — move all numbers out of the graphs into the data asset; character reads on BeginPlay (§2.6).
8. **Close-call feedback** `M_Vignette` + heartbeat driven by `DetectionAlpha` stub (§3.8). Verify the oh-no→relief arc by ramping the stub.
9. Commit after each of steps 1–8 (CLAUDE.md: commit per meaningful chunk; `save_assets` + `find ... -size 0` before commit per LESSONS).

**C++ flag:** none of this requires C++. If profiling later shows the per-frame HUD `Tick` bindings are hot with 8 players, convert the rarely-changing bindings (score, alert, timer) to OnRep-driven event dispatchers (still Blueprint). Only drop to C++ if AI-affiliation/teams force it (Tech doc §1) — not a concern for this slice.

---

## 5. Verification (against MVP doc §4 success criteria)

Manual Play-In-Editor checks (the only test harness — CLAUDE.md):
- **Movement:** all new verbs work; dive drains air with grace + forgiving refill; bush hide toggles the pip; hedge-squeeze slows + guides through without collision jitter; no verb fights another (speed resolution §2.5).
- **Authority:** confirm air/hidden/detection live on PlayerState and score/alert/timer on GameState — grep the character graph for any authoritative var (should be none beyond movement/cosmetic + local overlap bools). This is the co-op-readiness gate.
- **HUD:** every element reads its replicated source, animates on stub ramps, and clutters nothing when calm (air meter collapsed when dry, alert icon hidden when Unaware, hide pip hidden when exposed).
- **The close-call arc (MVP §4 crit 3):** ramping `DetectionAlpha` produces rising heartbeat + red vignette; dropping it fast produces the blue relief flash. If this arc doesn't *feel* like "oh no → relief," tune §3.8 curves + §2.6 numbers — do NOT add features (MVP doc §4 anti-goal).

---

*Companion to `Docs/07_Movement_Physics_UI_Research.md` (the research this spec operationalizes). When numbers change in playtest, update `DA_MovementTuning`, not this doc's tables — treat the tables here as the seed values only. Log any MCP gotchas hit while building this to `Docs/LESSONS.md`.*
