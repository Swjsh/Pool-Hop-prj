# Pool Hop — Design Bible

*Version 0.1 — the top-level vision that ties the domain design docs together. Last updated 2026-06-30. Engine: Unreal Engine 5.8, Blueprints-first.*

> **What this doc is.** The single north-star document for Pool Hop's design package. It states the fantasy, the pillars, and the core loop, then shows how the domain design docs (`01`–`07`, plus forward-spec `11`, in this `Docs/design/` folder) interlock into one coherent game. Read this first; then dive into whichever domain doc owns the piece you're building. For the *ordered build plan* that turns all of this into editor work, see the companion `08_Implementation_Roadmap.md`.
>
> **What this doc is NOT.** It is not a re-derivation of the source vision — that lives in `Docs/01_Game_Design_Document.md` (the canonical GDD) and the scope/architecture docs `Docs/02`/`03`. This bible *synthesizes* those plus the seven build-ready domain specs into one map. When this doc and a domain doc disagree on a number, the **domain doc wins** (it's closer to the metal); when a domain doc and the source GDD/Tech doc disagree on *vision or authority*, the **source doc wins**.

---

## 1. The North Star — "That Summer"

Pool Hop is a love letter to one real memory (`Docs/01` §2): a group of friends slips out at 1–2 AM, cuts through wealthy backyards, and hops fence-to-fence, pool-to-pool — dodging motion lights, a face in a window, once an actual cop — and **never gets caught**. They always evade, circle back to the school playground where they stashed their bags and shoes, and walk home like nothing happened.

**Everything we build serves that feeling: the thrill, the friendship, the running, the water, and the getaway.** When a design decision is unclear, the tie-breaker is always the same question: *which choice feels more like that summer?*

**Three-word art north star** (`design/01` §1): *Cozy. Cool-dark. Crystal-readable.* The world is a warm memory remembered at 2 AM — deep navy suburbia punched through by warm pools of light — with a flat, high-contrast readability layer (cones, noise rings, `?`/`!` icons) laid on top like a board game over a diorama.

**Tone guardrail** (`Docs/01` §12): playful, nostalgic, mischievous — **never mean-spirited or criminal.** Nothing is stolen or broken; the worst outcome is getting shooed off and losing your at-risk points. The fantasy is *freedom and friendship*, not delinquency.

---

## 2. Design Pillars

Every feature must reinforce at least one pillar (`Docs/01` §3). If it serves none, cut it.

1. **The Thrill of the Sneak.** Tension is the product — the pounding-heart beat before you're seen and the relief of getting away. The MVP is judged on whether this *close call* arc lands (`Docs/02` §4, `design/04` §1).
2. **Better With Friends.** A social hangout. Shared risk = shared fun: one loud cannonball wakes the block for everyone (`Docs/01` §6, `design/06` §5 heat).
3. **The Water Is the Reward.** Getting *into* the pool is the payoff — time-in-water = points. Water is the brand (`design/01` §4, `design/03` the grotto).
4. **Readable, Not Realistic.** Stylized cartoon world; the gameplay-critical layer (cones, noise, alert, loudness) is always crystal-clear on top (`design/01` §2, `design/04` §11, `design/07` §3).
5. **The Getaway.** A run isn't scored until you make it back. Points only *bank* on a clean escape (`Docs/01` §5.1, `design/06` §6).

**Market validation** (`Docs/05`): Pool Hop's loop already matches the winning "friendslop" formula (shared alert, one-loud-friend-dooms-all, emergent chaos, readable-on-purpose low fidelity, cosmetic-only costumes). The genre reference is P.O.N. / R.E.P.O. / PEAK — the lesson is *emphasis and clip-ability*, not a redesign: make the AI-chase louder and funnier sooner, and the antagonist's behavior alone can carry marketing.

---

## 3. The Core Loop (and how the pieces feed it)

**Home Base → Pick a Neighborhood → Infiltrate → Pool Hop → Heat Rises → Escape → Score & Upgrade → Repeat** (`Docs/01` §4).

The loop is powered by one coupling that every domain doc respects — **the tension chain**:

```
   Movement (speed/action)                          design/07  (movement + UI)
        │
        ▼
   LoudnessComponent  ── raises a 0–100 value ──►    design/06 §2
        │  fires ReportNoiseEvent scaled by loudness
        ▼
   AI Watcher hearing + sight  ── detection meter ►  design/04  (the Watcher)
        │  detection resolves server-side
        ▼
   AlertDirector  ── aggregates into neighborhood HEAT ► design/06 §5
        │  escalation at thresholds (Suspicious → Alert → cop, Phase 5)
        ▼
   Caught = lose AT-RISK points  ·  Escape to stash = BANK them  ► design/06 §3/§6
        ▲                                                            │
        └──────────────  PoolScoring feeds at-risk score  ──────────┘  design/06 §3
                          (time-in-water, decay, hop-streak, crew-splash)
```

**Read the chain as a sentence:** how you *move* sets how *loud* you are; loudness sets how far the *Watcher* can hear you; being seen or heard fills a *detection* meter; detection feeds neighborhood *heat*; heat escalates the threat; getting caught costs you the *at-risk* points that *scoring* has been piling up — and only a clean *escape* to the stash turns at-risk into banked. That single chain is the whole game. Every domain doc is a detailed spec of one link in it.

**The one discipline that holds it together** (`Docs/03` §2, `CLAUDE.md`): every authoritative value in that chain — loudness, score, detection, heat, banked points, night timer, air, detained — lives on **GameMode (rules) / GameState (replicated shared truth) / PlayerState (replicated per-player)**, *never* on the character/pawn. The pawn holds movement (`CharacterMovementComponent`, replicates for free) + cosmetic feedback only. This is what makes co-op (Phase 2) a *layer* we add, not a rewrite — and it is non-negotiable in every domain doc.

---

## 4. The Domain Doc Index — how the seven interlock

Each doc is build-ready (exact paths, parent classes, typed/replicated variables, tuning numbers, MCP steps). Here is what each owns and how it connects to the others.

| # | Doc | Owns | Feeds / depends on |
|---|---|---|---|
| **01** | [Art & Style Direction](01_Art_And_Style_Direction.md) | The look (`Cozy. Cool-dark. Crystal-readable.`), the canonical night palette + `DA_ArtPalette`, the grey-box toon material, the night PP/moon/sky rig, and the **readability layer** (vision-cone decal, noise-ring Niagara, `?`/`!` icons, HUD) that every other system renders through. Forward-looking Substrate Toon master, toon water, MegaLights playbook, HDRI sky. | Renders the *outputs* of `04` (cone/alert), `06` (loudness/score/heat) as pure readers of replicated state. Its §2 readability layer ships **with** `04`/`06`, not before. |
| **02** | [Neighborhood — Maple Court](02_Neighborhood_MapleCourt.md) | The first authored space: a buildable grey-box placement plan (world coords, dimensions, `SB_` props) for the tutorial cul-de-sac — pools A–D with escalating exposure, the one sensor light, the stash zone, and the Watcher's 6-waypoint patrol. | **Phase 4** deliverable. Reuses the exact five systems from `06`/`04`/`07` unchanged — Maple Court is where the proven sandbox systems get their first real level. Difficulty is authored via *route + layout + light density* (`design/01` §6), never per-actor cone changes. |
| **03** | [Underground Pools — "The Grotto"](03_Underground_Pools.md) | A net-new **stretch money-zone** (Phase 4+ on "The Heights"): a single committed door, a caretaker, a lockdown timer. The one place in Pool Hop where the smart play is to *stay*. | **100% reuse** of the five MVP systems with a grotto tuning profile + one transition actor + a re-skinned homeowner. Its real value now (§10): it *pressure-tests* whether `06`'s scoring/loudness/heat are data-driven enough (per-pool profiles, environment multipliers, local heat feeding global). |
| **04** | [The AI Watcher (Homeowner)](04_AI_Watcher.md) | **The priority build deliverable** — MVP System 4. The single patrolling homeowner: AIPerception (sight cone + loudness-scaled hearing), Blackboard, Behavior Tree (Unaware → Suspicious → Alert), EQS search, the server-authoritative detection contract, and catch→detain soft-fail. Establishes the **canonical AI-perception profile** all future threats reuse. | *Reads* loudness from `06` (System 2); *feeds* heat to `06`'s AlertDirector (System 5) and the lose-at-risk hook to scoring (System 3). *Renders* through `01`'s cone/icon readability layer. Its cone geometry + 3-color state model are the fixed standard for cop/chaser (`Docs/07` §4). |
| **05** | [Characters](05_Characters.md) | Player + Watcher bodies (placeholder Manny/Quinn → Synty Sidekick), the shared-skeleton decision, the Mixamo retarget plan, and the **CostumeComponent + Costume Data Asset** spine (MVP System 5 = one swap). | Costume identity → PlayerState (server), applied cosmetically via OnRep (authority rule). Stat modifiers are *read by* the server systems in `06` (LoudnessComponent setters) and `04` (bush-hide bonus). The Watcher body hosts the flashlight that *is* `04`'s vision cone (`design/01` §6). |
| **06** | [Core Systems Tech Spec](06_Core_Systems_TechSpec.md) | The build blueprint for the four reusable server-authoritative systems — **LoudnessComponent, PoolScoring + PoolVolume, CostumeComponent, AlertDirector** — plus the exact GameState/GameMode/PlayerState variable tables with replication modes. This is the mechanical backbone the whole tension chain (§3) runs on. | Every other domain doc plugs into these components. It *is* the tension chain in code. Build order inside it: Loudness → Scoring → Detection AI (`04`) → couple (AlertDirector) → Costume (`05`). |
| **07** | [Movement Polish + UI/HUD](07_Movement_And_UI.md) | Extends the done System 1 (hide-in-bush, hedge-squeeze, underwater breath-hold/air on PlayerState, dive) + the full UMG HUD (loudness meter, at-risk/banked score, `?`/`!` + screen-edge detection, diegetic wristwatch, multi-channel close-call feedback). | The HUD is the *read-out* for `06`'s values and `04`'s detection — every widget binds to a replicated source with a safe stub, so it builds NOW before Systems 2–4 exist. Movement feeds loudness (`06`). The close-call vignette+heartbeat is where Pillar 1 (`§2`) is *felt*. |
| **11** | [Loot & Extraction](11_Loot_And_Extraction.md) | **Forward-spec, Phase 5+ (parked).** Found-in-the-world field trinkets + one ultra-rare nightly Trophy item, carried at-risk and banked like score, small situational stat nudges via a sibling of the CostumeComponent pattern. | Mirrors `06`'s at-risk/banked pattern and `05`'s Data-Asset-+-Component spine one-for-one rather than inventing a parallel system; extends `01`'s palette with a rarity language kept deliberately separate from the alert-state colors. Does not build ahead of Step 8 (`Docs/02` §8). |

**The interlock in one paragraph:** `06` is the spine (the systems + the authoritative state); `04` is the antagonist that makes the spine *tense*; `07` is how the player *feels and reads* the spine (movement in, HUD out); `05` is the bodies + the costume spine that plugs modifiers into `06`/`04`; `01` is the flat readability language + night mood every system renders through; `02` is the first authored level those proven systems inhabit; `03` is the signature stretch zone that stress-tests whether the spine was built data-driven enough; `11` is a parked forward-spec that generalizes `05`/`06`'s at-risk/banked + Data-Asset patterns to found loot, once the spine is proven. Build the spine right (server-authoritative, data-driven, readable) and everything else is a *layer* — the same discipline that makes co-op a layer, not a redo.

---

## 5. Scope & Sequencing (the disciplined "no")

The MVP is a **systems sandbox** on a deliberately ugly grey-box map — its one job is to answer *"is sneaking to a pool, banking points while managing loudness, and escaping a patrol actually fun for one player?"* (`Docs/02` §0). Judge it only on **tense and repeatable**, never on graphics or content.

**Locked build order** (`Docs/02` §5 — the domain docs all obey it): System 1 movement is **DONE** → **Loudness** (`06` §2) → **Scoring + banking** (`06` §3) → **Detection AI / the Watcher** (`04`) → **couple it all** (AlertDirector + sensor light + caught/escape/heat, `06` §5) → **one costume/item swap** (`05` §7, `06` §4) → tune & playtest.

Everything forward-looking (Maple Court `02`, the grotto `03`, the Synty/toon art pass `01` §3–7, the cop/chaser, co-op netcode) is **specified but parked**. Writing those specs now is not permission to build them — it keeps the underlying systems honest (the grotto §10 is the clearest example) and means later phases are tuning-and-layout jobs, not rewrites. The full dependency-aware ordering lives in **`08_Implementation_Roadmap.md`**.

---

## 6. Hard Constraints (every doc obeys these)

1. **Server authority** (`Docs/03` §2): authoritative state on GameMode/GameState/PlayerState, never the pawn. Client → request → server validates → replicates back via OnRep (prefer OnRep over Multicast for late-join safety).
2. **Build order + scope** (`Docs/02` §5): build only the current system; park the rest.
3. **Folder + naming** (`CLAUDE.md`): our content under `Content/_Project/{Core,Characters,Components,AI,Systems,Gameplay,UI,Data,Maps}`; `BP_`/`M_`/`MI_`/`IA_`/`IMC_`/`L_`/`SB_`/`DA_`/`DT_`/`WBP_`/`NS_` prefixes. Never edit stock template folders in place — duplicate into `_Project/`.
4. **Ray tracing DISABLED** (`Docs/LESSONS.md`, `r.RayTracing=False` after a HWRT SBT deadlock): Lumen software + MegaLights, no HWRT reflections. Never re-enable `r.RayTracing` to chase a reflection.
5. **Blueprints-first**, C++ only when truly forced (the one flagged case is AI affiliation teams — sidestepped in `04` §3 via Detect-Neutrals + Tags).
6. **Manual Play-In-Editor is the only test harness** (`CLAUDE.md`) — no unit-test scaffolding.

---

## 7. Success Definition

The concept is **validated** when a fresh playtester, told only "get points from pools and don't get caught," in a 5-minute solo session (`Docs/02` §4): reads the tension (crouches near the Watcher), feels the risk/reward (wants one more pool but feels the heat), has at least one **close call** (oh-no → break sightline → relief), makes a real decision at the exit (bank vs one more), and **wants to go again**. If criteria 3 (close call) and 5 (one-more-run) land, we scale to a real neighborhood and layer co-op. If not, we **tune numbers** (cone size, loudness decay, score rates) — we do not add features.

---

*Start with this bible for the "why," open the matching `01`–`07` domain doc for the "what/how," and follow `08_Implementation_Roadmap.md` for the "in what order." The vision is fixed; the numbers are not — every tuning value in every doc is a seed to move in playtest, stored in a Data Asset so it can be moved without touching a graph.*
