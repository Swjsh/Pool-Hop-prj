# Pool Hop — Technical Architecture

*Version 0.1. Last updated June 30, 2026. Engine target: Unreal Engine 5.8.*

---

## 1. Engine & Tooling Decisions

| Decision | Choice | Why |
|---|---|---|
| Engine | **Unreal Engine 5.8** | Released June 17, 2026. New **Toon Shader** (experimental) fits our stylized look; **Lumen Lite** gives cheap GI. It's the last major UE5 (UE6 Early Access targets end of 2027), so 5.8 is a stable place to build for years. |
| Scripting | **Blueprints first, C++ only when needed** | Epic's own guidance + community consensus for first-timers. Blueprints for gameplay/UI/state; drop to C++ only for perf hot-paths or features Blueprint can't reach (e.g. AI affiliation teams). |
| Primary language of the world | Blueprints + Data Assets for tuning | Designers/first-timers iterate fast; tuning values live in Data Tables/Assets, not hardcoded. |
| Multiplayer topology | **Listen server (one friend hosts, P2P)** | Free, no server hardware, standard for 2–8-player co-op. Dedicated servers are overkill. |
| Online subsystem | **EOS (Epic Online Services)** or **Steam OSS** | EOS is free + cross-platform; Steam OSS if we ship on Steam. Evaluate **EnhancedOnlineSessions** plugin for the session/lobby layer. |
| Agentic assist | **Official Epic "Unreal MCP" plugin + Claude Code** | First-party, ships in UE 5.8 (Experimental). Drives the editor for scaffolding. See §5. |
| Source control | **Git + Git LFS** (or Perforce later) | Commit before every MCP session; MCP can mutate/delete assets. LFS for binary assets. |

---

## 2. The Central Discipline: Server-Authoritative From Line One

This is the most important engineering decision in the project, and it directly resolves the tension in "online co-op from day one" while still letting us build/test the loop single-player first.

**Rule:** every piece of state that must be consistent across players is **owned by the server** and lives in **GameState** or **GameMode** — never in a local-only variable on the player character.

- **GameMode (server-only, never replicated):** the *rules* — how points are earned, how heat escalates, win/lose/escape conditions, spawn logic.
- **GameState (replicated to all clients):** the *shared truth* — team score, neighborhood alert level, night timer, banked points.
- **PlayerState (replicated):** per-player score contribution, costume/loadout, detained status.
- **Character/Pawn:** movement (via `CharacterMovementComponent`, which gives networked prediction for free) + cosmetic/local feedback only.

**Data flow:** client input → **request** to server → server validates → server updates authoritative state → replicates back via **replicated variables + OnRep/RepNotify** callbacks.

Why this matters: if we build the sandbox this way even in single-player (where the "server" is just the local host), then adding real co-op later is **layering a network transport onto an already-correct model**, not a rewrite. Build the wrong way and co-op becomes a ground-up redo — the exact trap that kills ambitious first games.

### Replication gotchas to remember
- Prefer **OnRep booleans/state over Multicast RPCs** so late-joiners (players joining mid-night) see correct world state. Multicasts fire once and are lost to anyone who joins after.
- In C++, OnRep fires on clients only; in Blueprint it fires on both. Know which you're in.
- Mark the *actor* to replicate AND the specific *properties*. Both are required.
- Keep replicated data small; don't replicate things clients can derive locally (e.g. cosmetic particle timing).

---

## 3. System Architecture (how the pieces fit)

```
GameMode (server)              GameState (replicated)          PlayerState (replicated, per player)
  - scoring rules                - team score                    - individual score
  - heat/escalation rules        - neighborhood alert level      - loadout / costume
  - spawn/escape logic           - night timer                   - detained? banked?
  - threat director              - banked total
        |                              ^
        v                              |
  Threat AIControllers   -->  AIPerceptionComponent (Sight + Hearing)
  (homeowner, chaser, cop)          |
                                    v
  PlayerCharacter  --> LoudnessComponent --> reports Noise Events --> AI hearing radius
       |                                 
       +--> PoolScoringComponent (overlaps pool volumes -> asks server to add score)
       +--> CostumeComponent (swaps mesh + applies modifier data asset)
```

**Key components to build (reusable, data-driven):**
- `LoudnessComponent` — tracks a 0–100 value, raises it from tagged actions, decays over time, and fires **AI hearing noise events** (`ReportNoiseEvent`) scaled by the value.
- `PoolScoringComponent` / `PoolVolume` — a trigger volume that, while overlapped, asks the server to accrue points (with decay + hop-streak logic on the server).
- Threat `AIController` + **Behavior Tree** + **AIPerceptionComponent** — Sight (radius, `PeripheralVisionHalfAngle` for the cone, `LoseSightRadius`) and Hearing. `OnTargetPerceptionUpdated` feeds the BT state machine.
- `AlertDirector` (on GameMode) — aggregates loudness/detection into the neighborhood **heat** value and decides escalation (spawn the cop when heat crosses a threshold).
- `CostumeComponent` — applies a **Costume Data Asset** (mesh parts + optional stat modifier).

---

## 4. AI & Detection (UE5 AI Perception)

The stealth core maps cleanly onto engine built-ins — this is the *doable, fun* part.

- **AISense_Sight** = the vision cone ("flashlight range"): `SightRadius`, `LoseSightRadius`, `PeripheralVisionHalfAngle` (the cone angle). Use *Detect Neutrals + Tags* (Blueprint-friendly) to choose who is seen.
- **AISense_Hearing** = reacts to `ReportNoiseEvent` fired by the player's `LoudnessComponent`. Loudness scales the effective hearing range — this is the mechanical heart of the noise system.
- **Alert state machine (Behavior Tree):** Unaware (patrol waypoints) → Suspicious (move to last-known location, search via EQS) → Alert (chase). Overhead `?`/`!` widget reads the current state.
- **Motion-sensor light:** a trigger volume that turns on a spotlight and calls `ReportNoiseEvent`/raises local alert — cheap, reusable environmental threat.
- Debug with the built-in perception visualizer while tuning cones.

Server authority note: **detection resolution runs on the server.** Clients render the cones and their own detection bar from replicated state; the server decides who is actually seen/caught. This prevents desync and cheating.

---

## 5. MCP-Assisted Workflow (Claude Code ↔ Unreal 5.8)

UE 5.8 ships an **official first-party MCP integration** (Experimental). This lets Claude Code drive the editor — spawn actors, scaffold Blueprints, run editor Python, manage assets — which is genuinely useful for boilerplate and scene assembly. Treat it as a powerful assistant, not autopilot.

### Setup (high level)
1. In UE 5.8: **Edit → Plugins**, enable **"Unreal MCP"** *and* **"AllToolsets"** (without AllToolsets the server exposes no tools). Restart the editor.
2. Start the server: run `ModelContextProtocol.StartServer` in the editor console, or enable **Auto Start Server** in *Editor Preferences → Model Context Protocol*. It binds to `http://127.0.0.1:8000/mcp`.
3. Generate the client config: `ModelContextProtocol.GenerateClientConfig ClaudeCode` → writes `.mcp.json` to the project root.
4. Launch `claude` (Claude Code) **from the project root**. Verify with `/mcp` (should show `unreal-mcp` connected). Smoke test: *"List all actors in the current level."*
5. Optionally install Epic's official skills: the **`EpicGames/unreal-engine-skills-for-claude-code-plugin`** repo (adds a `unreal-mcp` skill + a session hook for UE conventions).
6. **Windows note:** the skills plugin's SessionStart hook is a bash script → install **Git Bash or WSL**. The MCP tools themselves work under native PowerShell; you just lose the auto context hint.

### What it's good for here
- Scaffolding the component/Blueprint skeletons in §3.
- Assembling the grey-box test map (spawn/arrange pools, cover, patrol waypoints).
- Batch asset ops (import/organize the Synty/Kenney packs, set up Data Tables).
- Wiring repetitive Blueprint graphs, then you refine by hand.

### Safety rules (Epic's own warnings — take seriously)
- **No authentication; localhost is not a trust boundary.** Don't run the MCP server on shared/untrusted machines or expose port 8000.
- **`execute_tool_script` runs arbitrary Python in the editor** with full project/disk access — every call is privileged and can move/delete assets.
- **Do NOT use `--dangerously-skip-permissions`** while the plugin is loaded — it removes the per-tool approval gate.
- **Commit/shelve before long MCP sessions** and **review diffs** before submitting. MCP edits live objects and can delete VCS-tracked assets in one call.
- It's **Experimental** — expect API churn and rough edges; keep the engine updated and don't build load-bearing automation on unstable tool signatures.

### Also available: the in-editor AI Assistant (UE 5.7+)
Press **F1** over any editor UI for contextual help / C++ snippets. It's *advisory* (doesn't drive the editor). Use it for "how do I…" while using MCP + Claude Code for hands-on automation.

---

## 6. Recommended Project / Folder Structure

```
PoolHop/                     (UE project root — run claude from here)
  Content/
    _Project/                (our stuff, underscore keeps it top of list)
      Core/                  GameMode, GameState, PlayerState, PlayerController
      Characters/            Player pawn, animation BPs
      Components/            LoudnessComponent, PoolScoringComponent, CostumeComponent
      AI/                    Threat controllers, Behavior Trees, EQS, perception configs
      Systems/               AlertDirector, scoring rules, data assets
      Gameplay/              Pools, sensor lights, stash zone, pickups
      UI/                    HUD (loudness, score, alert), menus
      Data/                  Data Tables / Data Assets (tuning: cone sizes, score rates, costumes)
      Maps/                  L_Sandbox (grey box), later L_MapleCourt, etc.
    ThirdParty/              Synty, Kenney, Mixamo imports (kept separate for licensing clarity)
  Config/
  .mcp.json                  (generated by the MCP plugin)
  .gitignore / .gitattributes (Git LFS for binaries)
```

Rationale: an underscore-prefixed `_Project` folder keeps *our* content separate from imported/marketplace content — makes licensing, updates, and cleanup sane.

---

## 7. Phased Roadmap

| Phase | Goal | Multiplayer? | Exit criteria |
|---|---|---|---|
| **0. Setup** | UE 5.8 project, Git+LFS, MCP wired, folder structure, import free placeholders | No | `claude` connects to Unreal; empty project runs |
| **1. Systems Sandbox (MVP)** | The 5 systems on a grey box (see doc 02), all state server-authoritative | Local only, but authority-correct | Loop is *tense and repeatable* per doc 02 success criteria |
| **2. Netcode Layer** | Add listen-server co-op for 2 players; sessions/lobby; test replication of score/loudness/alert | **Yes — 2p** | Two players share correct alert/score state over the network |
| **3. Scale Co-op** | 2 → 8 players; profile AI perception + replication cost; detained/rescue | Yes — up to 8 | 8 players stable; social tension works |
| **4. First Real Neighborhood** | Build "Maple Court" with Synty kit; replace grey box; add sensor variety, one real threat set | Yes | A full playable neighborhood run |
| **5. Content & Threats** | Cop + chaser + environmental threats; 2nd/3rd neighborhoods; costumes/gadgets; home-base intro | Yes | The full core loop from doc 01 |
| **6. Meta & Polish** | Leaderboards, unlocks, audio pass, Toon Shader look-dev, photo/clip features | Yes | Shippable demo |

**Biggest risk, stated plainly:** Phase 2 (netcode) is where most of the schedule risk lives. Co-op roughly doubles project complexity. The mitigation is entirely in Phase 1 discipline (server-authoritative state) — if we hold that line, Phase 2 is a hard-but-bounded milestone rather than a rewrite.

---

## 8. Performance & Platform Notes (PC / Windows first)

- Stylized + **Lumen Lite** + **MegaLights** (now production-ready) → good-looking night lighting at 60fps without a photoreal budget.
- Many dynamic lights (windows, streetlamps, sensor floods) is exactly MegaLights' use case — but profile; lights are still the classic stealth-game perf sink.
- 8 players + multiple perception-running AI is the perf watch-item; profile AI tick and network bandwidth as we scale in Phase 3.
- Water: use stylized/cheap water, not the heaviest simulation — it's a gameplay surface, not a tech demo.

---

*See `04_Research_Findings.md` for the sourced research this architecture is built on (UE 5.8 + MCP, assets/licensing, co-op & stealth best practices).*
