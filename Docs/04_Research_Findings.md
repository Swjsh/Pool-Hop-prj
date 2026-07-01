# Pool Hop — Research Findings

*Compiled June 30, 2026 from three parallel research passes. All claims verified against primary sources (Epic docs/GitHub, official license pages) where possible. Sources listed per section with reliability notes.*

---

## A. Unreal Engine 5.8 + the Claude/MCP Integration

### UE 5.8 — RELEASED
- **Shipped June 17, 2026** (announced at State of Unreal, Unreal Fest Chicago). Download via Epic Games Launcher now.
- Epic has said this is the **last planned major UE5 release**; they're pivoting to **UE6** (Early Access targeted end of 2027). So 5.8 is a stable base to build on for years.
- **Features relevant to us:**
  - **Toon Shader (Experimental)** — a shading model on the Substrate framework for 2D/stylized/cartoon/anime looks, all platforms. Directly relevant to our art direction.
  - **Lumen Lite** — medium-quality GI, ~2x faster than Lumen High, targets 60fps on PS5 / Switch 2. Great for a stylized night game.
  - **MegaLights (Production-Ready)** — many dynamic shadowed lights at 60fps. Perfect for our streetlamps/windows/sensor floods.
  - Mesh Terrain (Experimental), Procedural Vegetation Editor (Experimental), improved PCG, Sandboxes.

### The Unreal ↔ Claude MCP — it's an OFFICIAL Epic product (key finding)
The important correction to any older assumption: as of UE 5.8 this is **first-party**, not just community plugins.
- **Unreal MCP plugin** (engine id `ModelContextProtocol`) ships *inside* UE 5.8 as **Experimental** — embeds an MCP server in the editor, exposing engine functions as MCP tools over local HTTP.
- **Epic's official Claude Code plugin:** `EpicGames/unreal-engine-skills-for-claude-code-plugin` on GitHub (genuine EpicGames org) — a `unreal-mcp` skill + session hook.
- Credible community alternatives exist (`chongdashu/unreal-mcp`, `ChiR24/Unreal_mcp`, `remiphilippe/mcp-unreal`) but the **built-in Epic plugin is the recommended path** for 5.8.

**Setup summary** (full steps in `03_Technical_Architecture.md` §5): enable *Unreal MCP* + *AllToolsets* plugins → `ModelContextProtocol.StartServer` (binds `127.0.0.1:8000/mcp`) → `ModelContextProtocol.GenerateClientConfig ClaudeCode` → run `claude` from project root → verify `/mcp`. Windows needs Git Bash/WSL for the skills-plugin hook.

**Capabilities:** hundreds of tools across 30+ toolsets — spawn/transform/inspect actors; create & edit Blueprint graphs; manage assets/Data Tables; author materials; edit meshes/textures (LODs, Nanite, sockets); animation (Control Rigs, State Trees); Sequencer; Niagara VFX; UMG; gameplay (tags, GAS); run automation tests; and batch calls via `execute_tool_script` (editor Python).

**Limitations:** HTTP/SSE transport only; adding a new tool needs an editor restart; Experimental → "features incomplete/missing," APIs may change.

**Risks (Epic's own warnings) — take seriously:**
- No auth; localhost is not a trust boundary — don't expose the port / don't run on untrusted machines.
- `execute_tool_script` runs **arbitrary Python** in-editor with full disk/project access — every call is privileged.
- **Avoid `--dangerously-skip-permissions`** while the plugin is loaded (removes per-tool approval).
- **Commit/shelve before long sessions; review diffs** — MCP can delete VCS-tracked assets in one call.

### Bonus: in-editor AI Assistant (UE 5.7+)
Press **F1** in the editor for contextual help + C++ snippets. It's *advisory* (doesn't drive the editor), complementary to MCP. Free tier has daily limits; premium needs an Epic AI subscription.

**Sources (A):**
- Unreal MCP official docs — https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor — *Primary/authoritative* (setup, limits, security).
- EpicGames/unreal-engine-skills-for-claude-code-plugin (GitHub README) — https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin — *Primary* (Claude Code plugin, tools, warnings).
- UE 5.8 release announcement — https://www.unrealengine.com/news/unreal-engine-5-8-is-now-available — *Primary* (release, Toon Shader, Lumen Lite, MegaLights, MCP).
- State of Unreal 2026 recap — https://www.unrealengine.com/news/state-of-unreal-2026-top-news-from-the-show — *Primary* (timing, UE6 2027, MCP framing).
- UE 5.7 announcement — https://www.unrealengine.com/news/unreal-engine-5-7-is-now-available — *Primary* (in-editor AI Assistant).
- Epic Developer Assistant — https://dev.epicgames.com/community/assistant/unreal-engine — *Primary*.
- Community MCP alternatives — https://github.com/chongdashu/unreal-mcp , https://github.com/ChiR24/Unreal_mcp — *Community/secondary* (fallbacks).
- 80.lv UE 5.8 coverage — https://80.lv/articles/unreal-engine-5-8-is-out-today-with-big-optimization-improvements-and-mesh-terrain — *Secondary trade press* (cross-check).

*Uncertainty:* UE 5.8 release + official MCP plugin firmly confirmed by multiple primary sources. The specific model behind the in-editor Assistant is from secondary reporting — treat as unconfirmed. Both MCP and Toon Shader are officially **Experimental**.

---

## B. Assets & Licensing (stylized, commercial-safe)

**Bottom line:** base the world on **Synty POLYGON** packs, characters on **Synty Sidekick + Mixamo** animation, **skip MetaHuman** (built for photoreal, fights our style), fill gaps from **Fab free drops + Kenney (CC0)**, and pull audio from **Kenney + Pixabay (no attribution) + CC0-filtered Freesound**.

### Where to get stylized UE5 assets
| Source | What | Price | Commercial license |
|---|---|---|---|
| **Fab** (fab.com) | Epic's unified marketplace (replaced Unreal Marketplace + Quixel Bridge) | Free–$$$ | **Fab Standard License**, two tiers (Personal/Professional) with **identical rights**; Professional required only once you pass **$100k gross revenue** in trailing 12 months. Some assets are CC instead. |
| **Fab free drops** | Rotating "Limited-Time Free" (~3 assets / 2 weeks) | Free | Keep forever once claimed. |
| **Quixel Megascans** | Photoscanned realistic (secondary for us — ground/foliage/detail) | Free on Fab | Free under Standard License, yours once added. |
| **Synty Studios** (syntystore.com) | **Most relevant** — low-poly stylized POLYGON packs | $55–$250/pack; **SyntyPass** ~$30/mo for full library | Perpetual, royalty-free, worldwide, any engine. **5 seats/license.** No NFT/metaverse-tool/**AI-training** use. |
| **Kenney.nl** | CC0 3D/2D/audio kits | Free | **CC0** — no attribution, full commercial. Safest license. |
| **Poly Haven** | CC0 HDRIs (night skydomes!), PBR textures, some models | Free | **CC0**. |
| **Sketchfab** | Huge user library, mixed | Free–paid | **Per-model** CC — CC-BY = commercial w/ attribution; **CC-BY-NC = NOT commercial**. Read each. |
| **itch.io** | Indie packs, cheap | Free–low | **Per-creator, inconsistent**; "no stated license" = not cleared. |
| **Mixamo** (Adobe) | Auto-rig + humanoid mocap animations | Free | Royalty-free commercial; embed in project, don't redistribute standalone. |

### Concrete packs for a suburban-night-stealth game
- **POLYGON Town Pack** (Synty) — core rec: ~125 buildings, 412 props, modular house kit, preset houses, 9 characters. ~$149–200. On Synty Store + Fab.
- **POLYGON City Pack** — street furniture, sidewalks, parked cars, streetlights.
- **POLYGON Shops Pack** — storefronts to vary neighborhood edges.
- **Pools/hot tubs/patio/fences:** spread across Town/City packs; **no dedicated "backyard pool" SKU** — plan to supplement via Fab searches ("stylized pool", "patio props", "suburban fence") + Kenney CC0 furniture.
- **Poly Haven** night HDRIs for the evening sky + ambient light.
- **SyntyPass** (~$30/mo, ~25% off annual) is economical if pulling from several packs.

### Characters + animation (stylized humans)
- **Best fit: Synty characters + Sidekick modular system.** Sidekick packs (Modern Civilians, **Modern Police** = our cop, etc., ~$199; free Sidekick Starter to trial) let you mix heads/bodies/clothing — exactly how **costume/outfit-swapping** is normally done (swap skeletal-mesh parts on a shared rig, or material swaps).
- **Animation:** rig with **Mixamo** (free, commercial-OK, humanoid) — retargets cleanly onto UE5 humanoid skeleton — or Synty ANIMATION packs.
- **MetaHuman:** now commercially usable/exportable, but **built for photoreal** — fights a cartoon style. **Skip for this game;** revisit only for realistic NPCs later.

### Audio (night ambience, splashes, footsteps, stings)
- **Kenney audio** — CC0, no attribution. Best starting point.
- **Freesound.org** — huge (crickets, splashes, footsteps); **mixed licenses** — filter to **CC0** to avoid attribution bookkeeping; **avoid CC-BY-NC** for commercial.
- **Pixabay** — music + 120k+ SFX under Pixabay Content License: free commercial, no attribution. (Extra rules only if you distribute the *music itself* on Spotify/DSPs.)
- **itch.io audio** — cheap/free, check each license.

### Licensing pitfalls (for a first-time dev)
1. **CC-NC = never for commercial** — the most common trap on Sketchfab/Freesound/itch.
2. **CC-BY requires attribution that travels with the asset** — keep a credits screen + attribution log from day one; prefer CC0 when equal.
3. **"No stated license" ≠ free** — silence = all rights reserved.
4. **Synty's 5-seat rule + audit clause + no-AI-training/NFT/metaverse-tool restriction** — real limits if the team grows or you plan AI tooling.
5. **Fab tiers:** Personal & Professional grant the same rights; only move to Professional after $100k revenue.
6. **"Royalty-free" ≠ "free" ≠ unlimited seats.**
7. **Keep receipts/license snapshots** — your license is grandfathered; keep proof.

**Sources (B):**
- Fab — https://www.fab.com/ ; Fab Licenses & Pricing — https://dev.epicgames.com/documentation/fab/licenses-and-pricing-in-fab ; Fab EULA — https://www.fab.com/eula — *Authoritative*.
- Fab Limited-Time Free — https://www.fab.com/limited-time-free ; Fab free content (Unreal) — https://www.unrealengine.com/en-US/fabfreecontent — *Authoritative, rotates*.
- Quixel Megascans license — https://quixel.com/en-US/license — *Authoritative*.
- Synty One-Time Purchase Licence — https://syntystore.com/pages/one-time-purchase-licence ; POLYGON collection — https://syntystore.com/collections/polygon ; Town Pack — https://syntystore.com/products/polygon-town-pack ; SyntyPass — https://syntystore.com/products/syntypass ; Sidekick — https://syntystore.com/collections/sidekick-character-packs — *Primary EULA/products; prices vary with sales*.
- Kenney license — https://kenney.nl/support ; Kenney audio — https://kenney.nl/assets/category:Audio — *Authoritative CC0*.
- Poly Haven License — https://polyhaven.com/license — *Authoritative CC0*.
- Sketchfab CC intro — https://sketchfab.com/blogs/community/an-introduction-to-creative-commons-licenses/ — *Authoritative*.
- Mixamo FAQ — https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html — *Authoritative*.
- MetaHuman License — https://www.metahuman.com/license — *Authoritative*.
- Freesound FAQ — https://freesound.org/help/faq/ ; Pixabay License — https://pixabay.com/service/license-summary/ ; itch CC0 — https://itch.io/game-assets/assets-cc0 — *Authoritative / per-item varies*.

*Uncertainty:* exact live SyntyPass/pack prices and Fab free-drop count shift — confirm on the live pages at purchase.

---

## C. First-Game Best Practices, Co-op Reality, Stealth Design

### C1. First-time gamedev best practices
- **Scope order: prototype → vertical slice → MVP → full game.** The prototype only answers "is the loop fun?" (one player, one yard, one pool, one patroller, working loudness meter). The **vertical slice** is that loop at near-final quality for one chunk — your best defense against scope creep.
- Use **MoSCoW** (Must/Should/Could/**Won't**) and write the "Won't" list explicitly — a parked-ideas list stops shiny-object syndrome.
- **Double or triple your time estimates.** Halving scope halves the sales needed to break even.
- **Blueprints for a first-timer.** Epic's own guidance: Blueprints for gameplay/UI/state; **C++ only** for perf hot-paths or features Blueprint can't reach. You don't need C++ to ship this. (Caveat: AI *affiliation teams* are C++-only, but the "Detect Neutrals + Tags" Blueprint workaround is fine.)
- **Top failure mode:** overly ambitious scope + underestimation (cited as the dominant reason most indie games fail). De-risk: shrink the MVP brutally; ship single-player loop first; use UE 5.7's beginner "Intro to Unreal" template as scaffold.
- **2026 learning path:** Epic's free "Your First Hour in Unreal Engine," the "Welcome to Unreal Engine" learning path, official docs as reference. Learn single-player framework thoroughly *before* netcode.

### C2. Online co-op — honest reality check
- **Biggest risk in the plan.** UE auto-syncs ~90% of the boring work (mark a `UPROPERTY(Replicated)`/RepNotify + mark actors to replicate), but the mental model is unforgiving.
- **Server authority:** server owns truth; clients request, server decides. **Score, loudness, detection must be server-authoritative** or players desync/cheat.
- **GameMode (server-only, never replicated)** = rules; **GameState (replicated)** = shared truth (team score, alert, timer) — put shared meters here, not on the character.
- **RepNotify/OnRep** for state changes (C++: fires on clients only; Blueprint: both). **Prefer OnRep booleans over Multicast RPCs** so late-joiners see correct state.
- **`CharacterMovementComponent`** already gives predicted, instant-feeling movement — don't build custom prediction.
- **Topology:** **listen server** (one friend hosts, P2P) is the standard for 2–8 co-op — free, no hardware. Dedicated servers overkill.
- **Sessions/matchmaking:** **Steam OSS** (if on Steam) or **EOS** (free, cross-platform). **Advanced Sessions** plugin is common but has EOS/Steam friction in reports; **EnhancedOnlineSessions** is a newer, better-maintained alternative to evaluate.
- **Pragmatic recommendation: do NOT build "online co-op from day one."** Instead: (1) build the whole core loop single-player; (2) design multiplayer-aware from the start (all shared state in GameState/GameMode); (3) layer netcode as a dedicated milestone, 2 players first, then scale to 8 while profiling. Honest framing: co-op roughly **doubles** the project's complexity and is where most schedule slip lives.

### C3. Stealth & detection design
- **Use UE5 AI Perception.** Add `AIPerceptionComponent` to each threat's AIController:
  - **AISense_Sight** = the flashlight cone: `SightRadius`, `LoseSightRadius`, `PeripheralVisionHalfAngle` (cone angle ~45–60° for a focused homeowner). "Detect Neutrals + Tags" to filter (Blueprint-friendly). "Auto Success Range from Last Seen Location" models "I know you're right there."
  - **AISense_Hearing** = pair with **Report Noise Event** fired by the player on sprint/splash/knock. This is what makes the loudness meter *mean* something.
  - Respond via **On Target Perception Updated** → AIStimulus struct → feed a **Behavior Tree**. Debug with the perception visualizer.
- **Loudness meter + 3 alert states** (server-authoritative, in GameState so all co-op players see the same status): **Unaware → Suspicious/Searching → Alert**. Feedback on **multiple channels at once**: fill-up detection bar, overhead `?`/`!`, NPC animation tells, rising audio. Loudness raises effective hearing radius and is fed by actions (swimming/splashing = louder = great tension with "stay longer for points"; crouch/idle = quieter).
- **Patrol/chase/search via Behavior Trees:** predictable patrol when Unaware (predictability is a *feature* in stealth), move-to-last-known + EQS search when Suspicious, chase when Alert. **Motion-sensor light** = trigger volume → light on → Report Noise Event / raise alert. Cop = escalation spawn when team loudness/alert crosses a threshold.
- **Reference games & the lesson each gives:**
  - **Sneaky Sasquatch** — *closest match.* Simple circular sight+sound meter per NPC, disguises. Lesson: keep detection **readable and forgiving**; one combined radius reads instantly in co-op.
  - **Untitled Goose Game** — limited NPC vision, chunky discrete states. Lesson: comedic stealth wants clear states, not fine realism — ideal for party co-op.
  - **Thief** — invented hearing as a core sense; AI reacts to the environment. Lesson: let lights/splashes/knocked objects leave traces the AI investigates.
  - **Hello Neighbor** — adaptive AI that learns routes. Lesson: a little adaptivity (homeowner re-routes toward pools you keep using) adds replay value — but it's a **stretch goal**, not MVP.
  - **Payday-style stealth** — shared alert across a team. Lesson: make the loudness/alert meter a **team resource** — one loud player endangers all. That social tension is the point.

**Sources (C):**
- Vertical slice — https://tonogameconsultants.com/vertical-slice/ ; Scope creep — https://tonogameconsultants.com/scope-creep/ ; Indie scope creep — https://www.wayline.io/blog/scope-creep-indie-games-avoiding-development-hell — *Gamedev consultancy/indie, practical*.
- Blueprint vs C++ (Epic) — https://dev.epicgames.com/documentation/en-us/unreal-engine/coding-in-unreal-engine-blueprint-vs-cplusplus — *Authoritative*; 2026 guide — https://www.wholetomato.com/blog/c-versus-blueprints-which-should-i-use-for-unreal-engine-game-development/ — *Current, balanced*.
- Learn UE5 courses (Epic) — https://www.unrealengine.com/en-US/blog/learn-unreal-engine-5-fast-with-these-new-courses ; Welcome path — https://dev.epicgames.com/community/learning/paths/7a/welcome-to-unreal-engine — *Official*.
- Indie failure patterns — https://indiegamecloud.com/why-do-indie-games-fail/ — *Corroborates scope/underestimation*.
- Networking overview (Epic) — https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-and-multiplayer-in-unreal-engine ; GameMode/GameState (Epic) — https://dev.epicgames.com/documentation/en-us/unreal-engine/game-mode-and-game-state-in-unreal-engine — *Authoritative*.
- Multiplayer Network Compendium (Cedric Neukirchen) — https://cedric-neukirchen.net/docs/category/multiplayer-network-compendium/ ; Dedicated vs Listen — https://cedric-neukirchen.net/docs/multiplayer-compendium/dedicated-vs-listen-server/ — *Highly regarded community reference*.
- Multiplayer tips (WizardCell) — https://wizardcell.com/unreal/multiplayer-tips-and-tricks/ — *Well-known practical blog*.
- Online Subsystem Steam tutorial — https://dev.epicgames.com/community/learning/tutorials/dV57/setting-up-online-subsystem-steam-in-unreal-engine — *Official community*.
- EnhancedOnlineSessions — https://github.com/MajorTomAW/EnhancedOnlineSessions — *Active open-source*.
- AI Perception (Epic, 5.7) — https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine — *Authoritative; verified property names*.
- Stealth design — https://www.gamedesigndiary.co.uk/post/stealth-design-series-part-1 ; https://gamedesignskills.com/game-design/stealth/ ; https://www.gamedeveloper.com/design/stealth-game-design — *Focused/reputable*.
- Untitled Goose Game (Game Developer) — https://www.gamedeveloper.com/game-platforms/road-to-the-igf-house-house-s-i-untitled-goose-game-i- ; Sneaky Sasquatch — https://en.wikipedia.org/wiki/Sneaky_Sasquatch ; Hello Neighbor — https://en.wikipedia.org/wiki/Hello_Neighbor — *Dev interview / background*.

---

## Overall Bottom Line

1. **Tooling is a green light.** UE 5.8 is out and the Claude↔Unreal MCP is official Epic tooling — the exact workflow you wanted exists and is first-party. Treat MCP as a powerful assistant with real safety rules (commit first, no skip-permissions).
2. **Art path is clear and cheap.** Synty POLYGON + Sidekick + Mixamo + Kenney/Pixabay audio gets you a great stylized suburban night on a small budget. Skip MetaHuman. Mind CC-NC and Synty's seat/AI rules.
3. **The stealth core is very doable** in Blueprints via AI Perception + Behavior Trees — that's the fun, achievable heart. Sneaky Sasquatch is the north-star reference.
4. **Online co-op is the real risk.** The plan handles it by building the loop single-player first with server-authoritative state, then layering listen-server netcode as its own milestone (2 → 8 players). Hold that discipline and "co-op day one" becomes "co-op designed-in from day one, shipped in phase two."
