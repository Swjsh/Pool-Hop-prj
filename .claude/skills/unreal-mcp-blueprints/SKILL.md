---
name: unreal-mcp-blueprints
description: Author and edit Unreal Engine Blueprints through the unreal-mcp server — create classes, add variables/functions/events, wire graphs via the write_graph_dsl S-expression language or low-level create_node/connect_pins, set class defaults, and compile. Use when building or modifying any Blueprint (character, GameMode, components, actors) in this UE 5.8 project via MCP. Covers the DSL grammar, the reference/indexing gotchas, and verification.
---

# Authoring Blueprints via unreal-mcp

The `unreal-mcp` server drives the live UE 5.8 editor. Blueprint tools live in the `editor_toolset.toolsets.blueprint.BlueprintTools` toolset. Call `mcp__unreal-mcp__call_tool` with `toolset_name` + `tool_name` + `arguments`.

## Loading the tool schemas

`describe_toolset("editor_toolset.toolsets.blueprint.BlueprintTools")` is ~72k chars and overflows the tool-result limit (it spills to a file). **Don't fetch it whole repeatedly.** Grep the spilled file for `"name":"...BlueprintTools\.[a-z_]+"` to list tools, then extract the few you need with Python:

```python
import json
data = json.load(open(SPILLED_FILE, encoding='utf-8'))
want = {'create','add_variable','write_graph_dsl','compile_blueprint',...}
out = {t['name'].split('.')[-1]: t for t in data['tools'] if t['name'].split('.')[-1] in want}
```

Object paths for a Blueprint use the doubled form: `/Game/Path/BP_Foo.BP_Foo` (asset.object), and its generated class is `BP_Foo.BP_Foo_C`. Graphs are `/Game/Path/BP_Foo.BP_Foo:EventGraph` (or `:FunctionName`). Nodes are `<graph>.K2Node_...`.

## Creating classes

- `BlueprintTools.create(folder_path, asset_name, asset_type={refPath})` — parent by class path, e.g. `/Script/Engine.GameStateBase`, `/Script/Engine.PlayerState`, `/Script/Engine.Actor`. Discover valid parents with `ObjectTools.search_subclasses(base_class, class_name_substr)`.
- **Reuse working template BPs by duplicating**, not reparenting: `AssetTools.duplicate("/Game/ThirdPerson/Blueprints/BP_ThirdPersonCharacter", "/Game/_Project/Characters/BP_PlayerCharacter")` preserves the camera boom, movement tuning, and the wired Anim Blueprint — far less work than rebuilding.
- Some engine classes **can't** be Blueprint parents (e.g. `PhysicsVolume` — it's a brush/level actor). Place those directly in a level instead (see `unreal-mcp-scene-building`).

## Class defaults (DefaultPawnClass, speeds, component props)

Get the CDO with `BlueprintTools.get_default_object(blueprint)` → returns `...Default__BP_Foo_C`. Then `ObjectTools.set_properties(instance=CDO, values="{...json...}")`. Property names are lowerCamel (`defaultPawnClass`, `playerControllerClass`, `gameStateClass`, `playerStateClass`, `maxWalkSpeed`). Class-reference values take `{refPath: "/Game/.../BP_X.BP_X_C"}`.

**New member variables aren't settable on the CDO until the BP compiles.** Add the variable → `compile_blueprint` → then `set_properties` its default. Order matters.

Components are addressed as `CDO:ComponentName` (e.g. `...Default__BP_PlayerCharacter_C:CharMoveComp`). List them with `ActorTools.get_components(CDO)`. To enable crouch, set the movement component's `navAgentProps` with `bCanCrouch:true` (send the whole struct).

## Variables, functions, events

- `add_variable(bp, name, type_name)` — primitives (`bool int float byte string name text`) + basic structs (`Vector Rotator Transform Vector2D LinearColor`). Use `add_struct_variable` / `add_object_variable` for other types.
- `set_variable_replication(bp, name, "Replicated"|"RepNotify"|"None")` — RepNotify auto-creates the `OnRep_` function. **Use this for shared/authoritative state on GameState/PlayerState** (the project's core discipline).
- `add_function_graph(bp, name)` then `add_function_param(graph, name, type, input_param=false)` for a return value. Idempotent — returns the existing graph if the name matches.
- `add_event(bp, event_name)` — override an inherited event (`ReceiveBeginPlay`) or make a custom event. Idempotent.

## Wiring graphs — prefer the DSL

`write_graph_dsl(graph, code)` converts an S-expression program into nodes **and compiles**. Call `get_graph_dsl_docs()` once for the full grammar. Essentials:

```lisp
(fn TryVault ()
  (bind loc (Transformation|GetActorLocation))
  (bind fwd (Transformation|GetActorForwardVector))
  (bind traceEnd (+ loc (* fwd (Variables|Default|GetVaultTraceDistance))))
  (bind (hit didHit) (Collision|LineTraceByChannel :Start loc :End traceEnd))
  (if didHit
    (Character|LaunchCharacter :LaunchVelocity (+ (* fwd (Variables|Default|GetVaultLaunchForwardSpeed))
                                                  (Math|Vector|MakeVector :X 0.0 :Y 0.0 :Z (Variables|Default|GetVaultLaunchUpSpeed)))
                              :bXYOverride true :bZOverride true)
    (return true)
    (else (return false))))
```

DSL rules that bite:
- **Member variables need explicit getters**: `(Variables|Default|GetMyVar)`, not bare `MyVar` (bare names = locals/params only). Set with `(Variables|Default|SetMyVar value)`.
- **Use keyword pins for anything past the first data arg** on functions with a `self`/multi-input signature — positional args bind in pin order and will land a value on the wrong pin (e.g. `self`). `:PinName value`.
- `(bind (a b) (Node ...))` destructures multiple outputs. `(if cond ... (else ...))` — `else`/`elif` must be the last form in the body.
- Quote class paths / enum values / asset refs (`"/Script/Engine.StaticMeshActor"`, `"AlwaysSpawn"`) — unquoted words are treated as variables.
- Bind a node output once and reuse the variable; re-calling a node re-executes it.

Discover node type_ids with `find_node_types(graph, type_id_filter, context_pins=[])` and their pins with `get_node_type_pins(graph, type_id)` before writing DSL.

## Wiring graphs — surgical edits to existing graphs

When a graph already has content you must not clobber (e.g. the duplicated character's input handlers), edit at the node level instead of rewriting via DSL:
- `find_nodes(graph, title, node_class?, entry_points_only?)` and `get_node_infos([nodes])` to map the existing graph. Pin identity is `{direction, index_id, node:{refPath}}`.
- `create_node(graph, type_id, pos)`, `connect_pins(output_pin, input_pin)`, `break_pins(...)`, `set_pin_value(pin, value)`, `delete_node(node)`.
- Insert logic mid-flow: `break_pins` the existing exec link, then wire `A → new nodes → B`.

## Gotchas (verified in this project — see Docs/LESSONS.md)

- **Enhanced Input event nodes**: `find_node_types` only offers `Input|EnhancedActionEvents|IA_<X>` for actions already referenced in the graph; `create_node` on an un-indexed one errors "does not exist". Workaround: create the discoverable one (e.g. `...|IA_Move`), then `set_pin_value` its output `InputAction` pin (the `Input Action Object Reference` pin, index ~8) to the asset path you actually want. Exec pins wire correctly regardless of the cosmetic node title.
- **Asset references are hard**: deleting+recreating a referenced asset (Input Action, mesh, material) breaks the pins that pointed at it. Re-`set_pin_value` them and recompile.
- **`read_graph_dsl` is a lossy view** for some freshly-rewired nodes — it may show empty bodies. Trust `get_node_infos` + a clean `compile_blueprint(warnings_as_errors=true)` over the DSL round-trip.

## Always finish with

1. `compile_blueprint(bp, warnings_as_errors=true)` — catches dangling refs / missing pins.
2. `AssetTools.save_assets([])` then verify on disk (`ls -la`, `find ... -size 0`) — some saves silently no-op (see LESSONS).
3. Commit the chunk.
