# Pool Hop — Hunter/Antagonist Design Research

*Compiled July 2026. Triggered by a design question: should the homeowner, neighborhood watch, or cop be a human-controlled "hunter" role (asymmetric PvP, like Dead by Daylight) instead of pure AI?*

---

## The Question

Currently the GDD scopes homeowner/chaser/cop entirely as AI (UE5 AI Perception — vision cones, Unaware/Suspicious/Alert states). The idea on the table: let a player *be* the homeowner/watch, hunting their friends instead of an AI doing it.

This isn't just a feature toggle — it cuts against Pool Hop's stated #2 design pillar, **"Better With Friends"** (GDD §3): the whole friend group co-op against the environment together, with shared risk (one loud friend endangers everyone) as the fun. A dedicated hunter role makes one friend the enemy of the rest, which is a different game. Worth researching properly before deciding, not guessing.

---

## What the Asymmetric-Hunter Genre Teaches

- **The hunter role is structurally the harder role to make fun.** In Dead by Daylight, players and commentators describe most killers as "not fun due to being underpowered," with a small viable-killer meta and constant nerf/buff churn — described in retrospectives as "an unbalanced mess that would need an entire overhaul." Balancing 1-vs-many so *both* sides feel good is a persistent, unsolved tax on the whole genre, not a solved problem waiting to be copied.
- **Killer-role fatigue creates a death spiral.** As DBD's killer role got less rewarding, experienced players stopped queueing for it — killer queue times went from ~1 minute (2021-22) to 4-5+ minutes, since matches need far fewer killers than survivors.
- **The small-friend-group "sit out" problem is a named, recognized design failure.** Genre analysis flags that fixed 1-hunter-ratio games "need to change" specifically because when a friend group plays together, extra friends either can't get the role they want or can't all play at once.
- **The genre's own fix is more hunters, not solo hunters.** *The Texas Chain Saw Massacre* deliberately broke from the DBD/Evil Dead single-killer template by making "The Family" a 3-player hunting team specifically so more friends can be actively engaged as hunters simultaneously. *Killer Klowns from Outer Space* followed the same pattern. Nobody in the genre is solving the friend-group problem by keeping a single dedicated hunter seat.
- **Hybrid AI/human-fill precedent exists, but the AI side is the hard problem.** DBD ships survivor bots broadly but killer bots only for a handful of characters, used narrowly to backfill disconnects — because killer AI (unique powers, chase logic, resource management) is dramatically harder to build than survivor AI. This is years into a AAA-funded live-service game and still incomplete.
- **Left 4 Dead's Versus mode is the cleanest "optional possession" precedent, and the closest fit to Pool Hop.** Infected are AI-controlled by default (the Director spawns and drives them); humans simply *take over* those same AI-driven roles when present, up to a cap. Nobody is ever removed from the co-op team to make room for a hunter — the antagonist seat just accepts a human when one wants it.
- **Games built on the same pillar as Pool Hop stay single-team on purpose.** Content Warning and similar "everyone-vs-environment" co-op titles generate tension through risk/reward incentives (film the monster, revive teammates) rather than a player-controlled antagonist, and that's enough to sustain real tension. Co-op design literature names "all players depending on one another, winning or losing together" as *the* retention driver for friend-group games — a betrayal/hunter mechanic cuts directly against it.

*Sources: [Legacy of Games — DBD design evolution](https://legacyofgames.com/2025/10/19/how-players-ruined-dead-by-daylight-a-fascinating-evolution-of-game-design/), [Steam Discussions — killer frustration](https://steamcommunity.com/app/381210/discussions/0/1696045708658875363/), [BHVR Forums — Killer Role Crisis](https://forums.bhvr.com/dead-by-daylight/discussion/465494/for-developers-the-killer-role-crisis-why-the-4v1-balance-is-failing-and-queue-times-are-rising), [Seasoned Gaming — asymmetric games need to change](https://seasonedgaming.com/2022/09/11/opinion-asymmetrical-games-are-all-the-rage-but-they-need-to-change/), [In Review Critics — Texas Chain Saw Massacre](https://inreviewcritics.com/2023/07/02/will-texas-chainsaw-massacre-make-the-cut-reviewing-the-technical-test-and-forecasting-wishlisting-the-game/), [DBD Wiki — Bots](https://deadbydaylight.fandom.com/wiki/Bots), [PCGamesN — killer bots](https://www.pcgamesn.com/dead-by-daylight/killers-bots-bhvr-6-4-0), [Left 4 Dead Wiki — Versus](https://left4dead.fandom.com/wiki/Versus), [Wikipedia — Content Warning](https://en.wikipedia.org/wiki/Content_Warning), [Game Wisdom — Creating Compelling Co-op Design](https://game-wisdom.com/critical/creating-compelling-coop-design).*

---

## Recommendation

**Don't make the homeowner/watch/cop a dedicated human role. Keep pure AI for the MVP and all of Phase 1-3.**

Every finding above points the same way for a game whose whole premise is "the friend group plays together": the hunter role is the hardest role in the genre to make fun even for AAA studios with years of iteration; a fixed hunter slot recreates the exact "someone sits out and resents it" failure mode the genre's own newest entries (TCM, Killer Klowns) are actively designing away from; and Pool Hop's tone (warm, funny, mischief — not betrayal) is tonally opposed to making a friend the enemy.

**If you want antagonist agency as a future "spice" feature, design it as optional temporary possession, not a subtraction from the co-op team** — Left 4 Dead's model: AI runs the cop/homeowner by default; a spare player (extra body in a smaller lobby, someone already caught, or a designated "director" role) can jump into an existing AI-controlled threat for a limited window. This only ever *adds* an option and never *removes* a teammate from the crew, so it can't recreate the sit-out problem — but it's explicitly a **Phase 5+ stretch idea**, not something to design around now. Building it too early risks the same trap DBD is still in: spending scarce dev time on the hardest, least-proven role in the genre before the core AI-only loop is even proven fun (per the MVP doc's own success criteria).

**Action taken:** logged as a resolved open question in `01_Game_Design_Document.md` §13 and the threats section — AI-only confirmed for MVP, optional possession flagged as a stretch goal for Phase 5+, not before.
