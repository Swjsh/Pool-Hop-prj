# Pool Hop — First Neighborhood: "Maple Court" (Grey-Box Build Spec)

*Version 0.1 — build-ready grey-box placement plan. Last updated June 30, 2026.*
*Map asset: `Content/_Project/Maps/L_MapleCourt` · Grey-box only, no final art.*

> **What this doc is.** A concrete, buildable grey-box plan for Pool Hop's starter neighborhood — the tutorial cul-de-sac "Maple Court" (GDD §8). It specifies every actor with world coordinates + dimensions in the same style as `L_Sandbox_Movement`, so an engineer (or an agent driving the editor via unreal-mcp `SceneTools`) can place it directly from engine `BasicShapes`. It also gives the watcher's patrol-route waypoints, the one motion-sensor light, and the stash/exit bank zone.
>
> **What this doc is NOT.** Not final art, not a Synty dressing pass, not new gameplay systems. It reuses the exact systems from `Docs/02_MVP_Vertical_Slice.md` (movement, loudness, scoring, one detection AI, sensor light, stash zone) — Maple Court is where those proven systems get their first *authored* space instead of the abstract sandbox. Per build order (`Docs/02` §5) this map is a **Phase 4** deliverable; the placement plan here is forward-looking as the human requested, but the *systems* it depends on must be built in order (Loudness → Scoring → Detection AI → couple → costume) first.

> ⚠️ **CANON OVERRIDE ([CANON.md](CANON.md) wins).** The "Detection tuning" block in §3 hardcodes `PeripheralVisionHalfAngle=45°`, `LoseSightRadius=1700`, `Hearing=900`, fill `1.2s`/cool `2.0s` and says "do not re-tune" — **all wrong, ignore it.** Canonical cone = `35° / SightRadius 1400 / LoseSight 1800`, hearing `1200`, fill `1.5s` / decay `3.0s` (from `04`). The watcher actor is `BP_WatcherCharacter` (NOT `BP_HomeownerCharacter`). Cone geometry is fixed across all maps; author difficulty via route/dwell/light density.

---

## 0. Grounding & hard constraints (do not violate)

Pulled from the design docs so this plan stays consistent:

- **Server authority (Tech doc §2, CLAUDE.md).** Nothing in this map holds gameplay-authoritative state on a placed actor beyond what the sandbox already does. Pool volumes *request* score from the server (`PoolScoringComponent` → GameMode rules); the stash zone *requests* a bank; the sensor light *reports* a noise/alert event. Score, loudness, alert level, banked points, heat, night timer all live in GameMode/GameState/PlayerState. Placed actors are triggers + cosmetic geometry only.
- **Build order + scope (MVP §1, §5).** One watcher (the homeowner) only — no cop, no chaser, no dogs/cameras/sprinklers in this grey-box (those are Phase 5). One motion-sensor light. The five systems, unchanged.
- **Folder + naming (CLAUDE.md).** Map at `Content/_Project/Maps/L_MapleCourt`. Grey-box props prefixed `SB_`. Gameplay actors `BP_` (`BP_PoolVolume`, `BP_StashZone`, `BP_SensorLight`, `BP_HomeownerCharacter`). Water surfaces `M_`/`MI_`. All *our* content under `_Project/`.
- **Ray tracing DISABLED (LESSONS, 2026-06-30).** `r.RayTracing=False` — assume Lumen software / simple night lighting. Keep dynamic light count modest; the sensor flood is the one bright dynamic light that matters. Do **not** rely on HWRT reflections in the pools (a HWRT init deadlock forced RT off).
- **Trace before you place (LESSONS + scene skill).** The ThirdPerson template floor is NOT flat (central mound ~z=210, scattered z=200 strips). **This map should be built on a fresh, confirmed-flat z=0 plane, not on the template mound.** Either duplicate `Lvl_ThirdPerson` and flatten/replace its floor, or start from a large flat ground plane (below). Every coordinate in this doc assumes **ground = z=0**; still `SceneTools.trace_world` each footprint before dropping large geometry, because a duplicated template can retain hidden raised strips.

---

## 1. Design intent — the tutorial cul-de-sac

Maple Court teaches the loop by **escalating exposure left-to-right**. The player spots up at the school playground (west), and the pools get riskier as they push east/north-east toward the guarded "money pool," then must run the score back to the playground to bank it.

**The five reads we want a first-timer to learn, in order:**

1. **Pool A (open/easy)** — "getting in the water = points." Almost no risk. Teaches scoring + the at-risk/banked HUD.
2. **Pool B (fenced)** — "fences are the connective tissue." Teaches vault, and that vaulting is loud (loudness spike). One motion-sensor light guards the approach — teaches sensors.
3. **Pool C (hidden behind cover)** — "cover breaks line of sight." Teaches crouch-sneak + using hedges/sheds to stay out of the vision cone while the watcher passes.
4. **Pool D (the "money pool," guarded)** — "high risk, high reward." Deep in the watcher's patrol, best score-per-second, a sightline puzzle to enter unseen. This is the tension climax.
5. **The getaway** — "points only bank if you get out clean." Run the at-risk score west back to the playground stash zone.

Optional **Pool E (hidden hot-tub)** and **Pool F (roadside decoy)** give a hop-streak multiplier target and a "greed trap" — small, cheap to add, listed as stretch placements in §6.

**Signature "money pool":** Pool D sits in the back corner of the largest lot, ringed by a low patio wall (cover) with only two entry gaps — one exposed to the streetlight sightline, one requiring a hedge-squeeze. The watcher's patrol dwells longest here.

---

## 2. World layout & coordinate system

- **Origin (0,0,0):** centre of the cul-de-sac bulb (the round end of the dead-end street).
- **+X = East** (deeper into the neighborhood, toward the money pool). **+Y = North.** **+Z = Up.** Yaw 0 faces +X (per scene skill).
- **Overall footprint:** roughly **X: −2600 → +3400**, **Y: −2400 → +2400**. A ~6000 × 4800 unit play space (60m × 48m at UE's 1uu≈1cm). Comfortably larger than the sandbox, still small enough to grey-box fast and playtest in a 5-minute run.
- **Ground:** one flat plane at z=0 (see §3.0). Backyards are defined by fence/hedge lines, not by separate floor meshes — keep it cheap.
- **Street:** a lighter-toned strip running east-west through the middle (Y ≈ −300 → +300), ending in the cul-de-sac bulb at the west. The watcher and (future) cop favor the street; players favor the yards either side.

### ASCII map (top-down, +X right / +Y up)

```
        Y+ (North)
  +2400 ┌──────────────────────────────────────────────────────────────┐
        │  LOT 6 (Pool F trap)      LOT 3            LOT 4               │
        │   ○ Pool F(decoy)      ▒hedge▒          ┌── patio wall ──┐    │
        │                        [Pool C]         │   ★ POOL D      │   │
        │   ══fence══             hidden          │  (MONEY POOL)   │   │
        │                        behind           │  gap    gap     │   │
 +300 ──┼···············································└─cover──────────┘···┤
        │ ░░ SCHOOL   ║          S T R E E T  (cul-de-sac bulb west)      │
        │ ░ PLAYGRND ░║   ●────────── patrol loop ──────────●            │
 -300 ──┤ ░ [STASH]  ░║                                                  │
        │ ░░░░░░░░░░░░║          [Pool A]        ══fence══               │
        │  (START/EXIT)         open/easy        [Pool B]  ☀sensor       │
        │                        LOT 1           fenced  light           │
        │                                        LOT 2         LOT 5     │
  -2400 └──────────────────────────────────────────────────────────────┘
       X-2600                    X:0 (bulb)                        X+3400
                                  X+ (East) →

  Legend:  ░ playground/stash   ║ playground fence   ══ vault fence
           ▒ hedge (squeeze)    ○/[ ] pool   ★ money pool   ☀ sensor light
           ● patrol waypoint    · street edge
```

---

## 3. Grey-box actor placement plan

All actors placed from **engine `BasicShapes`** via `SceneTools.add_to_scene_from_asset` (`/Engine/BasicShapes/Cube.Cube`, `/Engine/BasicShapes/Plane.Plane`, `/Engine/BasicShapes/Cylinder.Cylinder`) or `add_to_scene_from_class` (`/Script/Engine.PhysicsVolume`). **BasicShapes are 100 uu at scale 1** — scale multiplies (scale 6 → 600 uu). A cube of height H on ground z=0 has **center z = H/2**. Volumes default 200³ (scale 4 → 800). `xform = {location:{x,y,z}, rotation:{pitch,yaw,roll}, scale:{x,y,z}}`.

Dimensions below are given as **W(x) × D(y) × H(z)** in world units, with the derived cube scale in parentheses.

### 3.0 Ground, street & PlayerStart

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale (x,y,z) | Notes |
|---|---|---|---|---|---|
| `SB_GroundPlane` | Plane | (400, 0, 0) | 7000×5200×— | (70, 52, 1) | Flat lawn. Confirm z=0 with `trace_world` at all four corners before building. Collision ON. |
| `SB_StreetStrip` | Plane | (400, 0, 1) | 6800×560×— | (68, 5.6, 1) | Cosmetic lighter strip, z=1 to avoid z-fighting, collision OFF (`bodyInstance.collisionEnabled=NoCollision`). Watcher walks it. |
| `PlayerStart` | (existing) | (−2200, −150, 90) | — | — | Relocate into the playground via `set_actor_transform`. Faces +X (yaw 0) toward the neighborhood. z=90 so the capsule sits on ground. |

> If starting from a duplicated `Lvl_ThirdPerson`: delete/replace the template floor + mound, drop `SB_GroundPlane`, then `trace_world(start={x,y,400}, end={x,y,-100})` at (−2200,0),(0,0),(3200,0),(400,2200),(400,−2200) to confirm a clean z≈0 everywhere.

### 3.1 The school playground — START / STASH / EXIT zone (west)

The diegetic "spot up" point from the true story: stash bags in the slide, bank points here. Grey-boxed as a fenced play-lot in the far west.

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale (x,y,z) | Notes |
|---|---|---|---|---|---|
| `SB_PlaygroundPad` | Plane | (−2200, 0, 2) | 1400×1600×— | (14, 16, 1) | Rubberized play-surface footprint (visual), collision OFF. |
| `SB_PlaygroundFence_N` | Cube | (−2200, 800, 60) | 1400×20×120 | (14, 0.2, 1.2) | Waist-high boundary fence, N side. Collision ON (blocks, not vaulted — this is a safe zone). |
| `SB_PlaygroundFence_S` | Cube | (−2200, −800, 60) | 1400×20×120 | (14, 0.2, 1.2) | S side. |
| `SB_PlaygroundFence_W` | Cube | (−2900, 0, 60) | 20×1600×120 | (0.2, 16, 1.2) | W back wall. |
| `SB_Slide` (bag stash prop) | Cube | (−2450, 300, 80) | 120×300×160 | (1.2, 3, 1.6) | The "slide" where bags stash — purely a landmark for the bank zone. |
| `SB_MonkeyBars` | Cube | (−2100, −350, 110) | 400×80×220 | (4, 0.8, 2.2) | Landmark verticality prop; player can jump/climb for a sightline. |
| `BP_StashZone` | `BP_StashZone` (Box trigger) | (−2200, 0, 100) | 1200×1400×200 | — | **Bank trigger.** On player overlap → request server bank of at-risk score (GameMode rule). Box extent (600,700,100). No mesh, collision = overlap-only. This is the same stash/bank actor from the sandbox, re-placed. |

**Gap to the neighborhood:** leave the playground's **east side open** (no fence at x=−1500) so the player exits toward the street/yards. The mouth of the cul-de-sac bulb is at x≈−1400.

### 3.2 Pool A — open / easy (Lot 1, south of street)

First pool. Almost fully exposed, no fence, no cover — pure "learn to score."

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale | Notes |
|---|---|---|---|---|---|
| `SB_PoolA_Basin` | Cube (thin, sunk) | (−200, −1400, −60) | 700×500×120 | (7, 5, 1.2) | Grey basin shell, top rim at z≈0. Cosmetic; the volume does the gameplay. |
| `BP_PoolVolume_A` | PhysicsVolume | (−200, −1400, 40) | 700×500×200 | (3.5, 2.5, 1) | `bWaterVolume=true, priority=1`. Center z=40 so capsule-center entry triggers swim. **Score rate: baseline ×1.0** (easy pool = lowest reward). |
| `MI_Water_A` (surface) | Plane | (−200, −1400, 20) | 700×500×— | (7, 5, 1) | Translucent unlit blue surface at waterline. Collision OFF. Uses `M_Water` per the sandbox material recipe. |

*Exposure:* Directly visible from the street. Watcher passing WP2/WP3 can see a player splashing here if loud. Teaches "in the water = points, but don't be loud in the open."

### 3.3 Pool B — fenced + the ONE motion-sensor light (Lot 2, south-east)

Reached by vaulting a fence; a motion-sensor floodlight guards the approach.

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale | Notes |
|---|---|---|---|---|---|
| `SB_VaultFence_B` | Cube | (900, −1050, 55) | 900×20×110 | (9, 0.2, 1.1) | **Vaultable fence** (110 uu — within the `TryVault` height the character already supports). Collision ON. Vaulting fires a loudness spike (System 2). |
| `SB_PoolB_Basin` | Cube | (1150, −1550, −60) | 650×500×120 | (6.5, 5, 1.2) | Basin shell. |
| `BP_PoolVolume_B` | PhysicsVolume | (1150, −1550, 40) | 650×500×200 | (3.25, 2.5, 1) | `bWaterVolume=true`. **Score rate: ×1.3.** |
| `MI_Water_B` | Plane | (1150, −1550, 20) | 650×500×— | (6.5, 5, 1) | Water surface. |
| `BP_SensorLight` (trigger) | `BP_SensorLight` (Box + SpotLight) | (700, −900, 150) | trigger 500×500×300 | — | **The one motion-sensor light.** Box extent (250,250,150) at the fence approach. On player overlap → snap SpotLight ON (downward, cone ~45°, intensity high enough to read as a flood) + `ReportNoiseEvent` / push nearest watcher toward **Suspicious** (System 4 coupling). SpotLight component points −Z, `AttenuationRadius≈1200`. This is the single bright dynamic light — fine with RT off. |

*Sightline puzzle:* the sensor box sits between the street and the fence, so the "obvious" straight approach trips it. The **clean line** is to swing south (Y < −1700) around the sensor's box and vault the fence's east end (x≈1300) out of the flood.

### 3.4 Pool C — hidden behind cover (Lot 3, north of street)

Behind a hedge + shed. Teaches crouch-sneak and using cover to defeat the vision cone.

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale | Notes |
|---|---|---|---|---|---|
| `SB_Hedge_C` (squeeze) | Cube | (700, 1200, 90) | 900×120×180 | (9, 1.2, 1.8) | **Hedge** screening the lot from the street. Full-height (180) = blocks sight. Leave a **squeeze gap** at x≈1050 (see next). |
| `SB_HedgeGap_C` marker | — | (1050, 1200, —) | gap 140 wide | — | Not an actor — a 140-uu break between two hedge segments (split `SB_Hedge_C` into `_C1` x:250–900 and `_C2` x:1200–1150). The player crouch-squeezes through. |
| `SB_Shed_C` | Cube | (450, 1550, 150) | 500×400×300 | (5, 4, 3) | Shed = hard cover; breaks line of sight from the north patrol leg. Collision ON. |
| `SB_PoolC_Basin` | Cube | (900, 1650, −60) | 600×450×120 | (6, 4.5, 1.2) | Basin. |
| `BP_PoolVolume_C` | PhysicsVolume | (900, 1650, 40) | 600×450×200 | (3, 2.25, 1) | `bWaterVolume=true`. **Score rate: ×1.5.** |
| `MI_Water_C` | Plane | (900, 1650, 20) | 600×450×— | (6, 4.5, 1) | Water surface. |

*Cover route:* Approach from the west behind `SB_Shed_C`, hug the hedge, squeeze through the gap, drop into the pool — all outside the watcher's cone if timed to the patrol. Teaches the core stealth verb loop.

### 3.5 Pool D — THE MONEY POOL, guarded (Lot 4, north-east)

The signature high-risk/high-reward pool, deepest in the watcher's patrol, ringed by a low patio wall with only two entry gaps — a proper sightline puzzle.

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale | Notes |
|---|---|---|---|---|---|
| `SB_PatioWall_N` | Cube | (2600, 1700, 55) | 1200×20×110 | (12, 0.2, 1.1) | Low patio wall (cover, vaultable). Rings the money pool on N. |
| `SB_PatioWall_E` | Cube | (3200, 1200, 55) | 20×1000×110 | (0.2, 10, 1.1) | E wall. |
| `SB_PatioWall_S1` | Cube | (2350, 700, 55) | 500×20×110 | (5, 0.2, 1.1) | S wall, west segment. **Gap 1** (exposed) at x≈2650. |
| `SB_PatioWall_S2` | Cube | (3050, 700, 55) | 300×20×110 | (3, 0.2, 1.1) | S wall, east segment. |
| `SB_PatioWall_W` | Cube | (2000, 1200, 55) | 20×1000×110 | (0.2, 10, 1.1) | W wall. **Gap 2** (hedge-squeeze) at its north end. |
| `SB_Hedge_D` (squeeze) | Cube | (2100, 1650, 90) | 120×300×180 | (1.2, 3, 1.8) | Screens Gap 2. Crouch-squeeze entry, hidden from the streetlight. |
| `SB_Streetlight_D` | Cylinder + PointLight | (2650, 400, 200) | pole 40×40×400 | (0.4,0.4,4) | Streetlight creating the sightline over **Gap 1**. Warm PointLight at z≈380, `AttenuationRadius≈900`. Entering via Gap 1 crosses the lit patch (risky); Gap 2 is dark. |
| `SB_PoolD_Basin` | Cube | (2650, 1250, −80) | 900×700×160 | (9, 7, 1.6) | Bigger, deeper basin — reads as "the good pool." |
| `BP_PoolVolume_D` | PhysicsVolume | (2650, 1250, 40) | 900×700×260 | (4.5, 3.5, 1.3) | `bWaterVolume=true`. **Score rate: ×2.0 (highest).** Deeper Z → supports underwater-hide (System 5 / GDD §5.5) to break the watcher's sightline while banking points. |
| `MI_Water_D` | Plane | (2650, 1250, 20) | 900×700×— | (9, 7, 1) | Water surface. |

*Sightline puzzle:* Gap 1 is the short, obvious entry but crosses `SB_Streetlight_D`'s pool of light and faces the patrol's east dwell point (WP5). Gap 2 requires the longer northern loop + a hedge-squeeze but is unlit and behind cover. The money pool's reward (×2.0) is worth the detour — the exact "greed vs safety" decision the MVP success criteria (§4.2, §4.4) want the player to feel.

### 3.6 Verticality

Cheap grey-box verticality so routes aren't all flat:

| Actor (label) | Asset | Location (x,y,z) | Dimensions W×D×H | Scale | Notes |
|---|---|---|---|---|---|
| `SB_Deck_C` | Cube | (300, 1900, 60) | 400×400×120 | (4, 4, 1.2) | Raised deck by the shed — jump up for a sightline over the hedge to time the patrol. |
| `SB_AC_Unit_D` | Cube | (2050, 900, 45) | 150×150×90 | (1.5, 1.5, 0.9) | Step-up beside `SB_PatioWall_W` — lets a player vault the wall as an *emergency third entry* (skill expression). |
| `SB_RampToRoof_B` | Cube (rotated) | (600, −1750, 90) | 500×160×20 | (5,1.6,0.2) rot pitch=−20 | Low ramp onto the Pool-B shed roof — an escape high-line back toward the street. |
| `SB_ShedRoof_B` | Cube | (900, −1750, 180) | 500×400×20 | (5,4,0.2) | Flat roof the ramp leads to; drop off the far side to break a chase. |

---

## 4. The watcher (homeowner) — patrol route & detection

**One** AI threat (MVP §1 System 4): a patrolling homeowner using AI Perception (Sight cone + Hearing scaled by loudness), three states (Unaware → Suspicious → Alert), `?`/`!` overhead widget. Reuses the sandbox's `BP_HomeownerCharacter` + BT/Blackboard/perception config unchanged — only the **patrol waypoints** are new here.

- **Spawn / home:** near the money-pool lot (his house), `(2900, 300, 90)`, yaw 180 (facing west down the street).
- **Detection tuning (identical geometry to sandbox — Movement/UI research §4, keep cones consistent):** `SightRadius=1400`, `LoseSightRadius=1700`, `PeripheralVisionHalfAngle=45°` (90° cone), `Hearing base range=900` scaled up to ~×2 by loudness. Detection bar fill ~1.2 s in-cone; cools in ~2 s out of sight. These are the sandbox values — **do not re-tune per map**; tune Maple Court's difficulty via *route timing and dwell*, not cone size.
- **Patrol style:** loops the street and dwells longest at the money pool (Pool D), giving that lot its guarded feel; the west end (Pool A / near the playground) gets the least attention, so the tutorial's first pool is forgiving.

### Patrol waypoint list (`SB_Waypoint_*` target points; BT `MoveTo` in order, then loop)

| WP | Label | Location (x,y,z) | Dwell (s) | Facing yaw | Purpose |
|---|---|---|---|---|---|
| 1 | `SB_WP1_West` | (−1200, 100, 90) | 1.0 | 0 (E) | West turnaround near the cul-de-sac bulb; furthest from money pool → Pool A stays easy. |
| 2 | `SB_WP2_PoolA` | (−200, −250, 90) | 2.0 | −90 (S) | Pauses facing Pool A — can catch a loud/open splash there. |
| 3 | `SB_WP3_MidStreet` | (700, 150, 90) | 1.0 | 0 (E) | Mid-street; overlooks the Pool B sensor approach and the Pool C hedge line. |
| 4 | `SB_WP4_PoolC_Glance` | (900, 500, 90) | 2.5 | 90 (N) | Turns north toward Pool C's hedge — the cover route must beat this glance. |
| 5 | `SB_WP5_MoneyGap1` | (2650, 500, 90) | 3.5 | 90 (N) | **Longest dwell**, staring up Gap 1 of the money pool under the streetlight. This is what makes Pool D the guarded climax. |
| 6 | `SB_WP6_EastEnd` | (3100, 200, 90) | 1.5 | 180 (W) | East turnaround by his house; then walks the loop back west. |

**Loop back:** WP6 → WP5 → ... → WP1 → WP2 ... (ping-pong along the street), OR a one-way loop WP1→2→3→4→5→6→1 via a return leg on the north edge `(1500, 800, 90)`. Ping-pong is simpler for the BT and reads more like a nervous homeowner — recommended.

**Suspicious/Alert behavior (unchanged from sandbox):** on a noise event (loud vault, splash, or the sensor light) → break patrol, `MoveTo` last-known-location, search; on direct sight → Alert/chase until `LoseSightRadius` + line-of-sight break for ~2 s, then relax to Suspicious → Unaware. Catch (touch while Alert) → MVP fail: respawn at PlayerStart, lose at-risk (unbanked) score.

---

## 5. Systems coupling recap (nothing new — just where it lives)

| System | Actor(s) in this map | Authority |
|---|---|---|
| Movement | `BP_PlayerCharacter` (from sandbox); fences/patio walls to vault, hedges to squeeze, decks/roofs to climb | `CharacterMovementComponent` (replicated) |
| Loudness | Vaulting `SB_VaultFence_B`/patio walls, splashing pool volumes, tripping `BP_SensorLight` | `LoudnessComponent` reports → server |
| Scoring | `BP_PoolVolume_A..D` (rates ×1.0/1.3/1.5/2.0), hop-streak across distinct pools | `PoolScoringComponent` → GameMode rules → GameState |
| Detection | `BP_HomeownerCharacter` + waypoints §4 | Server-side resolution; clients render cone from replicated state |
| Sensor light | `BP_SensorLight` (§3.3) | Overlap → server raises local alert / noise |
| Bank | `BP_StashZone` (§3.1) | Overlap → GameMode banks at-risk → GameState |

---

## 6. Stretch placements (optional, cheap — add only after A–D validate)

| Actor | Asset | Location (x,y,z) | Score rate | Notes |
|---|---|---|---|---|
| `BP_PoolVolume_E` (hidden hot-tub) | PhysicsVolume | (450, 2050, 40) | ×1.8, small | Tucked behind `SB_Deck_C`/shed in Lot 3; rewards a hop-streak detour. Basin scale (2,2,1). |
| `BP_PoolVolume_F` (roadside decoy) | PhysicsVolume | (−600, 1600, 40) | ×1.1 | "Greed trap" — visible and inviting but exposed to WP1/WP3 sightlines; teaches that not every pool is worth it. |
| `SB_DogPen_Fence` | Cube | (1600, −1200, 90) | — | Phase-5 placeholder only (barking dog = noise spike). Leave empty in grey-box; marks where the environmental threat goes. |

---

## 7. Build & verify checklist (for the agent driving unreal-mcp)

1. `AssetTools.save_assets([])`, commit, then create `L_MapleCourt` (duplicate `Lvl_ThirdPerson` for working sky/lighting, or a blank level + `SB_GroundPlane`).
2. **Set GameMode override** on `WorldSettings` → `/Game/_Project/Core/BP_PlayerGameMode.BP_PlayerGameMode_C` (scene skill — a duplicated template points at the wrong GameMode).
3. `trace_world` the five ground probes (§3.0) — confirm z≈0 before placing large actors.
4. Place §3 actors in order: ground/street → playground/stash → Pools A→D → verticality. Tag pools with a `Pool` tag and set each volume's score-rate property. `SB_` prefix all grey-box props.
5. Water surfaces: apply `M_Water` per the translucent-unlit recipe (LESSONS / scene skill), collision OFF.
6. Place the 6 `SB_WP*` target points; point `BP_HomeownerCharacter`'s BT/Blackboard patrol array at them; spawn him at §4 home.
7. Relocate `PlayerStart` to (−2200,−150,90), yaw 0.
8. `save_assets([])`, then `find Content -name "*.uasset" -size 0` (LESSONS — catch silent 0-byte saves) and commit.
9. **Verify:** `StartPIE` → confirm clean load, pawn spawns in the playground, GameMode wiring correct, watcher begins his loop, no compile modal. Then a **human Play pass** against `Docs/02_MVP_Vertical_Slice.md` §4 for feel (does the money-pool detour feel worth it? is there a close call at WP5?) — MCP can't inject input, so don't claim feel-verified.
10. Screenshot a 3/4 overhead (`CaptureViewport`, pitch −30, `gridHeight=0`) for the doc/PR; extract the base64 PNG per the scene skill.

---

## 8. Tuning knobs to expect to touch (after first playtest)

Per MVP §4 "if it's not fun, tune numbers — don't add features":

- **Patrol dwell at WP5** (money-pool guard): raise to make Pool D scarier, lower if it feels impossible.
- **Pool D score rate ×2.0** vs the detour length: the greed decision must feel close, not obvious.
- **Sensor light box extent / SpotLight radius** (§3.3): the clean southern line should be *learnable*, not invisible.
- **Hedge-gap widths** (Pool C x≈1050, Pool D Gap 2): wide enough to squeeze without frustration (Movement research §2 — bounded, not punishing).
- **Playground→Pool A distance:** if first-timers don't reach the water fast, pull Pool A west.

Cone geometry stays fixed across the map and matches the sandbox (Movement/UI research §4) — difficulty is authored through *route + layout*, not per-actor cone changes.

---

*Next: once Systems 2–5 are built and the sandbox loop validates (`Docs/02` §4), build this map per §7, playtest, and tune per §8. Then Maple Court becomes the Phase-4 first-real-neighborhood milestone (Tech doc §7).*
