# Pool Hop — Canonical Decisions (drift resolutions)

*The single source of truth when the parallel-authored design docs disagree. Established from `09_Design_Review_Punchlist.md`. When a domain doc conflicts with this file, THIS FILE WINS. Update here first, then propagate.*

Last updated: 2026-06-30 (overnight build loop).

---

## Why this exists
The 10 design docs were authored in parallel and drifted: the same state variable, enum, asset, and number appear under different names/values. `09` (the critique) flagged this as the dominant risk — if each doc is built literally, the systems won't connect. This file pins one canonical set. `06_Core_Systems_TechSpec.md` is the source of truth for **state + loudness**; `04_AI_Watcher.md` is the source of truth for **AI numbers**.

## Naming / path canon
- **Framework-state variable names → `06` (see tables below).** `07`'s HUD binds to these exact names; `04` writes to these exact names.
- **`E_AlertState` = 4 states: `Unaware(0), Suspicious(1), Alert(2), Critical(3)`.** Critical is a real member (AlertDirector §5.4 assigns it at heat ≥ 90). **Interim: no MCP tool can create a Blueprint enum, so the variable is built as `byte` (0–3) for now** — swap to the real `E_AlertState` enum in-editor later (2-min manual step), then retype the vars. Any code comparing states uses the integer values above.
- **`E_PoolTier` = `Standard(0), HotTub(1), Infinity(2), Money(3)`** — same `byte` interim.
- **Watcher actor = `BP_WatcherCharacter` (parent `Character`) + `BP_WatcherController` (parent `AIController`), both under `Content/_Project/AI/Watcher/`.** NOT `BP_Watcher`/`BP_Homeowner`/`BP_HomeownerCharacter`, NOT flat `_Project/AI/`.
- **Input assets stay in `Content/Input/`** (where `IA_Move`/`IMC_Default` already live). New actions (`IA_Interact`/`IA_Dive`/`IA_SwimUpDown`) go there too — NOT a new `Content/_Project/Core/Input/`. (Avoids the "which asset is real" class of bug from LESSONS.)
- **Materials** live under `Content/_Project/Gameplay/Materials/` (e.g. `M_GreyboxToon`, `M_WaterPlaceholder`). `Art/` is not a canonical folder.

## Number canon (the tuned pairs — move together, never one alone)
- **Watcher cone: `PeripheralVisionHalfAngle = 35°` (70° cone), `SightRadius = 1400`, `LoseSightRadius = 1800`.** (`04`. `02`/`01`'s 45°/1700/1200 are wrong.) The flashlight decal + vision-cone material use `SightRadius=1400` so art == truth.
- **Hearing: `HearingRange = 1200` baseline** (`04` wins for AI numbers). Loudness scales effective range up toward this; the loudness/hearing pair is tuned together (`06` §2.5).
- **Detection: fill `1.5s`, decay `3.0s`** (`04`). (`02`'s 1.2/2.0 are wrong.)
- **Chase vs Sprint pair: `ChaseSpeed = 650`, player `SprintSpeed = 600`** — keep chase ~50 above sprint so escape is reliable (`04` §13 knob 4). These two knobs are a pair across `AIP_WatcherProfile` and `DA_MovementTuning`.
- **Night length: `NightTimeRemaining` default `600`** (10 min).
- **Loudness magnitudes → the single `DT_LoudnessActions` table in `06` §2.6 is the source of truth** (Vault bump 30, SplashEnter 45, Sprint sustained band 55, SwimMove band 45, SensorTrip 40, FenceClimb 25, CrouchMove silent). `07`'s per-verb "noise" numbers must equal these rows.
- **Pools use absolute `BaseScorePerSecond`** (the real field on `BP_PoolVolume`), NOT multipliers: sandbox A/B/C/D = `10 / 13 / 15 / 20` per second.
- **Detain respawn target = the stash-zone actor** (`BP_StashZone`, exists by Step 3), everywhere.

## Canonical Step-1 variable tables (what the build creates)
Replication legend: `None` = server-only/local; `Rep` = Replicated (read-only mirror on clients); `RepNotify` = replicate + `OnRep_`.

**`BP_PlayerGameState`** (shared truth):
| var | type | repl | default |
|---|---|---|---|
| `TeamScoreBanked` | int | Rep | 0 |
| `TeamScoreAtRisk` | int | RepNotify | 0 |
| `NeighborhoodHeat` | float | RepNotify | 0 |
| `AlertLevel` | byte *(→E_AlertState)* | RepNotify | 0 |
| `NightTimeRemaining` | float | Rep | 600 |
| `bNightOver` | bool | RepNotify | false |

**`BP_PlayerState`** (per-player):
| var | type | repl | default |
|---|---|---|---|
| `IndividualScoreAtRisk` | int | RepNotify | 0 |
| `IndividualScoreBanked` | int | Rep | 0 |
| `DistinctPoolsHopped` | int | Rep | 0 |
| `CurrentLoudness` | float | Rep | 0 |
| `bDetained` | bool | RepNotify | false |
| `Air` | float | Rep | 100 |
| `bIsSubmerged` | bool | Rep | false |
| `bBreathCritical` | bool | Rep | false |
| `bIsHidden` | bool | Rep | false |
| `DetectionAlpha` | float | Rep | 0 |

Deferred to their systems (not Step 1): `EquippedCostume` (soft DataAsset ref → Step 6, and soft-ref-via-MCP is unconfirmed — see LESSONS), the DataTable/struct-typed vars (Step 2).

## Known MCP buildability gaps (from the spikes — see LESSONS)
- **Enum/struct creation: NOT possible via MCP** (`execute_tool_script` can't import `unreal`; no enum/struct tool). Use `byte`/`int` interim; create real enums/structs in-editor.
- **"Run-on-Server / Reliable" RPC flags: unconfirmed via MCP** — gates every `Server_*` request (Step 2+). Spike before Step 2; may need in-editor.
- **Behavior Tree / Blackboard authoring: inspect-only toolset** — Step 4's BT likely needs in-editor authoring or a future tool.
- **UMG widget-tree authoring: unconfirmed** — Step 7 HUD.
- **Niagara, EQS: unconfirmed** — use material/decal + hand-authored fallbacks first.
