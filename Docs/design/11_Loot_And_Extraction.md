# Pool Hop — Loot & Extraction (Trinkets + The Trophy)

*Version 0.1 — new domain doc. Added 2026-07-01 from a human brainstorm + cited research pass. **Phase 5+ forward-spec — parked.** Do not build any of this ahead of `Docs/02` §8 (MVP Step 8, the playtest that decides if the core loop is fun). Engine: UE 5.8, Blueprints-first.*

> **Scope of this doc.** A found-in-the-world loot layer that sits *alongside* the existing Costume system, not inside it: field pickups you carry at-risk during a run, one ultra-rare nightly "Trophy" item (the user's original idea — a garden gnome), and a small equippable-trinket slot system with situational (not power-creep) buffs. It reuses three patterns you've already built rather than inventing new ones: the **at-risk/banked** split (`06_Core_Systems_TechSpec.md` §3 / `CANON.md` Step 3), the **Data Asset + Component + PlayerState** spine (`05_Characters.md` §4, the CostumeComponent pattern), and the **LoudnessComponent public modifier hook** (`CANON.md` Step 2).
>
> **What this doc is NOT.** Not an MVP requirement — `Docs/02` §2 explicitly lists "full costume wardrobe, gadgets sandbox, meta-progression, unlocks" as OUT until after Step 8. Not a replacement for `BP_CostumeComponent`/System 5 — that stays exactly as `05_Characters.md` specifies; this is a **sibling** component, not an edit to it. Not yet build-ready in the sense Steps 0–8 are — treat every MCP action below as a *plan*, not a queue to start pulling from this session.
>
> **Read first:** `00_Design_Bible.md` §3 (the tension chain this plugs into), `05_Characters.md` §4 (the pattern this doc mirrors), `06_Core_Systems_TechSpec.md` §3 & §6 (the at-risk/banked + variable-table conventions), `CANON.md` (naming/enum conventions — this doc's names ARE canon from creation, since nothing else has drifted against them yet).

---

## 0. Why this exists

The human's ask: add loot that makes the run feel like an extraction game on top of the pool-hopping — a common pickup (speed-boosting pants) plus one ultra-rare hidden collectible (a garden gnome) that occupies a real inventory slot with its own ability, and a general risk/reward "get the loot and the score home before you're caught" layer. This doc turns that into a spec that plugs into the existing tension chain instead of bolting on a second, disconnected system.

---

## 1. Research foundations (cited, condensed)

Four practices came out of a dedicated research pass on extraction/loot design; each maps to a decision below.

1. **Extraction tension is sharper with fewer, clearer decision points, not more inventory.** Hunt: Showdown's single-bounty-token design (not "loot every container") concentrates the whole run's risk into one legible object — and *carrying it broadcasts your position map-wide*, which is what makes the walk to extraction tense. Deep Rock Galactic makes the "push vs. leave" call concrete via a visible, trackable resource (Nitra) rather than abstract risk math. → **Decision:** the Trophy (gnome) behaves like Hunt's bounty, not like a stat item you quietly pocket — it's loud and telegraphed while carried.
2. **Permadeath/loss should be scoped to the run, not to the item's existence.** Hunt keeps character-scoped loss (you lose *this hunter*) separate from account-scoped permanence (gear unlocks persist). The generalizable lesson for a rare drop: losing it to one bad patrol should not delete it from the game forever, or the rare-spawn becomes a rage-quit generator instead of a thrill. → **Decision:** loot dropped on capture respawns as a recoverable world pickup near the capture point, never deleted (§4).
3. **Rarity needs redundant, learned-once visual encoding, and RNG needs a floor.** Risk of Rain 2 encodes rarity three ways at once (world glow, inventory border, HUD list) so it reads in every context. WoW-style "bad luck protection" (odds climb after repeated misses, or a hard guarantee by N) is the standard answer to RNG frustration — games *without* a floor are the ones players cite as feeling punishing. → **Decision:** a rarity-color extension to `DA_ArtPalette` (§3) + a pity counter on the Trophy spawn roll (§6).
4. **Itemization stays fun via situational strength + synergy, not stacking power.** Risk of Rain 2, Slay the Spire, and Hades all avoid a single dominant build by making items *context-dependent* rather than uniformly strong, and by decoupling "any build clears the easy difficulty" from "optimal synergy matters at the hard difficulty." → **Decision:** trinket modifiers follow the exact small-nudge guardrail your Costume system already uses (`05_Characters.md` §4.1), never stacked into a dominant loadout (§5).

*(Citation strength note, carried over honestly from the research pass: patterns 1–2 and the Nitra example in pattern 1 are well-sourced to specific postmortem/dev-quoted articles; the "fixed-pool-with-random-activation" spawn convention in §6 is a general extraction-shooter industry pattern, not tied to a single citable source — flagged so it isn't mistaken for a direct quote.)*

---

## 2. The two-tier loot design

| Tier | What it is | Rarity band | Risk model |
|---|---|---|---|
| **Field Trinkets** | Small found items scattered per neighborhood (the "speed pants") — one modest, situational stat nudge each. | Common / Uncommon / Rare | At-risk while carried (§4); banked at the stash like score. |
| **The Trophy** | One unique, ultra-rare item per night per neighborhood (the garden gnome). Also an equippable trinket once banked, but its real hook is the carry-tension mechanic (§4), not raw power. | Mythic (exactly one in the world at a time) | Same at-risk/banked rule, but carrying it is *loud* — a Hunt-style "you are now hunted" cost (§4). |

Both tiers are **found in the world during a run**, not purchased or unlocked from a menu — that's the extraction feel the human asked for. Everything banked (successfully brought to the stash) joins the player's permanent collection and can be equipped as a trinket on a future run (§5).

---

## 3. Rarity model — extends `DA_ArtPalette`, does not touch the alert colors

`01_Art_And_Style_Direction.md` §2.1 reserves `ReadSafe`/`ReadWarn`/`ReadAlert` (green/amber/red) **exclusively** for gameplay alert-state readability, with an explicit guardrail against reusing that language elsewhere ("players never confuse warm lamp = pretty with amber = getting caught"). Loot rarity needs its own visual language for the same reason — so add new tokens, don't borrow the alert or world-light ones:

| New `DA_ArtPalette` token | Used for | Notes |
|---|---|---|
| `LootUncommon` | Uncommon field trinket world-glow | A cool ice-blue, distinct from `PoolTurquoise`/`TVGlow`. |
| `LootRare` | Rare field trinket world-glow | Violet — no existing token uses purple. |
| `LootMythic` | The Trophy's world-glow | Saturated gold-pink, but **always paired with a particle sparkle + a distinct audio chime** — never rely on hue alone, since a static gold glow could read as `LampWarm` (porch light) at a glance. Motion + sound is the disambiguator, per RoR2's redundant-encoding lesson (§1.3). |
| *(Common tier: no glow at all)* | — | Deliberate restraint — per the "loot pinata" pitfall (§10), making every pickup glow cheapens the rare ones. |

Encode rarity redundantly per RoR2's pattern: world-mesh glow color (above) + a border/tint on the future inventory icon + (once the HUD exists) a matching list-entry color — same token, three surfaces.

---

## 4. Extraction mechanics — carried vs. banked

Mirrors the existing at-risk/banked score pattern (`06_Core_Systems_TechSpec.md` §3, `CANON.md` Step 3) exactly, applied to items instead of points:

| State | Lives on | What happens |
|---|---|---|
| **Carried** | `PlayerState.CarriedLoot` (Array of `DA_LootItem` refs, RepNotify) | Added on pickup overlap. At risk — see "on capture" below. |
| **Banked** | `PlayerState.BankedLoot` (Array of `DA_LootItem` refs, Replicated) | Moved from Carried on stash overlap, alongside the existing `Server_BankAtRisk` call. Permanent for the session (see §6's save-system caveat). |

**On capture (`GameMode.HandleDetain`, `CANON.md` Step 5 substitution):** add a `Server_DropCarriedLoot(PS)` call alongside the existing `Server_LoseAtRisk`. For each item in `CarriedLoot`, spawn a `BP_LootPickup` at the player's pre-teleport location (recoverable by anyone that night), then clear the array. **Never destroy the underlying `DA_LootItem` asset or delete the drop outright** — per research finding 2, permanently deleting a rare item on one bad catch is the exact mechanic that generates rage-quits, not tension.

**Carry-loudness coupling (the Hunt-bounty mechanic, research finding 1):** each carried item's `DA_LootItem.CarryLoudnessMult` field multiplies into the existing `LoudnessComponent.LoudnessModifier` hook (`CANON.md` Step 2 — already a public choke-point, no new component surface needed). Field Trinkets nudge this barely (`1.02`–`1.05`). **The Trophy is different on purpose:** on top of a larger passive multiplier (~`1.3`), it fires a periodic `Server_ReportAction("Action.GnomeCarry")` bump (reusing the exact `Server_ReportAction`/`GetActionInstantBump` plumbing already built in Step 2 — zero new component work) every ~8–12s while carried. This is the literal "holding the bounty broadcasts your position" mechanic, expressed through a system you already have.

---

## 5. Trinket slots & the stat-modifier guardrail

**New sibling component, not an edit to `BP_CostumeComponent`:** `BP_LootComponent` (`_Project/Components/`), attached to `BP_PlayerCharacter` alongside `CostumeComp`. Same apply pattern as Costume (`05_Characters.md` §4.3): a server-set identity on PlayerState, an OnRep that calls the component to apply modifiers, cosmetic-vs-authoritative split preserved.

**`PlayerState.EquippedTrinkets`** — `Array<DA_LootItem ref>`, **RepNotify**, capped at **2 slots** (proposed default, tuning knob — see §11). Chosen from `BankedLoot` at the safehouse before a run starts (no menu exists yet — Phase 6/7 territory; for now this can be a debug-key swap like the MVP costume proof).

**`FLootTrinketModifier` struct** — deliberately mirrors `FCostumeStatModifier` (`05_Characters.md` §4.1) field-for-field where it can, so both components read from the same mental model:

| Field | Type | Default | Meaning |
|---|---|---|---|
| `MoveSpeedMultiplier` | float | `1.0` | The "speed pants" case. Keep within the same **±25% guardrail** the Costume system already enforces — this is a game about nerve, not gear. |
| `LoudnessFootstepMultiplier` | float | `1.0` | Same semantics as the Costume field; a trinket and a costume modifier both feed the same `LoudnessComponent` hook and should be additive, not each independently ±25% (see the stacking guardrail below). |
| `BushHideBonus` | float | `0.0` | Additive reduction to AI sight-fill rate while hidden — same semantics as `05_Characters.md`'s Ghillie costume field. |
| `DetectionRangeMultiplier` | float | `1.0` | New. Shrinks the *effective* distance the Watcher's sight check uses against this player. **Forward dependency, not yet a hook that exists** — needs a read added to `BP_WatcherController.HandlePerceptionUpdate`/`TickBrain` (`CANON.md` Step 4 substitution) to divide the measured distance by this multiplier before comparing to `SightRadius`. Flag this the same way `05_Characters.md` §9 flags its own forward dependencies — build the read-hook when this system is actually scheduled, not speculatively now. |
| `ScoreFlairMultiplier` | float | `1.0` | Same semantics as Costume's field — situational, not power. |

> **Stacking guardrail (research finding 4 — the single most important rule in this doc):** a costume modifier and a trinket modifier that touch the *same* underlying value (e.g. both reduce footstep loudness) must combine **multiplicatively against the same ±25%-ish band the Costume system already respects**, never stack additively toward a dominant "quietest possible" loadout. If a specific combo is measured (in playtest) to be strictly best in every situation, that's a bug in this spec to fix by making one of the two items *situational* instead — e.g. a trinket that's strong near water but does nothing on dry land — not by nerfing numbers in isolation. This is exactly the Hades/RoR2 lesson: the goal is "which combo suits *this* run," never "which combo is always correct."

---

## 6. Spawn design

**Field Trinkets:** a curated pool of spawn `Transform`s per neighborhood (placed by hand, like the existing `PatrolPoint`/pool placements), larger than the number that actually spawn any given night. Each night, a weighted-random subset activates (weight by rarity — mostly Common, a few Uncommon, rare Rare). This is a standard extraction-genre convention (fixed possible-locations, randomized per-raid activation) rather than fully free-roam random spawning — it gives repeat players learnable "tells" over many sessions without making drops fully predictable. *(Flagged per §1's citation note: this is an industry-convention inference, not a directly-cited source.)*

**The Trophy (gnome):** a smaller, separate curated pool of hiding-spot transforms (specific bushes/sheds/props — places a player would plausibly search, not just anywhere). Exactly **one** spawns per night, chosen from that pool. Telegraph it from ~30m via the `LootMythic` glow + sparkle + chime (§3) so finding it reads as skill-plus-luck, not pure chance.

**Pity mechanism (research finding 3):** track `NightsSinceLastGnome` (server-only int, lives on the spawn manager below — not GameState, since it's bookkeeping nobody needs replicated). Increase spawn probability per consecutive night without one, with a hard guarantee by `GnomeGuaranteedAfterNights` (proposed default **5** — tuning knob, §11).

**New actor:** `BP_LootSpawnManager` (`_Project/Systems/`, one instance per level or attached to `BP_PlayerGameMode` like `AlertDirector`): `FieldLootSpawnPoints: Array<Transform>`, `GnomeSpawnPoints: Array<Transform>`, `NightsSinceLastGnome: int` (None), `GnomeGuaranteedAfterNights: int = 5` (None). Functions: `Server_PopulateFieldLoot()` (called at night-start), `Server_RollForGnome()` (called at night-start, spawns a `BP_LootPickup` carrying the unique Trophy `DA_LootItem` at one chosen `GnomeSpawnPoints` entry).

**Save-system dependency, flagged honestly:** `BankedLoot`, the trophy collection, and `NightsSinceLastGnome` are only as persistent as the current session — there is no save system yet (that's `08_Implementation_Roadmap.md` Phase 6, "meta & polish"). Until then, this spec degrades gracefully to **session-scoped only**: a permanent trophy shelf and a pity counter that survives between play sessions are both blocked on Phase 6, not on anything in this doc. Don't build a bespoke save shim to work around this — wait for Phase 6.

---

## 7. Co-op design decision — needs a human call, not a silent default

The GDD's co-op pillar (`Docs/01` §6, "Better With Friends" — `00_Design_Bible.md` §2 pillar 2) treats heat/alert as a **shared team resource**. Loot raises a question that pillar doesn't answer on its own: in a 2–8 player run, is the Trophy **one gnome for the whole team** (first player to bank it credits the whole crew's collection — reinforces "shared risk/reward," matches how team heat already works) or **per-player** (each player can find their own copy — simpler, but turns a "the crew found the gnome" moment into a personal loot roll, working against the shared-team framing)?

**Proposed default, consistent with the existing pillar:** one Trophy per night, shared-team credit on banking — same shape as `TeamScoreBanked` already being a GameState-level shared value. Flagging this explicitly rather than deciding it silently, since it's a vision-level call (per `00_Design_Bible.md`'s own rule that the source GDD/vision wins over a domain doc's invented default).

---

## 8. Data & build spec (for whenever this is actually scheduled)

**`DA_LootItem`** — PrimaryDataAsset, parent `LootItemDataAsset`, path `Content/_Project/Data/Loot/DA_LootItem_Base` (class) + `DA_LootItem_<Name>` (instances), mirroring the Costume asset convention exactly:

| Field | Type | Notes |
|---|---|---|
| `LootID` | `Name` | Stable id, e.g. `Loot.SpeedPants`, `Loot.GardenGnome`. |
| `DisplayName` / `Description` | `Text` | UI-facing. |
| `Rarity` | `byte` (→ `E_LootRarity`, interim per the existing enum pattern — see below) | |
| `WorldMesh` | Static/Skeletal Mesh ref | For the `BP_LootPickup` actor. |
| `IconTexture` | Texture2D | For the future inventory UI (Phase 6/7). |
| `bIsUniqueTrophy` | bool | True only for the gnome (and any future one-of-a-kind items). |
| `CarryLoudnessMult` | float | Multiplies `LoudnessComponent.LoudnessModifier` while in `CarriedLoot` (§4). |
| `TrinketModifier` | `FLootTrinketModifier` (struct, §5) | Applied only once banked + equipped, never while merely carried. |

**New enum:** `E_LootRarity {Common(0), Uncommon(1), Rare(2), Mythic(3)}` — build as `byte` interim, same as `E_AlertState`/`E_PoolTier` (`CANON.md`'s documented MCP gap: Blueprint enums aren't MCP-creatable). Add to the existing "only the human can do this in-editor" pile (`START_HERE.md` §4) when this doc's build actually starts.

**`BP_LootPickup`** (Actor, `_Project/Gameplay/`): holds `LootItem: DA_LootItem ref`, root overlap volume, rarity-driven glow (§3). Overlap (HasAuthority) → adds to the overlapping player's `PlayerState.CarriedLoot`, then destroys/hides itself. Reused identically for both normal drops and capture-drops (§4).

**`PlayerState` additions** (alongside the Step-1 table in `CANON.md`):

| Var | Type | Repl | Default |
|---|---|---|---|
| `CarriedLoot` | `Array<DA_LootItem ref>` | RepNotify | [] |
| `BankedLoot` | `Array<DA_LootItem ref>` | Rep | [] |
| `EquippedTrinkets` | `Array<DA_LootItem ref>` (max 2) | RepNotify | [] |

**GameMode additions** (alongside the existing `Server_BankAtRisk`/`Server_LoseAtRisk` functions, same `HasAuthority`-guarded-function interim convention): `Server_BankCarriedLoot(PS)` (called from `BP_StashZone`, moves Carried→Banked), `Server_DropCarriedLoot(PS)` (called from `HandleDetain`, spawns recoverable `BP_LootPickup`s at the player's location, clears Carried).

---

## 9. MVP / roadmap placement

**Prerequisites:** Step 2 (LoudnessComponent's public modifier hook), Step 3 (the at-risk/banked pattern this mirrors), Step 5 (AlertDirector/`HandleDetain`, for the drop-on-capture hook), Step 6 (CostumeComponent — this doc's sibling component copies its exact pattern). All of Steps 0–8 (`Docs/02` §8, the MVP playtest) must pass first — **do not build this ahead of proving the core loop is fun**, same discipline as everything else parked in Phase 5.

**Sits in:** `08_Implementation_Roadmap.md` Phase 5 ("Content & Threats"), alongside the remaining costume wardrobe — see that doc for the added step block.

**Forward-dependencies this doc creates for other systems** (same pattern as `05_Characters.md` §9's own list — flagged so the systems they touch are built with the hooks in place, not retrofitted):
1. `BP_WatcherController` must eventually read `DetectionRangeMultiplier` (§5) — not needed until a trinket actually uses this field.
2. `BP_StashZone` and `GameMode.HandleDetain` need one new function call each (`Server_BankCarriedLoot` / `Server_DropCarriedLoot`) — trivial additions to existing, already-verified overlap logic.
3. The eventual save system (Phase 6) needs to persist `BankedLoot` + `NightsSinceLastGnome` — flagged in §6, not blocking this doc's build, but blocking this doc's *permanence*.

---

## 10. Guardrails / anti-patterns explicitly avoided

- **No loot pinata:** scarcity is deliberate (§3's "Common tier gets no glow," §6's curated-not-everywhere spawn pool) — every glowing pickup should feel like a real find.
- **No itemization bloat:** items are fixed, hand-authored Data Assets (like Costumes already are) — no procedural modifier rolls, ever. This is the single most-cited live-service loot complaint (research finding 3) and it's cheap to simply never start.
- **No RNG without a floor:** the Trophy always has a pity counter (§6) — never pure re-roll-forever odds.
- **No permanent loss to bad luck:** capture drops loot on the ground, recoverable, never deletes it (§4) — this is what keeps the rare spawn a thrill instead of a rage-quit.
- **No dominant loadout:** the stacking guardrail in §5 is the load-bearing rule — situational strength, not power creep, same as the Costume system already enforces.

---

## 11. Open decisions for the human

1. **Trinket slot count** — proposed 2 (§5), a tuning knob like everything else in `06`/`04`'s "numbers move, structure doesn't" philosophy.
2. **Co-op Trophy scoping** — shared-team vs. per-player (§7); proposed shared-team, needs confirmation since it's vision-level.
3. **`GnomeGuaranteedAfterNights`** — proposed 5 (§6), needs playtest tuning like every other threshold in this project.
4. **Exact trinket examples beyond speed pants + the gnome** — this doc deliberately specifies the *system*, not a full item list, mirroring how `05_Characters.md` ships five reference costumes rather than a full wardrobe. Populate the real item roster once this is actually scheduled.

**Asset sourcing:** where to actually get the meshes for the Trophy/gnome, the speed-pants item, and future trinkets is answered in `10_Asset_Generation_Toolkit.md` §7 (a follow-up research pass done specifically for this doc) — don't re-research sourcing here, that doc is the single source of truth for art sourcing. Short version: a free CC0 gnome model already exists (Poly Pizza); wetsuit/ghillie-style clothing and jewelry-style trinkets have no good free stock source and should route straight to the project's existing Sloyd/Meshy AI-gen pipeline instead of further searching.

---

*This is a Phase 5+ forward-spec, written to slot into the existing tension chain (`00_Design_Bible.md` §3) without adding a second parallel system. Nothing here should be built before `Docs/02` §8 validates that the core loop (movement → loudness → detection → heat → at-risk/banked score) is actually fun. When it is time to build it, follow the same discipline as every other step: CANON names, disk verification after asset work, small commits, server authority — see `START_HERE.md` §1.*
