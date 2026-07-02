# Pool Hop — Art & Style Direction

*Version 0.1 — build-ready look-dev spec. Last updated 2026-06-30.*

> **What this doc is.** The single source of truth for how Pool Hop *looks* and *reads*: the stylized suburban-night target, the concrete Unreal 5.8 recipes to hit it (toon master material, water, night post-process, sky), and the readability layer (vision cones, noise ripples, `?`/`!` icons) that sits on top. Every recipe names exact asset paths, parent classes, node graphs, and tuning numbers so an engineer driving the editor via `unreal-mcp` can build it.
>
> **What this doc is NOT.** A green light to build ahead of scope. Per [`Docs/02_MVP_Vertical_Slice.md`](../02_MVP_Vertical_Slice.md) §5 the build order is **Loudness → Scoring → Detection AI → couple → costume/item**, on a **grey box**. This document is *grey-box-first*: §2 is what to build now for readability; §3–7 are the look-dev target we grow into during Phase 4+ (real neighborhoods) and Phase 6 (Toon Shader look-dev). Where a recipe is forward-looking it is tagged **[TARGET / Phase 4+]**. Do not spend polish hours on §3–7 while the loop is unproven.

---

## 0. Ground truth this doc is built on

- **Engine constraints (LESSONS + CLAUDE.md):** UE 5.8, Blueprints-first. **`r.RayTracing=False`** (a HWRT SBT deadlock forced this — see [`Docs/LESSONS.md`](../LESSONS.md)). So: **Lumen in software mode**, **MegaLights** for the many small lights, **no hardware ray tracing** in any recipe here. Do not re-enable `r.RayTracing` to chase a reflection — use SSR / planar / cheap tricks instead (§4.4).
- **Pillars this serves (GDD §3):** Pillar 4 *"Readable, Not Realistic"* and *"lighting is the level design"* (GDD §10) are the spine of this doc. The world is pretty; the **gameplay-critical layer (cones, noise, alert, loudness) is always crystal-clear on top of it.**
- **Server authority (Tech doc §2) — art's one hard rule:** *no gameplay-authoritative state lives in a material or a widget.* Materials and widgets are **cosmetic readers** of replicated state (loudness 0–100 on PlayerState, alert enum on the AI / GameState, at-risk score on GameState). A vision-cone decal shows what the **server** decided; it never *is* the detection. Detection resolves server-side (Tech doc §4); clients render from replicated values. Keep every art recipe a pure function of replicated inputs.
- **Assets actually staged right now** (`_ThirdPartyStaging/`, verified on disk 2026-06-30):
  - `Kenney/kenney_furniture-kit/` — 140 FBX (patio chairs, tables, lamps, loungers → cover + patio dressing).
  - `Kenney/kenney_nature-kit/` — 330 FBX (hedges/bushes via `grass_*`, `flower_*`, `plant_*`, `tree_*`, `fence_simple*`/`fence_planks*`, `cliff_*` rocks → cover, hedge maze, fences).
  - `Kenney/kenney_impact-sounds/` — 130 OGG (footsteps by surface, impacts → placeholder splash/vault/fence audio).
  - `PolyHaven/satara_night_4k.exr` — **the staged night HDRI** (starry sky, warm distant village lamps; CC0). This is our sky plan's anchor.
  - **Not yet on disk:** Kenney City-Kit-Suburban (listed in `ASSET_CREDITS.md` but not present — grab before Phase 4), Synty POLYGON Town/City (paid, Phase 4+), Sidekick characters + Mixamo (need account login). All flagged in §8.

---

## 1. The Look in One Paragraph

**A warm memory, remembered at 2 AM.** Deep navy-black suburbia under a starry sky, everything flattened into clean toon shapes with a soft ink edge — then punched through by *warm pools of light*: a streetlamp's sodium cone, a TV's blue flicker in a window, the turquoise glow of a lit pool, the sudden white slap of a motion flood. Those warm/cool light pools are not just mood; **they are the level design** — light = danger, shadow = safety, water = reward. On top of the pretty night sits a **flat, high-contrast readability layer** (vision cones, expanding noise rings, `?`/`!` bubbles, a corner loudness meter) that never tries to be realistic — it reads instantly, like a board game overlaid on a diorama. The tone is *nostalgic mischief*, never crime: think Untitled Goose Game's cleanliness and Sneaky Sasquatch's forgiving legibility, lit like a Studio-Ghibli night.

**Three-word north star:** *Cozy. Cool-dark. Crystal-readable.*

---

## 2. BUILD NOW — Grey-Box Readability & Night Mood (Phase 1)

This is the only part of the doc you build during the systems sandbox. It exists so that while tuning Loudness → Scoring → Detection, the tester can *read* the game. Five cheap, high-leverage pieces. All live under `Content/_Project/` and are pure readers of replicated state.

### 2.1 The night palette (canonical colors — use these everywhere)

Define once, reuse in every material/widget so the game is color-consistent. Store as a `Data/DA_ArtPalette` **Primary Data Asset** (Blueprint parent `PrimaryDataAsset`) with `LinearColor` fields, so tuning is data-driven (Tech doc §4 — no hardcoded values). Values are **linear** (0–1), sRGB hex in parens for reference.

| Token | Linear RGB | (sRGB hex) | Used for |
|---|---|---|---|
| `NightSky` | 0.010, 0.018, 0.045 | `#1A2340` | sky zenith, deepest shadow |
| `NightAmbient` | 0.020, 0.030, 0.070 | `#28345C` | shadowed ground / cool fill |
| `NightBlueKey` | 0.04, 0.07, 0.16 | `#3A4E80` | moonlit surfaces (cool key) |
| `LampWarm` | 1.00, 0.62, 0.25 | `#FFB060` | streetlamps, porch lights (sodium) |
| `WindowGlow` | 1.00, 0.78, 0.42 | `#FFCF87` | lit interior windows |
| `TVGlow` | 0.30, 0.55, 1.00 | `#6E9BFF` | TV-lit rooms (cool flicker) |
| `PoolTurquoise` | 0.10, 0.72, 0.78 | `#22C3CC` | lit pool water (the reward color) |
| `FloodWhite` | 0.95, 0.97, 1.00 | `#F4F8FF` | motion-sensor flood (harsh, alarming) |
| **`ReadSafe`** (green) | 0.10, 0.85, 0.35 | `#1FD95A` | Unaware / safe / banked |
| **`ReadWarn`** (amber) | 1.00, 0.72, 0.05 | `#FFB80D` | Suspicious / at-risk / mid loudness |
| **`ReadAlert`** (red) | 1.00, 0.15, 0.12 | `#FF261F` | Alert / caught / high loudness |
| `LootUncommon` | 0.55, 0.80, 1.00 | `#8CCCFF` | Uncommon field-trinket world glow (`design/11` §3) |
| `LootRare` | 0.55, 0.20, 0.95 | `#8C33F2` | Rare field-trinket world glow (`design/11` §3) |
| `LootMythic` | 1.00, 0.75, 0.85 | `#FFC0D9` | The Trophy's world glow — always paired with particle sparkle + a distinct chime, never hue alone (`design/11` §3) |

> **Rule of two temperatures:** the *world* is cool (blues) with **warm** light pools. The *readability layer* is a separate, saturated **green→amber→red** language reserved ONLY for gameplay state, so players never confuse "warm lamp = pretty" with "amber = getting caught." Warm world light and amber alert are deliberately different hues (`LampWarm` #FFB060 vs `ReadWarn` #FFB80D-on-flat-UI) — the alert language is flatter, brighter, and always rendered unlit/on-top.
>
> **A third language, kept separate from both:** loot rarity (`LootUncommon`/`LootRare`/`LootMythic`) is neither a world-light color nor an alert-state color — it must never be reused for either, and vice versa, or the two "read this instantly" languages collide (`design/11` §3).

### 2.2 Grey-box master material `M_GreyboxToon` — cheap toon read now

Path: `Content/_Project/Gameplay/Materials/M_GreyboxToon`. Purpose: make grey boxes read as *stylized night* (banded shading + soft edge) with zero art cost, so tuning happens in the real palette. This is a **stand-in for the full toon master (§3)** — same *idea*, minimal nodes.

Build (MCP `MaterialTools.create_material` → `add_expression` → `connect_to_output`, per the LESSONS material recipe):
- **Shading model:** `MSM_DefaultLit` (keep it Lumen-lit; the toon *banding* is faked in the material, not the Toon Shading Model yet — the real Toon Shader is §3/[TARGET]). `TwoSided=false`.
- **Params (make it an instance-friendly master — expose as `ScalarParameter`/`VectorParameter`):**
  - `BaseColor` (Vector, default `NightBlueKey`).
  - `ShadowColor` (Vector, default `NightAmbient`).
  - `Bands` (Scalar, default `3`) — number of light steps.
  - `EdgeWidth` (Scalar, default `0.35`) — fresnel rim thickness.
  - `RimColor` (Vector, default `NightBlueKey`×1.4).
- **Cel graph (emulate toon without the shading model):**
  1. `Fresnel` (ExponentIn = 4, BaseReflectFractionIn = 0.04) → multiply by `EdgeWidth` → `lerp(BaseColor, RimColor, fresnelMasked)` gives a soft ink-ish rim.
  2. Banding: take `SkyLight`/ambient-independent read via a simple **`Lightmass`-free** trick — feed the dot of pixel normal · a constant "moon" direction (`normalize(0.3, 0.4, 0.8)`) through `floor(x*Bands)/Bands` to quantize into steps, `lerp(ShadowColor, BaseColor, stepped)`.
  3. Emissive: 0 (grey box is lit, not glowing).
  - Wire step-2 result into `BaseColor` output; step-1 rim added on top; `Roughness` const `0.85`; `Metallic` 0.
- **MIs to spawn from it** (so grey-box actors are color-coded for readability during tuning):
  - `MI_Greybox_Ground` (BaseColor `NightAmbient`) — floor/lawn.
  - `MI_Greybox_Cover` (BaseColor `NightBlueKey`) — bushes/walls/fences the player hides behind.
  - `MI_Greybox_Pool` (BaseColor `PoolTurquoise`, add `Emissive` = `PoolTurquoise`×0.6) — pool footprint reads as glowing reward even as a box.
  - `MI_Greybox_Stash` (BaseColor `ReadSafe`, Emissive ×0.4) — the bank/exit zone reads green = safe.

### 2.3 Night post-process + one directional "moon" — the mood, cheaply

A single `PostProcessVolume` (`Unbound=true`) + one `DirectionalLight` (the moon) + `SkyLight` (from the HDRI, §5) is the entire Phase-1 lighting rig. Place via `SceneTools.add_to_scene_from_class`; set with `ObjectTools.set_properties`.

**`DirectionalLight` (BP_Moon or plain actor):**
- Rotation: Pitch `-35°`, Yaw `35°` (raking side-moon → long readable shadows).
- `Intensity` = `1.8` lux (moonlight is dim), `LightColor` = `NightBlueKey`, `Temperature` off.
- `LightSourceAngle` = `1.5` (soft shadow edges — toon-friendly).
- Casts shadows ON (software Lumen handles it).

**`SkyLight`:** `SourceType = SLS_SpecifiedCubemap` → the Satara Night HDRI cubemap (§5), `Intensity` = `0.6`, `LowerHemisphereIsSolidColor=true` (color `NightSky`) so the ground isn't lit from below. **Real-Time Capture OFF for now** (cheaper + deterministic; re-enable in look-dev).

**`PostProcessVolume` settings** (this is where "2 AM" is authored — all under `Settings`):
- **Exposure:** `AutoExposureMethod = AEM_Manual`, `AutoExposureBias` such that scene reads dark-but-legible. Manual exposure = **critical for a night game** (auto-exposure will "brighten the dark" and kill the mood + the readability of light pools). Set `AutoExposureBias = -1.0` as a start, tune per map.
- **Color grading (the night key):**
  - `SceneColorTint` = slight cool: `LinearColor(0.85, 0.92, 1.05)`.
  - `Global > Saturation` = `0.90` (desaturate the dark world so the green/amber/red readability layer pops).
  - `Shadows > Gain` = cool blue push (`0.9, 0.95, 1.15`); `Highlights > Gain` = keep warm (`1.05, 1.0, 0.92`) so lamp pools stay golden. This split-tone (cool shadows / warm highlights) is the whole night look in two sliders.
  - `Global > Contrast` = `1.08`.
- **Bloom:** `BloomIntensity = 0.5`, `BloomThreshold = 0.6` — enough that lamps/pool/windows *bloom* into soft warm pools (this is what sells "pools of light" cheaply). Don't overdo it or the readability layer smears.
- **Vignette:** `VignetteIntensity = 0.45` — pulls focus inward, adds night intimacy.
- **Film grain:** `FilmGrainIntensity = 0.10` — subtle, filmic, hides banding in the dark gradients.
- **Ambient Occlusion:** `AmbientOcclusionIntensity = 0.6`, `Radius = 40` — grounds toon objects.
- **Lumen:** `DynamicGlobalIlluminationMethod = Lumen`, `ReflectionMethod = Lumen`, **`LumenRayLightingMode`** left at software default; `FinalGatherQuality` ~1.0 (this is Lumen Lite-ish — fine for stylized night; keep off HWRT). If perf dips with many lights, drop GI to Screen-Space as a fallback (§4.4).

### 2.4 The readability layer — what to build NOW (with Detection AI)

These ship *alongside System 4 (Detection AI)*, not before, but the recipes are specified here so they're consistent. All are **flat/unlit and drawn on top** — they must survive the dark and never be mistaken for world art.

**(a) Vision cone `M_VisionCone` (decal — the "flashlight range").**
- Type: **Deferred Decal material** (`MaterialDomain = MD_DeferredDecal`, `DecalBlendMode = DBM_Translucent`), projected on the ground from the AI's eye. A ground decal reads better on uneven terrain than a mesh cone and is dirt-cheap.
- Path `Content/_Project/AI/Materials/M_VisionCone`. Parent an MID so the AI Blueprint drives it.
- **Geometry:** the AI Blueprint owns a `DecalComponent` forward of the pawn; its box size = `SightRadius` (§ matches `AISense_Sight.SightRadius`, e.g. 1200 uu) so **the decal literally is the perception range** (art reads truth). The cone *angle* is masked in-material: convert decal-space UV to polar, mask `abs(angle) < PeripheralVisionHalfAngle` (e.g. 45°). **Per Docs/07: cone geometry is IDENTICAL across all AI types** — only the driven params (radius/angle/color) differ. One material, many MIDs.
- **Color drives off alert state (replicated enum), NOT local guesswork:**
  - Unaware → `ReadSafe` (green) at low opacity `0.12` (barely there, calm).
  - Suspicious → `ReadWarn` (amber), opacity `0.22`, add a slow pulse (`sin(Time*3)` on opacity).
  - Alert → `ReadAlert` (red), opacity `0.30`, fast pulse (`sin(Time*8)`).
- **Detection fill:** a radial gradient from the apex; a `Scalar` param `DetectFill` (0–1, = the server's per-AI detection value) drives a hard edge sweeping the cone red→ this is the "filling up" tell. Two-color read (in-cone-safe vs seen) borrows Invisible Inc. (Docs/07 §4).

**(b) Noise ripple `NS_NoiseRing` (Niagara) — the loudness made visible.**
- When `LoudnessComponent` fires a `ReportNoiseEvent` (Tech doc §3), also spawn a **ground ripple**: expanding flat ring, radius = the event's hearing radius (so the ripple = the actual radius the AI can hear at — art = truth again).
- Niagara system `Content/_Project/UI/FX/NS_NoiseRing`: single burst, a ring sprite/ribbon expanding `0 → HearingRadius` over `0.6 s`, color `lerp(ReadWarn, ReadAlert, Loudness/100)`, opacity fading `0.6 → 0`. Louder action = bigger, redder ring. Mirrors Mark of the Ninja's sound-radius circle (Docs/07 §4).
- Cheap diegetic cousin (**[TARGET]**, cheap enough to try in Phase 1): wet footprints — a decal trail from the pool that fades over ~8 s, so a splashing player literally leaves a readable "loud + traceable" path the AI can investigate (Thief's traces, Docs/04 §C3).

**(c) Alert icons `WBP_AlertIcon` (`?`/`!` overhead widget).**
- A `WidgetComponent` (Screen space, `DrawSize 96×96`) on each AI head. Shows: nothing (Unaware), `?` in `ReadWarn` amber (Suspicious), `!` in `ReadAlert` red (Alert). Simple, chunky, high-contrast glyph on a soft dark rounded pill for legibility against any background. Pop-scale animation on state change (0→1.2→1.0 over 0.2 s) for punch. Matches GDD §5.3 iconography.

**(d) Loudness + score HUD `WBP_HUD` (the non-diegetic fallback, per Docs/07 §5 "Minimal HUD Paradox").**
- Bottom-center **loudness bar**: horizontal segmented bar (5 segments, à la Splinter Cell → collapsed to 3-color reads), fill = replicated Loudness 0–100, color `lerp(ReadSafe→ReadWarn→ReadAlert)` at thresholds 0/50/80. Segments (not a smooth gradient) = faster read (Docs/07 §4).
- Top-right **score**: `Banked` in solid white; `At-Risk` in pulsing `ReadWarn` amber below it (so "you could lose this" is felt). On bank, amber flies up into white with a `ReadSafe` green flash (Scoring system §5.1 GDD).
- Top-center (later) the **diegetic wristwatch** (GDD §7) — park for Phase 5; a plain digital timer text is fine for the sandbox.
- **Team alert badge** (**[TARGET / Phase 2 co-op]**): a shared minimap/corner badge of neighborhood heat visible to the whole crew — Docs/07 §4 flags shared-detection UI as an under-served space Pool Hop can lead. Not built solo; spec'd so it's designed-in.

> **Readability acceptance test (Phase 1):** in a dark PIE screenshot, a first-time viewer can, at a glance, name (1) which AI can see where [cone], (2) how loud the last action was [ring + bar], (3) each AI's alert state [color + icon], and (4) whether their points are safe [green] or at risk [amber]. If any of the four isn't instant, the readability layer — not the world art — is what to fix.

---

## 3. [TARGET / Phase 6] The Toon Master Material `M_ToonMaster` (Substrate)

The real cartoon look. UE 5.8 ships the **Toon Shader (Experimental)** on the **Substrate** framework (Docs/04 §A). This replaces §2.2's fake-toon grey-box material for shipping art. **Flag: Experimental** — expect API churn; keep §2.2 as the always-works fallback.

**Prereqs (Project Settings):** enable **Substrate** (`r.Substrate=1`, Rendering settings — this is a project-wide, restart-required switch; do it once at the start of look-dev, not during Phase 1 tuning, so it can't perturb the movement sandbox). Toon shading models become available on Substrate.

Path: `Content/_Project/Art/Materials/M_ToonMaster`. Build a **master** with a fat parameter set; ship everything as MIs.

**Structure (Substrate Toon):**
- Use a **Substrate Slab** with the **Toon** diffuse model (cel/step ramp) rather than default GGX. Feed it via a **`SubstrateSlabBSDF`** node with a **toon step function** on the diffuse term.
- **Cel ramp:** expose a `CurveAtlas`/1D ramp texture param `ToonRamp` (a `Texture2D` gradient, e.g. 3-band dark→mid→light) sampled by N·L — swapping the ramp restyles the whole game (dawn vs deep-night ramps). Param `RampSharpness` (Scalar) blends between hard cel and soft.
- **Outline:** two options, expose both, default to (a):
  - (a) **Post-process outline** (`M_ToonOutline_PP`, `MD_PostProcess`, blendable) — edge-detect on SceneDepth + WorldNormal (Sobel), draw `OutlineColor` (default near-black `#0A0E1C`, i.e. `NightSky`×0.6) at `OutlineThickness` (Scalar, ~1.5 px), thickness scaled by depth so far objects don't over-ink. One PP outline covers the whole scene cheaply and reads as clean ink.
  - (b) **Inverted-hull** per-mesh (back-faces, `bReverseCulling`, pushed along normal by `OutlineWidth`) — sharper on hero props (player, threats), heavier. Use only on characters.
- **Specular:** toon-style **stepped highlight** (a hard `smoothstep` blob) rather than physical spec — sells the cartoon read on wet/plastic surfaces.
- **Exposed master params (drive all MIs):** `BaseColor`(Vec), `ToonRamp`(Tex), `RampSharpness`(Scalar 0–1), `ShadowTint`(Vec, default `NightAmbient`), `SpecStep`(Scalar), `SpecColor`(Vec), `EmissiveColor`(Vec)+`EmissiveStrength`(Scalar), `NormalMap`(Tex, optional — toon often skips normals for cleanliness), `Metallic`/`Roughness` (mostly unused, keep for wet surfaces).

**MIs to author from it (naming per convention `MI_`):**
| MI | Purpose | Key overrides |
|---|---|---|
| `MI_Toon_HouseWall` | Synty/Kenney house siding | Base per-house palette, `RampSharpness 0.7` |
| `MI_Toon_Roof` | roofs | darker base, matte |
| `MI_Toon_Foliage_Hedge` | hedges/bushes (cover) | `NightBlueKey` base, subtle SSS-fake via ShadowTint lift; **must read as "cover you can hide in"** |
| `MI_Toon_Grass_Lawn` | lawns | `NightAmbient` base |
| `MI_Toon_Concrete_Path` | driveways/paths | mid-grey, slightly warmer under lamps |
| `MI_Toon_Fence_Wood` | fences (vaultable) | plank base; **silhouette clarity is gameplay** — fences read as climbable |
| `MI_Toon_Char_Skin` / `MI_Toon_Char_Cloth` | player + NPC | brighter ramp so characters pop from the dark world |
| `MI_Toon_Plastic_Patio` | loungers/floaties | glossy stepped spec (the flamingo ring lives here) |

---

## 4. [TARGET / Phase 4+] Water — the Reward, the Brand (`M_ToonWater`)

Water is Pillar 3 and the brand (GDD §10: *"Water deserves special love"*). It must look joyful/splashy **and** read as the glowing reward from across a yard. Tech doc §8: *"stylized/cheap water, not the heaviest simulation."* So: **a custom stylized translucent material, NOT the UE Water plugin's heavy Single-Layer-Water sim.** (The Phase-1 grey-box pool already uses the translucent-unlit `M_WaterPlaceholder` / `MI_Greybox_Pool` from §2.2 — this is its shipping replacement.)

Path: `Content/_Project/Gameplay/Materials/M_ToonWater`. A **translucent** material on a flat plane sitting just below the pool-volume top (the `PhysicsVolume` `bWaterVolume=true` from LESSONS is the *gameplay* water; this plane is the *visual* surface).

**Material setup** (`MaterialTools` recipe from LESSONS — translucent):
- `BlendMode = BLEND_Translucent`, `ShadingModel = MSM_DefaultLit` (want it to catch the moon + lamp glints) **or** the Substrate toon slab if §3 is live; `TwoSided=false`, `bUseTranslucencyDepthPass` for sorting.
- **Color & depth fake:** `lerp(ShallowColor, DeepColor, fakeDepth)` where `ShallowColor` = `PoolTurquoise`×1.3 (bright, inviting), `DeepColor` = `LinearColor(0.02,0.18,0.28)`. `fakeDepth` from **`SceneDepth` − `PixelDepth`** (`DepthFade` node) so edges are lighter (shore) and center darker — classic stylized water depth with zero sim.
- **Emissive glow (the "reward beacon"):** add `EmissiveColor = PoolTurquoise × PoolGlow(Scalar, default 0.5)`. A lit pool must be visible/enticing from across the map at night — this is gameplay signposting via art. **[Perf]** the emissive plane + a single small point light *inside* the pool (MegaLights, §4.3) is what makes water the brightest cool pool of light in the scene.
- **Toon surface motion (no sim):**
  - Two panning normal maps (or a panning `Voronoi`/`Noise`) at different speeds/scales → distort a **stepped** specular highlight so the moon glints in cartoon dashes, not a photoreal streak.
  - **Toon foam/caustic band:** where `DepthFade` is small (shorelines, around a swimmer), draw a hard white `FloodWhite`×0.8 band via `smoothstep` on depth + a panning noise mask → animated foam ring. This is the "splashy" read.
- **Opacity:** ~`0.75`, with the foam band forced toward opaque so edges read crisp.
- **Refraction:** keep **very low** (`Refraction` ~1.02) or off — heavy refraction fights toon clarity and costs perf without HWRT. Prefer the flat stylized look.

**Splash & ripple VFX (Niagara, `Content/_Project/Gameplay/FX/`):**
- `NS_PoolSplash` — on dive/enter: a burst of chunky white droplet sprites + an expanding **flat ring decal** on the surface. This *also* is the moment `LoudnessComponent` spikes → tie the splash VFX size to the loudness value so **big splash = big noise ring (§2.4b) = real danger.** Art and mechanic are the same beat.
- `NS_SwimTrail` — gentle wake ribbon behind a swimmer, `PoolTurquoise` foam.
- **Underwater** (GDD §5.5 hide/breath-hold): a cheap fullscreen PP blend when the camera enters the water volume — cool `DeepColor` tint, gentle caustic overlay, vignette up, muffled audio. Drive from the `bWaterVolume` overlap the movement system already has.

### 4.4 No-HWRT reflection plan (important — `r.RayTracing=False`)
Pools *want* reflections but we have **no hardware ray tracing** (LESSONS). Layered fallback, cheapest first:
1. **Lumen software reflections** (on by default with Lumen) — good enough for the diffuse night bounce.
2. **Screen-Space Reflections** on the water material for the bright stuff (lamp/window/moon streaks) — free-ish, screen-limited artifacts are hidden by the dark + toon style.
3. **A single `SphereReflectionCapture` or `PlanarReflection`** per pool **only if** a hero "money pool" needs a crisp mirror (PlanarReflection is the pricey one — budget one, not many). MegaLights + emissive already do most of the visual work; don't reach for planar reflections by default.
4. **Never** re-enable `r.RayTracing` to solve a reflection — it re-triggers the SBT deadlock (LESSONS). This is a hard line.

---

## 5. Sky / HDRI Plan — Satara Night is staged

The night sky is authored, not procedural, because **`PolyHaven/satara_night_4k.exr` (CC0) is already staged** (`ASSET_CREDITS.md`) — starfield with warm distant village lamps on the horizon, which matches our palette perfectly.

**Import & setup:**
1. Import `_ThirdPartyStaging/PolyHaven/satara_night_4k.exr` → `Content/ThirdParty/PolyHaven/HDRI/HDR_SataraNight` (keep third-party under `Content/ThirdParty/` per conventions; do NOT drop raw EXR into `Content/` — UE must generate the `.uasset` on import, LESSONS/ASSET_CREDITS note). Compression: `HDR`, `sRGB off`, `Mip 0` full res.
2. **Sky rendering:** a `SkyAtmosphere` is wrong for a fixed-HDRI night — instead use a **`StaticMeshActor` sky sphere** (engine `SM_SkySphere` or a large inverted sphere) with an **unlit emissive material** `M_NightSky` sampling `HDR_SataraNight` as a **LongLatLatitude** cubemap, `Emissive` × `SkyBrightness`(Scalar, ~0.8). OR the simpler **`SkyLight` + `SkyAtmosphere`-off** route: set the `SkyLight` `SourceType=SLS_SpecifiedCubemap` to a cubemap baked from the EXR (`TextureCube`), which both *lights* the scene (ambient cool fill, §2.3) and can be shown via a `HDRIBackdrop` actor.
3. **Recommended concrete path (cheapest, deterministic):**
   - Convert EXR → `TextureCube` (`HDRI_SataraNight_Cube`) via the HDRIBackdrop tooling or an import-time cubemap.
   - **`HDRIBackdrop` actor** in the level referencing the cube → gives you the visible starry dome + horizon lamps *and* a ground projection, sized to the neighborhood.
   - **`SkyLight`** (`SLS_SpecifiedCubemap` = same cube, `Intensity 0.6`, Real-Time Capture OFF) for ambient.
   - The `DirectionalLight` moon (§2.3) is the only shadow-caster.
4. **Rotate** the dome so the warm horizon-lamp glow sits *behind* the neighborhood's "town" edge — free establishing warmth on the horizon (art doubling as orientation cue: "town is that way").
5. **Stars:** the HDRI has them; add a faint `M_NightSky` twinkle (panning noise on emissive) only in look-dev, optional.

**Per-neighborhood sky variants (Phase 4+):** same cube, different `DirectionalLight` angle/intensity + PP grade = "early night" (higher moon, `-0.5` exposure) vs "near dawn" (low warm moon, exposure `-1.5`, warmer highlight gain) — drives GDD §7's clock-based escalation *visually*. Store presets in `Data/DA_NightPhase` (dawn/dusk grade + light params).

---

## 6. Lighting-as-Level-Design — MegaLights playbook

GDD §10 / Tech doc §8: *lighting IS the level design*, and **MegaLights (production-ready in 5.8)** is exactly for "many small dynamic shadowed lights at 60 fps" — our streetlamps/windows/floods. This is where the world's danger map is authored in light.

**Enable MegaLights:** Project Settings → Rendering → `r.MegaLights.Enabled=1` (or per-PostProcessVolume where supported). It lets us place *dozens* of shadow-casting local lights without the classic stealth-game light perf collapse (Tech doc §8 flags lights as the perf sink). Still **profile** — lights are the watch-item.

**The light vocabulary (each light type = a gameplay meaning):**
| Light | Class / config | Color | Gameplay meaning | Build note |
|---|---|---|---|---|
| **Streetlamp** | `SpotLight`, cone ~70°, `AttenuationRadius` 900, `Intensity` ~5000 lm | `LampWarm` | **Danger pool** — stepping into it spikes your visibility. | On a `BP_Streetlamp` with the lamp mesh; the pool of light on the ground *is* the hazard the player routes around. |
| **Window (lit room)** | `RectLight` behind window plane, `Intensity` ~1500 lm | `WindowGlow` (warm) or `TVGlow` (cool flicker) | Occupied house = watcher risk (GDD §5.4). TV-flicker = homeowner awake. | Flicker via a tiny `Timeline` on intensity for TV rooms. |
| **Porch light** | small `PointLight`, radius 400 | `LampWarm` | Marks doorways = homeowner exit points. | — |
| **Motion-sensor flood** | `SpotLight`, off by default, snaps ON via trigger | `FloodWhite` (harsh) | **The alarm.** On-trip: floods the area, spikes local visibility, pushes AI → Suspicious (Tech doc §4). | `BP_SensorLight`: trigger volume → light on + `ReportNoiseEvent` + PP flash. The *white* (vs warm world) makes it read instantly as "wrong / danger." |
| **Pool glow** | small `PointLight` inside water, radius 300 | `PoolTurquoise` | The **reward beacon** — draws the eye/player toward water. | Pairs with the emissive water plane (§4). The one *safe-ish inviting* cool light. |
| **Cop flashlight** (Phase 5) | `SpotLight` on the cop, narrow | `FloodWhite` | The escalation boss's sweeping beam. | Attached to cop mesh; a moving danger cone. |

**Design principle to hand level designers:** *route the player through darkness between warm danger-pools, toward cool reward-pools, past white alarm-floods.* Shadow = the safe path; the negative space between lights is the level. A neighborhood's difficulty is tuned largely by **light density and overlap**, not geometry — "The Heights" (GDD §8, hard) has tight overlapping floods + cameras; "Maple Court" (starter) has sparse warm lamps with big dark gaps.

---

## 7. Home-Base Contrast (Phase 5) — warm CRT nostalgia

GDD §10: the intro living room is the **deliberate tonal opposite** of the cold tense night. Spec'd here so the contrast is intentional, not accidental.
- Palette: warm tungsten (`LampWarm`+`WindowGlow`), high ambient, cozy. Exposure *up* vs the night's exposure *down*.
- A **CRT TV** as the key light — `RectLight` with an animated flicker + a CRT-scanline emissive material (`M_CRT`: scanlines via `frac(UV.y*240)`, chromatic offset, gentle bloom) showing the couch-co-op game (nod to Timesplitters/CoD4).
- Kenney furniture-kit props (already staged!) dress this scene: `chair*`, `bench*`, `lamp*`, `cabinetTelevision*`, `bookcase*`, `desk*`, `computerScreen` → the retro living room is literally buildable from `_ThirdPartyStaging/Kenney/kenney_furniture-kit/`.
- Post: warm grade (highlight gain `1.1, 1.0, 0.85`), grain up slightly (VHS feel), vignette soft. Walking *out the door* into the cold blue night is the emotional cut — light temperature and exposure both flip.

---

## 8. Asset Plan — mapped to what's staged

Per Docs/04 §B licensing. **Grey-box now (§2) uses only CC0 staged assets; paid Synty is Phase 4+ and must be asked-for before purchase** (ASSET_CREDITS.md).

| Need | Use NOW (staged, CC0) | Phase 4+ target | Status / action |
|---|---|---|---|
| **Cover / hedges / bushes** | `Kenney/kenney_nature-kit` (`grass_large`, `flower_*`, `plant_*`, `tree_*`) | Synty POLYGON Town hedges | ✅ staged → import to `Content/ThirdParty/Kenney/Nature/` |
| **Fences (vaultable)** | `nature-kit` `fence_simple*`, `fence_planks*`, `fence_gate` | Synty Town fences | ✅ staged |
| **Patio furniture / cover / floaties** | `Kenney/kenney_furniture-kit` (`loungeChair*`, `bench*`, `lamp*`, `chair*`) | Synty props + custom flamingo ring | ✅ staged (140 FBX) |
| **Rocks / terrain detail** | `nature-kit` `cliff_*`, `rock*` | Synty | ✅ staged |
| **Houses / driveways / suburban shells** | ⚠️ **Kenney City-Kit-Suburban NOT on disk** (listed in credits, missing) | Synty POLYGON **Town Pack** (~$149–200) | ⛔ **Action: download Kenney suburban kit** for grey-box houses before Phase 4; buy Synty only when asked. |
| **Streetlamps / street furniture** | grey-box `BP_Streetlamp` + furniture-kit `lamp*` as stand-in | Synty POLYGON **City Pack** | Grey-box now. |
| **Night sky** | `PolyHaven/satara_night_4k.exr` (CC0) | same (keep) | ✅ staged → §5 import. |
| **Player + NPC characters** | UE5 **Mannequin** (already in project, `Content/Characters/Mannequins`) | **Synty Sidekick** (modular = costume system, GDD §5.6) | Sidekick **free Starter** needs Fab "Add to Library" (you're logged in) — ASSET_CREDITS §"Still needed". Mannequin is fine for the whole sandbox. |
| **Animation** | Mannequin's stock anims | **Mixamo** walk/run/crouch/swim (free) | Needs Adobe login — grab yourself. |
| **Audio (splash/step/vault)** | `Kenney/kenney_impact-sounds` (130 OGG, `footstep_*`, impacts) | Freesound CC0 / Pixabay pass | ✅ staged. |
| **Toon look / outlines** | fake-toon `M_GreyboxToon` (§2.2) | **Substrate Toon Shader** `M_ToonMaster` (§3) | Engine feature (Experimental). |
| **Water** | `M_WaterPlaceholder` / `MI_Greybox_Pool` (translucent-unlit, exists) | `M_ToonWater` (§4) | ✅ placeholder exists. |

**Import discipline (LESSONS + conventions):** third-party imports go to `Content/ThirdParty/{Kenney,PolyHaven}/…`; our derived materials/BPs to `Content/_Project/…`. After any MCP asset batch: `save_assets([])` then `find Content -name "*.uasset" -size 0` before committing (the 0-byte corruption lesson). Keep `_ThirdPartyStaging/ASSET_CREDITS.md` updated on every new asset.

---

## 9. Folder / Naming Additions (extends ARCHITECTURE.md §1)

New art homes under `Content/_Project/` (create as needed, don't pre-make empty):
```
_Project/
  Art/Materials/        M_ToonMaster, M_ToonOutline_PP, ramps, DA_ArtPalette
  Gameplay/Materials/   M_GreyboxToon, M_ToonWater, M_WaterPlaceholder(exists)
  Gameplay/FX/          NS_PoolSplash, NS_SwimTrail, underwater PP
  AI/Materials/         M_VisionCone
  UI/FX/                NS_NoiseRing
  UI/                   WBP_HUD, WBP_AlertIcon
  Data/                 DA_ArtPalette, DA_NightPhase
Content/ThirdParty/
  Kenney/{Nature,Furniture,ImpactSounds}/
  PolyHaven/HDRI/       HDR_SataraNight, HDRI_SataraNight_Cube
```
Naming (per CLAUDE.md): `M_`/`MI_` materials, `NS_` Niagara, `WBP_` widgets, `DA_` data assets, `BP_` blueprints, `L_` maps, `HDR_`/`HDRI_` sky. Readability-layer colors ALWAYS come from `DA_ArtPalette` — never hardcode a green/amber/red in a widget or material.

---

## 10. Priority Order (what to actually do, and when)

1. **NOW (with System 2–4 build):** §2 in full — `DA_ArtPalette`, `M_GreyboxToon` + 4 MIs, the night PP + moon + skylight rig, and the readability layer (`M_VisionCone`, `NS_NoiseRing`, `WBP_AlertIcon`, `WBP_HUD`). Nothing here blocks the movement/loudness/scoring work; it makes tuning legible. Pass the §2.4 readability acceptance test.
2. **Phase 4 (first real neighborhood):** import Satara sky (§5), stand up MegaLights vocabulary (§6), download the missing Kenney suburban kit, replace grey boxes.
3. **Phase 6 (look-dev):** enable Substrate, build `M_ToonMaster` (§3) + `M_ToonWater` (§4), outline pass, home-base scene (§7), per-neighborhood sky grades. This is the "make it pretty" phase — earned only after the loop is proven and co-op ships.

> **The one thing not to get wrong:** keep the readability layer (green/amber/red, cones, rings, icons) a **flat, on-top, replicated-state-driven** language that is *never* confused with the warm/cool world lighting. Pretty is Phase 6; **readable is every phase**, starting now.
