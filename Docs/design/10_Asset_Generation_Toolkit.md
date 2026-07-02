# Pool Hop — Free/Cheap Asset-Generation Toolkit (Design-Mode Research)

*Research pass — 2026-07-01. Produced as the fallback deliverable when an autonomous build session hit a hard blocker (the `unreal-mcp` connection dropped mid-session, no in-session reconnect possible) and the human was away. Per the human's own framing: "find the best free or cheapest models we can use to style the game with — characters, pools, costumes, HUD, menus."*

> **What this doc is NOT.** A green light to spend polish hours now. [`01_Art_And_Style_Direction.md`](01_Art_And_Style_Direction.md) is explicit: build grey-box-first, don't chase look-dev before Step 8's playtest proves the loop is fun. This doc exists so that *when* styling work starts (Phase 4+ per the roadmap, or sooner if the human wants a vertical-slice screenshot), there's already a vetted, current (checked 2026-07-01) shortlist instead of a cold search. Read [`01`](01_Art_And_Style_Direction.md) §0 first for what's already staged on disk before generating anything new — don't regenerate what's already sitting in `_ThirdPartyStaging/`.

---

## 0. The one decision that matters most: free CC0 packs before AI generation

For **environment geometry** (houses, fences, patio furniture, pool coping, hedges) — the bulk of what "pools" and "neighborhood" styling needs — **AI 3D generation is not yet the right tool.** Current text/image-to-3D generators (Meshy, Tripo, Rodin/Hyper3D, Sloyd — see §2) are excellent for a handful of *hero* or *one-off* props, but they're slower, costlier, and lower-quality-per-piece than just downloading an existing CC0 low-poly kit built for exactly this genre. `01_Art_And_Style_Direction.md` §0 already confirms this project is on that path:

| Already staged (verified on disk) | Not yet staged — grab before AI-generating equivalents |
|---|---|
| `Kenney/kenney_furniture-kit` (140 FBX — patio chairs, tables, lamps, loungers) | **Kenney City-Kit-Suburban** — houses, garages, driveways; listed in `ASSET_CREDITS.md` but missing from disk. **Do this first**, it's free, CC0, and purpose-built for this exact suburban-night aesthetic. |
| `Kenney/kenney_nature-kit` (330 FBX — hedges, trees, fences, rocks) | **Kenney Suburban Houses Pack** (via [poly.pizza](https://poly.pizza/bundle/Suburban-Houses-Pack-dZQwy8vcDv)) — same family, worth a side-by-side check against City-Kit-Suburban to see which fits the vision-cone/cover-object needs better. |
| `Kenney/kenney_impact-sounds` (130 OGG) | **Quaternius** ([quaternius.com](https://quaternius.com/)) — thousands of CC0 low-poly models across genres, often rigged/animated; good fallback if Kenney's suburban kit is missing a specific prop (pool ladder, diving board, lawn ornament). |
| `PolyHaven/satara_night_4k.exr` (staged night HDRI) | **Synty POLYGON Town / City** — paid (~$30–60/pack on the Unreal marketplace or Synty's own store), but it's the closest *toon-low-poly* match to this project's exact "flat shapes, soft ink edge" target if the free kits don't read stylized enough. Budget it for Phase 4 if the grey-box loop proves fun. |

**Rule of thumb going forward:** search Kenney → poly.pizza → Quaternius → OpenGameArt (all CC0, zero cost, zero generation time) *before* reaching for an AI generator on any prop that's "a normal suburban thing" (a house, a fence, a lawn chair, a pool ladder). Reach for AI generation only for (a) something bespoke that doesn't exist as a free asset — a stylized pool-float, a specific costume silhouette — or (b) *textures/materials*, where AI generation is now genuinely faster than sourcing (§4).

---

## 1. Quick-decision table

| Need | First choice (free-first) | If you need AI generation | Notes |
|---|---|---|---|
| Suburban houses, fences, patio props | Kenney City-Kit-Suburban / Suburban Houses Pack (CC0) | Sloyd (parametric, low-poly presets) | Free packs first — see §0 |
| Hero/one-off 3D prop (unique pool float, mailbox, lawn gnome) | **Poly Pizza "Gnome" by Polygonal Mind — free CC0** (§7.1) | **Sloyd** or **Meshy** (§2) | Confirmed free hit for the specific loot-Trophy gnome — see §7 before generating one from scratch. Sloyd/Meshy still the fallback for anything else in this category. |
| Wetsuit / ghillie / tracksuit / sneakers costume pieces | Synty Sidekick Modern Civilians ($199.99, partial fit only) | **Sloyd/Meshy** for wetsuit + ghillie specifically | No free/cheap stock pack confirmed to cover wetsuit or ghillie — see §7.2, don't spend more search time on this category before generating. |
| Inflatable pool flamingo / floatie accessory | CGTrader free listing (license unconfirmed — verify before use, §7.3) | **Sloyd/Meshy** or hand-model (simple torus shape) | No CC0 hit found; this is simple enough that modeling/generating may beat chasing an uncertain license. |
| Jewelry/gadget-style small trinket props (future loot roster) | Quaternius "Fantasy Props MegaKit" (CC0, itch.io) — general seed only, not jewelry-specific | Sloyd/Meshy per-item | Recurring gap, not a one-time miss — see §7.4. |
| Player/Watcher/cop character base mesh | Existing Mannequin + Mixamo animations (already the project's pipeline) | Meshy / Tripo / Rodin for a stylized custom base mesh, if the mannequin proxy needs replacing | Don't touch this until `ABP_Unarmed`/animation pipeline is validated — see CLAUDE.md's mannequin-repair history |
| Costume concept art / character sheets | — | **Leonardo AI** (free tier, character-reference) | 2D concept first, then decide if a costume needs an actual 3D mesh swap or is just a material/texture swap (cheaper, matches the Step 6 spec's `LoudnessModifierMult`-only design — see §3) |
| Pool water / tile / stucco / grass PBR materials | PolyHaven (free, CC0, already the HDRI source) | **AITextured**, **GenPBR**, **3DTexel**, **MateriAI** (§4) | All have genuinely free tiers, engine-ready exports (Unreal-tagged) |
| Style-consistent asset SET (many props/icons in one visual language) | — | **Scenario** (§4) | Best when you have ~20+ reference images of *this game's* look to train a custom model on — not a cold-start tool |
| HUD mockups / layout ideas | — | **Recraft** (icons, free), **Uizard** / **ZSky AI** (HUD mockups) | Mockups only — the actual `WBP_*` widget trees still need human UMG authoring per this project's confirmed MCP ceiling (CANON "Known MCP buildability gaps") |
| Menu screens, title art | — | **Leonardo AI** / **Recraft** | Low priority — Step 7/8 territory, well past the current build phase |

---

## 2. 3D model / character generation

All three below were re-checked 2026-07-01; pricing/free-tier details change often — verify before committing budget.

- **[Meshy](https://www.meshy.ai/)** — text/image-to-3D, textured meshes in under a minute. **Free tier: 100 credits/month, 10 downloads of Meshy-4 models** — enough to prototype several props without paying. Good for organic/character-adjacent shapes; topology is usable but not always game-clean.
- **[Tripo](https://www.tripo3d.ai/)** (via 3D AI Studio or standalone) — fast generation, clean meshes, **auto-rigging built in**. Paid starts ~$12/mo but has a free trial tier. Best pick if a character needs a rig fast and Mixamo's retarget isn't a fit.
- **[Rodin / Hyper3D.ai](https://hyper3d.ai/)** — widely reviewed as the current quality leader for *production-usable* topology (clean quads) among the free-to-generate tools. Worth the first prototype pass on any hero prop before paying for anything else.
- **[Sloyd](https://www.sloyd.ai/)** — **the best fit for this project's low-poly, game-ready needs specifically.** Parametric (slider-based) generation with an explicit low-poly/stylized preset, exports GLB/OBJ, drag-and-drop into UE5. Free Starter plan exists (preview-only text-to-3D/image-to-3D + template editor); Plus is $11–15/mo. Use this over Meshy/Tripo for anything that should read as *hard-surface* and match the "flat toon shapes" target rather than organic-AI-blob topology.

**Recommendation for this project:** start with **Sloyd's free tier** for any one-off hard-surface prop (pool ladder, diving board variant, distinctive mailbox), fall back to **Meshy's free credits** for anything organic, and don't touch Tripo/Rodin paid tiers until a specific asset genuinely needs their strengths (auto-rig, production topology) — the free CC0 packs in §0 should cover 80%+ of prop needs at zero cost either way.

---

## 3. Costume / character styling

The Step 6 spec (`08_Implementation_Roadmap.md` — costume system) is **stat-first, cosmetic-second**: `DA_Costume` carries `LoudnessModifierMult`/`SwimSpeedMult` as the actual gameplay effect, with `MeshOverride`/`AttachMesh` as a purely visual layer. This means costume *styling* can be as cheap as a texture/material swap or an attached accessory mesh — it does **not** require a full new character model per costume.

- **[Leonardo AI](https://leonardo.ai/)** — generous free tier (**150 tokens/day, resets daily**), with character-reference (`cref`) mode specifically built for "same character, different costume/expression" sheets. This is the right tool for *concept art* to hand a costume idea to whoever builds the actual mesh/material swap (human-in-editor or a follow-up 3D-gen pass). Paid tier ($12/mo Artisan) only needed for private generations or high volume.
- For an actual in-engine costume swap: prefer a **material/texture change or a small attached mesh** (a hat, quiet-shoes overlay) over a full replacement skeletal mesh — cheaper to build, cheaper to skin, and matches the `DA_Costume.AttachMesh`/`AttachSocket` design already spec'd.

---

## 4. Textures, materials, and style-consistent asset sets

This is where AI generation is **unambiguously worth it right now** — PBR texture/material generation is fast, free-tier-friendly, and produces genuinely engine-ready output.

- **[AITextured](https://aitextured.com/)** — 20,000+ free existing seamless textures plus AI text-to-texture; exports full PBR sets (base color/normal/roughness/height) ready for Unreal.
- **[GenPBR](https://genpbr.com/)** — no-signup-required free PBR generation, up to 1024×1024 fully free (8K on paid tiers). Lowest-friction option to just try something right now.
- **[3DTexel](https://3dtexel.com/)** — text-prompt-to-full-PBR-set (base color/normal/roughness/height) at 4K/8K, tileable, Unreal-ready.
- **[MateriAI](https://matgenai.com/)** — dedicated free Unreal plugin for one-click PBR material import with automatic parameter mapping — worth checking first specifically *because* of the plugin (skips manual texture-map wiring in the Material Editor).
- **[Scenario](https://www.scenario.com/)** — different category: **style-consistent set generation**, not a cold-start single-texture tool. You train a small custom model on ~20+ reference images of *this game's specific look* (once `M_GreyboxToon`/the toon palette produces enough reference renders), then generate new props/icons/textures that automatically match. Free tier: 50 credits, no card required; paid starts ~$15–20/mo. **Revisit this once Phase 4 environment art exists to train on** — it's the wrong tool for a cold start with no reference images yet.

**Recommendation:** for the pool's water/tile materials specifically, try **GenPBR** or **MateriAI** first (free, fastest), since PolyHaven (already the HDRI source) is also worth checking for a ready-made tileable pool-tile/water-caustic texture before generating one from scratch.

---

## 5. HUD, icons, and menus

Per CANON's confirmed MCP-buildability gaps, **UMG widget-tree authoring is not something this build loop can do via MCP** — the actual `WBP_HUD`/`WBP_LoudnessMeter`/etc. widget trees need the human in-editor regardless of what art feeds into them (per `08_Implementation_Roadmap.md` Step 7 and the in-editor checklist in `START_HERE.md`). AI tools below help with the *art and mockup* layer, not the functional widget graph.

- **[Recraft](https://www.recraft.ai/)** — free online generator with a dedicated icon mode; good for `?`/`!` alert bubbles, HUD button icons, in a consistent flat/vector style that matches the "readability layer" doctrine in `01_Art_And_Style_Direction.md` §2.1 (flat, saturated, unlit-on-top).
- **[Uizard](https://uizard.io/)** — general UI-mockup-from-text/sketch tool; useful for laying out where HUD elements sit before the human builds the real `WBP_HUD` tree.
- **[ZSky AI](https://zsky.ai/ai-game-ui-generator)** — game-specific HUD/menu generator with explicit style options (pixel/hand-drawn/vector/stylized) — closer-fit mockups than a generic UI tool for a stylized game HUD specifically.
- **[Ludo.ai](https://ludo.ai/)** — broader "every asset your game needs" generator (sprites, icons, UI, textures) if a single subscription covering multiple categories is preferred over separate point tools.

**Recommendation:** use Recraft (free) for the `?`/`!` icon set and loudness-meter iconography specifically — it's the cheapest, fastest match for the project's flat-readability-layer requirement — and treat the others as optional mockup aids for the human before they build the real widget trees in Step 7.

---

## 6. Suggested order of operations (when styling work actually starts)

1. **Grab the missing free CC0 packs first** (§0) — Kenney City-Kit-Suburban, cross-check against the Suburban Houses Pack, fill any prop gaps from Quaternius. Zero cost, zero generation wait, purpose-built for this genre.
2. **Generate PBR materials for pool water/tile/stucco** via GenPBR or MateriAI (§4) — cheapest win, directly improves the grey-box's readability-layer contrast (per `01`'s "warm light pools vs cool world" doctrine) without touching geometry.
3. **Concept the first costume** in Leonardo AI's free tier (§3) once Step 6 is scheduled — hand the sheet to whoever builds the actual attach-mesh/material swap.
4. **One-off hero props** (a distinctive pool float, a specific fence style not in the free kits) via Sloyd's free tier (§2) — only once the free-pack sweep in step 1 has confirmed a genuine gap.
5. **Only after Phase 4 environment art exists**, consider training a Scenario custom model (§4) for style-consistent bulk generation of remaining smaller props/icons.
6. **HUD/menu art** (§5) is last — it's Step 7/8 scope, well after the current Step 5 build phase, and gated on the human authoring the actual widget trees regardless of what art feeds them.

**Do not let this list become a reason to start styling early.** The project's own doctrine (`01_Art_And_Style_Direction.md` §0, `CLAUDE.md`'s Phase 1 discipline) is explicit: prove the loop is fun on grey-box first. This toolkit is here so that *when* the human decides it's time, the research is already done.

---

## 7. Loot & Costume item sourcing (follow-up pass, 2026-07-01, for `design/11_Loot_And_Extraction.md`)

Targeted research for the specific items the loot system (`11_Loot_And_Extraction.md`) and the existing costume roster (`05_Characters.md` §4.1) need — a narrower, item-by-item pass rather than the general survey in §0–§6 above. Same rules apply: CC0 preferred, CC-BY okay if attributed, **CC-BY-NC unusable**, verify any live listing before spending budget (prices/availability shift).

### 7.1 The Trophy — garden gnome
- **Primary pick: [Poly Pizza — "Gnome" by Polygonal Mind](https://poly.pizza/m/Yy3yuQ4l6r).** Free, **CC0/Public Domain**, FBX/GLTF, explicitly tagged Unity/Unreal/Godot-ready, low-poly stylized — a genuine match for the toon look and zero licensing overhead. Use this first.
- **Fallback if it needs a "hero" polish pass:** Fab lists a paid **"Garden Gnome"** (stylized PBR, ~3,893 quads, 4K textures) — commercial-safe under the standard Fab license, but the live price couldn't be confirmed (Fab blocks unauthenticated fetches) — check the listing directly before budgeting.
- **Skip:** a Sketchfab CC-BY "Garden Gnome" exists but is an ultra-low-detail voxel/Blockbench model (120 tris) — too crude to read as a hero collectible; a Fab "Garden Gnomes Bundle" is horror-themed (Gnome Killer/Rampage) — wrong tone entirely, don't use it.
- **AI-gen fallback not needed here** — the free CC0 hit is good enough to start from; only reach for Sloyd/Meshy if the design wants a distinctive pose/hat-color variant no stock model has.

### 7.2 Costume/loot clothing — wetsuit, ghillie suit, tracksuit, sneakers, plain pants
**This is the weakest-covered category — plan AI-gen time for it, don't keep searching.** Synty's Sidekick system doesn't have a confirmed pack for any of these specifically:
- **Sidekick Starter Pack** (free) is base rig/parts only — no costume-specific pieces.
- **Sidekick Modern Civilians** ($199.99, syntystore.com) is the closest paid candidate — 160+ modular clothing/hair/accessory parts, casual-everyday focus — but Synty doesn't publish an itemized parts list and a customer review flags gaps in formal wear. Treat as **"plausibly covers plain pants/sneakers/tracksuit-adjacent casual wear, does NOT confirm wetsuit or ghillie."** Verify against Synty's parts-list PDF or Discord before buying on the assumption it covers everything.
- **No CC0 hit on Kenney or Quaternius** — neither stocks swappable garment meshes (they skew whole-premade-character, not modular clothing).
- **Recommendation:** buy Sidekick Modern Civilians for the casual-wear layer (pants/sneakers/tracksuit) if/when the wardrobe expands, and **generate the wetsuit and ghillie suit via Sloyd or Meshy specifically** (§2) — both are niche enough that no stylized stock pack targets them, and this project already has that AI-gen pipeline validated for one-off hero pieces.

### 7.3 Flamingo pool floatie (accessory)
- No CC0 hit on Kenney/Quaternius (no beach/pool-themed kit currently stocked by either).
- A free CGTrader listing exists ("Inflatable Flamingo") but **its exact license must be confirmed on the listing page before use** — CGTrader's "free" tier is sometimes editorial-only rather than commercial-cleared, and that wasn't verifiable without an account. A paid CGTrader "Inflatable Flamingo Pool Float — Low-Poly PBR" listing is explicitly game/VR-tagged and a safer bet if buying.
- **Given this is a simple torus/inner-tube shape, hand-modeling it or generating it via Sloyd/Meshy is likely faster and more certain than chasing an unconfirmed free license** — recommend that over the CGTrader free option.

### 7.4 General trinket/small-prop seed packs (future loot roster beyond the 5 named items)
- **[Quaternius "Fantasy Props MegaKit"](https://quaternius.itch.io/fantasy-props-megakit)** — free, **CC0**, 200+ low-poly props (potions, chests, tools, market goods), shared texture sets. Good generalist seed pack, but skews medieval/fantasy — **not** jewelry/gadget-specific.
- No dedicated CC0 "jewelry/trinket" pack was found on Kenney or Quaternius by name.
- **Flag as a recurring gap, not a one-time miss:** every future jewelry/gadget-flavored loot item will likely need its own Sloyd/Meshy generation pass or a one-off CGTrader/Fab search — budget for that per-item rather than expecting a single pack to cover the eventual full roster.

**Bottom line for §7:** the gnome is solved for free right now; clothing (wetsuit/ghillie) and small jewelry-style trinkets are the two categories to route straight to AI generation instead of continuing to search for stock packs that don't appear to exist yet in this style.
