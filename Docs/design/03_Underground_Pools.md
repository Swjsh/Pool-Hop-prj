# Pool Hop — Underground Pools (Design + Build Spec)

*Version 0.1 — new concept, first draft. Last updated 2026-06-30. Author: design pass via Claude.*

> **Status:** This is a **NET-NEW concept** not previously in Docs 01–07. It is a *stretch pool zone*, not a new game mode — a single high-risk / high-reward "money zone" that reuses the exact systems the MVP is already building (loudness → AI hearing, time-in-water scoring, heat/escalation, bank-on-escape). Nothing here should be built before the Systems Sandbox (Doc 02) passes its success criteria. This doc exists because the concept was requested up front, and because designing it now keeps the underlying systems honest (see §10, "What this pressure-tests").

---

## 1. The Fantasy — "The Grotto"

Every neighborhood has that one house. The one with the *rumor*. On **The Heights** (Doc 01 §8, the rich/hard neighborhood), the rumor is real: behind a cedar gate, past the cabana, there's a **hatch in the pool deck** — and under it, a warm blue glow.

It's a **members-only underground spa** — a private grotto pool the owner built into an old storm-drain cistern under the property. Tiled, lantern-lit, steam curling off the water, a little too fancy for its own good. Getting in feels like finding the *secret level* of the neighborhood. It is the single best water in the game — and there's exactly **one way in, one way out**, and a **caretaker** who does slow rounds down there with a lantern.

This is the "money pool" from the MVP grey-box (Doc 02 §3, "Pool D") promoted to its own little **place**: the ultimate stay-nerve-or-leave gamble.

**Tone guardrails (Doc 01 §12 — warm mischief, never crime):**
- It's a **spa/grotto**, not a vault or a heist. You're sneaking into the *nicest hot tub on Earth*, not robbing anyone. Nothing is stolen, nothing is broken.
- The caretaker is a **sleepy night-shift pool guy with a lantern and a robe**, not a guard with a weapon. Getting "caught" = shooed out, same soft-fail as everywhere else (respawn at staging, lose at-risk points — Doc 02 §1 System 4).
- The reward is bragging rights and points: *"we found the grotto and got out clean."* Pure summer-night legend material — exactly the north-star memory (Doc 01 §2).
- Diegetic charm over menace: warm lantern light, dripping echo, a rubber duck on the tiles, a "MEMBERS ONLY 🩴" sign. It should make players *grin*, then sweat.

---

## 2. Where It Sits in Scope

| Question | Answer |
|---|---|
| Is this MVP? | **No.** It's a **Phase 4+ stretch** (first real neighborhood / "The Heights"), per Doc 03 §7 roadmap. The grey-box blockout in §9 can be prototyped on the sandbox map *after* Systems 1–5 pass, as a "money-zone" test — but do not build ahead of the Doc 02 §5 order (Loudness → Scoring → Detection AI → couple → costume). |
| New systems required? | **Ideally zero.** It is deliberately designed to be **100% reuse** of the five MVP systems + AlertDirector. The only genuinely new *actor* is the hatch/entry transition (a teleport-style trigger between two sub-areas of one level). See §5 for why a real sub-level is optional. |
| Server authority? | **Fully.** Every value below (score rate, heat, caretaker alert, lockdown timer, one-way-out state) lives in GameMode/GameState/PlayerState — never on the pawn (Doc 03 §2). See §7. |
| C++ needed? | **No.** All Blueprint. The one thing to watch (streaming a sub-level) is a Blueprint node (`Load Stream Level`); flagged in §5 if we go that route. |

---

## 3. The Loop Inside the Loop

The grotto is a **detour** off the normal night, with its own mini-arc that couples back into the main loop:

1. **Find the hatch.** It's hidden on The Heights (behind the money house's cabana). Optional per run — most runs never touch it. Finding it is a skill/knowledge reward.
2. **Descend.** Drop through the hatch → a short ladder/drain tunnel → the grotto chamber. This is the **commitment moment**: it's loud-ish to open, and once you're down, the *only* way back up is the same hatch (or a slow secondary drain — see §4).
3. **Bank nothing yet — the water is incredible.** The grotto pool pays the **highest score-per-second in the game** (§6). But the caretaker patrols, the chamber echoes (loudness is amplified), and a **grotto-heat** timer is ticking that will eventually **lock the hatch** and force the escape.
4. **The squeeze.** Staying longer = more points *and* more heat *and* the caretaker getting closer to the one exit. Classic Pool Hop nerve check, dialed to 11 because there's no lateral escape — you can't just hop the fence to the next yard.
5. **Get out.** Climb back up through the hatch (or the slow drain) before the caretaker blocks it or grotto-heat hits lockdown. Surfacing puts you back in The Heights with your at-risk points still at risk — you **still have to escape the neighborhood** to bank them (Doc 01 §5.1 bank-on-escape). The grotto doesn't bank; it just *loads you up*.

**The core tension it adds:** everywhere else in Pool Hop, escape is *lateral and improvisational* (hop any fence, break any sightline). The grotto makes escape **singular and committed** — one door, one guard, one timer. That's the whole reason it's the "ultimate" zone.

---

## 4. Entry & Exit

### 4.1 The Hatch (primary in **and** out)
- A **pool-deck hatch** actor (`BP_GrottoHatch`) sitting flush in the cabana deck on The Heights.
- **Opening it is a loud action** (routes through `LoudnessComponent`, same as vaulting/splashing — Doc 03 §3): a `+35` loudness spike + a `ReportNoiseEvent` (see §7 numbers). You don't sneak the hatch open; you commit.
- **Descend:** overlapping the open hatch + an "interact" input triggers the transition to the grotto interior (§5). Short ladder animation / fade.
- **Ascend:** the hatch is the primary exit. Climbing out takes **~2.0 s** (a deliberate vulnerability window — you can be shooed off the ladder if the caretaker reaches it, see §6).

### 4.2 The Storm Drain (secondary, one-way-*out* only)
- A **slow secondary exit** — a grated storm-drain crawl at the far end of the grotto — so a caretaker parked on the hatch isn't an unwinnable soft-lock (anti-frustration; Doc 07 §2 "controllability ceiling" applies to level design too).
- **One-way out only** (you can't enter through it), **slow** (~4.0 s crawl), and it dumps you at a **different, worse** surface point on The Heights (out in a more exposed side yard, farther from the neighborhood exit). Trade-off: safer from the caretaker, worse for the *neighborhood* escape.
- Grate is **latched shut by default**; a **loud** action to pry it (`+30` loudness) — so even the "safe" exit costs you noise.

### 4.3 Lockdown (the timer teeth)
- **Grotto-heat** (a local heat value, §7) rising to `100` triggers **Lockdown**: the hatch mechanism clamps for a cooldown (the caretaker "resets the timer lock"). During lockdown the **hatch cannot be used** — only the slow storm drain remains. Lockdown is the "you stayed too long, now you pay" beat. It never *fully* traps a player (drain always works), it just takes the good exit away.

---

## 5. Sub-Level vs. Same-Level (build decision)

Two ways to build "underground," in preference order:

**Option A (preferred for prototype) — same level, a sealed chamber below the deck.**
Build the grotto as a **walled-off room beneath the map** (e.g. a chamber at `Z ≈ -600`), connected only by the hatch trigger which **teleports** the pawn between the deck hatch and the grotto ladder-top. No streaming, no new systems — just two `SceneComponent` transform targets and a `SetActorLocation` on interact, with a camera fade. AI perception is naturally sealed off because the chamber is physically separated and out of every above-ground cone/hearing radius. This is the cheapest, most MCP-buildable path and the one the §9 blockout assumes.

**Option B (later polish) — a streamed sub-level (`L_Grotto`).**
Use `Load Stream Level` / `Unload Stream Level` (Blueprint nodes) to stream the grotto in on descent. Cleaner for a big, art-heavy grotto and keeps above-ground perf untouched. **Flag:** level streaming + AI perception + replication interaction is the fiddly part (make sure the caretaker AIController and its perception component belong to the streamed level and register/unregister cleanly; test late-join replication per Doc 03 §2). Not worth it until the concept is proven with Option A.

> **Decision:** prototype with **Option A**. Only move to Option B if the grotto grows past a single room or perf on The Heights demands isolation.

---

## 6. Mechanics & Risk/Reward

Everything below is a **reuse** of an existing system with grotto-specific tuning. Numbers are first-pass; treat as tuning-doc defaults (they belong in `Content/_Project/Data/`, per Doc 03 §1 "tuning values live in Data Assets, not hardcoded").

### 6.1 Scoring — the payday
Reuses `PoolScoringComponent` / server scoring rules (Doc 03 §3). The grotto pool volume is just a `BP_PoolVolume` with a **grotto tuning profile**:

| Value | Normal pool (MVP) | **Grotto** | Rationale |
|---|---|---|---|
| Base points / sec in water | `10` /s | **`30` /s** | ~3× the best surface pool — this is *the* money water. |
| Per-pool decay (diminishing returns) | decays after ~8 s | **no decay** (or very slow, kicks in after `20 s`) | You're *meant* to linger here; the risk (heat/caretaker/one exit) is the limiter, not decay. This inverts the normal "keep moving" rule *on purpose* — the grotto is the one place you plant. |
| Crew-splash bonus (all players in same pool) | `×1.5` | **`×2.0`** | Rewards the whole crew committing together (Doc 01 §6 crew bonuses) — and stacks the tension since one loud teammate dooms everyone. |
| "Deep dive" bonus | — | **`+50` one-time** for touching the grotto floor (deepest point, forces a breath-hold — Doc 01 §5.5 underwater) | A small skill flourish unique to the grotto. |

**Ballpark math (single player):** a clean 12-second grotto dip ≈ `12 × 30 = 360` + `50` deep-dive = **~410 at-risk points** — versus a good *surface* pool at maybe `10/s` with decay netting ~60–70 for the same time. The grotto is worth **~5–6× a normal pool** for the same seconds spent, which is what makes it the "ultimate money zone." But it's all **at-risk** until you escape the *neighborhood* (§3 step 5) — the grotto can turn a mediocre run into a record, or a caught grotto run into the worst wipe of the night.

### 6.2 Loudness — the echo chamber
Reuses `LoudnessComponent` unchanged; the grotto just applies an **environment multiplier** to noise generated inside it.

- **Echo multiplier `×1.4`** on all loudness *generated* inside the grotto (splashing, the deep dive, prying the drain). Enclosed tile chamber = sound carries. Makes the grotto's own splashing feed the caretaker's hearing harder than an open backyard would.
- Loudness **decay is normal** (crouch-still on the tile ledge to cool off), so the skill expression is: splash for points → climb out onto the dry ledge → go quiet to bleed loudness → dip again. A rhythm, not a hold.
- **Coupling:** grotto loudness feeds *both* the caretaker's `AISense_Hearing` **and** the grotto-heat accumulator (§7). One cannonball is genuinely reckless down here.

### 6.3 The Caretaker — the one guard
Reuses the **exact** threat stack (Doc 03 §4: `AIController` + Behavior Tree + `AIPerceptionComponent`, three alert states, identical cone geometry per Doc 07 §4). He is a **re-skinned homeowner** with a lantern, tuned slower and more local:

| Trait | Value | Note |
|---|---|---|
| Sight radius | `1400 uu` | Shorter than a yard homeowner — it's a small chamber. |
| Lose-sight radius | `1800 uu` | |
| Peripheral vision half-angle | `35°` | Same cone *geometry* as all AI (Doc 07 §4 hard rule); the **lantern light** is the diegetic tell for where he's looking. |
| Hearing range (base) | `900 uu`, scaled by player loudness × echo | The echo (§6.2) makes noise the primary way he finds you here. |
| Move speed (patrol) | `120 uu/s` | Sleepy rounds. Slow but relentless (Doc 01 §5.4). |
| Move speed (alert/chase) | `340 uu/s` | Can't sprint like a cop — but in a one-exit room he doesn't need to. |
| Patrol | 3–4 waypoints looping the ledge, **passing the hatch and the drain** | So both exits are periodically watched — reading his loop is the puzzle. |
| On catching a player | Shoo → soft-fail (respawn at neighborhood staging, lose at-risk) | Same non-punitive fail as Doc 02 §1 System 4. No violence. |

**Key behavior — "guard the door":** when the caretaker goes **Alert**, his BT prefers moving to **block the hatch** (the primary exit) rather than blindly chasing. This is what makes the storm drain (§4.2) matter and creates the signature *"he's on the hatch, take the drain!"* crew moment.

### 6.4 Grotto-Heat — the local escalation timer
A **local heat value** (`0–100`) owned by the grotto, distinct from (but feeding) neighborhood heat. Reuses the AlertDirector pattern (Doc 03 §3, "aggregates loudness/detection into heat").

- **Rises from:** time-in-grotto (passive `+3/s` while any player is in the water), loudness events (`+0.4` per loudness point generated inside), and each caretaker sighting (`+15`).
- **At `70`:** the caretaker wakes fully (forced Suspicious→Alert bias) — "someone's been down here a while."
- **At `100`:** **Lockdown** (§4.3) — hatch clamps for `20 s`, forcing the slow drain exit.
- **On last player leaving the grotto:** grotto-heat **decays** at `-8/s` and the caretaker resets to patrol, so re-entry later in the night is possible but the timer is "warmer" if you come back soon.
- **Feeds neighborhood heat:** a grotto lockdown pushes **`+25` neighborhood heat** up top (Doc 01 §5.3) — the disturbance ripples out, making the *neighborhood* escape harder right when you surface loaded with points. This is the coupling that ties the detour back into the main run's stakes.

### 6.5 The risk/reward one-liner
> **The grotto is the only place in Pool Hop where the smart play is to *stay*. Everywhere else, movement is safety; here, the water is so valuable you plant your feet — and the price is a single guarded door and a clock that will take it away.**

---

## 7. Server Authority & Data Model (Doc 03 §2 — non-negotiable)

Nothing grotto-specific lives on the pawn. Full authority mapping:

**GameMode (server-only, never replicated) — the rules:**
- Grotto score rates, decay profile, deep-dive bonus, crew multiplier.
- Grotto-heat rise/decay rules, lockdown threshold + duration.
- Caretaker spawn / patrol / alert-bias rules; "guard the door" decision.
- Descend/ascend validation (is the hatch usable right now? is the player actually overlapping it?).

**GameState (replicated to all clients) — shared truth:**
- `GrottoHeat` (float 0–100) — replicated, `OnRep_GrottoHeat` drives the shared UI badge (Doc 07 §4 shared-team indicator).
- `bGrottoLockdown` (bool) — replicated, `OnRep` locks the hatch VFX/collision for all clients. **Use OnRep, not a Multicast**, so a teammate who descends late sees correct lock state (Doc 03 §2 late-join gotcha).
- `CaretakerAlertState` (enum: Unaware/Suspicious/Alert) — replicated for the shared alert icon.
- `PlayersInGrotto` (int/array) — for the crew-splash multiplier and grotto-heat "any player in water" check.

**PlayerState (replicated, per player):**
- `bInGrotto` (bool) — whether this player is currently in the grotto sub-area (drives their own scoring context + which exit prompts show).
- Individual at-risk score contribution accrued in the grotto (rolls into the normal at-risk/banked model — the grotto does **not** introduce a separate currency).

**Character/Pawn:** movement (`CharacterMovementComponent`, `MOVE_Swimming` in the grotto water volume — Doc: LESSONS `bWaterVolume` note) + **cosmetic only** (wet/steam VFX, lantern-glow reaction, echo SFX). No score, no heat, no alert state on the pawn.

**Data flow:** interact-with-hatch → **client request** → GameMode validates (hatch usable? not locked? overlapping?) → GameMode teleports/streams + sets `PlayerState.bInGrotto` → replicates → clients fade + show grotto UI. Identical request→validate→replicate pattern as every other system (Doc 03 §2).

**Tuning lives in Data Assets:** `DA_GrottoProfile` under `Content/_Project/Data/` holds every number in §6 (score rate, decay, echo mult, heat rates, caretaker stats, lockdown timing) so designers tune without touching Blueprint graphs (Doc 03 §1).

---

## 8. Assets to Build (Blueprints, paths, parents)

All under the established convention (Doc 03 §6 / CLAUDE.md): `Content/_Project/{Gameplay,AI,Data,Maps}`, `BP_`/`DA_`/`L_` prefixes. Grey-box first (Doc 02 golden rule) — `SB_` prefixed cubes/cylinders, no custom art.

| Asset | Path | Parent class | Purpose |
|---|---|---|---|
| `BP_GrottoHatch` | `_Project/Gameplay/Grotto/BP_GrottoHatch` | `Actor` | Deck hatch: overlap + interact → request descend; loud on open; ascend point; locks on `bGrottoLockdown` (OnRep). Components: `StaticMesh` (hatch lid), `BoxCollision` (interact volume), `SceneComponent` GrottoTargetXform, `AudioComponent`. |
| `BP_GrottoDrain` | `_Project/Gameplay/Grotto/BP_GrottoDrain` | `Actor` | Secondary one-way-out crawl; pry = loud; ~4 s exit to a worse surface point. |
| `BP_GrottoPoolVolume` | `_Project/Gameplay/Grotto/BP_GrottoPoolVolume` | reuse `BP_PoolVolume` (MVP) | The grotto water. `PhysicsVolume` in-level with `bWaterVolume=true` (LESSONS pattern) + grotto scoring profile applied. |
| `BP_GrottoManager` | `_Project/Systems/BP_GrottoManager` | `Actor` (or a component on GameMode) | Owns grotto-heat accumulation, lockdown state machine, echo multiplier broadcast, crew-in-water check. Talks to GameMode/GameState only (authority). |
| `BP_Caretaker` | `_Project/AI/BP_Caretaker` | reuse `BP_Homeowner` (MVP threat) | Re-skinned homeowner; grotto perception/speed profile; "guard the hatch" BT branch. Lantern = `SpotLight` child pointed along the cone (diegetic sight tell). |
| `BT_Caretaker` / `BB_Caretaker` | `_Project/AI/Grotto/` | reuse MVP threat BT/Blackboard + a `GuardDoor` branch | Unaware(patrol loop past both exits) → Suspicious(investigate last-known) → Alert(block hatch / chase). |
| `DA_GrottoProfile` | `_Project/Data/DA_GrottoProfile` | `PrimaryDataAsset` | All §6/§7 tuning numbers. |
| `WBP_GrottoBadge` | `_Project/UI/WBP_GrottoBadge` | reuse HUD widget style | Shared team indicator: grotto-heat bar (3-color per Doc 07 §4) + caretaker alert icon + "LOCKDOWN" flash. |
| `L_Grotto` *(only if Option B)* | `_Project/Maps/L_Grotto` | streamed sub-level | Deferred; Option A needs no new map. |

**Reused unchanged:** `LoudnessComponent`, `PoolScoringComponent`, `AIPerceptionComponent` config, AlertDirector, bank-on-escape logic. That's the point — the grotto is a *tuning + layout + one transition actor* on top of shipped systems.

---

## 9. Grey-Box Blockout (buildable coordinates)

Assumes **Option A** (sealed chamber below the map). Coordinates are for dropping onto the existing sandbox / a Heights test area via `SceneTools.add_to_scene_from_class` — **trace ground before placing** (LESSONS: template floors aren't flat z=0; use `SceneTools.trace_world`). Deck-side objects sit at the local ground z; the grotto chamber sits at a **fixed `Z = -600`** well clear of any above-ground geometry so no cone/hearing bleeds in.

### 9.1 Deck side (above ground, on The Heights money house)
```
                 cabana wall (SB cube)
   [money-house pool]        |
        (surface)            |   [HATCH]  <- BP_GrottoHatch, flush in deck
                             |   (X=1200, Y=400, ground_z)
   patrol route of the       |
   above-ground homeowner ---+---- cedar gate (cover)
```
- **Hatch:** `X=1200, Y=400, Z=ground_z` (trace first). Interact box `120×120×80`.
- Tuck it behind a `SB_CabanaWall` cube (`~600×40×300`) at `X=1100, Y=400` so it's genuinely hidden — finding it is the reward (§3.1).

### 9.2 Grotto chamber (sealed, Z = -600)
A single rectangular tiled room, ~`2000 × 1400` footprint, ceiling at `Z=-300` (≈300 uu headroom above the ledge). Everything below is grey-box `SB_` geometry.

```
  Z = -600 plane (chamber floor level)          (top-down)

  (Ladder top / HATCH exit)                         (Storm DRAIN exit)
   X=-800,Y=-500  ●-------- dry tile LEDGE --------● X=800,Y=-500
                  |                                 |
                  |        ~~~ GROTTO POOL ~~~      |
   caretaker      |   ~~~  (BP_GrottoPoolVolume) ~~~|
   patrol loop -> |   ~~~   deep point = floor    ~~~|   <- deep-dive +50 here
                  |        ~~~  Z ≈ -560 top   ~~~   |      (pool floor Z ≈ -900)
                  |                                 |
   X=-800,Y=500   ●------------ tile LEDGE ---------● X=800,Y=500
```

| Element | Placement (X, Y, Z) | Size / note |
|---|---|---|
| Chamber floor | center `0, 0, -900` | `SB_Floor` plane `2400×1800`. |
| Chamber walls | around footprint | 4× `SB_Wall` cubes, height to `Z=-300` ceiling; **fully seals** the room (no perception leak). |
| **Grotto pool volume** | center `0, 0, -730`; water surface `Z=-560` | `PhysicsVolume` `bWaterVolume=true`, ~`1600×1000×340` (LESSONS: scale the 200³ brush). Deep floor at `Z≈-880` for the deep-dive. |
| Dry ledge (cool-off) | ring at `Z=-560` around the pool | `SB_Ledge` strips, ~`300` wide — where you crouch to bleed loudness (§6.2). |
| **Ladder top / hatch exit** | `-800, -500, -560` | Ascend point; `~2.0 s` climb; teleport target back to deck hatch. |
| **Storm drain exit** | `800, -500, -560` | `BP_GrottoDrain`; `~4.0 s` crawl; teleports to a *worse* Heights surface point (a far side yard). |
| Caretaker spawn | `600, 0, -560` | On the ledge. |
| Caretaker waypoints | e.g. `-700,-450` → `-700,450` → `700,450` → `700,-450` (all `Z=-560`) | Loop passes **both** exits (§6.3). |
| Grotto lanterns | 2–3 along the ledge | Warm `PointLight`s (diegetic mood + readability; RT is OFF per LESSONS — software Lumen / simple point lights only). |
| Ceiling | `0, 0, -300` | `SB_Ceiling` plane; seals the top so the hatch teleport is the only opening. |

**Ground-trace reminder (LESSONS):** before dropping the deck hatch, `trace_world` from high above `X=1200,Y=400` down past 0 and set the hatch to the hit z. The chamber is authored at fixed negatives and doesn't need tracing (it's in empty space below the map), but verify nothing else occupies `Z≈-600..-900` there first.

### 9.3 How to verify (Play-In-Editor, per CLAUDE.md manual-test discipline)
1. Walk to the hidden hatch → interact → confirm teleport-fade into the chamber and `bInGrotto=true` on PlayerState.
2. Enter the water → confirm score ticks at grotto rate, deep-dive `+50` fires on floor touch, crew multiplier if a 2nd (later-networked) player joins.
3. Splash → confirm echo `×1.4` loudness and that grotto-heat climbs; confirm the caretaker's hearing reacts.
4. Let grotto-heat hit 100 → confirm Lockdown clamps the hatch and only the drain works; confirm `+25` neighborhood heat up top.
5. Escape via hatch **and** via drain → confirm each returns you to the correct (and correctly *different*) Heights surface point with at-risk points intact, then bank by reaching neighborhood staging.

---

## 10. What This Pressure-Tests (why designing it now is useful)

Even though it's not built until Phase 4+, specifying the grotto now **stress-tests the MVP systems' architecture** — if any of these can't express the grotto cleanly, the underlying system has a hidden assumption to fix *before* it's load-bearing:

- **Scoring** must support **per-pool tuning profiles** (rate, decay, bonuses) via Data Asset, not hardcoded — the grotto proves scoring can't bake its numbers into the component.
- **Loudness** must support an **environment multiplier** applied by a volume — proves noise generation is decoupled from a fixed constant.
- **Heat/AlertDirector** must support a **local heat sub-accumulator that feeds the global** — proves the director isn't a single hardcoded neighborhood value.
- **Escape/banking** must treat a zone transition as *not* a bank event — proves at-risk points survive a teleport/sub-level without accidentally banking (a real bug risk).
- **Server authority** must handle a **spatial transition (descend/ascend)** as a validated request with correct late-join OnRep state — the exact Phase 2 netcode discipline (Doc 03 §2), rehearsed on a self-contained feature.

Building the five MVP systems with these seams in mind costs nothing now and makes the grotto (and every future "special pool") a tuning-and-layout job rather than a system rewrite — the same discipline that makes co-op a layer instead of a redo.

---

## 11. Open Questions (park until Phase 4)

- **Discovery:** is the hatch always in the same spot, or does its location vary/rumor-hint per run? (Leaning fixed-per-neighborhood so knowledge is a learnable reward.)
- **Solo vs crew:** should the grotto be gated to require 2+ players (a true "co-op money zone"), or fully soloable? (Leaning soloable but *better* with a crew via the `×2.0` splash — don't wall off the single-player practice mode, Doc 01 §14.)
- **Caretaker count on The Heights hard mode:** ever two caretakers? (Probably not — one guarded door is the clean fantasy; two risks the unwinnable soft-lock the drain exists to prevent.)
- **Multiple grottos:** one per hard neighborhood as a signature "money pool," or Heights-only? (Start Heights-only; it's a *signature*, not a template — over-using it dilutes the legend.)
- **Cosmetic reward:** a grotto-only unlock (e.g. a "Grotto Member" robe costume — 90% flex per Doc 01 §5.6) for a clean grotto-and-out run? Good retention hook, pure cosmetic, on-tone.

---

*This concept reuses the MVP's five systems verbatim with a grotto tuning profile, one transition actor, and a re-skinned homeowner. It adds the one thing Pool Hop's lateral, improvisational escape never has — a single committed door — and makes the water valuable enough that, for once, the smart play is to stay. Build nothing here until the Systems Sandbox (Doc 02) is proven fun.*
