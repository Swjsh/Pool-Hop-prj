# Build Lessons

Running log of hard-won, non-obvious findings — bugs, tool quirks, workarounds. **Newest first.** One entry per lesson. Keep entries concrete (what happened, why, what to do). Cross-reference skills in [`.claude/skills/`](../.claude/skills/) where a lesson generalizes into a reusable procedure.

---

## 2026-06-30 — Session: System 1 (movement)

### The initial commit shipped 18 `.uasset` files as literally 0 bytes
**Signature:** MCP `load_asset` fails with "Unable to load"; a Blueprint's Enhanced Input events show as `EnhancedInputActionNone` (dangling); the asset registry still "sees" the path (`find_assets` lists it) but it won't open. **Not** an LFS smudge failure — `git check-attr` showed the LFS filter applied, and `git cat-file -s HEAD:<file>` returned `0`, i.e. the blob itself was committed empty.
**Detect:** `find Content -name "*.uasset" -size 0`. Here it caught all 5 Enhanced Input assets, the Touch UI widgets, and Manny's material instances / textures / Control Rigs. `IA_Move` never existed at all.
**Fix:** recreate the asset via the right MCP tool (`DataAssetTools.create` for Input Actions/Contexts), set its properties, **then delete-and-recreate if `save_assets` silently no-ops** (see next lesson), and finally verify size on disk with `ls -la`.
**Prevention:** after any batch of asset creation, `save_assets([])` then `find ... -size 0` before committing. Never trust the in-editor state alone.
**Text files were hit too:** `Docs/00_README.md` was committed **truncated mid-sentence** (working copy on disk was intact) — the corruption wasn't limited to binaries. Worth a `git diff --stat` sanity pass on the whole tree, not just uassets.

### `save_assets` silently returns `true` but writes nothing for corrupted stub packages
A 0-byte package that's "loaded" in the editor won't re-serialize on `save_assets` — it returns success but the file stays 0 bytes (`is_dirty` reads false). **Workaround:** `AssetTools.delete` the stub, then `DataAssetTools.create` / `BlueprintTools.create` a fresh asset at the same path. The fresh asset saves normally. Re-point any Blueprint pins that referenced the old asset (they break on delete — see next).

### Blueprint asset references are hard, not soft — they break when you delete+recreate the target
After deleting and recreating an Input Action, the character's event nodes and the controller's `AddMappingContext` pins reverted to empty/None. **Re-set them** via `set_pin_value` with the asset path, then `compile_blueprint`. Verify with `get_node_infos` (not `read_graph_dsl` — see below).

### `find_node_types` only surfaces `EnhancedInputAction` events for actions already referenced in the graph
Freshly-created `IA_Crouch`/`IA_Sprint` weren't offered as `Input|EnhancedActionEvents|IA_*` node types, and `create_node` on those type_ids errored "does not exist" (Blueprint action DB indexing lag). **Workaround:** create the node using the one discoverable action event type (`...|IA_Move`), then repoint its output `InputAction` pin (index 8) to the target action with `set_pin_value`. Compile — exec pins still wire correctly even though the node's cosmetic title/pin-shape lags.

### `read_graph_dsl` mis-renders freshly-rewired nodes; trust `get_node_infos`
After rewiring input events, `read_graph_dsl` showed the events as empty-bodied `EnhancedInputActionIA_Move` stubs. `get_node_infos` on the actual nodes showed the connections were correct, and `compile_blueprint` (with `warnings_as_errors`) passed. The DSL reader is a lossy view for some node types — verify wiring via `get_node_infos` and a clean compile, not the DSL round-trip.

### DSL: member variables need explicit getters; latent/multi-out nodes need keyword pins
In `write_graph_dsl`, a bare `MyVar` only resolves to locals/params — a member variable must be `(Variables|Default|GetMyVar)` or you get "Undefined variable". And positional args bind in pin order, which put a value on `self` for `Character|LaunchCharacter` (self is arg 0). Use **keyword args** (`:LaunchVelocity ... :bZOverride true`) for anything past the first data pin. Always `get_graph_dsl_docs` before first use.

### `PhysicsVolume` cannot be a content-Blueprint parent
`BlueprintTools.create` with parent `/Script/Engine.PhysicsVolume` → "Cannot create a blueprint based on the class 'PhysicsVolume'." Volumes are brush actors that must live in a level. **For a water/pool volume:** `SceneTools.add_to_scene_from_class` a `PhysicsVolume` directly into the map, scale it (actor scale resizes the brush; default is 200³ so scale 4 → 800), then `set_properties` `{"bWaterVolume": true, "priority": 1}`. `CharacterMovementComponent` switches to `MOVE_Swimming` for free when the capsule center is inside.

### The ThirdPerson template level has a raised central mound — trace before placing
Ground is **not** flat z=0 everywhere: the spawn sits on a mound (~z=210 at origin, sloping down to the z=0 outer floor), and there are scattered raised platforms (found z=200 strips). **Always `SceneTools.trace_world` (start high, end below 0) at each intended placement XY before dropping geometry**, and probe the footprint corners for a large actor. `trace_world` returns the *distance* from start to hit, so ground_z = start_z − distance.

### CaptureViewport / big describe_toolset results overflow context — extract with Python
`CaptureViewport` returns a multi-MB base64 PNG inline; `describe_toolset` for `BlueprintTools` is ~72k chars. Both exceed the tool-result limit and get spilled to a file. **Handle it:** `python3` to `json.load` the saved file, `base64.b64decode` the `image.data` to a `.png` in scratchpad, then `Read` the PNG (Read renders images). For describe dumps, extract just the tool objects you need by short name. Pass `captureTransform` explicitly (the "optional" field is required in practice) and set `annotations.gridHeight` to your ground z for readable coordinate labels.

### Material-from-scratch via MCP (translucent unlit)
`MaterialTools.create_material` → `ObjectTools.set_properties {blendMode: BLEND_Translucent, shadingModel: MSM_Unlit, twoSided: true}` → `add_expression` a `Constant3Vector` (set `constant` LinearColor) and a `Constant` (set `r`) → `connect_to_output` to `MP_EmissiveColor` / `MP_Opacity` → `recompile`. Apply per-instance via the component's `overrideMaterials` array (don't `StaticMeshTools.set_material`, which edits the shared engine mesh). Disable a decorative plane's collision via `bodyInstance.collisionEnabled = NoCollision` so the player can pass through.

### Enhanced Input mapping JSON shape (for `ObjectTools.set_properties` on an IMC)
`mappings` is an array of `{action: {refPath}, key: {keyName: "..."}, triggers: [], modifiers: [{refPath: "/Script/EnhancedInput.InputModifier<X>"}]}`. WASD from one Axis2D action: bind `D` plain, `A` with `InputModifierNegate`, `W` with `InputModifierSwizzleAxis` (default order YXZ = swap X/Y), `S` with Swizzle+Negate. Set the array in one `set_properties` call — incremental array edits fail with "insertion points are ambiguous"; `reset_properties` the array first if you need to rebuild it.
