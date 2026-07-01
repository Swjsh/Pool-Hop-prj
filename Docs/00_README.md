# 🏊 Pool Hop — Project Kickoff

*A stylized online co-op stealth game. Sneak through sleeping suburbs at 2 AM, hop backyard pools for points, escape before the cops. Built in Unreal Engine 5.8.*

**Kickoff date:** June 30, 2026 · **Status:** Phase 0 (setup) complete — UE 5.8 project created, MCP + AllToolsets enabled, Git/LFS pushed to [github.com/Swjsh/Pool-Hop-prj](https://github.com/Swjsh/Pool-Hop-prj). Starting Phase 1 (Systems Sandbox).

---

## The Idea in One Line
You and 2–8 friends slip out at midnight, cut through backyards, and hop from pool to pool for points — dodging homeowners, motion lights, and cops — then race back with your score before you get caught. Based on a true story.

## Locked Decisions (this kickoff)
- **Multiplayer:** Online co-op (2–8) is the vision — but built single-player-first with server-authoritative state, then netcode layered as a milestone (see Tech doc for why this resolves the risk).
- **Platform:** PC / Windows first.
- **First build:** A **systems sandbox** — prove the core loop is fun on a grey-box map before any level art.
- **Look:** Stylized/cartoon (Synty-style + UE 5.8 Toon Shader), not photoreal.

---

## The Documents

| # | Doc | What's in it |
|---|---|---|
| 01 | **[Game Design Document](01_Game_Design_Document.md)** | The full vision: pillars, core loop, mechanics (scoring, loudness, detection, threats, items/costumes), co-op design, neighborhoods, art/audio, tone. Start here for the *what* and *why*. |
| 02 | **[MVP / Vertical Slice](02_MVP_Vertical_Slice.md)** | The first build — the "systems sandbox." Exactly what to build, what to leave out, the grey-box test map, and success criteria. Start here for *what to build first*. |
| 03 | **[Technical Architecture](03_Technical_Architecture.md)** | UE 5.8 setup, the server-authoritative co-op model, AI/detection with AI Perception, the Claude↔Unreal MCP workflow + safety rules, folder structure, phased roadmap. The *how*. |
| 04 | **[Research Findings](04_Research_Findings.md)** | Sourced research: UE 5.8 + official MCP, free/stylized assets + licensing, and first-game/co-op/stealth best practices. Every claim cited. |
| 05 | **[Virality & Market Research](05_Virality_And_Market_Research.md)** | What's breaking out in indie co-op right now (PEAK, R.E.P.O., Content Warning, "friendslop"), monetization/pricing, what makes a design clip-worthy, and launch strategy — with concrete, ranked recommendations for Pool Hop. |
| 06 | **[Hunter/Antagonist Design Research](06_Hunter_Antagonist_Design_Research.md)** | Should the homeowner/watch/cop be a player-controlled hunter (Dead by Daylight-style) instead of AI? Researched against the asymmetric-multiplayer genre. Resolved: no, not for MVP — see GDD §13. |
| 07 | **[Movement, Physics & UI Research](07_Movement_Physics_UI_Research.md)** | What makes third-person movement feel good, how far to push physics comedy without frustration, swim/water traversal precedent, and stealth-detection UI conventions — with concrete changes for Systems 1 and 4. |

---

## Top Takeaways from Research
1. **UE 5.8 is out (June 17, 2026) and the Claude↔Unreal MCP is official Epic tooling** — the workflow you wanted is real and first-party. (Use it carefully: commit before sessions, never `--dangerously-skip-permissions`.)
2. **Cheap great-looking art path exists:** Synty POLYGON world + Sidekick characters + Mixamo animation + Kenney/Pixabay audio. Skip MetaHuman (photoreal, wrong style). Watch CC-NC licenses.
3. **The stealth core is very doable in Blueprints** via AI Perception + Behavior Trees. Sneaky Sasquatch is the reference game.
4. **Online co-op is the #1 risk** — mitigated entirely by building single-player-first with server-authoritative state, then layering listen-server netcode (2 → 8 players).

---

## Suggested Next Steps
1. **Read 01 (vision) and 02 (first build)** and mark anything you'd change — these are living docs.
2. **Decide the open questions** flagged in the GDD §13 (player-count sweet spot, caught = detain vs run-ends, monetization — affects asset licensing).
3. **Set up the project (Phase 0):** install UE 5.8, enable the Unreal MCP + AllToolsets plugins, wire up Claude Code, init Git + LFS, create the folder structure (Tech doc §5–6). I can walk you through this or help drive it.
4. **Start the sandbox (Phase 1):** movement → pool scoring → loudness → detection AI → couple it → playtest. Judge only on "is it tense and repeatable?"

> When you're ready, I can help scaffold the UE project and the first systems (via the MCP workflow), write the tuning data tables, or expand any of these docs (e.g. a detailed detection-tuning spec or a shot-list for the sandbox map).

---
*All figures/tooling claims verified against primary sources as of June 30, 2026. Prices and Experimental-feature details may shift — confirm on live pages.*
