---
name: unreal-mcp-scene-building
description: Build and inspect Unreal Engine levels through the unreal-mcp server — load/duplicate levels, place and transform actors, probe ground height with world traces, set a level's GameMode override, create materials, capture viewport screenshots (handling the multi-MB base64 result), and run Play-In-Editor to verify. Use when assembling grey-box test maps, placing gameplay volumes, or visually/functionally checking the game via MCP in this UE 5.8 project.
---

# Building & verifying levels via unreal-mcp

Toolsets: `SceneTools` (levels/actors), `ActorTools` (transforms/components/tags), `PrimitiveTools` (cube/sphere/cylinder components), `EditorToolset.EditorAppToolset` (camera, screenshots, PIE), `MaterialTools`, `ObjectTools` (properties).

## Levels

- `SceneTools.get_current_level()`, `load_level(path)`. **`load_level` refuses if the current level has unsaved changes** — `AssetTools.save_assets([])` first.
- Start a grey-box map by **duplicating the template**: `AssetTools.duplicate("/Game/ThirdPerson/Lvl_ThirdPerson", "/Game/_Project/Maps/L_Sandbox_Movement")`. You inherit working lighting, sky, PlayerStart, and a floor.
- **Set the GameMode override** so the level spawns your pawn/controller: find the `WorldSettings` actor (`find_actors(name="WorldSettings")`), then `ObjectTools.set_properties(WorldSettings, '{"defaultGameMode": {"refPath": "/Game/_Project/Core/BP_PlayerGameMode.BP_PlayerGameMode_C"}}')`. A duplicated template level still points at the template GameMode — you must repoint it or you'll test the wrong (possibly broken) character.

## Placing actors

- From an asset: `SceneTools.add_to_scene_from_asset(asset_path, name, xform)` — e.g. `/Engine/BasicShapes/Cube.Cube`, `/Engine/BasicShapes/Plane.Plane`. Returns the spawned actor's refPath. The engine cube/plane are 100 units; scale in `xform.scale` to size (scale 6 → 600).
- From a class: `SceneTools.add_to_scene_from_class(actor_type={refPath}, name, xform)` — e.g. `/Script/Engine.PhysicsVolume`. Volume brushes default to 200³; actor scale resizes them (scale 4 → 800).
- `ActorTools.set_actor_transform`, `set_label`, `add_tag`; `get_actor_bounds` (world AABB), `get_actor_transform`. Relocate the PlayerStart with `set_actor_transform` to move the spawn.
- `xform` is `{location:{x,y,z}, rotation:{pitch,yaw,roll}, scale:{x,y,z}}`. Yaw 0 faces +X. A cube of height H sitting on ground z=G needs center z = G + H/2.

## Finding actors exhaustively — `name` substring search can silently miss instances

`SceneTools.find_actors(name=...)` matches against the actor's **Label**, not its class — an instance whose Label doesn't happen to contain your search string is silently excluded, with no error or indication anything was skipped. Bit a project-wide "audit all N pools" sweep: `find_actors(name="PoolVolume")` returned 4 of 5 pool volumes; the 5th (an older instance predating a Label-naming convention) simply didn't have "PoolVolume" in its Label and was invisibly dropped from the result. **For any exhaustive/audit-style query, use `find_actors(actor_type={refPath: "/Game/Path/BP_Foo.BP_Foo_C"}, name="")` (the class filter) instead of a name guess** — this matches by actual class, catching every instance regardless of how it was labeled. Reserve name-substring search for "find the one thing I already know the name of," not "find all of X."

## Probe ground before you place — the floor is NOT flat

The ThirdPerson template has a raised central mound (spawn ~z=210 at origin) sloping to the z=0 outer floor, plus scattered raised platform strips (z=200). **Always trace first:**

`SceneTools.trace_world(start={x,y,high}, end={x,y,low})` returns the **distance** from start to the first hit → `ground_z = start_z − distance`. Trace from z≈400 down to z≈−100. For a large actor, probe all four footprint corners, not just the center — you'll otherwise bury or float it where the ground steps.

Build test courses on a confirmed-flat z=0 stretch and relocate the PlayerStart onto it.

## Materials (quick placeholder)

`MaterialTools.create_material(folder, name)` → `ObjectTools.set_properties(mat, '{"blendMode":"BLEND_Translucent","shadingModel":"MSM_Unlit","twoSided":true}')` → `add_expression(mat, {refPath:"/Script/Engine.MaterialExpressionConstant3Vector"})` (set its `constant` LinearColor) and a `MaterialExpressionConstant` (set `r`) → `connect_to_output(expr, "", "MP_EmissiveColor")` / `"MP_Opacity"` → `recompile`. Apply **per instance** via the component's `overrideMaterials` array (`ObjectTools.set_properties(component, '{"overrideMaterials":[{"refPath":"/Game/.../M_X.M_X"}]}')`) — don't use `StaticMeshTools.set_material`, which edits the shared engine mesh for every instance. Disable a decorative plane's collision so players pass through: set `bodyInstance.collisionEnabled = "NoCollision"`.

## Water / swim volumes

Place a `PhysicsVolume` actor (not a Blueprint — it can't be one), scale to size, then `set_properties(vol, '{"bWaterVolume": true, "priority": 1}')`. `CharacterMovementComponent` auto-switches to `MOVE_Swimming` when the capsule center enters. Add a translucent-blue surface plane at the water's top for visual read (collision off). Tune swim feel via the movement component's `buoyancy`, `maxSwimSpeed`, `fluidFriction`.

## Screenshots — extract the base64 to a PNG

`EditorAppToolset.CaptureViewport` returns a multi-MB base64 PNG **inline**, which overflows the tool-result limit and spills to a file. Handle it:
1. Pass `captureTransform` explicitly (the "optional" field is required in practice). Point the camera with location + `rotation:{pitch,yaw,roll}` (pitch −25 to −35 for a 3/4 overhead).
2. Set `annotations.gridHeight` to your ground z (e.g. 0) and a `gridSpacing`/`maxLabelDistance` for coordinate labels + actor name callouts; pass `gridSpacing:0` to drop the grid.
3. `python3` to `json.load` the spilled file, `base64.b64decode(returnValue['image']['data'])` to a `.png` in scratchpad, print `returnValue['labeledActors']` (label + worldLocation) for spatial context, then `Read` the PNG.

`SetCameraTransform` / `GetCameraTransform` move the editor camera independently. `CaptureEditorImage` grabs the whole editor window.

## Play-In-Editor verification (no automated tests in this project)

- `EditorAppToolset.StartPIE(options={bSimulate:false, playMode:"PlayMode_InViewPort", warmupSeconds:1})` — completes after BeginPlay + warmup. `bSimulate:true` ticks the world without possessing a pawn (good for observing AI/physics later).
- `IsPIERunning()`, then inspect state / `CaptureViewport`, then `StopPIE()`.
- Note: MCP can't inject player input, so PIE verifies spawn/possession, GameMode wiring, and that the level loads and runs cleanly. Feel-testing the actual movement verbs (does sprint feel fast? does vault clear the wall?) is a human Play pass against `Docs/02_MVP_Vertical_Slice.md` §4 — call that out rather than claiming verified.
- **Measuring at runtime — screenshots and the log frame counter LIE; use these instead (learned the hard way, LESSONS 2026-07-01 PM):**
  - **Prove movement via game state, not pixels:** read the pawn's root location — `ObjectTools.get_properties(<pawn>.CollisionCylinder, ["RelativeLocation"])` — vs the `PlayerStart` root (`CollisionCapsule`). Independent of whether the display draws. This is how movement got *proven* (pawn walked spawn x=100 → x=645). To drive movement without input, temporarily add `EventTick → Pawn|Input|AddMovementInput((1,0,0), 1, bForce=true)` to the character, then delete it.
  - **The editor throttles its display to ~3 fps and idles the GPU when its window is NOT the OS-foreground app** → `CaptureEditorImage` returns identical (frozen-looking) frames while the game ticks underneath. Automation can't reliably force OS foreground (Windows blocks `SetForegroundWindow` from background procs). Don't conclude "frozen/slow" from a screenshot — check pawn position (moving?) and `nvidia-smi` (`clocks.current.graphics` ~2800 MHz = rendering; ~1852 MHz + ~3% util = throttled/idle).
  - **The log `[N]` frame number is NOT a reliable fps counter** (resets on PIE restart, non-monotonic). Never derive fps from it.
  - `stat unit`/`stat fps` can't be enabled from automation (BeginPlay `ExecuteConsoleCommand` and the editor Cmd bar didn't render the overlay; synthetic Slate keys reach neither Enhanced Input nor the game console).

## Discipline

- Save + verify on disk after scene edits; commit each chunk.
- Prefix grey-box props `SB_` (SB_VaultWall, SB_CrouchBar). Keep placeholder geometry cheap — no art in the sandbox phase.
