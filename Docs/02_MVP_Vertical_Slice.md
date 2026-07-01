# Pool Hop — MVP / Vertical Slice: "The Systems Sandbox"

*Version 0.1 — first build definition. Last updated June 30, 2026.*

---

## 0. Purpose of This Build

You chose the **systems sandbox** as the first build. Smart call. The goal is **not** a pretty level or a full night — it's to **prove the core systems are fun in isolation**, on a deliberately ugly test map, before spending a single hour on level art.

> **The one question this build must answer:** *Is sneaking to a pool, racking up points while managing loudness, and escaping a patrol actually fun for one player?*
>
> If yes → we scale to a real neighborhood and layer co-op. If no → we've spent weeks, not months, finding out.

**Golden rule for this phase:** grey boxes and free/placeholder assets only. No custom art. Every hour on polish now is an hour stolen from finding the fun.

---

## 1. Scope — What's In

The sandbox is a single flat test map ("the grey box") containing a handful of pools, some cover, some lights, and one patrolling threat. It exists to exercise these **five systems**:

### System 1 — Player Controller & Movement
- Third-person character (placeholder capsule/Mannequin or Synty Sidekick starter).
- Verbs: walk, **crouch** (quieter, slower), **sprint** (fast, loud), **jump/vault**, **enter/exit pool**, **swim**, **crouch-in-bush hide**.
- Movement is the base everything else reads from (speed → loudness).

### System 2 — Loudness Meter
- A visible on-screen meter (0–100).
- Rises from: sprinting, splashing into a pool, vaulting, triggering a sensor. Falls when crouched/idle.
- **Drives AI hearing radius** (System 4). This is the coupling that makes the whole thing tick.
- Server-authoritative even in single-player (so co-op is a drop-in later — see Tech doc).

### System 3 — Scoring ("Time in Water")
- Volume/trigger on each pool. While the player is inside → **points tick up per second**.
- Track: current run score, **at-risk vs banked**, distinct pools visited (hop streak), per-pool decay (diminishing returns).
- A **"stash/exit zone"** that **banks** the at-risk score when the player reaches it.

### System 4 — Detection AI (one threat)
- **One patrolling homeowner** using UE5 **AI Perception** (Sight + Hearing).
- **Vision cone** (the "flashlight range"): sight radius + peripheral angle, visualized.
- **Three alert states**: Unaware (patrol waypoints) → Suspicious (investigate last-known location) → Alert (chase). Clear `?`/`!` overhead icon.
- Hearing radius scales with the player's **loudness** (System 2).
- On catching the player (touch while Alert) → simple fail: respawn at start, lose at-risk points.

### System 5 — One Costume/Item Swap (proof of the system)
- A pickup or menu toggle that swaps **one** cosmetic + applies **one** small stat change (e.g. "quiet shoes" = -20% loudness from footsteps).
- Purpose: prove the item/costume plumbing (attach mesh, apply modifier) works — not to build the full wardrobe.

### Plus: Motion-Sensor Light (one instance)
- A trigger volume that flips a spotlight on and pushes nearby AI toward Suspicious. Proves the environmental-threat pattern.

---

## 2. Scope — What's Explicitly OUT (do not build yet)

Writing the "Won't" list is the most important part of scoping a first game. **Out of this build:**

- ❌ **Online multiplayer / networking.** (But architect for it — see below. This is the deliberate tension in your "co-op day one" choice; resolved in the Tech doc.)
- ❌ Real neighborhood art, houses, modular kits, nice water shaders.
- ❌ Multiple neighborhoods / the map screen.
- ❌ The retro home-base intro scene.
- ❌ The cop, the chaser-across-yards, dogs, cameras, sprinklers (only ONE homeowner threat here).
- ❌ Full costume wardrobe, gadgets sandbox, meta-progression, unlocks.
- ❌ Leaderboards / online services / accounts.
- ❌ Menus beyond a bare start/restart.
- ❌ Audio polish (one placeholder splash + one footstep is enough to test the loop).

If a task isn't one of the five systems + sensor light, it goes on the **Parked Ideas** list, not into this build.

---

## 3. The Test Map ("Grey Box")

Deliberately unglamorous. Rough layout:

```
  [START / STASH ZONE] ---- open lawn ---- [POOL A] ---- fence ---- [POOL B]
         |                     (patrol route crosses here)              |
     bush cover                                                    sensor light
         |                                                              |
     [POOL C (behind cover)] ------- hedge maze ------- [POOL D (the "money pool")]
                              patrolling HOMEOWNER
```

- 4 pools with different exposure (A: open/easy, B: past a fence, C: hidden behind cover, D: guarded "money pool").
- 1 homeowner on a patrol loop that threads between the pools.
- 1 motion-sensor light near Pool B.
- Cover: a few bushes/walls (grey cubes).
- 1 stash/exit zone to bank points.

Everything is BSP/grey-box geometry or free placeholder props. Lighting: simple night + the one sensor spotlight.

---

## 4. Success Criteria (how we know it worked)

The build is a success if a fresh playtester (a friend), with no instruction beyond "get points from pools and don't get caught," experiences all of this in a 5-minute session:

1. **Reads the tension.** They naturally crouch near the homeowner and feel nervous in the vision cone.
2. **Feels the risk/reward.** They *want* to stay in the money pool longer but feel the loudness/heat pressure to leave.
3. **Has a "close call."** At least one moment of "oh no" → break sightline → relief. (This is THE feeling; if it's not here, iterate on detection tuning.)
4. **Makes a decision at the exit.** They weigh "bank now vs one more pool."
5. **Wants to go again.** The "one more run" pull is present.

If 3 and 5 land, the concept is validated. If not, we tune numbers (cone size, loudness decay, score rates) — NOT add features.

**Anti-goal:** do not judge this build on graphics, content amount, or polish. Judge it only on whether the loop is tense and repeatable.

---

## 5. Build Order (suggested, ~each a short milestone)

1. **Movement first.** Character that walks/crouches/sprints/swims in a grey box. Nothing else.
2. **Pool scoring.** Enter pool → score ticks → HUD shows score + at-risk. Add the stash/bank zone.
3. **Loudness meter.** Actions raise/lower it; show on HUD. No AI yet.
4. **Detection AI.** One patrolling homeowner with AI Perception sight cone + the three states. Wire hearing radius to loudness.
5. **Couple it all.** Getting caught loses at-risk points; escaping banks them. Add the sensor light.
6. **One costume/item swap.** Prove the modifier plumbing.
7. **Tune & playtest.** Numbers pass. Get 2–3 friends to play it separately. Decide: fun or not?

Only after this passes do we open the **networking** and **first real neighborhood** milestones (Tech doc, Phase 2+).

---

## 6. Architected-For-Later (the "co-op day one" reconciliation)

You want online co-op from day one — but building netcode into an unproven loop is the classic first-game trap. The compromise, enforced in this sandbox:

- **All shared/authoritative state lives in GameState/GameMode, never in local-only variables.** Score, loudness, alert level, banked points — server-authoritative from the very first line, even though we're testing single-player.
- Player input flows as **requests** the (local, for now) server validates.
- This means "adding co-op" later is **layering a network transport onto an already-correct authority model**, not rewriting gameplay. It's the single most important discipline in the whole project.

See `03_Technical_Architecture.md` for exactly how.

---

## 7. Assets for the Sandbox (all free/placeholder)

- Character: UE5 Mannequin or **Synty Sidekick Starter (free)**.
- Animation: **Mixamo** (free) walk/run/idle/crouch/swim.
- Props/cover: grey-box BSP or **Kenney (CC0)** kits.
- Water: default UE water/plane + a placeholder splash from **Kenney audio (CC0)**.
- See `04_Research_Findings.md` §Assets for sources and licenses.

---

*This build should be small enough that a first-time dev can reach it. Everything past it is earned by proving the loop is fun first.*
