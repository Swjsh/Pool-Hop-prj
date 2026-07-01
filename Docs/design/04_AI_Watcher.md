# Pool Hop — Design + Build Spec: The AI Watcher (Homeowner)

*Version 0.1 — build-ready spec for MVP System 4 (Detection AI). Last updated 2026-06-30. Engine: Unreal Engine 5.8, Blueprints-first.*

> This is the **priority deliverable**. It fully specs the single patrolling Homeowner/Watcher NPC for the Systems Sandbox (Docs/02 System 4), the first threat in build order after Loudness → Scoring. It is written to be built directly by an engineer driving the editor via the `unreal-mcp` plugin: every asset has a path, parent class, and concrete tuning numbers, and §12 sequences it into buildable MCP steps.

> ⚠️ **CANON OVERRIDE ([CANON.md](CANON.md) wins).** Two things in this doc are stale: (1) `E_AlertState` here shows **3** members — it has **4** (`Unaware, Suspicious, Alert, Critical`). (2) The AI-numbers here (35°/1400/1800 cone, hearing **1200**, fill 1.5s/decay 3.0s) are correct — but where a BT service mirrors to the player, the canonical PlayerState field is **`DetectionAlpha`** and the alert enum is **`AlertLevel`** (see CANON §"Verified drift resolutions"). Build to CANON.

---

## 0. Where this sits in the build

- **Build order (Docs/02 §5):** System 1 movement is DONE. Order from here: **Loudness → Scoring → Detection AI (this doc) → couple it all → costume/item.** The Watcher is System 4 and is the point where the whole loop first becomes *tense*. It **reads** the Loudness value (System 2) and **feeds** the couple-it-all step (catch = lose at-risk points from Scoring/System 3).
- **Dependencies this doc assumes exist by the time the Watcher is built:**
  - `LoudnessComponent` on `BP_PlayerCharacter` exposing a replicated `Loudness` float (0–100) and firing `MakeNoise` / `ReportNoiseEventFromComponent` (§5.2). If Loudness is not built yet when you reach this doc, the Watcher's **sight** half is fully buildable and testable on its own; wire hearing when Loudness lands.
  - `BP_PlayerGameState` (replicated) and `BP_PlayerState` (replicated) already scaffolded (they are — see `Content/_Project/Core/`). Detection resolution writes to GameState; per-player detained flag writes to PlayerState.
- **Scope discipline:** ONE homeowner, on foot, on a patrol loop. No cop, no cross-yard chaser, no dogs/cameras — those are Phase 5 (Docs/02 §2). The motion-sensor light is specced here only as an *input* to the Watcher (§10) because Docs/02 lists it as part of System 4/5; build it in the couple-it-all step, not before the Watcher patrols.

---

## 1. Design intent (from the research)

The Watcher exists to manufacture the **one feeling** the MVP must prove (Docs/02 §4 criterion 3): *the close call — "oh no" → break sightline → relief.* Everything below is tuned toward producing that arc several times in a 5-minute session, and never toward a hard, unfair, or unreadable catch.

Applied findings from `Docs/06_Hunter_Antagonist_Design_Research.md` and `Docs/07`:

- **Pure AI, no human hunter (Docs/06, resolved).** The Watcher is 100% AI for MVP and Phases 1–3. No possession/hunter seat. This keeps the "Better With Friends" pillar intact (a friend is never the enemy) and avoids the genre's hardest, least-proven role. Build the AI loop well; that *is* the antagonist.
- **Readability is a hard requirement (Docs/07 §4).** The vision cone geometry and detection fill-speed must be **identical across all future AI types** (homeowner/chaser/cop). We are building the homeowner first, so its cone/detection tuning **becomes the project's canonical AI-perception profile** — later threats reskin stats but keep the same *shape and rules*. Bake this into a shared Data Asset (§8) so the cop/chaser literally read the same asset.
- **Three telegraphed states, 3-color, not a fine gradient (Docs/07 §4, GDD §5.3).** Unaware / Suspicious / Alert, with a clear `?` (Suspicious) and `!` (Alert) overhead icon and a color-coded detection bar. Splinter Cell's arc (5-segment → 3-color) says: simpler reads faster. We use one bar + three colors, nothing finer.
- **Catch is a soft fail, not a death screen (GDD §6, Docs/02 §4).** Getting tagged while Alert = **detain**: player respawns at the stash/start zone, loses at-risk (un-banked) points, banked points are safe. This is the roguelike sting that powers "one more run" — sharp enough to matter, soft enough to keep friends in the session (co-op: detained + rescuable later; MVP: respawn-after-delay).
- **Bounded, telegraphed threat, not a twitch reflex test (Docs/07 §2).** The homeowner is *slow but persistent within their property* (GDD §5.4). Detection fills over ~1.5 s of continuous exposure, not instantly, so the player always gets a beat to react — the "oh no" window. Chase speed is only slightly above player sprint so a clean sightline break + going quiet reliably escapes.

---

## 2. Server-authority contract (NON-NEGOTIABLE — Docs/03 §2, §4)

**All detection is resolved on the server. Clients render, they never decide.** Concretely:

| State | Owner | Where it lives | Replication |
|---|---|---|---|
| Who the AI perceives, current alert state, detection meter (0–1), last-known location | **Server** | `BP_WatcherController` (server-only logic) + mirrored to `BP_PlayerState` / `BP_PlayerGameState` for clients | See below |
| "Am I currently being seen / how full is my bar" (for the local player's HUD) | **Server decides**, client reads | `BP_PlayerState.DetectionMeter` (float 0–1), `BP_PlayerState.SeenByAlertState` (enum) | `Replicated` + `RepNotify` |
| Neighborhood heat contribution from this AI | **Server** | `BP_PlayerGameState.NeighborhoodAlert` (float) via AlertDirector | `Replicated` |
| Cosmetic cone mesh, overhead `?`/`!` widget, chase music | **Client** (derived) | Watcher pawn / HUD | Driven by OnRep of the replicated state above — **never** computed locally as truth |
| Detained flag | **Server** | `BP_PlayerState.bDetained` (bool) | `Replicated` + `RepNotify` (respawn/UX on client) |

- The `AIPerceptionComponent` and the Behavior Tree run **on the server/authority only**. In single-player the listen "server" is the local host, so it all runs locally today — but the code path is already the authoritative one, so co-op (Phase 2) is a transport layer, not a rewrite.
- **Guard every state-mutating BT/perception callback with `HasAuthority`.** On a listen server the AIController exists only on the authority; clients have no AIController. Cone visuals on clients read replicated enums, not the perception component.
- **Never put the alert state, detection meter, or detained flag on the Watcher *pawn* as gameplay truth** — pawn holds only the mesh, the cone VFX, and the overhead widget, all driven by replicated values pushed from the controller/PlayerState. (Same rule as the player: pawn = movement + cosmetic only.)

---

## 3. The C++ question — and the Blueprint workaround (IMPORTANT)

**UE's AI affiliation "teams" (`IGenericTeamAgentInterface` / `FGenericTeamId` / `Detect Enemies`) are C++-only.** You cannot set a team ID or implement the team-agent interface purely in Blueprint. Docs/03 explicitly calls this out as the one place we might be forced into C++.

**We do NOT need C++ for the MVP.** Use the **Detect Neutrals + Tags** Blueprint pattern instead:

1. On the `AIPerceptionComponent`'s **AISense_Sight config**, set **`Detect Neutrals = true`** (also tick Detect Enemies/Friendlies so nothing is filtered by an affiliation we never set). With no team interface implemented, *every* perceivable actor registers as **Neutral**, so "Detect Neutrals" is what makes the AI see anything at all in pure Blueprint.
2. Because that makes the AI "see" *everything* (including other AI, props with stimuli), **filter by Actor Tag in Blueprint** inside `OnTargetPerceptionUpdated`: only treat the actor as a target if `Actor.ActorHasTag("Player")`. Ignore all others.
3. Add the tag **`Player`** to `BP_PlayerCharacter` (Class Defaults → Actor → Tags, or `Tags` array = `["Player"]`). This is the single source of "who is a valid target."

> This is the full, correct Blueprint path. Revisit real C++ teams only in Phase 5 when multiple AI factions (cop vs. homeowner vs. player) need genuine friend/enemy relationships — the MVP has one AI and one target, so tag-filtering is strictly simpler and sufficient. **Flag for later:** if/when we add C++ teams, the tag filter can stay as a belt-and-suspenders check.

No other part of this spec requires C++. Everything else is Blueprint + Behavior Tree + EQS + Data Assets.

---

## 4. Asset manifest (create all of these under `Content/_Project/AI/`)

Folder layout (create the subfolders):

```
Content/_Project/AI/
  Watcher/
    BP_WatcherCharacter        (Character)      — the homeowner pawn (mesh, cone VFX, overhead widget)
    BP_WatcherController       (AIController)   — perception + runs the BT (SERVER ONLY)
    BT_Watcher                 (Behavior Tree)  — the state machine
    BB_Watcher                 (Blackboard)     — keys below
    BP_PatrolPoint             (TargetPoint)    — placeable patrol waypoint actor (ordered loop)
  Perception/
    AIP_WatcherProfile         (PrimaryDataAsset — custom "AIPerceptionProfile" data asset; §8)
  EQS/
    EQS_WatcherSearch          (Environment Query)
    EQC_ObserverIsSelf         (EnvQueryContext_BlueprintBase — the querier/AI as context)
  Tasks/                       (BTTask_BlueprintBase subclasses)
    BTT_SetStateAndSpeed       — sets movement speed + writes alert enum to PlayerState mirror
    BTT_FindNextPatrolPoint    — advances the ordered patrol index, writes next MoveTo target
    BTT_RunEQSSearch           — runs EQS_WatcherSearch, writes result to SearchLocation (or use built-in EQS task)
    BTT_CatchPlayer            — server-side detain: sets bDetained, deducts at-risk points, triggers respawn
  Services/
    BTS_UpdateDetection        — per-tick detection meter fill/decay + state transition (the core service)
  Decorators/                  (can be built-in Blackboard decorators; listed for completeness)
  Widgets/
    WBP_WatcherStateIcon       (UserWidget)     — the overhead ?/! icon (WidgetComponent on pawn)
    WBP_DetectionBar           (UserWidget)     — the player's detection fill bar (added to player HUD)
```

Also touched (existing, in `Content/_Project/`):
- `Content/_Project/Core/BP_PlayerState` — add `DetectionMeter` (float), `SeenByAlertState` (enum), `bDetained` (bool).
- `Content/_Project/Core/BP_PlayerGameState` — `NeighborhoodAlert` (float) if not already present from Loudness work.
- `Content/_Project/Core/BP_PlayerGameMode` — `HandleDetain(PlayerState)` server function (respawn + point loss); this is the AlertDirector's home too.
- `Content/_Project/Characters/BP_PlayerCharacter` — add Actor Tag `Player`; ensure a **Perception Stimuli Source** is registerable (register for Sight + Hearing so the AI can sense it — see §5.1/§5.2).
- `Content/_Project/Data/` — one **Enum** `E_AlertState` and one **Struct** `S_PatrolRoute` (optional).

---

## 5. AIPerceptionComponent config (on `BP_WatcherController`)

Add an `AIPerceptionComponent` to `BP_WatcherController` (AIControllers can own perception directly — preferred over the pawn so it lives on the server-side controller). Set it as the dominant sense = Sight.

### 5.1 AISense_Sight config (the flashlight cone) — canonical numbers

| Property | Value | Rationale |
|---|---|---|
| **Sight Radius** | **1400** (14 m) | How far the "flashlight" reaches. Backyard-scale; long enough to feel threatening across a yard, short enough that cover/hedges reliably break it. |
| **Lose Sight Radius** | **1800** (18 m) | Must be ≥ Sight Radius. The hysteresis gap (400 uu) stops flicker at the edge — you stay "seen" a bit past where you'd first be seen. |
| **Peripheral Vision Half Angle (deg)** | **35** | Half-angle → a **70° full cone**. Flashlight-like, readable, not a 360° god-eye. This is the canonical cone angle ALL future AI reuse (Docs/07 §4). |
| **Auto Success Range From Last Seen Location** | **0** (off) | Don't auto-confirm; we want honest line-of-sight. |
| **Detect Neutrals** | **true** | REQUIRED for the no-C++-teams path (§3). Also tick Detect Enemies + Detect Friendlies. |
| **Max Age** | **5.0** s | How long a sight stimulus is remembered before expiring. Feeds the "last known location" grace. |
| **Point of View** | Eyes socket / head bone of the Watcher mesh, height ~160 uu | Cone originates at eye height, not the capsule center, so crouch-cover works. |

**Vertical note:** Sight is a straight LOS + cone test; it does not clamp vertical FOV separately. Keep the Watcher's eye socket at head height and rely on cover geometry (hedges, fences, crouching player) to break LOS. Crouching the player should physically drop them below fence/hedge LOS — that is how "crouch to hide" works mechanically (no separate stat needed).

### 5.2 AISense_Hearing config (wired to Loudness) — canonical numbers

| Property | Value | Rationale |
|---|---|---|
| **Hearing Range** | **1200** (12 m) baseline | The AI's ears. This is the *max* range at which a full-loudness noise event is heard. |
| **Detect Neutrals** | **true** (+ Enemies + Friendlies) | Same reason as sight. |
| **Max Age** | **3.0** s | A heard noise's memory before it expires. |

**How Loudness scales hearing (the mechanical heart — Docs/03 §4, GDD §5.2):**

The player's `LoudnessComponent` does NOT change the AI's `HearingRange` property directly. Instead it scales the **loudness value passed into the noise event**, and the engine attenuates that by distance against the AI's HearingRange. Wire it as:

- The player fires noise via **`MakeNoise`** (or `AISense_Hearing::ReportNoiseEvent`) from `LoudnessComponent`, with:
  - `Loudness` param = `Loudness / 100.0` (so 0–100 maps to 0.0–1.0). At Loudness 100 the noise carries the full `MaxRange`; at Loudness 25 it carries ~1/4 the effective range.
  - `Location` = player world location.
  - `Tag` = optional (e.g. `Splash`, `Sprint`) for future per-noise handling.
- **Cadence:** fire a noise event **only when Loudness is above a floor (≥ 15)** and then at most every **0.25 s** while above it, OR event-driven on discrete loud actions (splash-in, vault, sprint-start). Do NOT fire every frame — it floods perception. Recommended: an event-driven ping on each loud action *plus* a throttled 0.25 s "you are still loud" ping while Loudness ≥ 40 (sprinting/splashing continuously).
- **Effective heard range** ≈ `HearingRange (1200) × (Loudness/100)`. So: crouch-walking (Loudness ~10) → effectively inaudible; walking (~30) → heard within ~3.6 m; sprinting (~70) → ~8.4 m; cannonball splash spike (~100) → full 12 m. These are the numbers that make "should I splash?" a real gamble.

**Register the player as a stimuli source:** on `BP_PlayerCharacter`, add an **AIPerceptionStimuliSource** component (or call `RegisterPerceptionStimuliSource`) and register it for **AISense_Sight and AISense_Hearing** so the Watcher can perceive it. (Sight often works via auto-registration, but register explicitly to be safe; hearing via `MakeNoise` works regardless.)

### 5.3 `OnTargetPerceptionUpdated` handler (on `BP_WatcherController`, SERVER-GUARDED)

Pseudocode (Blueprint event):

```
Event OnTargetPerceptionUpdated(Actor, Stimulus):
  if not HasAuthority(): return                     // server only
  if not Actor.ActorHasTag("Player"): return        // Detect-Neutrals + Tag filter (§3)

  branch Stimulus.Type:
    SIGHT:
      if Stimulus.WasSuccessfullySensed():
        BB.set CanSeePlayer = true
        BB.set TargetActor = Actor
        BB.set LastKnownLocation = Actor.Location    // refresh continuously while seen
      else:
        BB.set CanSeePlayer = false
        BB.set LastKnownLocation = Stimulus.StimulusLocation  // where we last saw them
    HEARING:
      // hearing never fully "sees"; it nudges suspicion and gives a search point
      BB.set HeardNoise = true
      BB.set LastKnownLocation = Stimulus.StimulusLocation
      BB.set NoiseStrength = Stimulus.Strength        // 0..1, already distance-attenuated
```

The **detection meter fill/decay and the actual state transition happen in a Behavior Tree Service** (`BTS_UpdateDetection`, §7.3), driven by these blackboard flags — NOT in this event. This keeps fill/decay smooth (per-tick) and testable, and keeps the event handler cheap.

---

## 6. Blackboard (`BB_Watcher`) — keys

| Key | Type | Purpose |
|---|---|---|
| `AlertState` | **Enum `E_AlertState`** (Unaware=0, Suspicious=1, Alert=2) | The state machine driver. Read by BT branches, mirrored to player HUD. |
| `TargetActor` | Object (Actor) | The perceived player when seen. Cleared when lost. |
| `CanSeePlayer` | Bool | Set by sight stimulus success/fail. |
| `HeardNoise` | Bool | Set true on a hearing stimulus; consumed/reset by the service after routing to Suspicious. |
| `NoiseStrength` | Float | 0–1 attenuated strength of the last noise (for future: louder = faster suspicion). |
| `LastKnownLocation` | Vector | Where to investigate / where we last saw the target. |
| `SearchLocation` | Vector | EQS output — the next spot to check during Suspicious search. |
| `DetectionMeter` | Float (0–1) | The fill value. 0 = unaware, 1 = fully spotted → Alert. Mirrored to PlayerState. |
| `HomeLocation` | Vector | The Watcher's spawn/patrol anchor — returns here to resume patrol after giving up. |
| `PatrolIndex` | Int | Current index into the ordered patrol-point array. |

`E_AlertState` enum lives at `Content/_Project/Data/E_AlertState` (Blueprint Enumeration): `Unaware`, `Suspicious`, `Alert`.

---

## 7. Behavior Tree (`BT_Watcher`) — full node tree

Root → a top-level **Selector** whose children are ordered highest-priority-first (Alert, then Suspicious, then Unaware/patrol). A single **Service on the root** (`BTS_UpdateDetection`) runs every tick to update the meter and set `AlertState`, and Blackboard decorators on each branch gate which branch is active. This is the classic "priority selector keyed on an alert enum" structure.

```
BT_Watcher
└── ROOT
    │  ‹Service› BTS_UpdateDetection            (interval 0.1s, 0.0 random)  ← fills/decays meter, sets AlertState, mirrors to PlayerState
    └── Selector  "Brain"
        │
        ├── [1] Sequence  "ALERT — Chase"
        │      ‹Decorator› Blackboard: AlertState == Alert   (Aborts: Both/LowerPriority — self+lower)
        │      ├── BTT_SetStateAndSpeed(  Speed = ChaseSpeed(650),  ShowIcon = "!" )
        │      ├── Selector "Reach target"
        │      │     ├── Sequence
        │      │     │     ‹Decorator› Blackboard: CanSeePlayer == true
        │      │     │     └── MoveTo( TargetActor, AcceptRadius = 120 )        // chase the actual player
        │      │     └── MoveTo( LastKnownLocation, AcceptRadius = 100 )        // lost sight mid-chase → go last-known
        │      └── (catch is handled by capsule overlap on the pawn → BTT_CatchPlayer / server event, §9)
        │
        ├── [2] Sequence  "SUSPICIOUS — Investigate + Search"
        │      ‹Decorator› Blackboard: AlertState == Suspicious   (Aborts: Both)
        │      ├── BTT_SetStateAndSpeed( Speed = InvestigateSpeed(300),  ShowIcon = "?" )
        │      ├── MoveTo( LastKnownLocation, AcceptRadius = 80 )               // go to where the noise/sight was
        │      ├── Wait( 1.5s )                                                 // look around beat
        │      ├── BTT_RunEQSSearch → writes SearchLocation                     // EQS_WatcherSearch (§7.4)
        │      ├── MoveTo( SearchLocation, AcceptRadius = 80 )
        │      ├── Wait( 1.5s )
        │      └── (loop implicit: if still Suspicious the Selector re-enters; if meter decays to 0 the service
        │            sets AlertState=Unaware and this branch's decorator fails → fall through to patrol)
        │
        └── [3] Sequence  "UNAWARE — Patrol"
               ‹Decorator› Blackboard: AlertState == Unaware
               ├── BTT_SetStateAndSpeed( Speed = PatrolSpeed(180),  ShowIcon = none )
               ├── BTT_FindNextPatrolPoint → writes next patrol Vector into SearchLocation (advances PatrolIndex)
               ├── MoveTo( SearchLocation, AcceptRadius = 60 )
               └── Wait( 2.0s + rand 0..1s )                                    // pause at each waypoint, feels alive
```

**Speeds (uu/s), canonical:**
- `PatrolSpeed = 180` — a slow, sleepy amble (homeowner in a robe).
- `InvestigateSpeed = 300` — a purposeful walk toward the noise.
- `ChaseSpeed = 650` — just above the player's sprint (set player `SprintSpeed` ≈ 600). Fast enough to be scary, slow enough that a clean corner + going quiet loses them. Tune this against the final `SprintSpeed`.

**Abort rules matter:** the Alert branch's decorator must use **Observer Aborts = Both** (or at least Lower Priority) so that the instant the meter crosses into Alert, the tree drops whatever lower-priority patrol/search it was doing and switches to chase. Same for Suspicious over Unaware. This is what makes the reaction feel immediate.

### 7.3 `BTS_UpdateDetection` (the core service — fill/decay + transitions)

Runs on the BT root every **0.1 s**. All server-side. Logic:

```
tick(dt = 0.1):
  fillRate  = 1.0 / 1.5     // full bar in 1.5s of continuous clear sight  → ~0.667/s
  decayRate = 1.0 / 3.0     // empties in 3.0s once unseen                  → ~0.333/s  (decay slower than fill = fair)

  seeing = BB.CanSeePlayer
  heard  = BB.HeardNoise

  if seeing:
    DetectionMeter += fillRate * dt
  else:
    DetectionMeter -= decayRate * dt
  DetectionMeter = clamp(DetectionMeter, 0, 1)

  // State transitions (hysteresis so it doesn't chatter):
  if DetectionMeter >= 1.0:
      AlertState = Alert
  else if AlertState == Alert and DetectionMeter <= 0.6:
      AlertState = Suspicious            // lost them, drop to searching (not straight to calm)
  else if (heard or DetectionMeter > 0.05) and AlertState != Alert:
      AlertState = Suspicious
      BB.HeardNoise = false              // consume the noise flag
  else if DetectionMeter <= 0.0 and not heard:
      AlertState = Unaware

  // MIRROR to the player for HUD (server writes replicated PlayerState):
  if HasAuthority() and TargetActor is a Player:
      TargetActor.PlayerState.DetectionMeter   = DetectionMeter   // 0..1 fill for the bar
      TargetActor.PlayerState.SeenByAlertState = AlertState        // drives bar color
```

- **Fill 1.5 s / decay 3.0 s** is the "oh no → relief" engine: you have ~1.5 s of exposure before you're fully caught (time to duck behind a hedge), and it takes 3 s to fully cool — long enough to feel the tension, short enough not to punish. **These two numbers are the primary tuning knobs; expose them in the Data Asset (§8) and expect to iterate them in playtest (Docs/02 §4).**
- **Multiple exposures don't stack** in the MVP (one AI, one player) — the meter is per-player already because it lives on that player's PlayerState.
- Optionally scale `fillRate` by proximity or by `NoiseStrength` later; keep it flat for the first playtest so the number is legible.

### 7.4 EQS — `EQS_WatcherSearch`

Used only in the Suspicious branch to pick where to look next (so the search feels intelligent, not a fixed spin). Minimal, cheap query:

- **Generator:** `Points: Grid` centered on **`LastKnownLocation`**, GridHalfSize = **600** (6 m search bubble), SpaceBetween = **150**.
- **Context:** querier = the Watcher (use `EQC_ObserverIsSelf`, an `EnvQueryContext_BlueprintBase` returning `self` pawn) — or the built-in `EnvQueryContext_Querier`.
- **Tests (weighted):**
  1. `Distance` to LastKnownLocation — **prefer closer** (Score, weight 1.0): check spots near where the noise came from first.
  2. `Trace` (visibility/LOS) from the Watcher's eyes to each point — **prefer points the Watcher can currently see** (filter: discard points behind walls; this makes it walk to a vantage that reveals hiding spots). Use `Trace: Visibility`, Bool filter = only reachable/visible.
  3. `Pathfinding` (reachable via nav) — **filter out** points with no valid path.
- **Run mode:** Single Best Item → write to `SearchLocation`. Frequency: run once per Suspicious search cycle (via `BTT_RunEQSSearch` or the stock **Run EQS Query** BT task writing to `SearchLocation`), not every tick.

> You can start WITHOUT EQS (just re-investigate `LastKnownLocation` + a couple of hand-authored search offsets) to get the loop running, then swap EQS in. But EQS is cheap here and makes Suspicious feel much smarter, so build it in the couple-it-all pass.

---

## 8. Shared tuning Data Asset — `AIP_WatcherProfile`

Create a Blueprint `PrimaryDataAsset` (or a Data Asset from a Blueprint struct) at `Content/_Project/AI/Perception/AIP_WatcherProfile`. **All numbers below live here, not hardcoded in the BT/controller** (Docs/03 §1: tuning lives in Data Assets). Because Docs/07 requires identical cone geometry across all AI, the cop/chaser later create their *own* profile asset of the same type but reuse these field names — the geometry fields stay equal.

| Field | Type | Default | Notes |
|---|---|---|---|
| SightRadius | float | 1400 | §5.1 |
| LoseSightRadius | float | 1800 | §5.1 |
| PeripheralVisionHalfAngleDeg | float | 35 | §5.1 — canonical cone; keep equal across all AI |
| SightMaxAge | float | 5.0 | §5.1 |
| HearingRange | float | 1200 | §5.2 |
| HearingMaxAge | float | 3.0 | §5.2 |
| DetectionFillSeconds | float | 1.5 | §7.3 — time to full bar under clear sight |
| DetectionDecaySeconds | float | 3.0 | §7.3 — time to empty when unseen |
| AlertReleaseThreshold | float | 0.6 | §7.3 — meter level at which Alert drops back to Suspicious |
| PatrolSpeed | float | 180 | §7 |
| InvestigateSpeed | float | 300 | §7 |
| ChaseSpeed | float | 650 | §7 — retune vs final player SprintSpeed |
| CatchRadius | float | 120 | §9 — overlap distance that counts as a tag |
| SearchGridHalfSize | float | 600 | §7.4 EQS |
| GiveUpAfterSeconds | float | 8.0 | how long in Suspicious with meter ~0 before returning HomeLocation and going Unaware |
| DetainRespawnDelay | float | 2.0 | §9 — seconds before respawn at stash |

`BP_WatcherController` reads this asset on `BeginPlay` and applies the perception values to its `AISense_Sight`/`AISense_Hearing` configs, and the BT tasks read the speeds/thresholds from it via the controller. One asset = one source of truth = trivial retuning during playtest.

---

## 9. Catch → Detain (soft fail) — server-side flow

The catch resolves the moment the Watcher physically reaches the player **while Alert**.

**Trigger:** on `BP_WatcherCharacter`, a capsule/sphere **overlap** (radius = `CatchRadius` 120) OR the Alert-branch `MoveTo(TargetActor, AcceptRadius 120)` succeeding. On overlap **with an actor tagged `Player`**, and **only if `AlertState == Alert`** and **`HasAuthority()`**, call the server detain flow. (Overlapping while Unaware/Suspicious does nothing — you can brush past a sleepy homeowner; only an actively-alerted one detains you.)

**Server flow (`BP_PlayerGameMode.HandleDetain(PlayerState)` — the authoritative rule owner):**

```
HandleDetain(playerState):                     // SERVER ONLY (GameMode is server-only, never replicated)
  if playerState.bDetained: return              // debounce
  playerState.bDetained = true                  // replicated → RepNotify on client plays "caught" UX

  // lose AT-RISK points only; banked points are safe (Docs/02 §3, GDD §5.1):
  lost = playerState.AtRiskScore
  playerState.AtRiskScore = 0                   // (AtRisk/Banked are System-3 fields; this is the couple-it-all hook)
  // do NOT touch playerState.BankedScore

  // reset the AI so it doesn't insta-recatch on respawn:
  watcherController.BB.DetectionMeter = 0
  watcherController.BB.AlertState     = Unaware
  watcherController.BB.TargetActor    = null

  // respawn after a short beat at the stash/start zone:
  delay(DetainRespawnDelay = 2.0s)
  TeleportPlayerToStashZone(playerState.Pawn)   // stash/exit zone actor from System 3
  playerState.bDetained = false                 // replicated → client clears "caught" UX
```

- **Banked vs at-risk is the whole sting.** Getting caught should hurt (you lose the run's un-banked points) but never eject you from the session. In co-op (Phase 2) this becomes *detained + teammate can free you*; the MVP uses respawn-after-delay. The flag + point math live on PlayerState/GameMode exactly so the co-op version is a behavior swap, not a rewrite.
- Client reads `bDetained` via RepNotify to play the fade/"caught!" overlay and disable input during the 2 s — cosmetic only; the server already decided.

---

## 10. Motion-sensor light as a Watcher input (build in couple-it-all, not before)

Per Docs/02 System 4/5, one motion-sensor light exists. It is an **input to the Watcher**, specced here for completeness (build it during the couple-it-all step alongside Scoring/Loudness coupling):

- `BP_SensorLight` (`Content/_Project/Gameplay/BP_SensorLight`): a trigger `BoxComponent` + a `SpotLight` (off by default).
- On player overlap (server): turn the spotlight ON, and **fire a hearing noise event** at the player's location with strength ~0.7 (so the Watcher routes to Suspicious even if it didn't see/hear the player), and/or directly nudge the nearest Watcher's `HeardNoise = true` + `LastKnownLocation = player.Location`. Also feeds the AlertDirector heat.
- The light itself increases the *player's* visibility conceptually, but mechanically the effect on the Watcher is via the noise ping + the extra illumination breaking the player's cover. Keep it to: light on + suspicion ping. Turn off after ~4 s of no overlap.

---

## 11. UI / cosmetic layer (client, driven by replicated state)

- **Overhead `?`/`!` widget** — `WBP_WatcherStateIcon` on a `WidgetComponent` on `BP_WatcherCharacter` (Screen space, size ~64px, offset ~120 uu above head). Reads the Watcher's replicated `AlertState` (mirror the controller's `AlertState` onto the pawn as a replicated enum for the visual): Unaware = hidden, Suspicious = yellow `?`, Alert = red `!`. Matches GDD §5.3 icons exactly.
- **Vision cone visual** — a cheap translucent unlit cone mesh (or a decal/ground-projected cone) parented to the Watcher, matching `SightRadius`/`PeripheralVisionHalfAngle` geometry so what the player *sees* is what the AI *sees* (Docs/07 §4 legibility). Color-tint by state (neutral when Unaware, yellow Suspicious, red Alert) — an Invisible-Inc-style read. Purely cosmetic; identical geometry across all future AI. (Reuse the translucent-unlit material recipe from `Docs/LESSONS.md` — `M_WaterPlaceholder` already proves the pattern.)
- **Detection bar** — `WBP_DetectionBar` on the player HUD, reads `BP_PlayerState.DetectionMeter` (0–1) and `SeenByAlertState`. **3-color** (Docs/07 §4): fills white/neutral → **yellow** as it climbs in Suspicious → **red** at Alert/full. No fine gradient. Optionally a directional pip showing which way the threat is (nice-to-have).
- All three are **derived from replicated server state** — a client never fills its own bar. This is the §2 contract made visible.

---

## 12. Build sequence for unreal-mcp (concrete, ordered)

Do this **after** Loudness (System 2) and Scoring (System 3) are in, per build order. Commit before starting (Epic MCP safety rule). Reference the `unreal-mcp-blueprints` and `unreal-mcp-scene-building` skills. Sight-only is testable before Loudness exists (§0), so you can start at step 5's sight path early if needed.

1. **Data types first.** Create `Content/_Project/Data/E_AlertState` (Blueprint Enumeration: Unaware, Suspicious, Alert). Create the `AIP_WatcherProfile` data-asset class + an instance with the §8 defaults. `save_assets`, verify on disk (`ls -la`, `find ... -size 0` — LESSONS: saves can silently no-op).
2. **Blackboard.** Create `BB_Watcher` with all §6 keys and correct types (Enum key uses `E_AlertState`).
3. **Controller.** `BlueprintTools.create` `BP_WatcherController` (parent `AIController`). Add an `AIPerceptionComponent`; add Sight + Hearing sense configs; on `BeginPlay` read `AIP_WatcherProfile` and apply §5.1/§5.2 values (Detect Neutrals = true on both). Wire `OnTargetPerceptionUpdated` per §5.3 (guard `HasAuthority` + `ActorHasTag("Player")`). `RunBehaviorTree(BT_Watcher)`.
4. **Watcher pawn.** `BP_WatcherCharacter` (parent `Character`). Give it a placeholder mesh (Manny/Quinn or a capsule), set `AIControllerClass = BP_WatcherController` and `AutoPossessAI = PlacedInWorldOrSpawned`. Add the `WidgetComponent` (overhead icon) and the cone visual mesh. Add a replicated `AlertState` enum on the pawn for the visuals only.
5. **Player as target.** On `BP_PlayerCharacter`: add Actor Tag `Player`; add/confirm an `AIPerceptionStimuliSource` registered for Sight + Hearing. (This is the §3 workaround made real.)
6. **BT tasks/service.** Create the `BTT_*` tasks, `BTS_UpdateDetection` service, and (optionally) `EQS_WatcherSearch` + `EQC_ObserverIsSelf`. Prefer `write_graph_dsl` for the task/service graphs (`get_graph_dsl_docs` first; member vars need explicit getters — LESSONS). Keep each task tiny.
7. **Behavior Tree.** Build `BT_Watcher` per §7: root Service `BTS_UpdateDetection` (0.1s), Selector with the three decorated branches (correct `AlertState ==` Blackboard decorators + Observer Aborts = Both on Alert/Suspicious), MoveTo/Wait/EQS nodes with the §7 accept radii and waits.
8. **Patrol points.** Place 4–6 `BP_PatrolPoint` (or stock `TargetPoint`) actors in `L_Sandbox_Movement` threading between the pools (Docs/02 §3 layout — route crosses the open lawn between Pool A and Pool B, past Pool C's cover, out to the money pool D). `trace_world` each XY before placing (LESSONS: ground isn't flat). `BTT_FindNextPatrolPoint` reads them in order (tag them `Patrol` and gather, or expose an ordered array on the controller).
9. **Detain flow.** Add `HandleDetain` to `BP_PlayerGameMode` (§9); add `bDetained`/`DetectionMeter`/`SeenByAlertState` (replicated + RepNotify) to `BP_PlayerState`. Wire the Alert-branch overlap/reach → `BTT_CatchPlayer` → `HandleDetain`. Place/confirm the stash zone teleport target (from System 3).
10. **UI.** Build `WBP_WatcherStateIcon` (reads pawn `AlertState`) and `WBP_DetectionBar` (reads PlayerState `DetectionMeter`/`SeenByAlertState`, 3-color). Add the bar to the player HUD.
11. **Sensor light (couple-it-all).** `BP_SensorLight` per §10.
12. **Compile clean + verify.** `compile_blueprint(warnings_as_errors=true)` on every new BP (LESSONS: a non-compiling BP freezes PIE on a modal the MCP can't dismiss). `save_assets`, `find ... -size 0`. Then **Play-In-Editor**: confirm patrol loop runs, cone tint changes on approach, bar fills over ~1.5 s, `?`→`!` icons, chase, catch → detain → respawn at stash with at-risk points lost and banked safe. Use the **AI perception debug visualizer** (`showdebug AI` / gameplay debugger apostrophe key) to tune cones. Commit.

---

## 13. Playtest tuning checklist (Docs/02 §4 is the judge)

Tune **numbers only**, never add features (Docs/02 §4 anti-goal). Primary knobs, in order of impact:

1. `DetectionFillSeconds` (1.5) / `DetectionDecaySeconds` (3.0) — the close-call window. If players get caught with no "oh no" beat, raise fill; if it never feels dangerous, lower it.
2. `PeripheralVisionHalfAngleDeg` (35) + `SightRadius` (1400) — cone size. Too catchy → narrow/shorten; too safe → widen/lengthen. **Whatever you settle on becomes the canonical cone for cop/chaser.**
3. `HearingRange` (1200) + the Loudness→strength mapping — is splashing a *real* gamble? If sprinting past is free, raise range or the Loudness ceiling.
4. `ChaseSpeed` (650) vs final player `SprintSpeed` — a clean sightline break + going quiet must *reliably* escape (GDD: they never got caught). If chase is inescapable, lower it; if trivially escapable, nudge up.
5. Patrol route + waypoint waits — make the route *thread the pools* so the player must time crossings (that timing pressure is half the tension).

**Success = Docs/02 §4 criteria 3 (a close call) and 5 (one-more-run) land.** If they don't, iterate these numbers before anything else.

---

*This is the canonical AI-perception spec for Pool Hop. When the cop and cross-yard chaser arrive (Phase 5), they create their own `AIP_*Profile` data assets and reskinned BTs but MUST reuse this cone geometry, this 3-color state model, and this server-authoritative detection contract (Docs/07 §4 legibility requirement; Docs/03 §2/§4 authority requirement).*
