# 13 — Physics & Movement Mechanics Brainstorm

Grounded brainstorm requested 2026-07-03, alongside building the crouch-walk/slide/swim animations, the fence retile, and the tall-fence climb mechanic. Scoped to ideas that extend systems **already built** (loudness bands, AI perception, pool scoring, breath/swim, loot) rather than inventing new subsystems — matching this project's "don't gold-plate ahead of the MVP playtest" discipline. Not built — this is a menu for a future scoping pass, same status as `11_Loot_And_Extraction.md` before it got built out.

## Traversal

1. **Ledge-hang + peek, on the new climb mechanic.** Instead of an instant `LaunchCharacter` over a tall fence, let the player grab and hang first (quiet), peek over to scout the far side, then choose: pull up (committed, louder — a second `Action.Climb` bump) or drop back down (silent retreat). Turns the binary vault/climb split into a real stealth decision point.
2. **Prone crawl space.** `BP_HedgeSqueeze` already narrows the player horizontally; a prone state (below crouch) would let the same trace-and-squeeze pattern work for *vertical* gaps — under a porch, under a deck, under a fence with a dug-out gap. Reuses `SqueezeSpeedMultiplier` verbatim.
3. **Drainpipe/trellis vertical climb → roof route.** A second, vertical variant of the new tall-fence climb: trace up instead of forward, chain multiple `LaunchCharacter` pulses up a drainpipe to reach a roof. Opens a "high route" that dodges ground-level Watcher sightlines but risks silhouetting against the moon — direct payoff for the AI's existing sight-cone system.
4. **Slide-under, not just slide-to-stop.** The slide mechanic currently only decays to a stop. The same momentum-decay state could be gated by a *height* trace instead of a *stop* condition — sliding under a low gap (fence gap, table, half-open gate) the way the tall-fence climb gates on height, just inverted.
5. **Pool-bounce jump.** Landing in a pool and jumping immediately grants a boosted jump on exit (buoyancy assist). Emergent tech a skilled player discovers rather than an explicit tutorial prompt — matches the vault/slide precedent of "physics-only, no new UI."

## Stealth & distraction

6. **Throw-to-distract.** A throwable object (the loot system already has a garden gnome!) that lands and creates a noise elsewhere, pulling a Watcher's attention — direct payoff for the AI hearing/perception system that's already fully built (`AISense_Hearing`, `HeardNoise`/`LastKnownLocation` already exist on the Watcher controller).
7. **Push/topple objects as noise OR as a step-up.** A lawn chair or trash can can be knocked over deliberately (loud, a decoy) or pushed adjacent to a wall and used as a boost to reach a ledge the vault/climb traces wouldn't otherwise reach — one prop, two uses depending on player intent.
8. **Submerged hiding.** `BP_BreathComponent`'s air meter already exists as a resource; holding a full submerge near a Watcher's patrol path becomes a hiding technique distinct from `BP_BushHide`, with the air timer as the built-in risk clock instead of a new one.

## Risk/reward & systemic

9. **Material-tagged climb/vault loudness.** `Action.Climb`/`Action.Vault` currently report one fixed loudness bump each. Tagging obstacles (wood fence = quiet creak, chain-link = loud rattle, metal patio wall = mid) and reading that tag in `TryVault` before calling `Server_ReportAction` would make route choice a real stealth tradeoff without adding a new system — just a data lookup on the hit actor.
10. **Movement-flow score multiplier.** `GetHopStreakMultiplier` already exists for chained pool visits; the same shape (a decaying window since the last "flow" action) could generalize to vault→slide→climb chains performed without stopping, rewarding fluid traversal the way skate/parkour games do.
11. **Rain as a systemic loudness mask.** A weather toggle that raises the ambient noise floor would let sprint-band loudness go unnoticed under rain, without touching the `IdleFloor`/`WalkBand`/`SprintBand` tuning itself — a global multiplier read at the top of `TickLoudness`, not a new mechanic.
12. **Wet-footprint visual trail.** After a swim, leave fading wet footprints for a short time — a *visibility* tell to complement the *audio* tell the loudness system already owns, giving Watchers (or a future human opponent in co-op) a sight-based way to pick up a trail instead of only a hearing-based one.

## Suggested next scoping pass

If picking a next slice to actually build: **#6 (throw-to-distract)** and **#9 (material-tagged loudness)** are the highest value-to-risk ratio — both are pure data/logic extensions of systems that are already fully wired and live-verified (hearing perception, loudness reporting), with no new animation or asset dependency. **#1 (ledge-hang)** is the natural next step for the climb mechanic just built, but needs its own animation work like crouch/slide/swim did tonight.
