# Pool Hop — Movement, Physics Comedy, Swimming & Stealth UI Research

*Compiled July 2026. What players actually respond to for third-person movement feel, physics-based comedy, water traversal, and stealth-detection UI — applied to Pool Hop's verbs (walk/crouch/sprint/vault/swim) and its loudness meter + vision-cone detection system.*

---

## 1. Third-Person Movement & Traversal Feel

- **Procedural, physics-reactive traversal is out-performing rigid context-sensitive prompts for stylized/physical games.** Techniques like building climb animation from just two keyframes via IK and multi-point pendulum simulation let movement adapt to any geometry, instead of relying on pre-authored vault/climb clips — more range for comedy, since the physics can "fail" in funny ways rather than snapping to a canned animation.
- **Context-sensitive systems (Assassin's Creed-style) trade agency for guaranteed success.** Reliable, but less expressive — physics-informed movement (distinct inputs reacting to speed/angle) gives a stronger "my input caused this" feeling, at the cost of occasional failure. For a comedy-forward game, some failure is a feature.
- **Astro Bot's process is a useful model for a small team:** gray-box the movement first, validate it's fun with nothing else, *then* layer animation on top to "elevate" already-good movement. Matches Pool Hop's own MVP doc discipline (grey box before art).
- **Weight reads through asymmetric velocity curves** — fast acceleration ramp-up paired with slower, friction-like deceleration — not a binary start/stop. Applies directly to sprint/walk/crouch transitions.

## 2. Physics Comedy — the Controllability Ceiling

- **PEAK's "deliberately awkward, physics-driven movement"** — one misstep triggers a group tumble — is called out by name as core to its reception (95% positive, 130K+ reviews). Comedy comes from *coordination* breaking down, not random chaos.
- **Gang Beasts' clumsiness is deliberately bounded**, not maximal — the character model itself was reshaped (short legs, no feet) specifically to *reduce* physics glitches. Bennett Foddy's principle: comedy needs a controllability ceiling, or it stops being funny and starts being frustrating.
- **Human: Fall Flat's own devs found fully independent per-limb control produced "really messy controls"** and had to simplify to a mappable scheme. Direct evidence that maximum physics freedom is not the goal — controlled, learnable physics is.
- **Content Warning pairs physics chaos with a 90-second filming/replay mechanic** that turns a failure into shareable narrative rather than just noise — reinforces the earlier virality research (Docs/05): make failure states visible and capturable, not just physically funny in the moment.

**Implication for Pool Hop:** vault, dive, and "getting caught" physics should be bounded chaos — enough ragdoll to be funny (per Docs/05's clip-worthiness findings) without ever feeling like the player lost control of basic movement. Don't go full Human: Fall Flat freedom; go PEAK/Gang Beasts bounded-comedy.

## 3. Swimming & Water Traversal

- **BotW's swimming is widely cited as the game's weak point** — no dedicated dive button, punishing stamina-drain-to-drowning design. A cautionary example, not a model.
- **Sneaky Sasquatch — the GDD's own north-star reference — handles this well**: a simple oxygen meter that reddens near-empty, with a forgiving grace period before any rescue/penalty kicks in. Non-punitive, readable, low-stakes.
- **"Floaty" is the standard complaint for weightless/unresponsive swim-air controls** (LittleBigPlanet cited repeatedly as the example to avoid).
- **Subnautica's dedicated up/down axis** (rather than pitch-and-thrust to control depth) is called out as central to why its diving feels good; AC Valhalla's swim physics are also praised as best-in-class.

**Implication for Pool Hop:** model the pool dive/swim/underwater-hide mechanic on Sneaky Sasquatch's forgiving oxygen meter, not BotW's punishing one — misjudging a dive or staying under too long should read as a funny close call, not a hard fail. Use a direct up/down input for underwater movement rather than pitch-and-thrust.

## 4. Stealth Detection UI

- **Mark of the Ninja**: a shaded vision cone plus an expanding sound-radius circle puts "all information available on screen" with no tooltips needed — the reference for legibility.
- **Shadow Tactics**: identical cone geometry and fill-speed across *every* enemy is treated as a hard requirement — inconsistency between enemies breaks the player's mental model fast.
- **Invisible, Inc.**: a two-color cone (red = seen, yellow = in-range-but-hidden) plus a numeric 0–6 alarm counter gives both an instant read and a cumulative one at the same time — a pattern worth borrowing for the loudness meter (instant color + a numeric/segmented heat value).
- **Splinter Cell's meter got simpler over the series**, not more detailed — a 5-segment gradient bar collapsed into a 3-color (green/yellow/red) light by *Double Agent*, specifically for faster reads. Detail lost fidelity but gained speed-of-read.
- **Co-op shared-detection UI is a genuinely underserved design space** — no strong sourced precedent exists for how multiple players should see a shared threat/alert state at once. This is a gap Pool Hop can actually lead on, not just copy from elsewhere.

**Implication for Pool Hop:** keep vision cones geometrically identical across all AI types (homeowner/chaser/cop) even as their stats differ, per Shadow Tactics. Use simple 3-color alert states (matches the GDD's existing Unaware/Suspicious/Alert design) rather than a fine gradient. Since shared-team detection UI has no strong precedent, there's room to design something original here — e.g., a shared minimap alert badge visible to the whole crew, not just the nearest player.

## 5. Minimal / Diegetic HUD

- **Untitled Goose Game** — another of the GDD's own references — renders honks as cartoon speech-lines and interactables as a glow outline instead of icons, keeping UI stylistically part of the world rather than bolted on top.
- **Dead Space remains the reference case for full diegetic UI** (health bar on the spine), but "few studios rushed to create the next Dead Space" — it's expensive to do well.
- **The "Minimal HUD Paradox" (named in 2025 design commentary):** most directors *want* diegetic/minimal HUD, but it requires real 3D art/VFX/sound budget, so teams overcommit early and fall back to bolted-on non-diegetic UI late in production when the budget runs out. A direct scoping warning for a small team.
- **Overcooked keeps HUD to bare completed/pending icons**, pushing most feedback into environmental chaos and forced player communication instead of screen UI.

**Implication for Pool Hop:** budget diegetic feedback (glowing wet footprints, sensor-light glow, character head-turns/animation tells, ripple SFX) as the *primary* layer, per Untitled Goose Game's approach — but keep a simple, cheap, non-diegetic loudness/alert meter as the reliable fallback rather than over-committing to a full Dead-Space-style diegetic HUD the team can't afford to finish (the Minimal HUD Paradox trap).

---

## Summary of Concrete Changes to Carry Into Systems 1-4

1. Movement (System 1): build vault/crouch/sprint as physics-reactive with asymmetric accel/decel curves, gray-boxed and feel-tested before any animation pass — already the plan, this validates it.
2. Physics comedy: cap ragdoll/physics freedom (Gang Beasts/PEAK model) for vaults, dives, and getting-caught states — funny, not frustrating.
3. Swimming: forgiving oxygen meter with grace period (Sneaky Sasquatch model), direct up/down swim axis, not stamina-drowning punishment.
4. Detection UI (System 4): identical cone geometry across all AI types, simple 3-color alert state, consider a shared team-visible alert indicator as an original design contribution.
5. HUD overall: diegetic-first (environmental tells) with a cheap, reliable non-diegetic loudness/alert meter as fallback — scope the diegetic layer conservatively given small-team budget reality.
