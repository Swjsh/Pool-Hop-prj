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

## Verified drift resolutions (2026-07-01 audit — a fresh model MUST build from these, not the domain docs)

A doc audit confirmed the parallel-authored docs `04`/`07`/`02` still contain **old names and numbers that silently break bindings**. These are the rulings; the offending docs carry a banner pointing here.

**1. HUD / framework-state variable names — `07` is WRONG, build the names in the Step-1 tables below.** `07_Movement_And_UI.md` binds the HUD to short names that DO NOT EXIST after Step 1. Use this translation:

| `07` says (WRONG) | Actual canonical var (build + bind THIS) | Lives on |
|---|---|---|
| `ScoreBanked` | `TeamScoreBanked` | GameState |
| `ScoreAtRisk` | `TeamScoreAtRisk` (shared) / `IndividualScoreAtRisk` (per-player) | GameState / PlayerState |
| `NeighborhoodAlert` | `AlertLevel` | GameState |
| `NightSecondsRemaining` | `NightTimeRemaining` | GameState |
| `Heat` | `NeighborhoodHeat` | GameState |
| `Loudness` | `CurrentLoudness` | PlayerState |
| `DetectionAlpha` | `DetectionAlpha` ✓ (this one matches) | PlayerState |

`04_AI_Watcher.md` writes detection to PlayerState: the canonical field is **`DetectionAlpha`** (0–1 fill). If `04` also names `DetectionMeter`/`SeenByAlertState`, treat those as the same `DetectionAlpha` + `AlertLevel` unless you deliberately add a separate raw-meter var.

**2. `E_AlertState` has FOUR members: `Unaware(0), Suspicious(1), Alert(2), Critical(3)`.** `04 §6/§11` and its pseudocode show only 3 (omit `Critical`) — **stale**. `Critical` is real (AlertDirector assigns it at heat ≥ 90, `06 §5.4`). Build 4.

**3. Hearing range = `1200` (both fields, one number).** `04` says `HearingRange = 1200`; `06 §2.2/§2.5` says `HearingRangeAtMaxLoudness = 2500` — **conflict**. Ruling: use **1200** everywhere (the AI sense `HearingRange` AND the LoudnessComponent's `HearingRangeAtMaxLoudness` both = `1200`). It's one tuned pair; `06`'s 2500 is superseded. (Playtest may move it — but move both together.)

**4. Watcher cone geometry = `35° / 1400 / 1800`, fill `1.5s` / decay `3.0s`.** `02 §"Detection tuning"` hardcodes `45° / 1700 / 900 / 1.2s / 2.0s` and even says "do not re-tune per map" — **all wrong, ignore that whole block**. `04` (which CANON already blesses for AI numbers) is right. Difficulty per map = route/dwell/light, never cone size.

**5. Watcher actor name = `BP_WatcherCharacter` + `BP_WatcherController` under `Content/_Project/AI/Watcher/`.** `05`/`02`/`03` variously call it `BP_Watcher`/`BP_Homeowner`/`BP_HomeownerCharacter` — all wrong, use the `04` name everywhere.

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

## Step 3 variable additions (pool scoring — not in the original Step-1 tables, added when building `06 §3`)
`06`'s spec text implies these as tuning knobs/bookkeeping but doesn't list them in a variable table; canonizing here so they aren't re-invented differently next time:

| Var | Type | Repl | Default | Lives on | Purpose |
|---|---|---|---|---|---|
| `CrewSplashBonusPerExtra` | float | None | 0.25 | `BP_PoolVolume` | Per-extra-occupant crew multiplier bonus, used by `GetCrewMultiplier` (§3.4 knob). |
| `StreakStep` | float | None | 0.15 | `BP_PlayerGameMode` | Hop-streak multiplier step, used by `GetHopStreakMultiplier` (§3.4 knob). |
| `StreakCap` | int | None | 6 | `BP_PlayerGameMode` | Hop-streak clamp cap (§3.4 knob). |
| `VisitedPoolIDs` | Array\<Name\> | None | [] | `BP_PlayerState` | Server-only bookkeeping so `Server_RegisterPoolVisit` can tell whether a `PoolID` is new for this run; cleared on bank (`Server_BankAtRisk`) and on catch (`Server_LoseAtRisk`) alongside `DistinctPoolsHopped` reset. Not in `06`'s PlayerState table — needed because the spec's "is PoolID new for this PlayerState?" check has nothing else to check against. |

**Scoring rule functions built as regular Functions (not Custom Events)**, per the existing `Server_*` → `HasAuthority`-guarded-function interim convention: `Server_AddScore`, `GetHopStreakMultiplier`, `Server_BankAtRisk`, `Server_LoseAtRisk`, `Server_RegisterPoolVisit` (new — not named in `06`, needed to back the "is this pool new" check), `Server_OnReachStash` (thin wrapper → `Server_BankAtRisk`, per the roadmap's Step 3 sequencing) — all on `BP_PlayerGameMode`. `BP_PoolScoringComponent.Server_ExitPool` does **not** null `CurrentPool` (spec says "clear") — it only resets `AccrualAccumulator`/`bIsScoring`; the tick gate uses `bIsScoring`, not `IsValid(CurrentPool)`, sidestepping an unresolved "how do you DSL-author a null object literal" question. Functionally equivalent; revisit only if something ever needs to read a scoring component's `CurrentPool` while `bIsScoring` is false and expects `None`.

## Known MCP buildability gaps (from the spikes — see LESSONS)
- **Enum/struct creation: NOT possible via MCP** (`execute_tool_script` can't import `unreal`; no enum/struct tool). Use `byte`/`int` interim; create real enums/structs in-editor.
- **"Run-on-Server / Reliable" RPC flags: unconfirmed via MCP** — gates every `Server_*` request (Step 2+). Spike before Step 2; may need in-editor.
- **Behavior Tree / Blackboard authoring: inspect-only toolset** — Step 4's BT likely needs in-editor authoring or a future tool.
- **UMG widget-tree authoring: unconfirmed** — Step 7 HUD.
- **Niagara, EQS: unconfirmed** — use material/decal + hand-authored fallbacks first.
