# Pool Hop — Overnight Session Plan (2026-07-03)

*Written blind, without a live `unreal-mcp` connection (see `Docs/LESSONS.md` 2026-07-03 top entry). This doc is the live work queue — status markers below are the source of truth for what's done, not this prose. Update the marker + commit immediately after each section's Verify step passes; don't batch updates to the end.*

**Ground rule, carried over from every prior session: verify fresh, don't trust an old "✅ resolved" claim, especially for collision/physics.** The swim-collision bug alone has "recurred" 3-4 times specifically because a stale verification was trusted.

---

## HOW TO RESUME THIS (read before doing anything else — safe for a fresh agent or a repeated /loop pass)

1. **Confirm MCP is live first** — see the handoff prompt this doc was paired with. Don't touch anything below until a real tool call has succeeded, not just a `ToolSearch` hit.
2. **Scan every `STATUS:` line below**, top to bottom. That's the entire state of this plan — don't re-derive progress from git log or CLAUDE.md, they can lag behind this file mid-session.
3. **Resume at the first section that is not `[x]`**, in numeric order (0→5), unless the "Priority order recap" at the bottom says otherwise for a time-boxed session.
4. **`[x]` does NOT mean "trust blindly and skip forever."** If a section touches collision/physics/replication (§0 is the standing example), do the cheap spot-check in its Verify block again before building anything on top of it — this project's whole history is claims like this going stale between sessions. Everything else marked `[x]` can be trusted without re-checking.
5. **Before starting a section:** flip its marker to `STATUS: [~] IN PROGRESS`. This makes a mid-section interruption (crash, context limit, user stops the loop) visible to the next pass instead of silently re-starting or silently skipping.
6. **After a section's Verify step actually passes:** flip to `STATUS: [x] DONE — verified <how, briefly>`, commit + push (small commit, this section only), then add one line to `Docs/LESSONS.md` if anything non-obvious came up.
7. **If a section is genuinely blocked** (not just hard — actually blocked on something outside this session's control): leave it `[~]`, write a one-line `BLOCKED ON: ...` note directly under its STATUS line, and move to the next section rather than spinning on it. Don't mark a blocked section `[x]`.
8. **This is loop-safe by construction**: re-running this whole doc from a cold start after any of the above always does the right thing — skips real `[x]` work, re-enters `[~]` work where it left off (using the `BLOCKED ON` note as context), and never repeats a passed Verify step needlessly.

---

## 0. Swim re-verification + defensive self-heal

**STATUS: [~] IN PROGRESS** — the collision property is confirmed correct; full behavioral confirmation is the remaining work.

Tonight's standalone-probe diagnostic (LESSONS 2026-07-03) confirmed the historically-recurring root cause (`StaticMeshComponent.bUseDefaultCollision` on the 5 water surfaces) is currently **correct** (`False` + `CollisionEnabled=NoCollision` on all 5, verified in a cold standalone process, no MCP). What it could NOT confirm without coordinates or MCP: whether `MOVE_Swimming` actually triggers on contact.

**Do:**
1. `SceneTools.find_actors` for the 5 `PhysicsVolume` actors (`bWaterVolume=true`) — read their bounds. Cross-check against each pool's (now ~130 units deeper, per `d6a907d`) basin — confirm the volume's bottom face still overlaps the basin and the water surface's Z position sits inside the volume, not above/outside it after the depth change.
2. `set_actor_transform` teleport the player into **at least 2 of the 5 pools** (not just Pool_A), then read `CharMoveComp.movementMode` directly. Expect `MOVE_Swimming`.
3. If it fails: check the `PhysicsVolume` bounds vs. the deepened basin first (the most likely suspect given tonight's evidence), NOT the collision property (already confirmed fine).
4. **Add a defensive self-heal regardless of what step 3 finds**: on `BP_PoolVolume.EventBeginPlay`, explicitly force `bUseDefaultCollision=False` + `CollisionEnabled=NoCollision` on its own water surface component every time the level loads. This bug's mechanism has recurred without full root-cause multiple times — make the runtime self-correct rather than trusting the saved asset property to hold.

**Verify (flip to `[x]` only after this passes):** fresh PIE or standalone, teleport into 2 different pools, `CharMoveComp.movementMode == MOVE_Swimming` on both, read directly (not inferred from a screenshot). Then update `CLAUDE.md` "Current state" — note it's verified via cold-process/fresh-teleport, not just "✅ RESOLVED" again.

---

## 1. Crouch animation

**STATUS: [ ] NOT STARTED**

**Confirmed (LESSONS 2026-07-03):** AnimGraph nodes are not reachable via `BlueprintTools`/`write_graph_dsl` (two independent negative probes). Zero crouch-anything exists in the project's 119-sequence library or `_ThirdPartyStaging`. The vault/slide precedent (`d6a907d`) used `AnimMontage` + `Montage_Play` from the EventGraph as a workaround.

**Try, in order, stop at the first that works:**
1. **Control Rig procedural crouch (unexplored — try first).** `animation_toolset.toolsets.controlrig.ControlRigTools` is real and proven (BigVegas IK retarget). Investigate a Control Rig on `ABP_Unarmed`'s post-process chain reading a Blueprint-exposed `CrouchAlpha` float to procedurally lower the pelvis/spine. **Time-box this: ~30-45 min of iteration, then fall back if it hasn't clicked — don't grind past that.**
2. **Montage fallback (near-certain, lower fidelity).** Find the closest tonal match in the 119-sequence library (a lowered/hunched combat pose), wrap as `AM_Crouch` (`unreal.AnimMontageFactory`, same pattern as `AM_Slide`/`AM_Vault`), `Montage_Play` from `HandleCrouchPressed`'s crouch-start branch only.
3. **If both fail:** leave the current mechanically-correct-but-static crouch as-is. Not a regression — don't ship something worse chasing a fix.

**Verify:** `StartPIE(bSimulate=True)` + `CaptureViewport` on a crouched pawn — pose visibly changed from standing, not a T-pose, not identical to standing. If step 3 was taken instead, verify is just "confirm nothing regressed" (capsule shrink still works).

---

## 2. Menu system

**STATUS: [ ] NOT STARTED** (three sub-items — track each independently, see sub-status lines)

`09_Design_Review_Punchlist.md` §C confirms: no menu doc, no results-screen design, menus explicitly parked. `UMGToolSet` is confirmed MCP-buildable (`WBP_HUD` proof). Build in order — results screen first (closes the core loop), then pause, then main menu.

### 2a. Results screen (`WBP_ResultsScreen`)
**SUB-STATUS: [ ] NOT STARTED** — highest value, closes a real gap.
- **Check first:** does anything currently decrement `GameState.NightTimeRemaining` and flip `bNightOver=true` at 0? Verify via `get_node_infos`, don't assume. If missing, add a Tick/timer on `BP_PlayerGameMode` that does both.
- `WBP_ResultsScreen`: "NIGHT OVER" title, `GameState.TeamScoreBanked` value, "Play Again" (`OpenLevel` reload) + "Quit" (`QuitGame`).
- Wire: `GameState`'s `OnRep_bNightOver` → `CreateWidget(WBP_ResultsScreen) → AddToViewport → SetInputMode_UIOnly`.
- **Verify:** force `NightTimeRemaining` to a small value (or manually set `bNightOver=true`) in a live PIE session, confirm the widget actually appears with the correct banked score, both buttons work (Play Again reloads, Quit exits).

### 2b. Pause menu (`WBP_PauseMenu`)
**SUB-STATUS: [ ] NOT STARTED**
- New `IA_Pause` in `Content/Input/`, bound to `Escape` in `IMC_Default`.
- `WBP_PauseMenu`: "Resume" / "Restart Night" / "Quit to Desktop".
- `BP_PlayerController`: `IA_Pause` toggles create/remove + `SetGamePaused` + input mode.
- **Verify:** in live PIE (or standalone + real `Escape` keypress via the input-probe skill), confirm the game actually pauses (a moving actor stops), the menu shows, Resume un-pauses cleanly.

### 2c. Main menu (`WBP_MainMenu`)
**SUB-STATUS: [ ] NOT STARTED** — lowest urgency, do last if time allows.
- Shown at `BeginPlay`, layered on top of the existing HUD creation chain — append, don't touch it.
- "Play" → remove self + `SetInputMode_GameOnly`. "Quit" → `QuitGame`.
- **Positive finding to reconfirm while here, not re-litigate:** tonight's standalone log showed `BP_PlayerController`'s `BeginPlay` firing fine (`"...BeginPlay fired, creating WBP_HUD"`) — the old "cold-load BeginPlay doesn't fire" flag in `CLAUDE.md` looks stale. Confirm once, update the record either way.
- **Verify:** cold standalone launch, main menu appears before the player can move, Play button hands off control correctly.

---

## 3. Loot system — scoped-down buildable slice of `11_Loot_And_Extraction.md`

**STATUS: [ ] NOT STARTED**

The user explicitly asked for loot tonight, overriding doc 11's own "don't build ahead of Step 8" self-imposed rule (a prior-session discipline, not something the user is bound by). Build this smaller vertical slice, not the full doc 11 scope:

**Build:**
1. `E_LootRarity` — `byte` interim (`Common=0, Uncommon=1, Rare=2, Mythic=3`), same pattern as `E_AlertState`/`E_PoolTier`.
2. `DA_LootItem` (PrimaryDataAsset, `_Project/Data/Loot/`): `LootID`(Name), `DisplayName`(Text), `Rarity`(byte), `WorldMesh`(StaticMesh ref), `CarryLoudnessMult`(float, default 1.0), `bIsUniqueTrophy`(bool). **Skip the `FLootTrinketModifier` struct** (structs aren't MCP-buildable) — use flat float fields directly if trinket effects get built at all.
3. Two instances: `DA_LootItem_SpeedPants` (Common), `DA_LootItem_GardenGnome` (Mythic, `bIsUniqueTrophy=true`, `CarryLoudnessMult=1.3`).
4. `PlayerState` additions: `CarriedLoot` (RepNotify Array), `BankedLoot` (Rep Array). **Skip `EquippedTrinkets`** — no selection UI exists yet.
5. `BP_LootPickup` (Actor, `_Project/Gameplay/`): overlap → add to `CarriedLoot`, destroy self. Rarity-tinted glow via new `DA_ArtPalette` tokens (`LootUncommon`/`LootRare`/`LootMythic`, doc 11 §3).
6. GameMode: `Server_BankCarriedLoot(PS)` (from `BP_StashZone`, alongside `Server_BankAtRisk`), `Server_DropCarriedLoot(PS)` (from `HandleDetain`, alongside `Server_LoseAtRisk` — spawn a pickup per item, clear the array, **never destroy the `DA_LootItem` asset itself**).
7. Loudness coupling: if `CarriedLoot` has a `bIsUniqueTrophy` item, multiply its `CarryLoudnessMult` into `LoudnessComponent`'s modifier calc. Skip the periodic `Action.GnomeCarry` bump unless time allows.
8. Place 3-4 `BP_LootPickup` instances in the sandbox (a couple SpeedPants, one GardenGnome near the bush).

**Explicitly deferred:** pity-mechanism spawn manager, trinket equip slots + stat application, co-op Trophy-sharing decision.

**Verify:** live PIE — walk into a pickup, confirm `PlayerState.CarriedLoot` gains an entry; reach the stash, confirm it moves to `BankedLoot`; get caught while carrying one, confirm a new pickup spawns at the capture location and `CarriedLoot` clears.

---

## 4. Player skin — wire one of the 3 unwired Mixamo candidates

**STATUS: [ ] NOT STARTED**

`SK_Kaya`/`SK_Josh`/`SK_Michelle` were imported (mesh+skeleton, no materials/animations) but never wired — the old two-lane split that blocked touching `BP_PlayerCharacter` no longer applies.

**Recipe (identical to the proven BigVegas pipeline, LESSONS 2026-07-02 — just re-point at a different target skeleton):**
1. Pick one candidate (try Josh or Michelle for a silhouette distinct from the Watcher's BigVegas).
2. `IK_Manny` (exists) + new `IK_<Target>` rig + `RTG_Manny_To_<Target>` retargeter, `auto_align_all_bones` + `auto_map_chains(FUZZY, True)`.
3. Batch-retarget `ABP_Unarmed` (+ sequences) via `IKRetargetBatchOperation.duplicate_and_retarget`.
4. **Expect the same Control Rig T-pose gotcha** — set the retargeted ABP's `CR_Mannequin_FootIK` node `Alpha` pin `1.0→0.0`.
5. Wire mesh+AnimClass onto `BP_PlayerCharacter.CharacterMesh0` (CDO). Resize `overrideMaterials` to the new mesh's actual slot count.
6. **Verify the Costume system still works** — `DA_SwimTrunks`/`DA_QuietShoes` attach to named sockets (e.g. `foot_l_Socket`) on the Manny skeleton; confirm the new skeleton has equivalent sockets or costume attach will silently fail.

**Verify:** `StartPIE(bSimulate=True)` + `CaptureViewport` — natural idle pose, not a T-pose. Then equip a costume in live PIE and confirm the attach mesh still shows up in the right place.

---

## 5. Stealth mechanics — mostly built; re-verify before adding anything new

**STATUS: [~] IN PROGRESS** — one specific regression found tonight, not yet fixed.
**BLOCKED ON:** MCP reconnection (found via the MCP-free probe, needs MCP tools to actually fix).

Most of the mechanical stealth loop is already built and was verified working in recent sessions: detection meter, 4-state alert, sight+hearing perception, the mesh-based vision cone (confirmed still present tonight), hiding bushes, hedge squeeze, sensor light, the loudness ladder, catch→detain→respawn. **Don't rebuild any of this.**

**Do, in order:**
1. **Fix the sandbox AI Watcher — tonight's MCP-free probe already isolated this, don't re-diagnose from zero.** Sampled `CharacterMovementComponent.Velocity` for both Watchers 3× across ~2 real minutes: **Maple Court's Watcher is confirmed actively patrolling** (different nonzero velocity each sample). **The sandbox Watcher read exactly `(0,0,0)` all three times.** Since the sibling class works fine with the same `TickBrain` shape, check instance-specific state first: the sandbox Watcher's gathered `PatrolPoints` array (empty or off-navmesh?), its `NavMeshBoundsVolume` coverage, whether `BeginPlay` even fires (compare to Maple Court's). Don't touch the shared brain logic until instance-specific state is ruled out.
2. If both Watchers move correctly after the fix: this system is in good shape. Time permitting, consider a second AI archetype (the game names both "homeowners" and "cops" — only one exists). Stretch goal, not required.
3. If the instance-specific check doesn't explain it: fall back to known prior culprits — `SupportedAgents` in `Config/DefaultEngine.ini` (needs an editor restart), NavMesh `Build → Build Paths`.

**Verify:** fresh PIE, sample the sandbox Watcher's velocity at 2+ points across a real ~20s gap, confirm nonzero at least once (matching the standard already met by Maple Court tonight).

---

## Priority order recap (if the session ends before everything's `[x]`)

0. Swim re-verification + defensive self-heal — blocking, do first (the user explicitly said this is broken right now)
1. Results screen (§2a) — closes the core loop, reuses existing hooks
2. Loot vertical slice (§3) — explicit ask, doc 11 already specs it
3. Pause menu (§2b)
4. Crouch animation (§1) — Control Rig attempt, then Montage fallback
5. Player skin wiring (§4)
6. Main menu (§2c)
7. Stealth fix + stretch (§5) — the AI Watcher fix should happen whenever §5 is reached; the second-archetype stretch only if everything above is `[x]`

Commit after each section flips to `[x]`. Update `Docs/LESSONS.md` as you go, not batched. Don't write "✅ RESOLVED" for anything collision/physics-related without a fresh cold-process or fresh-PIE check in hand.
