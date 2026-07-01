# Pool Hop — Game Design Document (Vision)

*Version 0.1 — living document. Last updated June 30, 2026.*

---

## 1. The One-Liner

**Pool Hop** is a stylized online co-op stealth game where you and your friends sneak through sleeping suburban neighborhoods at 2 AM, hop from backyard pool to backyard pool for points, and slip away before the lights come on and someone calls the cops.

> The pitch in one breath: *Sneaky Sasquatch meets Untitled Goose Game, at midnight, in your swim trunks, with your best friends.*

---

## 2. Where This Came From (the true story)

This game is a love letter to a specific real memory:

A group of 4–8 friends spends every summer night at one friend's house, staying up until 1–2 AM playing video games. When the night peaks, they slip out, cut through backyards to avoid curfew and the cops, and reach a school on the edge of a nice, wealthy neighborhood. There they stash their bags and shoes in the playground slide, strip down to swim trunks, and disappear into the neighborhood — jumping fence to fence, pool to pool. Big houses, hot tubs, motion-sensor lights, the occasional homeowner peering out a window, once or twice an actual cop. Someone chased them once. **They never got caught.** They'd always evade, circle back to the school, grab their bags, and walk home like nothing happened.

Everything in this design should serve that feeling: **the thrill, the friendship, the running, the water, and the getaway.** That's the north star. When a design decision is unclear, ask "which choice feels more like that summer?"

---

## 3. Design Pillars

Everything we build should reinforce at least one of these. If a feature serves none of them, cut it.

1. **The Thrill of the Sneak.** Tension is the product. Motion lights, a face in the window, distant sirens — the fun is the pounding-heart moment before you're seen and the relief of getting away.
2. **Better With Friends.** This is a hangout. The game should be funny, chaotic, and social. One loud friend endangers everyone — shared risk is shared fun.
3. **The Water Is the Reward.** Getting *into* the pool is the payoff. Time in the water = points. The pool is safe-ish, joyful, and dangerous to linger in.
4. **Readable, Not Realistic.** Stylized, "good enough but looks great" cartoon world. Everything the player needs to read — vision cones, noise, alert level — is crystal clear, never hyper-real.
5. **The Getaway.** A run isn't scored until you make it back. Escaping with your points is the climax, not an afterthought.

---

## 4. The Core Loop

**Home Base → Pick a Neighborhood → Infiltrate → Pool Hop → Heat Rises → Escape → Score & Upgrade → Repeat.**

1. **Home Base (the intro / lobby).** You and your friends are in a retro living room playing couch co-op (a nod to Timesplitters 2 / Call of Duty 4). It doubles as the multiplayer lobby: pick loadouts/costumes, chat, ready up. The clock on the wall ticks toward midnight. When everyone's ready, you *leave the house*.
2. **Pick a Neighborhood.** A hand-drawn map shows 2–3 neighborhoods, each with a different vibe, layout, difficulty, and pool density. The crew votes / the host picks. You "spot up" at the staging point (the school playground) and stash your gear.
3. **Infiltrate.** Move through yards, over fences, through hedges. Avoid streetlights, motion sensors, and sightlines. Keep your **loudness** low.
4. **Pool Hop.** Get in the water. A pool's score **ticks up the longer you stay in**, but staying too long raises **heat** (splashing is loud; a lingering group draws eyes). Hot tubs, infinity pools, and covered pools have different risk/reward.
5. **Heat Rises.** Homeowners wake, lights flick on, a resident might come out and chase you, and if the neighborhood's alert crosses a threshold, **a cop shows up**. Threats escalate the longer you're out.
6. **Escape.** Make it back to the staging point (grab your stashed bag) before you're caught or the night ends. **Points only bank if you get out clean.**
7. **Score & Upgrade.** Bank points → leaderboards, unlocks (costumes, gadgets, cosmetic flair), and new neighborhoods. Then go again.

---

## 5. Core Mechanics

### 5.1 Scoring — "Time in Water"
- Points accrue **per second submerged / in a pool**, not per pool touched. This rewards nerve, not just speed.
- **Multipliers** for: number of *distinct* pools visited in one run (a "hop streak"), all players in the same pool together (a "crew splash" bonus), rare pools (infinity pool, rooftop hot tub), and clean getaways.
- **Risk curve:** the score-per-second in a single pool can *decay* the longer you stay (diminishing returns) so the optimal play is to keep *moving* and hopping — mirroring the real thrill of never staying in one place.
- **Bank-on-escape:** unbanked points are shown as "at risk." Getting caught loses the run's at-risk points (roguelike sting). This is the tension engine of the meta.

### 5.2 Loudness Meter (the noise system)
- A visible meter that rises with loud actions — **sprinting, splashing/diving, knocking over patio furniture, climbing noisy fences** — and falls when you're crouched, still, or in cover.
- Loudness **feeds the AI's hearing radius**: the louder you are, the farther threats can hear you. This is what makes splashing in a pool a genuine gamble.
- In co-op it's partly **shared/aggregated per neighborhood** — one cannonball can wake the block for everyone. Social tension by design (see §6).

### 5.3 Detection & "The Flashlight Cone"
- Threats have a **vision cone** — the "flashlight range" the player described: a visible arc of sight distance + angle. Standing in it fills a **detection bar**; break line of sight to cool it down.
- **Three alert states**, telegraphed clearly (icons: `?` suspicious, `!` spotted):
  - **Unaware** — patrolling / asleep / TV glow.
  - **Suspicious** — heard/half-saw something; investigates the last-known spot.
  - **Alert** — actively chasing or calling for help.
- **Motion-sensor lights**: stepping into a sensor zone snaps a floodlight on, spikes local visibility, and bumps nearby threats toward Suspicious. Learning the sensor map is a skill.

### 5.4 Threats (escalating)
- **The Homeowner (window watcher):** peeks from a lit window; if they see you, they come outside and become a **Chaser**. Slow but relentless within their property.
- **The Chaser ("the guy who chased us"):** a resident (or a big dog?) that pursues across yards once alerted. Losing them requires breaking sightline + going quiet. Great for comedic panic moments.
- **The Cop:** the escalation boss. Spawns when neighborhood heat crosses a threshold. Has a car, a real flashlight, and covers streets fast — pushes you off roads and into yards. Getting "caught" = cop tags you.
- **Environmental:** dogs behind fences (bark = noise spike), sprinklers (loud + wet trail), security cameras on fancier houses, sensor lights.

### 5.5 Movement & Traversal
- Core verbs: **walk, crouch-sneak, sprint, vault fences, climb, dive/enter pool, swim, hide** (in bushes, behind sheds, underwater breath-hold).
- **Underwater hiding**: submerge to break sightline (with an air meter) — a clutch escape tool and a nod to hiding in the deep end.
- **Fence vaulting** and **hedge-squeezing** as the connective tissue between yards — fast but sometimes noisy.

### 5.6 Items, Gadgets & Costumes
- **Found around the map** and **unlocked via the meta.** Examples to prototype:
  - *Gadgets:* noise-maker/decoy (throw to distract), sensor-jammer (temporarily disables a motion light), grappling/pool-noodle vault-assist (silly, on-brand), night-vision goggles (see cones better), quiet-shoes (reduce loudness).
  - *Costumes (mostly cosmetic, some light perks):* swim trunks (default), full wetsuit (quieter in water), inflatable flamingo ring (loud but hilarious, score flair), ghillie-bush suit (better bush hiding), retro tracksuit. Costumes lean into humor and self-expression — a huge social/retention hook.
- Keep perks **small** so the game stays about skill and nerve, not gear. Costumes should be **90% flex, 10% function.**

---

## 6. Co-op Design (2–8 players, online)

Co-op is the heart. Design principles:
- **Shared alert state.** The neighborhood's heat/alert is a **team resource** shown to everyone. One reckless player raises the temperature for all — this is the source of the best laughs and the best "DUDE, be quiet" moments.
- **Crew bonuses.** Being in the same pool together, escaping together, or reviving/un-spotting a friend gives bonuses — the game rewards actually playing *together*, not scattering.
- **Downed & rescue, not eliminated.** If a player is "caught," ideally they're *detained* (soft-fail) and a teammate can free them or they respawn back at the staging point after a delay — keeps friends in the session instead of watching a death screen.
- **Roles emerge naturally.** Lookout (watches cones), splasher (racks up pool time), distractor (draws the chaser). We won't hard-code classes early; let players self-organize.
- **Drop-in friendly.** 2–8 players; late-joiners should sync to correct world state (see Tech doc: prefer OnRep state over multicast events).

> **Reality check (see Tech doc):** online co-op from day one is the single biggest technical risk. We're committing to it as the vision, but the build plan keeps all shared state (score, loudness, alert) *server-authoritative from line one* so networking is a layer we add, not a rewrite.

---

## 7. Structure of a Session (the "night")

- **Timed night.** Each run is a night on a clock/wristwatch — e.g. 8–12 real minutes from "leave the house" to "dawn." Dawn = soft time pressure; heat also rises over time independent of the clock.
- **Escalation baked into the clock.** Early night = sleepy, easy. Late night = more lights on, homeowner patrols, cop more likely. Racing the dawn *and* the heat.
- **The wristwatch** is a diegetic HUD element — check it to see time left, maybe a compass back to the staging point.

---

## 8. Neighborhoods (the "levels")

Each neighborhood is a themed sandbox with its own layout, pool density, and threat profile. Launch target: **2–3 hand-authored neighborhoods.** Ideas:
- **"Maple Court" (starter):** classic cul-de-sac, medium homes, forgiving sightlines, few sensors. The tutorial neighborhood.
- **"The Heights" (rich/hard):** big estates, infinity pools and hot tubs (high score), but cameras, tall fences, more sensor lights, private security. High risk / high reward.
- **"Sprinkler Flats" (chaotic):** dense smaller yards packed close together — lots of pools crammed together, easy to hop fast, but everything's loud and neighbors are close. A "combo" playground.

Design each with **verticality, cover routes, sightline puzzles, and a signature "money pool."** Neighborhoods are the main content lever post-launch.

---

## 9. Meta, Progression & Social

- **Leaderboards:** per-neighborhood high scores, longest hop streak, biggest clean getaway, weekly rotating challenge neighborhood. Friends-list boards matter more than global for this audience.
- **Unlocks:** costumes, gadgets, cosmetic trails/emotes, home-base decorations, new neighborhoods.
- **Challenges / modifiers:** "no sprinting night," "cops start alert," "fog," "one big pool" — cheap replay value.
- **Photo mode / clip-worthiness:** this game lives or dies on *shareable chaos*. Lean into moments worth clipping (the flamingo-ring escape from a cop). A built-in highlight/replay or easy capture is a growth engine.

---

## 10. Art Direction

- **Stylized, low-poly-plus / cartoon** — think Synty POLYGON world with nicer lighting. Not photoreal. UE 5.8's new **Toon Shader** (experimental) is directly relevant.
- **Night palette:** deep blues and blacks, warm pools of light (streetlamps, windows, floodlights) as both mood and gameplay signal. Lighting *is* the level design.
- **Readability first:** vision cones, noise ripples, alert icons rendered clearly on top of the pretty world.
- **Retro home-base contrast:** the intro living room is warm, cozy, CRT-lit nostalgia — a deliberate tonal counterpoint to the cool tension outside.
- **Water** deserves special love — it's the reward and the brand. Stylized, splashy, satisfying.

---

## 11. Audio Direction

- **Silence as tension.** Sparse night ambience (crickets, distant dogs, AC hum) so that *your* noises pop. Splashes, footsteps, and fence rattles are gameplay-critical audio.
- **Dynamic music:** near-silent when unaware → pulse/heartbeat rising with detection → chase sting when Alert → sweet release cue on clean escape.
- **Diegetic comedy:** a barking dog, a sprinkler, a screen door slam. Sound sells both the fear and the funny.

---

## 12. Tone

Playful, nostalgic, a little mischievous — **never mean-spirited or criminal-feeling.** This is summer-night mischief, not a crime game. No property destruction as a goal, no violence; the "worst" outcome is getting chased off and losing your points. Keep it PG-13, warm, and funny. The fantasy is *freedom and friendship*, not delinquency.

---

## 13. Open Questions / To Decide Later

- **Should homeowner/watch/cop be player-controlled (asymmetric hunter) instead of AI? — RESOLVED: no, not for MVP.** Researched against Dead by Daylight/Evil Dead/TCM-style asymmetric design (see `06_Hunter_Antagonist_Design_Research.md`). A dedicated hunter role recreates the genre's well-documented "someone sits out and resents it" failure mode for small friend groups, and cuts against the "Better With Friends" pillar (§3) by making a friend the enemy. Keep pure AI antagonists through Phase 1-3. Optional temporary possession of an existing AI threat (Left 4 Dead Versus model — never removing a teammate from co-op to create a hunter) is flagged as a possible Phase 5+ stretch feature, not before.
- Exact player count sweet spot (4? 6? full 8?) — tune during co-op milestone.
- Is "getting caught" per-player (detained/rescue) or does it end the crew's run? (Leaning per-player detain + rescue.)
- Persistent progression vs per-session roguelike scoring — likely a blend (cosmetic persistence + per-run score runs).
- Procedural neighborhood generation as a long-term stretch (Hello Neighbor-style adaptive homeowner is a *stretch goal*, not MVP).
- Monetization stance (cosmetic-only? premium one-time? free demo?) — decide before any store assets are locked in; affects asset licensing (see Research doc).

---

## 14. What This Game Is *Not*

- Not a combat game. No weapons, no fighting.
- Not photoreal.
- Not a solo campaign — co-op and social are the point (single-player exists mainly as a practice/warm-up mode and a dev stepping-stone).
- Not a griefing/crime simulator. The tone is warm mischief.

---

*Next docs: **02 — MVP / Vertical Slice** (what we actually build first), **03 — Technical Architecture** (UE 5.8, co-op, MCP workflow), **04 — Research Findings** (sourced tooling/asset/best-practice research).*
