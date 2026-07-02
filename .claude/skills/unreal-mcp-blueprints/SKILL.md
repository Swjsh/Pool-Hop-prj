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
- **PURE nodes (no exec pins — plain variable getters, `Math|*`, `Array|Length/ContainsItem`, `HasAuthority`, `GetGameMode/GetGameState`, `Components|GetOwner`) are NOT cached even when you `bind` once and wire the single output to multiple consumers.** Blueprint re-evaluates a pure node **fresh at each consumption point** in exec order. If you read a variable, then later in the same function *reset* that variable, then have a THIRD statement (positioned after the reset) that re-consumes the *same bound* pure-read — that third consumer sees the NEW (post-reset) value, not the frozen original, even though it's the same DSL variable name / same graph node. **Concretely:** don't `(bind atRisk (Get...)) ... (Set... 0) ... (SomethingElse using atRisk)` — reorder so every use of `atRisk` happens *before* the reset, or nest the reset as the LAST statement in the same exec branch as its last consumer. This bit Step 3's `Server_BankAtRisk`/`Server_LoseAtRisk` — compiled clean, `get_node_infos` showed perfectly correct wiring, but live PIE testing showed GameState's delta come out wrong because the reset ran before the GameState math re-pulled the same "old value" node. See LESSONS for the full story — this class of bug is invisible to compile checks and even to static graph inspection; only a live runtime read catches it.
- **User-created custom Blueprint functions default to impure (have `execute`/`then` exec pins) even with zero side effects** — no tool exposes a "Pure" toggle. Never inline a call to your own custom function inside an arithmetic expression; always `(bind x (CallFunction|MyFunc ...))` as its own statement, then use `x`.
- **Cross-object vs. self calls use different type_id prefixes — don't assume, `find_node_types` from the actual calling graph.** Calling another Blueprint's member/function from a DIFFERENT class's graph uses `Class|BP<ClassNameNoUnderscores>|<Member>` (e.g. `Class|BPPlayerGameMode|ServerAddScore`); calling a Blueprint's own function from within its own graph uses `CallFunction|<Name>` instead (e.g. `CallFunction|GetCrewMultiplier`) — the same function has TWO different type_ids depending on who's calling. Boolean vars strip their `b` prefix in both accessor forms (`bIsScoring` → `GetIsScoring`/`SetIsScoring`, not `GetbIsScoring`).
- **`(event EventName ...)` for engine-overridable events (collision/mouse/touch) needs the category prefix from `find_node_types`'s `AddEvent|...` result**, not the bare event name — `EventActorBeginOverlap` fails, `Collision|EventActorBeginOverlap` works (matching `AddEvent|Collision|EventActorBeginOverlap` minus the `AddEvent|` prefix). `EventBeginPlay`/`EventTick` have no category and work bare. Always check `find_node_types(graph, "AddEvent|")` first.

Discover node type_ids with `find_node_types(graph, type_id_filter, context_pins=[])` and their pins with `get_node_type_pins(graph, type_id)` before writing DSL.

## Wiring graphs — surgical edits to existing graphs

When a graph already has content you must not clobber (e.g. the duplicated character's input handlers), edit at the node level instead of rewriting via DSL:
- `find_nodes(graph, title, node_class?, entry_points_only?)` and `get_node_infos([nodes])` to map the existing graph. Pin identity is `{direction, index_id, node:{refPath}}`.
- `create_node(graph, type_id, pos)`, `connect_pins(output_pin, input_pin)`, `break_pins(...)`, `set_pin_value(pin, value)`, `delete_node(node)`.
- Insert logic mid-flow: `break_pins` the existing exec link, then wire `A → new nodes → B`.

## Gotchas (verified in this project — see Docs/LESSONS.md)

- **`connect_pins` does NOT support exec-pin fan-out — treat it as single-connection-per-output-pin, always.** In the graphical Blueprint editor, one output exec pin can drive multiple wires (both fire in order). Calling `connect_pins` a SECOND time on an already-connected output pin does not add a parallel branch — it **silently replaces** the existing connection. `{"returnValue":null}` reports success either way, so this is invisible unless you re-check. To add new logic that should fire *alongside* an existing chain (not instead of it), splice linearly instead: `break_pins` the existing link, connect the event's output to your new node, then connect your new node's own `then` output to the ORIGINAL target (`Event → YourNewNode → OriginalTarget`). After touching any pin that already fed a load-bearing chain, immediately `get_node_infos` on BOTH ends (source and original destination) to confirm the original link survived — a clean compile won't catch a disconnected-but-otherwise-valid exec pin (see LESSONS 2026-07-02, `NS_PoolSplash`/`BP_PoolVolume` — caught before shipping a silently-broken pool-scoring path).
- **Enhanced Input event nodes — the action binding is baked at node creation, NOT settable via the pin.** A `K2Node_EnhancedInputAction` event binds to the action it was *created* with (`Input|EnhancedActionEvents|IA_<X>`). Setting its output `InputAction` pin with `set_pin_value` changes only the pin's *display* — the event stays bound to the original action. **Do not use that as a workaround** (it silently mis-binds; if you point several event nodes at the same action this way, you get duplicate bindings that collide and kill the whole input component — no input at all). Verify real bindings with `get_node_infos`: the node's `type_id` (e.g. `...EnhancedInputActionIA_Jump`) is the truth, not the pin value.
  - `find_node_types` only offers `Input|EnhancedActionEvents|IA_<X>` for actions the **action database has indexed** — a freshly-created/recreated Input Action won't appear until it's been saved and the DB refreshes (it does so on its own shortly after; re-query until all your actions appear). Once offered, `create_node` with that exact type_id makes a genuinely-bound event. To fix a mis-bound node: delete it and `create_node` with the correct `IA_<X>` type, then rewire its exec/data pins to the downstream logic.
- **Asset references are hard**: deleting+recreating a referenced asset (Input Action, mesh, material) breaks the pins that pointed at it. Re-`set_pin_value` them and recompile.
- **`read_graph_dsl` is a lossy view** for some freshly-rewired nodes — it may show empty bodies. Trust `get_node_infos` + a clean `compile_blueprint(warnings_as_errors=true)` over the DSL round-trip.

## Always finish with

1. `compile_blueprint(bp, warnings_as_errors=true)` — catches dangling refs / missing pins.
2. `AssetTools.save_assets([])` then verify on disk (`ls -la`, `find ... -size 0`) — some saves silently no-op (see LESSONS).
3. **For any logic with multiple reads/writes of the same state (score math, resets, accumulators), verify with a live PIE run reading actual property values** (`StartPIE` → `ActorTools.set_actor_transform` to place the pawn where needed → `ObjectTools.get_properties` on the real PlayerState/GameState instances) — a clean compile and a correct-looking `get_node_infos` dump can BOTH be true while the runtime numbers are wrong (see the pure-node re-evaluation gotcha above).
4. Commit the chunk.
