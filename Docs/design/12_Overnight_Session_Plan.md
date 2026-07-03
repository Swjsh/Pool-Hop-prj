# Pool Hop — Overnight Session Plan (2026-07-03)

*Written blind, without a live `unreal-mcp` connection (see `Docs/LESSONS.md` 2026-07-03 top entry — editor+port 8000 came up fine, but this Claude Code session's MCP client never got a live handle to it; needs a user-side restart to reconnect). This doc exists so that whenever the connection comes back — tonight, or next session — execution starts immediately instead of re-deriving the plan. Priority order below is deliberate; do NOT reorder without a reason. Update `CLAUDE.md` "Current state" and `Docs/LESSONS.md` as each chunk actually gets built and verified — this doc is the plan, not the record of what happened.*

**Ground rule carried over from every prior session: verify fresh, don't trust an old "✅ resolved" claim, especially for collision/physics.** The swim-collision bug alone has now "recurred" 3-4 times specifically because a stale verification was trusted. Every item below that touches collision/physics gets a fresh-process or fresh-PIE check before being called done.

---

## 0. First action once MCP is back: swim re-verification (blocking, do this before anything else)

Tonight's standalone-probe diagnostic (LESSONS 2026-07-03) confirmed the historically-recurring root cause (`StaticMeshComponent.bUseDefaultCollision` on the 5 water surfaces) is currently **correct** (`False` + `CollisionEnabled=NoCollision` on all 5, verified in a cold standalone process). What it could NOT confirm without coordinates or MCP: whether `MOVE_Swimming` actually triggers on contact.

**Do this first:**
1. `SceneTools.find_actors` for the 5 `PhysicsVolume` actors (`bWaterVolume=true`) — read their bounds. Cross-check against each pool's (now ~130 units deeper, per `d6a907d`) basin — confirm the volume's bottom face still overlaps the basin and the water surface's Z position sits inside the volume, not above/outside it after the depth change.
2. `set_actor_transform` teleport the player into **at least 2 of the 5 pools** (not just Pool_A — the deepening touched all 5, and a per-pool config error could affect only some), then read `CharMoveComp.movementMode` directly. Expect `MOVE_Swimming`.
3. If it fails: the most likely suspect given tonight's evidence is the `PhysicsVolume` bounds vs. the deepened basin (a geometry mismatch introduced by `d6a907d`'s "extend basin floor ~130 units deeper" edit), NOT the collision property (already confirmed fine). Check that first before re-touching `bUseDefaultCollision`/`collisionEnabled` again.
4. **Add a defensive self-heal, regardless of what step 3 finds**, since this bug's mechanism has now recurred without full explanation multiple times: on `BP_PoolVolume.EventBeginPlay` (or the sandbox/Maple Court GameMode's level-start path), explicitly force `bUseDefaultCollision=False` + `CollisionEnabled=NoCollision` on its own water surface component every time the level loads. This makes the runtime behavior self-correct even if something (still not fully root-caused — see LESSONS 2026-07-03 "THIRD confirmed occurrence") resets the saved asset property again between sessions. Cheap, low-risk, directly answers this project's own LESSONS ask to "instrument WHEN it happens" rather than blind-refixing a 5th time.
5. Only after both pools verified swimming correctly: update `CLAUDE.md` "Current state" (don't just repeat "✅ RESOLVED" — note this is verified via cold-process + fresh teleport, same discipline as before, since that's what "fixed" has to mean now for this specific bug).

---

## 1. Crouch animation — the one real asset gap, try Control Rig before falling back to Montage

**Confirmed (LESSONS 2026-07-03):** AnimGraph nodes are not reachable via `BlueprintTools`/`write_graph_dsl` (two independent negative probes). Zero crouch-anything exists in the project's 119-sequence library or `_ThirdPartyStaging`. The vault/slide precedent (`d6a907d`) used `AnimMontage` + `Montage_Play` from the EventGraph as a workaround — real triggered motion, but using tonally-unrelated stand-in clips (`MM_Dash`, `MM_WallJump`).

**Try, in order, stop at the first that works:**
1. **Control Rig procedural crouch (unexplored — try this first).** `animation_toolset.toolsets.controlrig.ControlRigTools` is a real, working toolset (proved capable via the BigVegas IK retarget pipeline). Investigate whether a Control Rig can be added to `ABP_Unarmed`'s post-process chain (or a new dedicated one) that reads a Blueprint-exposed float (`CrouchAlpha`, driven by the character's existing `IsCrouching`/capsule-half-height state) and procedurally lowers the pelvis/spine bones to fake a crouch pose on top of the existing locomotion. This sidesteps the "no crouch animation asset" problem entirely — it's a pose modifier, not a new clip. **Unknown territory — if it doesn't pan out within a bounded attempt (rough budget: 30-45 min of iteration), stop and fall back to step 2. Don't grind it past that.**
2. **Montage fallback (same proven trick as vault/slide, near-certain to work, lower fidelity).** Inspect the actual 119-sequence anim library (`AssetTools`/`SkeletalMeshTools` list) for the closest usable stand-in — something with a lowered/hunched pose (a "take cover"/aim-low/prone-adjacent combat clip) reads better as a rough crouch than an unrelated clip. Wrap it as `AM_Crouch` (`unreal.AnimMontageFactory`, same pattern as `AM_Slide`/`AM_Vault`), call `Montage_Play` from `HandleCrouchPressed`'s crouch-start branch (not the uncrouch branch — a one-shot transition cue reads better than trying to loop a wrong-semantic clip while crouched).
3. **If both fail or time runs out:** leave the current mechanically-correct-but-visually-static crouch (capsule shrinks, no pose change) as-is — already built, not a regression, just not visually complete. Don't ship a worse experience chasing a fix.

---

## 2. Menu system (genuinely unbuilt — confirmed gap, not a drifted doc)

`09_Design_Review_Punchlist.md` §C confirms: no menu doc, no results-screen design, "07 explicitly parks menus." `UMGToolSet` is confirmed MCP-buildable (`WBP_HUD` proof). Build in this order — results screen first (closes the core loop), then pause (playtest usability), then main menu (least functionally urgent):

### 2a. Results screen (`WBP_ResultsScreen`) — highest value, closes a real gap
- **Check first:** does anything currently decrement `GameState.NightTimeRemaining` and flip `bNightOver=true` at 0? (Step 1 built the *variables*; the countdown *behavior* may not exist — verify via `get_node_infos` on GameMode/GameState before assuming.) If missing, add a `Tick` (or a repeating timer, same `SetTimerByFunctionName` substitute used elsewhere for the missing `Delay` node) on `BP_PlayerGameMode` that ticks `NightTimeRemaining` down and sets `GameState.bNightOver = true` at 0.
- `WBP_ResultsScreen`: "NIGHT OVER" title, `GameState.TeamScoreBanked` value, a simple stat line or two (e.g. total `DistinctPoolsHopped` across players if easy, skip if it needs new aggregation work), "Play Again" (`OpenLevel` reload of the current level) + "Quit" (`QuitGame`) buttons.
- Wire: `GameState`'s `OnRep_bNightOver` (should already exist as an empty stub from the `RepNotify` auto-creation, per this project's own established pattern — verify via `get_node_infos`, don't assume it does nothing useful already) → on the local/owning client, `CreateWidget(WBP_ResultsScreen) → AddToViewport → SetInputMode_UIOnly`.

### 2b. Pause menu (`WBP_PauseMenu`)
- New Input Action `IA_Pause` in `Content/Input/` (matches CANON's input-asset-location ruling), bound to `Escape` in `IMC_Default`.
- `WBP_PauseMenu`: semi-transparent dark background, "Resume" / "Restart Night" / "Quit to Desktop" buttons.
- `BP_PlayerController`: `IA_Pause` (`Triggered`) → toggle: create+add (if not present) + `SetGamePaused(true)` + `SetInputMode_UIOnly`; else remove + `SetGamePaused(false)` + `SetInputMode_GameOnly`. "Resume" button does the same toggle-off. "Restart Night" → `OpenLevel` reload. "Quit to Desktop" → `QuitGame`.

### 2c. Main menu (`WBP_MainMenu`) — lowest urgency, do last if time allows
- Shown at `BeginPlay`, layered on top of (not instead of) the existing HUD creation chain — append, don't touch the existing `CreateWidget(WBP_HUD)` logic.
- "Play" → remove self, `SetInputMode_GameOnly`, hide cursor. "Quit" → `QuitGame`.
- **Positive finding worth confirming while here:** tonight's standalone probe log showed `"[BP_PlayerController_C_0] PoolHop HUD: BeginPlay fired, creating WBP_HUD"` — `BP_PlayerController`'s `BeginPlay` chain, long flagged in `CLAUDE.md` as possibly not firing on a cold load, appears to be firing fine now. Don't re-litigate that old flag; just confirm it's still true while adding the main menu here.

---

## 3. Loot system — scoped-down buildable slice of `11_Loot_And_Extraction.md`

The user explicitly asked for loot tonight, which overrides that doc's own "don't build ahead of Step 8" self-imposed rule — that rule was this project's own prior-session discipline, not a rule the user is bound by, and a direct human ask supersedes it. Full doc 11 is Phase 5+ scope (trinket slots+modifiers, pity-mechanism spawn manager, co-op Trophy sharing decision); build this smaller vertical slice tonight instead of the whole thing:

**Build:**
1. `E_LootRarity` — `byte` interim (`Common=0, Uncommon=1, Rare=2, Mythic=3`), same established pattern as `E_AlertState`/`E_PoolTier`.
2. `DA_LootItem` (PrimaryDataAsset, `_Project/Data/Loot/`): `LootID`(Name), `DisplayName`(Text), `Rarity`(byte), `WorldMesh`(StaticMesh ref), `CarryLoudnessMult`(float, default 1.0), `bIsUniqueTrophy`(bool). **Skip the `FLootTrinketModifier` struct** (structs aren't MCP-buildable — known gap) — if trinket stat effects get built at all tonight, use flat float fields directly on `DA_LootItem` instead of a nested struct.
3. Two instances: `DA_LootItem_SpeedPants` (Common, `CarryLoudnessMult=1.0`, plain pickup) and `DA_LootItem_GardenGnome` (Mythic, `bIsUniqueTrophy=true`, `CarryLoudnessMult=1.3`).
4. `PlayerState` additions: `CarriedLoot` (`Array<DA_LootItem ref>`, RepNotify), `BankedLoot` (`Array<DA_LootItem ref>`, Rep). **Skip `EquippedTrinkets`** — no selection UI exists, that's real Phase 6/7 scope per the doc's own admission.
5. `BP_LootPickup` (Actor, `_Project/Gameplay/`): `LootItem` (DA_LootItem ref, instance-editable), overlap volume + `StaticMeshComponent` (mesh from `LootItem.WorldMesh`), rarity-tinted glow (reuse `DA_ArtPalette` — add `LootUncommon`/`LootRare`/`LootMythic` tokens per doc 11 §3, a straightforward Data Asset edit). Overlap (`HasAuthority`) → add to `PlayerState.CarriedLoot`, destroy self.
6. GameMode additions: `Server_BankCarriedLoot(PS)` (call from `BP_StashZone`'s existing overlap, alongside `Server_BankAtRisk`) moves Carried→Banked. `Server_DropCarriedLoot(PS)` (call from `HandleDetain`, alongside `Server_LoseAtRisk`) spawns a `BP_LootPickup` per carried item at the pre-teleport location, clears Carried — **never destroy the underlying `DA_LootItem` asset**, only the pickup actor instance (matches doc 11's explicit "never permanently delete on capture" guardrail).
7. Loudness coupling: extend `BP_LoudnessComponent`'s modifier calc — if `CarriedLoot` contains an item with `bIsUniqueTrophy=true`, multiply in its `CarryLoudnessMult`. Skip the periodic `Action.GnomeCarry` bump for tonight (nice-to-have, not load-bearing for a first pass) unless time allows — it's a one-line addition reusing `Server_ReportAction` if you get to it.
8. Place 3-4 `BP_LootPickup` instances in the sandbox — a couple SpeedPants, one GardenGnome hidden near the bush (matches the design intent of "the Trophy occupies a real hiding spot").

**Explicitly deferred (real Phase 5+ scope, not tonight):** pity-mechanism spawn manager, trinket equip slots + `FLootTrinketModifier` stat application, co-op Trophy-sharing decision (moot for a single-player test session anyway).

---

## 4. Player skin — wire one of the 3 unwired Mixamo candidates

`SK_Kaya`/`SK_Josh`/`SK_Michelle` were imported (mesh+skeleton, no materials/animations) but never wired — `BP_PlayerCharacter` was off-limits during the two-lane split; that split no longer applies (one session, no concurrent lane now).

**Recipe (identical to the proven BigVegas pipeline, LESSONS 2026-07-02 "MIXAMO CHARACTER INTEGRATION" entry — just re-point at a different target skeleton):**
1. Pick one candidate (whichever characterizes cleanest via `apply_auto_generated_retarget_definition()` — try Josh or Michelle first for a visually distinct silhouette from the Watcher's BigVegas).
2. `IK_Manny` (already exists) + a new `IK_<Target>` rig + `RTG_Manny_To_<Target>` retargeter, `auto_align_all_bones` + `auto_map_chains(FUZZY, True)`.
3. Batch-retarget `ABP_Unarmed` (+ referenced sequences) via `IKRetargetBatchOperation.duplicate_and_retarget`.
4. **Expect the same Control Rig T-pose gotcha** — the retargeted ABP will carry `CR_Mannequin_FootIK` authored for Manny; set that AnimGraph node's `Alpha` pin `1.0→0.0` to bypass it (exact fix already proven on BigVegas).
5. Wire `SkeletalMesh` + `AnimClass` onto `BP_PlayerCharacter.CharacterMesh0` (CDO). Resize `overrideMaterials` to the new mesh's slot count (BigVegas gotcha #4 — different mesh, different slot count, don't assume 2).
6. Verify via `StartPIE(bSimulate=True)` + `CaptureViewport` (not off-screen bone reads — proven unreliable, see the BigVegas gotchas) — confirm a natural idle pose, not a T-pose.
7. **This is the character the player will actually see for the rest of the game — verify it doesn't break the already-working Costume system** (`DA_SwimTrunks`/`DA_QuietShoes` attach-mesh sockets like `foot_l_Socket` are named against the Manny skeleton's socket names; confirm the new skeleton has equivalent sockets, or the costume attach logic will silently fail to find them).

---

## 5. Stealth mechanics — mostly built already; re-verify before adding anything new

Per `CLAUDE.md`'s own history, most of the mechanical stealth loop is built and was verified working as of the last several sessions: detection meter, 4-state alert (`Unaware/Suspicious/Alert/Critical` as byte), sight+hearing perception, the mesh-based vision cone (confirmed still present tonight — `VisionFanMesh_GEN_VARIABLE` showed up correctly configured, `bUseDefaultCollision=False`, in tonight's own diagnostic dump), hiding bushes, hedge squeeze, sensor light, the loudness ladder (crouch/walk/sprint tiers), and catch→detain→respawn.

**Don't rebuild any of this from scratch. Do, in order:**
1. **Re-verify AI Watcher movement fresh — tonight's MCP-free probe already narrowed this down, don't start from zero.** Sampled `CharacterMovementComponent.Velocity` for both Watchers 3× across ~2 real minutes (see `Docs/LESSONS.md` 2026-07-03): **Maple Court's Watcher (`BP_WatcherCharacter_MC_C`) is confirmed actively patrolling** (different nonzero velocity each sample). **The sandbox Watcher (`BP_WatcherCharacter_C`) read exactly `(0,0,0)` all three times** — a real, specific, isolated regression signal, not the old contradictory back-and-forth. Since the sibling class works fine with the same `TickBrain` shape, check instance-specific state FIRST: the sandbox Watcher's gathered `PatrolPoints` array (empty or all off-navmesh?), its `NavMeshBoundsVolume` coverage of the sandbox region specifically, and whether it's even receiving `BeginPlay` (compare against Maple Court's). Don't re-touch the shared brain logic both classes use until the sandbox-specific state is ruled out.
2. If movement is healthy on both after the fix: this system is in good shape. Consider, time permitting, a second AI archetype (the game's own premise names both "homeowners" and "cops" — only one Watcher class exists). This is a stretch goal, not required — don't start it if items 0-4 above aren't done first.
3. If the instance-specific check doesn't explain it: fall back to the known prior culprits — `SupportedAgents` in `Config/DefaultEngine.ini` (process-lifetime-cached, needs an editor restart to take effect — CANON.md Step 4 has the exact fix already), NavMesh build state (`Build → Build Paths`, the one action this project has repeatedly needed a literal human editor click for).

---

## Priority order recap (if the night runs out before everything's done)

0. Swim re-verification + defensive self-heal (blocking — do first, it's the thing the user explicitly said is broken right now)
1. Results screen (closes the core loop, reuses existing `bNightOver`/`TeamScoreBanked` hooks)
2. Loot vertical slice (explicit ask, doc 11 already fully specs it, just scope down)
3. Pause menu
4. Crouch animation attempt (Control Rig, then Montage fallback)
5. Player skin wiring
6. Main menu
7. Stealth re-verification + stretch (second AI archetype) only if everything above is done

Commit after each numbered chunk, per this project's own standing rule. Update `CLAUDE.md` "Current state" and `Docs/LESSONS.md` as you go — don't batch it to the end, and don't write "✅ RESOLVED" for anything collision/physics-related without a fresh cold-process or fresh-PIE check in hand.
