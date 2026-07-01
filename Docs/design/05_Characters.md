# Pool Hop — Characters Design & Build Spec

*Version 0.1 — build-ready spec. Last updated June 30, 2026. Engine: Unreal Engine 5.8, Blueprints-first.*

> **Scope of this doc:** the player character(s) and the Watcher NPC body — placeholder-first (UE5 Mannequin), targeting Synty Sidekick modular + Mixamo animation later. It fully specifies the **CostumeComponent + Costume Data Asset** system (the "one costume/item swap" that is MVP System 5), the Watcher NPC visual read, and the animation/retarget plan onto the UE5 humanoid skeleton.
>
> **Read first:** `Docs/01_Game_Design_Document.md` §5.6 (items/costumes), §5.5 (movement verbs), §12 (tone); `Docs/02_MVP_Vertical_Slice.md` §1 System 5; `Docs/03_Technical_Architecture.md` §2 (server authority) & §3 (component list); `Docs/07_Movement_Physics_UI_Research.md` (swim/physics-comedy feel); `Docs/LESSONS.md` (MCP asset gotchas — 0-byte stubs, hard references, RT disabled).
>
> **Golden constraints this doc obeys:**
> 1. **Server authority (Tech §2):** costume identity and any stat modifier live in **PlayerState** (replicated), applied by the **server**. The character mesh swap is **cosmetic** and driven by an OnRep. Loudness/score/heat are NOT touched here except as *inputs* the CostumeComponent modifies via the LoudnessComponent's public modifier API.
> 2. **Build order (MVP §5):** System 1 (movement) is done; loudness → scoring → detection AI come before the full costume wardrobe. This doc gives the **full forward-looking spec** but flags the **minimal MVP slice** (System 5 = one swap) explicitly in §7.
> 3. **Folder convention:** all our content under `Content/_Project/{...}`. Placeholders reuse the stock `Content/Characters/Mannequins/` skeleton/meshes (never edited in place).
> 4. **Ray tracing disabled** (`r.RayTracing=False`, see LESSONS) — assume Lumen software / simple materials. No RT-only character shading.

---

## 0. TL;DR — What Gets Built

| Thing | Placeholder (now) | Target (later) | Asset path |
|---|---|---|---|
| Player body | UE5 Manny (`SKM_Manny_Simple`) | Synty Sidekick modular (multi-part on shared rig) | `_Project/Characters/BP_PlayerCharacter` (exists) |
| Player anim | Stock Manny ABP / Mixamo retargets | Mixamo full set retargeted to UE5 Mannequin skeleton | `_Project/Characters/Anim/ABP_PoolHopCharacter` |
| Costume system | 1 data asset ("Quiet Shoes") + component | Full wardrobe of Costume Data Assets | `_Project/Components/BP_CostumeComponent` + `_Project/Data/Costumes/` |
| Watcher NPC body | Manny (or Quinn) + tinted robe silhouette + spotlight "flashlight" | Synty Sidekick robed figure + flashlight | `_Project/AI/BP_Watcher` (body) — logic is System 4, not here |

The **CostumeComponent** and **CostumeDataAsset** are the reusable spine. Everything else (Sidekick swap, Mixamo, Watcher robe) plugs into that spine without changing gameplay authority.

---

## 1. Character Roster & Design Intent

Pool Hop has exactly two character archetypes for the whole MVP + early phases:

### 1.1 The Player (the "Hopper")
- A kid/young-adult in **swim trunks** at 2 AM. Barefoot or sneakers. Reads as *harmless, playful, sneaky* — never a criminal (GDD §12 tone).
- Silhouette must stay **light and low** when crouched — the crouch pose is a gameplay tell teammates read across a yard.
- Cosmetically the primary self-expression surface (GDD §5.6, §9): costumes are "90% flex, 10% function." This is the retention/virality hook, so the *body* must be built to swap parts cheaply.
- In co-op (Phase 2+) up to 8 identical-rig bodies exist; per-player costume differentiates them at a glance. Distinct costume silhouettes = readable teammates in the dark.

### 1.2 The Watcher (the antagonist body — MVP threat)
- The MVP's single threat is the **Homeowner/Watcher** (GDD §5.4, MVP §1 System 4). This doc owns its **body/visual read only** — its AI (perception, BT, alert states) is System 4 and specified in `Content/_Project/AI/` per Tech §4.
- Must be **instantly readable as "the danger"** at distance, at night, in a stylized world: a **robed figure holding a flashlight**. The robe gives a heavy, wide, unmistakable silhouette that contrasts the light/low player. The flashlight is both character read *and* the literal diegetic vision cone (Tech §4, research Docs/07 §4 "cone geometry identical across AI types").
- Future threats (Chaser, Cop — Phase 5) reuse the **same rig and CostumeComponent-style part system**, re-skinned. The Cop = same body, uniform + real flashlight + car; the Chaser = same body, bathrobe/dog. Designing the Watcher body modularly now means the Cop is a costume swap later, not a new character.

---

## 2. The Shared Skeleton Decision (critical, load-bearing)

**Everything — player, Watcher, all future threats — uses ONE skeleton: the UE5 Mannequin skeleton (`/Game/Characters/Mannequins/Meshes/SK_Mannequin` a.k.a. the skeleton asset shared by `SKM_Manny_Simple` / `SKM_Quinn_Simple`).**

Rationale:
- **Synty Sidekick modular is authored/retargetable onto the UE5 Mannequin skeleton** — Sidekick ships with UE-Mannequin-compatible rigs, so its modular parts (head, torso, arms, legs, feet, accessories) can drive the same skeleton. One skeleton = one animation set covers player AND NPCs.
- **Mixamo animations retarget cleanly to the UE5 Mannequin** via IK Rig + IK Retargeter (§6). Retarget once, share everywhere.
- **Modular part swapping (the costume system, §4) requires all mesh parts share a skeleton** so `SetLeaderPoseComponent` (or a single multi-section mesh) animates them together.
- Avoids the classic first-game trap of per-character bespoke rigs and duplicated anim graphs.

> **LESSONS cross-ref:** the stock `SKM_Manny_Simple` / `SKM_Quinn_Simple` are intact (not 0-byte). Manny's **material instances, textures, and control rigs are 0-byte stubs** from the initial-commit corruption (CLAUDE.md "Known issues"). This does NOT block grey-box character work (untextured grey Manny renders fine) but MUST be fixed or replaced before the Synty swap. When swapping to Sidekick, we sidestep the corrupted Manny materials entirely.

---

## 3. Player Character Body — `BP_PlayerCharacter`

`Content/_Project/Characters/BP_PlayerCharacter` already exists (duplicated from ThirdPerson template, movement verbs wired — CLAUDE.md). This section specifies the **mesh/costume additions**, not the movement (System 1, done).

### 3.1 Parent class & existing state
- Parent: `Character` (stock). Keep `CharacterMovementComponent` (gives networked prediction free — Tech §2). Keep the existing camera boom + camera.
- Existing verbs (do not disturb): walk / crouch / sprint / jump / vault / swim (via water `PhysicsVolume`, LESSONS).

### 3.2 Mesh architecture — placeholder vs modular target

**Placeholder (now):** the single stock `Mesh` component uses `SKM_Manny_Simple`. Costume "swaps" in the MVP are proven by swapping this one `SkeletalMesh` and/or an **override material** + one attached accessory (see §7). Simple and correct for System 5.

**Modular target (Phase 4+, Synty Sidekick):** replace the single mesh with a **modular part set**, all sharing the Mannequin skeleton:

| Component name | Slot | Sidekick part category | Default (swim trunks) |
|---|---|---|---|
| `Mesh` (the leader) | Body base / skin | Sidekick base body | Bare torso + legs (swimmer) |
| `SM_Head` (SkeletalMeshComponent) | Head | Sidekick heads | Default head |
| `SM_Hair` | Hair/hat | Sidekick hair | Default hair |
| `SM_Torso` | Torso clothing | Sidekick tops | *(none — bare for trunks)* |
| `SM_Legs` | Legs clothing | Sidekick bottoms | Swim trunks |
| `SM_Feet` | Feet | Sidekick feet/shoes | Bare feet |
| `SM_Accessory` | Accessory (attach to socket) | Sidekick accessories / custom | *(none)* |

- The `Mesh` component is the **leader**; every other `SkeletalMeshComponent` calls **`SetLeaderPoseComponent(Mesh)`** in `BeginPlay` so they all animate from the single ABP driving `Mesh`. This is the standard UE modular-character pattern and is the cheapest correct way to do part swapping.
- Accessory props (flamingo ring, night-vision goggles) attach as **StaticMesh or SkeletalMesh components to named sockets** on the Mannequin skeleton (e.g. `hand_r`, `head`, `spine_03`). Define sockets: `socket_head` (goggles/hats), `socket_ring` (waist — flamingo ring), `socket_back` (future).

> **Why not a single multi-material mesh?** Modular components let a Costume Data Asset (§4) swap *one* slot (just the feet for "quiet shoes") without touching the rest — exactly what the "swap one part + optional small modifier" design needs.

### 3.3 Variables added to `BP_PlayerCharacter` (cosmetic only — NO gameplay truth)
| Variable | Type | Replication | Purpose |
|---|---|---|---|
| `CostumeComponent` | `BP_CostumeComponent` (component) | n/a (component) | Owns the costume apply logic (§4) |
| `bIsInWater` | bool | (already driven by movement) | Anim graph input for swim state |

**No score, loudness, alert, or costume-identity variable lives here.** Costume identity lives on **PlayerState** (§4.2). The character only *renders* what the CostumeComponent tells it to.

---

## 4. Costume System — the reusable spine

This is the heart of the deliverable. Two pieces: a **Data Asset** (defines a costume) and a **Component** (applies it, server-authoritatively). Plus the authority hook on **PlayerState**.

### 4.1 `CostumeDataAsset` — the data definition

- **Asset type:** a `PrimaryDataAsset` (Blueprint) so costumes are discoverable/loadable by the meta later. Create via MCP `DataAssetTools.create` (LESSONS: this is the tool that works for data assets; verify size on disk after).
- **Class path:** `Content/_Project/Data/Costumes/DA_Costume_Base` (the class); instances live alongside as `DA_Costume_<Name>`.
- **Base class name:** `CostumeDataAsset` (parent `PrimaryDataAsset`).

**Fields (with types):**

| Field | Type | Notes |
|---|---|---|
| `CostumeId` | `Name` | Stable unique id (e.g. `Costume.QuietShoes`). Used by PlayerState + save/unlock later. |
| `DisplayName` | `Text` | UI-facing name ("Quiet Shoes"). |
| `Description` | `Text` | Flavor for the wardrobe UI. |
| `MeshParts` | `Map<Name, SkeletalMesh>` | Slot name → mesh. Keys match §3.2 component slot names (`Torso`, `Legs`, `Feet`, `Head`, `Hair`). Empty/unset slot = "use default / bare". |
| `AccessoryMeshes` | `Array<FCostumeAccessory>` | Struct: `{ SocketName: Name, Mesh: StaticMesh, Scale: Vector }`. For flamingo ring, goggles, etc. |
| `OverrideMaterials` | `Map<Name, MaterialInterface>` | Optional per-slot material override (color flex without new mesh). |
| `StatModifier` | `FCostumeStatModifier` (struct) | The **optional small function**. See below. |
| `bIsDefault` | `bool` | True for swim trunks (fallback). |

**`FCostumeStatModifier` struct (the 10% function — keep SMALL per GDD §5.6):**

| Field | Type | Default | Meaning |
|---|---|---|---|
| `LoudnessFootstepMultiplier` | float | `1.0` | Multiplies loudness generated by footsteps (quiet shoes = `0.8`). |
| `LoudnessInWaterMultiplier` | float | `1.0` | Multiplies loudness while swimming/splashing (wetsuit = `0.75`; flamingo ring = `1.5`). |
| `BushHideBonus` | float | `0.0` | Additive reduction to AI sight-detection rate while in a bush volume (ghillie = `+0.4`, i.e. 40% slower fill). |
| `ScoreFlairMultiplier` | float | `1.0` | Cosmetic-adjacent score flair (flamingo ring = `1.1` — reward the funny risk). Applied server-side in scoring rules. |
| `MoveSpeedMultiplier` | float | `1.0` | Reserved; keep `1.0` for MVP (movement feel is sacred, System 1). |

> **Design guardrail (GDD §5.6):** every modifier is a small multiplier/additive nudge, never a hard on/off power. No costume should be strictly dominant. Examples below stay within ±25% except the deliberate flamingo trade (louder but funnier + score flair).

**The five reference costumes (data-only — build the assets, not new code):**

| Data Asset | MeshParts changed | StatModifier | Design read |
|---|---|---|---|
| `DA_Costume_SwimTrunks` | Legs=trunks (default) | all defaults; `bIsDefault=true` | Baseline. Free. |
| `DA_Costume_Wetsuit` | Torso+Legs+Feet=wetsuit | `LoudnessInWaterMultiplier=0.75` | Quieter in water — the "diver." |
| `DA_Costume_FlamingoRing` | Accessory: flamingo ring at `socket_ring` | `LoudnessInWaterMultiplier=1.5`, `ScoreFlairMultiplier=1.1` | Loud but hilarious; clip-bait (Docs/05 virality). |
| `DA_Costume_Ghillie` | Torso+Legs=ghillie, Head=hood | `BushHideBonus=0.4` | Better bush hide — the "lurker." |
| `DA_Costume_QuietShoes` | Feet=sneakers | `LoudnessFootstepMultiplier=0.8` | −20% footstep loudness. **This is the MVP System 5 proof (§7).** |

### 4.2 `PlayerState` — where costume identity lives (server-authoritative)

Per Tech §2, the *choice* of costume is per-player replicated truth → **PlayerState**.

Add to `BP_PlayerState` (`_Project/Core/BP_PlayerState`):

| Variable | Type | Replication | Notes |
|---|---|---|---|
| `EquippedCostume` | `CostumeDataAsset` (soft or hard ref) | **Replicated, RepNotify → `OnRep_EquippedCostume`** | The equipped costume. Set only by the server. |

- `OnRep_EquippedCostume` (fires on clients; in Blueprint also on server — LESSONS/Tech §2 note) calls the owning character's `CostumeComponent.ApplyCostume(EquippedCostume)`.
- **Server sets it** via a validated request: client calls `Server_RequestEquipCostume(CostumeDataAsset)` (a Server RPC on the PlayerController or Character) → server checks it's unlocked/valid → sets `PlayerState.EquippedCostume`. In MVP (single-player/local host) this path still runs, keeping the authority model correct for Phase 2.
- **Use OnRep, not Multicast** (Tech §2 gotcha) so a late-joining co-op player (Phase 2+) sees everyone's correct costume from replicated state, not a missed one-shot event.

### 4.3 `BP_CostumeComponent` — the applier

- **Class path:** `Content/_Project/Components/BP_CostumeComponent`. Parent: `ActorComponent`.
- **Attached to:** `BP_PlayerCharacter` (and later the Watcher/other NPCs — the same component skins them).

**Public functions:**

| Function | Signature | Runs on | Does |
|---|---|---|---|
| `ApplyCostume` | `(CostumeDataAsset Costume)` | Client + server (cosmetic) | Sets mesh parts, accessories, materials on the owning character; then applies the stat modifier (server only — see below). |
| `ApplyMeshParts` | `(CostumeDataAsset)` (internal) | Everywhere (cosmetic) | For each slot in `MeshParts`, `SetSkeletalMesh` on the matching component; empty slot → default/hidden. Spawns/updates accessory components at their sockets. Applies `OverrideMaterials` via component `overrideMaterials` array (LESSONS: don't edit the shared mesh material). |
| `ApplyStatModifier` | `(FCostumeStatModifier)` (internal) | **Server only** | Pushes multipliers into the systems that own that truth (see wiring below). |
| `ClearStatModifier` | `()` | Server only | Restores defaults before applying a new costume (no stacking). |

**Stat-modifier wiring (the authority-respecting part):**
- The CostumeComponent does **not** store loudness/score. It calls **setters on the systems that own that state**:
  - `LoudnessComponent.SetFootstepMultiplier(x)` and `SetInWaterMultiplier(x)` — the LoudnessComponent (System 2) exposes these; it applies them when generating noise. (System 2 must expose these setters — a one-line forward dependency noted here so System 2 is built with the hooks.)
  - `BushHideBonus` → stored on the character as a replicated-derived cosmetic? **No** — detection resolves server-side (Tech §4). The value is read by the **AI sight resolution / scoring rules on the server** from `PlayerState.EquippedCostume.StatModifier.BushHideBonus`. So the AI, not the component, reads it. The component's job for this field is nothing at runtime; the *server AI* consults PlayerState. (Documented so System 4 knows to read it.)
  - `ScoreFlairMultiplier` → read by the **scoring rules in GameMode** from PlayerState when banking pool time (Tech §2: rules live in GameMode). Again: server reads PlayerState; component doesn't push score.
- Net rule: **cosmetic (mesh/material/accessory) is applied everywhere by the component; functional modifiers are read by the owning server systems from PlayerState.** This keeps the character/component free of gameplay truth.

**Apply order (`ApplyCostume`):**
1. `ClearStatModifier()` (server).
2. `ApplyMeshParts(Costume)` (everywhere) — visual.
3. If `HasAuthority`: `LoudnessComponent.SetFootstepMultiplier(...)` / `SetInWaterMultiplier(...)` from `Costume.StatModifier`. (Bush/score modifiers need no push — server systems read PlayerState directly.)
4. `SetLeaderPoseComponent` re-assert on any newly-swapped skeletal parts.

---

## 5. The Watcher NPC Body — `BP_Watcher` (visual read only)

> **Boundary:** this section specs the **body, mesh, silhouette, and flashlight**. The AIController, AIPerceptionComponent, Behavior Tree, and Unaware/Suspicious/Alert states are **System 4** — built later under `_Project/AI/` per Tech §4 and `Docs/07` §4. This doc only guarantees the *body reads correctly* and *hosts the flashlight that IS the vision cone*.

### 5.1 Class & mesh
- **Class path:** `Content/_Project/AI/BP_Watcher`. Parent: `Character` (so it can walk patrol routes via `CharacterMovementComponent`, and reuse the shared skeleton/anim).
- **Mesh (placeholder):** `SKM_Quinn_Simple` (use Quinn to visually differ from the player Manny) with a **dark override material** (translucent-unlit dark blue-grey, built per LESSONS "Material-from-scratch via MCP"), OR Manny with a distinct tint. Goal: a **dark, heavy, non-player silhouette**.
- **Mesh (target):** Synty Sidekick **robed figure** — long robe/dressing-gown part in the Legs+Torso slots (uses the SAME CostumeComponent + a `DA_Costume_WatcherRobe` data asset — the Watcher is literally "an NPC wearing the robe costume"). This is why the costume system is built to also skin NPCs.

### 5.2 The silhouette contract (readability — GDD Pillar 4, Docs/07 §4)
The Watcher must be distinguishable from a player **in one glance, at night, at 15+ meters**:
- **Robe** = wide, floor-length, heavy base → bottom-heavy triangle silhouette (player is a lean vertical).
- **Slower, upright, deliberate** gait (anim, §6) vs the player's crouch-sneak.
- **Carries a flashlight** — no player ever holds a flashlight, so "light source in hand" reads as threat instantly.
- **Overhead alert icon** (`?`/`!`) widget — System 4, but the body reserves a `socket_head`-anchored widget component slot for it.

### 5.3 The flashlight (this IS the vision cone)
- **Component:** a `SpotLightComponent` named `Flashlight`, attached to the right-hand socket (`hand_r`) or a dedicated `socket_flashlight` on `spine_03` pointing forward.
- **Config:** `Intensity` moderate, warm-white color (`~4500K`), `InnerConeAngle` / `OuterConeAngle` **matched to the AIPerception `PeripheralVisionHalfAngle`** so the *visible* light cone equals the *actual* detection cone (Tech §4 "clients render the cones", Docs/07 §4 "identical cone geometry across AI types"). Suggested start: OuterCone ≈ 35° (half-angle), matching a `PeripheralVisionHalfAngle` of 35 and `SightRadius` ≈ the light `AttenuationRadius` (~1200 units start).
- A small `StaticMesh` flashlight prop (Kenney/placeholder cylinder) attached at the same socket so the source reads diegetically.
- **RT-off note (LESSONS):** the flashlight is a normal dynamic spotlight under Lumen software — fine. Do NOT rely on RT shadows. Keep shadow-casting on but simple; profile (MegaLights handles many such lights — Tech §8).
- **State color tell (optional, System 4 hook):** the flashlight/beam color can tint toward the alert state (neutral warm → subtle when Suspicious). Body just exposes the SpotLight; System 4 drives the tint.

### 5.4 Reuse for future threats (Phase 5)
- **Cop** = `BP_Watcher` variant / same rig + `DA_Costume_Cop` (uniform, real flashlight, hat) + a car actor. 
- **Chaser** = same rig + `DA_Costume_Bathrobe` (or a dog variant on a different mesh).
- Because they share the skeleton + CostumeComponent, adding them is a **data + AI-tuning job**, not a new character pipeline.

---

## 6. Animation Plan & Retarget Approach

### 6.1 Target skeleton & source
- **Target skeleton:** UE5 Mannequin (the skeleton shared by `SKM_Manny_Simple`/`SKM_Quinn_Simple`). All animation lives on this one skeleton so player + Watcher + future threats share it.
- **Sources, in priority order:**
  1. **Stock UE5 Mannequin locomotion** (already in the template — walk/run/idle/jump) for the fastest grey-box path. `BP_PlayerCharacter` currently uses the template ABP.
  2. **Mixamo** (free) for the Pool-Hop-specific verbs not in the stock set: **swim, tread-water, crouch-walk, vault/climb-over, hide-crouch, dive-in, caught/ragdoll-recover, and the Watcher's robed patrol walk + flashlight-sweep idle.**

### 6.2 Required animation set (by verb — MVP System 1 verbs first)
| Anim | Who | Source | Priority |
|---|---|---|---|
| Idle, Walk, Run/Sprint | Player + Watcher | Stock UE5 | **MVP** (have it) |
| Crouch idle + crouch walk | Player | Mixamo "Crouch" / stock | **MVP** |
| Jump / fall / land | Player | Stock UE5 | **MVP** (have it) |
| Vault / climb-over | Player | Mixamo "Climbing" / "Vault" | System 1 polish |
| Swim forward + tread-water idle | Player | Mixamo "Swimming" | Scoring milestone (pools) |
| Dive-in / splash-enter | Player | Mixamo "Diving" | Scoring milestone |
| Underwater swim + up/down | Player | Mixamo (direct up/down axis, Docs/07 §3) | Scoring milestone |
| Bush-hide crouch | Player | Mixamo / reuse crouch | Detection milestone |
| Caught / hands-up / stumble | Player | Mixamo "Reaction" (bounded ragdoll, Docs/07 §2) | Detection milestone |
| Watcher patrol walk (slow, upright) | Watcher | Mixamo "Walking" (slowed) | Detection milestone |
| Watcher flashlight-sweep idle / look-around | Watcher | Mixamo "Looking Around" | Detection milestone |

### 6.3 Retarget approach (UE 5.8 — IK Rig + IK Retargeter)
Mixamo → UE5 Mannequin is a solved, documented pipeline in UE5.8:
1. **Import Mixamo FBX** into `Content/ThirdParty/Mixamo/` (keep imports out of `_Project` for licensing clarity — Tech §6). Import **without** creating a new skeleton per clip where possible; if Mixamo's own skeleton is created, that's fine — retargeting bridges it.
2. **IK Rig for the Mixamo skeleton** (`IK_Mixamo`) and **IK Rig for the UE5 Mannequin** (`IK_Mannequin` — Epic ships one, or create: set the Retarget Root to `pelvis`, define the standard chains: Spine, Head, LeftArm, RightArm, LeftLeg, RightLeg).
3. **IK Retargeter** (`RTG_MixamoToMannequin`): source = `IK_Mixamo`, target = `IK_Mannequin`. Map chains (Mixamo's `mixamorig:` bones → Mannequin bones). Mixamo bone naming is standard so chain auto-mapping is reliable.
4. **Batch-export retargeted animations** (right-click the retargeter → Export Animations, or the Retarget Animations batch tool) into `Content/_Project/Characters/Anim/` as Mannequin-skeleton AnimSequences prefixed `AS_` (e.g. `AS_Swim_Fwd`, `AS_Vault`, `AS_Watcher_Patrol`).
5. **These retargeted sequences now play on Manny AND Synty Sidekick** (both on the Mannequin skeleton) — no re-retarget when we swap the mesh to Sidekick. That's the payoff of the §2 one-skeleton decision.

### 6.4 Animation Blueprint
- **`ABP_PoolHopCharacter`** (`_Project/Characters/Anim/`), skeleton = UE5 Mannequin.
- **State machine:** Ground (Idle/Walk/Run blendspace by speed) → Crouch (crouch blendspace) → Jump/Fall → **Swim** (surface tread ↔ swim-forward ↔ underwater, driven by `bIsInWater` + up/down input) → Vault (montage) → Caught (montage → bounded ragdoll, Docs/07 §2 "controllability ceiling").
- **Inputs from character (all cosmetic/derived, not authoritative):** `Speed`, `bIsCrouched`, `bIsInWater`, `bIsFalling`, `Direction`. Vault/caught triggered by **AnimMontage** played from gameplay events.
- **Watcher** can share `ABP_PoolHopCharacter` with a slower play-rate + a flashlight-sweep additive on the upper body, OR a trimmed `ABP_Watcher`. Start by sharing to save work.

### 6.5 Placeholder-first discipline (Docs/07 §1 "Astro Bot model")
Grey-box the movement feel with **stock anims** first (already done for walk/run). Only retarget the Mixamo set when its milestone arrives (swim at scoring, hide/caught at detection). Don't front-load the full anim set before the systems that use it exist — matches MVP §5 build order.

---

## 7. The MVP Slice (System 5) — exactly what to build NOW vs later

MVP System 5 (MVP §1) is **"one costume/item swap + one small stat change"** — the proof the plumbing works, not the wardrobe. Build **only** this now:

**MVP build (System 5, ~one short milestone, AFTER detection AI per build order):**
1. Build `CostumeDataAsset` class (§4.1) with all fields (cheap; the struct is small).
2. Build **one** instance: `DA_Costume_QuietShoes` — `Feet` slot swap (or just an override material if no shoe mesh yet) + `StatModifier.LoudnessFootstepMultiplier = 0.8`.
3. Build `BP_CostumeComponent` (§4.3) with `ApplyCostume` / `ApplyMeshParts` / `ApplyStatModifier`. For MVP, `ApplyMeshParts` can operate on the **single stock Manny mesh** (swap material or one accessory) — modular multi-part is deferred to the Synty phase.
4. Add `EquippedCostume` (replicated + OnRep) to `BP_PlayerState` and the `Server_RequestEquipCostume` path (§4.2).
5. Wire `LoudnessComponent.SetFootstepMultiplier` (requires System 2 to expose that setter — build System 2 with the hook).
6. Trigger: a **pickup actor** (`BP_CostumePickup` in `_Project/Gameplay/`, holds a `CostumeDataAsset`) or a debug key. On overlap → `Server_RequestEquipCostume`.
7. **Verify (MVP §4-style):** equip Quiet Shoes → footstep loudness measurably drops (~20%) → AI hears you from a shorter radius. Server-authoritative (value set on server, mesh swaps on client via OnRep).

**Explicitly deferred (Phase 4+, do NOT build now):** modular Sidekick multi-part mesh, the other four reference costumes, the wardrobe UI, accessory sockets/props, the Watcher robe costume data asset. All are *specified* above so they slot in without rearchitecting — that's the point of writing the full spec.

---

## 8. Build Sequence Checklist (for the MCP-driven engineer)

Respecting MVP §5 order — costume work comes AFTER loudness/scoring/detection:

- [ ] **(Now/parallel-safe) Anim:** confirm stock walk/run/idle on `BP_PlayerCharacter`; retarget Mixamo **swim + crouch** when the scoring/pool milestone lands (§6.3). Build `RTG_MixamoToMannequin` once.
- [ ] **(System 5 milestone) Data:** `DataAssetTools.create` → `CostumeDataAsset` class at `_Project/Data/Costumes/` (verify on-disk size after, LESSONS). Then `DA_Costume_QuietShoes` instance.
- [ ] **(System 5) Component:** `BlueprintTools.create` `BP_CostumeComponent` (parent `ActorComponent`) at `_Project/Components/`. Author `ApplyCostume` graph via `write_graph_dsl` (get docs first, LESSONS). Add to `BP_PlayerCharacter`.
- [ ] **(System 5) PlayerState:** add `EquippedCostume` (replicated, RepNotify) + `OnRep_EquippedCostume` → calls CostumeComponent. Add `Server_RequestEquipCostume` RPC path.
- [ ] **(System 5) Pickup:** `BP_CostumePickup` in `_Project/Gameplay/` with a `CostumeDataAsset` field + overlap → server request.
- [ ] **(System 5) Verify:** PIE — equip Quiet Shoes, confirm loudness drop + shorter AI hear radius; confirm value set server-side.
- [ ] **Commit + push** after the milestone (CLAUDE.md standing rule). Update LESSONS with any MCP costume/data-asset gotchas.
- [ ] **(Phase 4+, deferred) Synty swap:** import Sidekick to `ThirdParty/`, retarget onto Mannequin skeleton, convert `BP_PlayerCharacter` to modular components (§3.2), build remaining costume data assets, build Watcher robe.
- [ ] **(Detection milestone) Watcher body:** `BP_Watcher` (parent `Character`) with dark Quinn mesh + `Flashlight` SpotLight cone matched to perception angle (§5.3). AI logic = System 4, separate.

---

## 9. Authority & Convention Compliance (self-check)

- ✅ **No gameplay truth on character/pawn.** Costume identity → PlayerState (replicated). Stat modifiers → read by server systems (LoudnessComponent setters, GameMode scoring rules, server AI sight) from PlayerState. Character/component only render + forward.
- ✅ **OnRep over Multicast** for costume replication (late-join safe, Tech §2).
- ✅ **Server validates** the equip request (`Server_RequestEquipCostume`).
- ✅ **Folder + naming:** `_Project/{Characters,Components,Data,AI,Gameplay}`, `BP_`/`DA_`/`AS_`/`RTG_`/`IK_` prefixes.
- ✅ **One shared skeleton** (UE5 Mannequin) for player + Watcher + future threats → one anim/retarget set.
- ✅ **Placeholder-first:** stock Manny/Quinn now, Sidekick later; stock anims now, Mixamo per-milestone.
- ✅ **RT disabled respected:** flashlight is a Lumen-software dynamic spotlight; no RT-only shading.
- ⚠ **Forward dependencies flagged:** System 2 (LoudnessComponent) must expose `SetFootstepMultiplier` / `SetInWaterMultiplier`; System 4 (AI) must read `BushHideBonus`; GameMode scoring must read `ScoreFlairMultiplier` — all from PlayerState. Noted so those systems are built with the hooks.
- ⚠ **Known asset debt:** Manny material instances / textures / control rigs are 0-byte stubs (CLAUDE.md) — fine for grey-box, must be fixed or bypassed at the Synty swap (we bypass by moving to Sidekick materials).
- **C++ flag:** everything here is Blueprint-buildable. The only classic C++-only character concern (AI perception *affiliation teams*, Tech §1) belongs to System 4, not this doc. No C++ required for the costume system or character bodies.

---

*Next: when the scoring milestone lands, build `RTG_MixamoToMannequin` and retarget swim/crouch. When System 5's turn comes in the build order, build the Costume spine per §7. The Watcher body is built alongside System 4 (detection).*
