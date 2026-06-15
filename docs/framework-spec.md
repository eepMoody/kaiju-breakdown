# Kaiju Breakdown — Framework Architecture Spec (v0.1, draft for review)

**Status:** Draft for Ean's review. Scaffolding only — no gameplay content.
**Engine:** Godot 4.6, GDScript.
**Audience:** an AI implementer (Fable) building the first-pass framework, and Ean reviewing the design.
**Date:** 2026-06-12.

This document defines the "boring" framework — state, save/load, settings, time, locations, inventory, quests — that the interesting gameplay will be built on. It is deliberately decoupled from content. Where a decision is still open, it is called out in **OPEN QUESTION** blocks rather than guessed at.

---

## 1. Design decisions captured from the interview

These are settled and the architecture below assumes them:

- **Engine / pattern:** Godot 4.6 GDScript. Cross-cutting services are autoload singletons; per-save game state is a single serializable object that gets swapped on load.
- **Time:** Persona-style. A calendar of **days**, each day divided into a small fixed number of **segments** ("slots"). Some actions consume a segment (work, combat, relationship-building); some are free (shopping). Not a real-time wall clock. **Time is discrete and uniform: every costed action spends exactly one segment — there are no variable durations.** Rare exceptions are modeled as an explicit *skip ahead* to a discrete point (e.g. jump to evening, or to the next day), never as a multi-segment cost.
- **Overworld:** **Discrete location scenes + transitions.** Each block/interior is its own `.tscn`; a router loads them with named spawn points. Job sites are also locations.
- **Save model:** **Playthrough → snapshots + autosave.** A playthrough is a profile (chosen character/campaign); within it there are multiple manual save snapshots plus a rolling autosave. Save anywhere.
- **Inventory & crafting:** **Both** discrete part-items (instances with id + optional quality/attributes) **and** bulk materials (stackable quantities). Crafting is one general, reversible transformation: a recipe consumes **any** mix of inputs — discrete items, bulk materials, tools, consumables, money — and produces **any** mix of outputs. Flow runs both ways: combine a consumable + a material + a basic tool into an upgraded tool, or break a tool/part back down into resources. "Refinement" and "construction" are just named recipe categories, not a fixed direction.
- **Narrative:** authored in **Dialogic** (already integrated). The framework provides the goals/quests/relationships layer; the team writes the actual content.
- **Characters:** exactly two playable bodies (masculine-presenting, feminine-presenting) with **pronoun selection handled separately** from body choice.

### Guiding principles

1. **State is data, not nodes.** All persistent game state lives in one serializable object (`GameState`). Scenes/nodes read and mutate it through systems; they never *are* the save.
2. **Static content vs runtime state.** Design-time data (item definitions, tool definitions, quest definitions, location definitions) are Godot **Resources** in `res://content/`, referenced by stable string `id`. Runtime state stores only ids + instance data. This keeps saves small and survives content edits.
3. **Systems communicate through an event bus.** A global `Events` singleton decouples producers (minigame, dialogue, shop) from consumers (quests, achievements, HUD). This is what makes the quest system tractable.
4. **Reuse over rewrite.** Build on Dialogic, the existing `SvgLoader`, the existing cutting minigame, and Godot's built-in `ConfigFile`/`ResourceLoader`. Pull in a vetted save addon only if it earns its place (see §5 open question).

---

## 2. Current codebase: what exists and what changes

So the implementer isn't flying blind, here is the relevant existing surface:

| Area | Exists today | Framework change |
|---|---|---|
| Autoloads | `Dialogic` only | Add the singletons in §3 |
| Boot flow | `main.tscn` (title) → `_unhandled_input` → `change_scene_to_file(overworld)`; `intro_dialog.gd` and `overworld_prototype.gd` also hardcode scene changes / `Dialogic.start()` | Route **all** scene changes through `SceneRouter` (§7) |
| Player | `overworld/player.gd` — `CharacterBody2D`, WASD via `move_*` actions, `interact` action, controller vibration already wired | Keep; gets spawn-point placement from `SceneRouter` |
| Interaction | `InteractableArea` (Area2D) carries `part_id`, `part_svg_path`, `part_texture`, `interaction_scene`; notifies the `kaiju_manager` group | Keep; `part_id` becomes a reference into the content DB; interaction consumes a time segment |
| Harvest | `cutting_minigame.gd` slices an SVG polygon via `GodotPolygonSlicePlugin`; spawns physics fragments; emits `minigame_completed` **with no payload** | Add a typed `HarvestResult` payload and an inventory bridge (§9) |
| SVG import | `SvgLoader.load_polygon()` parses one `id="outline"` path | Extend the tag convention to author multi-zone levels (§10) |
| Narrative | Dialogic timelines (`intro`, `main`), runtime character registration in `intro_dialog.gd` | Wrap behind a thin narrative boundary so quests can observe it (§8, §5 open question) |

**Portability flag:** `GodotPolygonSlicePlugin` ships as a macOS-only GDExtension (`libGodotPolygonSlicePlugin.macos.*`). Not a blocker for scaffolding, but every other platform build will fail to load the harvest scene until Windows/Linux binaries exist. Track it before any non-Mac milestone.

---

## 3. Autoload singletons (global services)

Declared in `project.godot` `[autoload]`, in this order (Godot initializes top-down; later ones may reference earlier ones):

```
Events       res://core/autoload/events.gd        # signal bus, no state
Settings     res://core/autoload/settings.gd       # machine-global config (NOT per-save)
Database     res://core/autoload/database.gd        # loads & indexes all content Resources by id
SaveManager  res://core/autoload/save_manager.gd    # playthrough/snapshot/autosave I/O
Game         res://core/autoload/game.gd            # holds the active GameState + systems; new/load/save orchestration
Clock        res://core/autoload/clock.gd           # discrete time: spend_segment() advances exactly one; skip_to() jumps ahead to a discrete point
SceneRouter  res://core/autoload/scene_router.gd    # location transitions with spawn points
Dialogic     (existing)
```

**Why this split:** `Settings` and `SaveManager` and `Database` are genuinely global (independent of which game is loaded). `Game` owns the one thing that is per-save. `Clock` and `SceneRouter` are services that *operate on* `Game.state` but don't own persistent data themselves. Keeping the save-scoped state in exactly one place (`Game.state`) is what makes save/load a single serialize call instead of a scavenger hunt across ten singletons.

---

## 4. The runtime state model (`GameState`)

One object holds everything that belongs to a save. Systems (§6) are thin façades over slices of it. Proposed shape (GDScript-ish pseudocode; serializes to a plain `Dictionary`):

```
class GameState:
    # --- meta ---
    schema_version: int            # for migrations
    playthrough_id: String         # stable id of the parent playthrough
    save_name: String
    created_unix: int
    played_seconds: int
    body: String                   # "masc" | "fem"
    pronouns: Dictionary           # { subject, object, possessive } — chosen independently of body

    # --- time (Persona-style) ---
    calendar: {
        day: int,                  # 1-based day counter
        segment: int,              # index into Clock.SEGMENTS for the current day
        # optional later: weekday, phase, season
    }

    # --- economy ---
    wallet: { money: int }

    # --- inventory (both models) ---
    inventory: {
        items: Array,              # discrete part-instances: { uid, def_id, quality, attrs:{} }
        materials: Dictionary,     # bulk: { def_id: quantity }
    }

    # --- tools & progression ---
    tools: {
        owned: Array,              # { def_id, mods:[mod_id...], level }
        equipped: String,          # def_id or uid
    }
    upgrades: Array                # unlocked upgrade/permit/certification ids
    crew: Array                    # hired NPC ids + their state

    # --- relationships ---
    relationships: Dictionary      # { character_id: { points, level, flags:[] } }

    # --- quests ---
    quests: Dictionary             # { quest_id: { status, objectives:{ obj_id: progress } } }
                                   # status ∈ locked | offered | active | completed | failed

    # --- generic durable memory ---
    flags: Dictionary              # { key: Variant } — the source of truth for "did X happen"

    # --- world position (for resume) ---
    location: { current_id: String, spawn_point: String }

    func to_dict() -> Dictionary
    static func from_dict(d) -> GameState   # applies migrations if schema_version is old
```

**`flags` is load-bearing.** Transient actions ("talked to Snips the Mechanic") are recorded as durable flags, not as fleeting signals. That is what lets an order-independent quest condition like *"own the chainsaw **and** have talked to Snips"* resolve correctly even if the player did them in either order and reloaded in between. Signals fire the *re-evaluation*; flags + state hold the *truth*.

---

## 5. Save / load

**Directory layout** (under `user://`):

```
user://settings.cfg                              # global, separate from saves
user://playthroughs/<playthrough_id>/
    playthrough.json                             # body, pronouns, created date, display name
    autosave.json                                # rolling
    save_001.json  save_002.json  ...            # manual snapshots
    save_001.png   ...                           # optional thumbnail per snapshot
    dialogic/                                     # Dialogic's own save blob (see open question)
```

**Format recommendation — JSON, not `.tres`.** Serialize `GameState.to_dict()` to JSON with a top-level `schema_version`.

- *Why JSON:* survives renaming/removing GDScript classes (a `.tres`/`ResourceSaver` save hard-references script paths and breaks when you refactor), is diff-able and hand-editable for debugging, and is mod-friendly. Cost: you hand-write `to_dict`/`from_dict`. Mitigate with a small `Serializable` base and a convention that only whitelisted keys persist.
- *Migrations:* `from_dict` checks `schema_version` and runs ordered migration steps. Cheap to add now, painful to retrofit later — include the hook from day one even though there's only version 1.

> **OPEN QUESTION 1 — Save format.** I recommend hand-rolled JSON for refactor-resilience. The alternative is a vetted addon (e.g. a `Resource`-based save plugin) that auto-serializes but couples saves to your class layout. Given the framework will churn heavily early, I lean JSON. Your call — you have more Godot-save scar tissue than I should assume.

> **OPEN QUESTION 2 — Dialogic state boundary.** Dialogic ships its own save subsystem and its own variables. Two options: (a) **Dialogic owns narrative variables**; we persist its blob alongside our save and mirror only the handful of flags quests care about into `GameState.flags` via a Dialogic signal; or (b) **our `flags` are the single source of truth** and we push them into Dialogic on load. I lean (a) — less fighting the addon, timelines resume natively — but it means two stores that must be saved atomically together. Flagging because it's a real fork and easy to get subtly wrong.

---

## 6. Systems (façades over `GameState`)

These are plain GDScript objects owned by `Game`, reconstructed around `GameState` on load. They contain logic, not persistent data, and they emit on `Events` after every mutation so the UI/quests react.

- **Wallet** — `add(n)`, `spend(n) -> bool`, `balance()`. Emits `money_changed(new, delta)`.
- **Inventory** — `add_item(def_id, quality, attrs) -> uid`, `remove_item(uid)`, `add_material(def_id, n)`, `remove_material(def_id, n) -> bool`, `count(def_id)`, `has_item(def_id)`. Emits `item_acquired/removed`, `material_changed`.
- **Tools** — `acquire(def_id)`, `equip(...)`, `apply_mod(...)`. Emits `tool_acquired`, `tool_equipped`.
- **Crafting** — `can_craft(recipe_id) -> bool`, `craft(recipe_id)`. Validates the recipe's inputs against `GameState` (items/materials/tools/money), consumes them, and grants the outputs through `Inventory`/`Tools`/`Wallet`. A breakdown ("salvage a tool into resources") is just a recipe whose inputs and outputs are swapped — no special-casing. Emits `recipe_crafted(recipe_id, outputs)`.
- **Progression** — `unlock(upgrade_id)`, `has(upgrade_id)`, `hire(npc_id)`. Emits `upgrade_unlocked`, `crew_changed`.
- **Relationships** — `add_points(character_id, n)`, level thresholds → emits `relationship_changed(character_id, level, points)` and sets a `rel_<id>_lvl<n>` flag at each new tier (so quests can require relationship tiers without polling).
- **QuestLog** — the engine in §8.

`Game` exposes them: `Game.inventory`, `Game.wallet`, `Game.crafting`, `Game.quests`, etc.

**`RecipeDef`** (Resource, `res://content/recipes/`) — the data behind Crafting. Inputs and outputs use the same shape, which is what makes recipes reversible by simply swapping them:

```
id: String
category: String                  # "refinement" | "construction" | "salvage" | ... (cosmetic grouping)
inputs:  Array[Ingredient]        # each: { kind, ref, count }   kind ∈ item | material | tool | money
outputs: Array[Ingredient]        # same shape; an output item may carry quality/attrs
requirements: Condition           # optional gate (e.g. UpgradeUnlocked("lathe_permit"), RelationshipAtLeast)
costs_segment: bool               # true = costs the standard 1 segment; false = free (like shopping)
```

`item`/`tool` inputs can match by `def_id` (any instance) or by a specific `uid`/quality threshold — implementer's choice of granularity, but document it. Because inputs and outputs are symmetric, "salvage this tool into materials" is authored as a recipe with the tool in `inputs` and materials in `outputs`; no separate breakdown path is needed.

---

## 7. Locations & transitions (`SceneRouter`)

**`LocationDef`** (Resource, in `res://content/locations/`): `id`, `display_name`, `scene: PackedScene`, `spawn_points: { name: NodePath }` (markers in the scene), `music`, `costs_segment_on_enter: bool` (usually false). Job sites are `LocationDef`s too.

**`SceneRouter` API:**

```
SceneRouter.go_to(location_id: String, spawn_point := "default") -> void
    # 1. emit location_changing(from, to); fade out
    # 2. free current location scene
    # 3. load LocationDef.scene (ResourceLoader threaded for large maps)
    # 4. instance it; move player to spawn_points[spawn_point]
    # 5. write Game.state.location = {current_id, spawn_point}
    # 6. fade in; emit location_ready(location_id)
```

Doors/edges are `Area2D` triggers carrying a `target_location` + `target_spawn`; on body-enter (or on `interact`) they call `SceneRouter.go_to(...)`. The **player persists across transitions** (state lives in `GameState`, not the scene), so the router can keep a single player instance and re-parent it, or re-instance and re-apply state — implementer's choice, but document which.

**Replaces:** the hardcoded `change_scene_to_file` calls in `main.gd`, `intro_dialog.gd`, and the bare `Dialogic.start('main')` in `overworld_prototype.gd`. Boot flow becomes: `Boot → main menu → (new/continue) → SceneRouter.go_to(start_location)`.

---

## 8. Quests & conditions — the core of the request

You called out two resolution types: pure state ("have \$5000") and action+state ("get the chainsaw **and** talk to Snips"). Both are handled by one **composable condition tree**, evaluated **event-driven** (not polled).

**`QuestDef`** (Resource, `res://content/quests/`):

```
id: String
title, summary: String
prerequisites: Condition          # when this quest becomes "offered"/"active"
objectives: Array[Objective]      # each: { id, label, condition: Condition }
rewards: Array[Reward]            # money / item / material / tool / upgrade / unlock_quest / set_flag
auto_complete: bool               # complete the instant all objectives pass, or require a turn-in
```

**`Condition`** (Resource, polymorphic — small subclasses):

```
HasMoney(amount)
HasItem(def_id)                  HasMaterial(def_id, count)
ToolOwned(def_id)                UpgradeUnlocked(id)
FlagSet(key, value)              RelationshipAtLeast(character_id, level)
QuestCompleted(quest_id)         CalendarReached(day)
All(children: [Condition...])    Any(children: [Condition...])    Not(child)
```

> *"Get the chainsaw and talk to Snips"* = `All([ ToolOwned("chainsaw"), FlagSet("met_snips", true) ])`. The dialogue with Snips ends by setting the `met_snips` flag (via a Dialogic event/signal → `Game.set_flag`). Order-independent and reload-safe because both legs read durable state.

**Evaluation loop:** `QuestLog` subscribes to the relevant `Events` signals (`money_changed`, `item_acquired`, `flag_set`, `relationship_changed`, `tool_acquired`, `day_started`, …). On any of them it re-evaluates the `prerequisites` of `locked` quests and the `objectives` of `active` quests, updates per-objective progress, fires `quest_objective_updated` / `quest_completed`, and grants rewards. Re-evaluating only on relevant signals keeps it cheap; conditions are pure functions of `GameState`.

> **OPEN QUESTION 3 — Quest authoring surface.** I'm proposing quests as `.tres` Resources editable in the Godot inspector (designer-friendly, no code per quest). The alternative is authoring quest logic inside Dialogic timelines. I lean Resources for the *structure/rewards* and Dialogic for the *conversation*, with flags as the handshake between them — but if you'd rather drive everything from Dialogic, the condition system can instead expose a `Game.check(condition_string)` for timeline branch conditions. Worth a decision before §Phase 4.

---

## 9. Harvest → inventory bridge

The existing minigame proves the *feel* but drops the *loot*. Minimal wiring to connect it to the state layer:

- Define **`HarvestResult`**: `{ parts: Array[{def_id, quality, attrs}], materials: { def_id: qty }, hazards_triggered: int }`.
- `InteractableArea` already has `part_id` — make it (or the `HarvestLevelDef` it points to, §10) carry the `def_id`s that fragments map to.
- In the minigame, when a fragment crosses the harvestable threshold and is collected, accumulate into a `HarvestResult`. On modal close, emit `Events.harvest_completed(result)` instead of the bare `minigame_completed`.
- `Game` consumes `harvest_completed`: pushes parts/materials into `Inventory`, asks `Clock` to spend one segment (harvesting is a costed action), fires the downstream signals quests listen to.

This is the smallest change that turns the prototype into a loop that produces persistent state.

---

## 10. Authoring harvest "levels" from SVG/PNG

You asked for a system to craft minigame levels using the existing importer — and as a Ringling-trained illustrator, authoring levels as vector art plays to your strengths. Proposal:

- **`HarvestLevelDef`** (Resource): `svg_path`, `texture`, `regen_rules`, plus the mapping of SVG layer ids → semantics. (A harvest is a costed action like any other — it spends one segment; the level carries no duration of its own. Any in-level timers, like tissue regen, are real-time *feel*, not calendar time.)
- **Extend the `SvgLoader` tag convention.** Today it reads a single `id="outline"`. Define reserved ids so one SVG encodes a whole level: `outline` (cut boundary, as now), `flesh` / `bone` / `sinew` (material zones → which `def_id` a fragment yields + cut resistance), `hazard` (triggers damage/spawn), `regen` (healing tissue with a timer). `SvgLoader` returns a structured set of zones; a `LevelBuilder` assembles the minigame scene from a `HarvestLevelDef`.
- Keep this **forward-looking but thin** for the steel thread — `outline` + one material zone is enough to prove the pipeline; the rest can land as the harvest mechanic matures.

---

## 11. Settings (machine-global)

Persisted to `user://settings.cfg` via `ConfigFile`, applied on boot, independent of any save.

- **Video:** resolution, window mode (windowed / fullscreen / borderless), vsync, `max_fps`, UI scale.
- **Audio:** create an Audio Bus layout — `Master / Music / SFX / UI / Voice` — and expose a linear slider per bus (convert to dB). Mute toggles.
- **Gameplay:** language (drives `TranslationServer` locale), **profanity filter** (bool), text speed.
- **Input:** remap overrides layered over the project's default `InputMap` actions (`move_*`, `interact`, `use_tool`, etc.).

**Localization-ready from the start:** route player-facing strings through Godot's translation system (CSV/PO) rather than hardcoding, even if there's only English now. **Profanity filter:** implement as a single `Loc.filter(text)` pass (word-substitution dictionary) that the dialogue layer and UI run strings through when the toggle is on — one chokepoint, not scattered checks.

> **RESOLVED — Platform & input target.** **Desktop + controller is the primary target**, with mouse support planned (so design every interaction for both from the start). **Mobile is a future goal**, not a near-term constraint — keep input abstracted behind `InputMap` actions and avoid hardcoding control assumptions, but don't invest in touch UI now. Practical consequence: the (currently Mac-only) `GodotPolygonSlicePlugin` still needs Windows/Linux binaries before any non-Mac desktop build.

---

## 12. Proposed file layout

```
res://
  core/
    autoload/   events.gd  settings.gd  database.gd  save_manager.gd  game.gd  clock.gd  scene_router.gd
    state/      game_state.gd  serializable.gd  migrations.gd
    systems/    wallet.gd  inventory.gd  tools.gd  crafting.gd  progression.gd  relationships.gd  quest_log.gd
    defs/       item_def.gd  material_def.gd  tool_def.gd  upgrade_def.gd  character_def.gd
                location_def.gd  quest_def.gd  condition.gd  reward.gd  recipe_def.gd  harvest_level_def.gd
  content/      items/  materials/  tools/  upgrades/  characters/  locations/  quests/  recipes/  levels/   (.tres)
  ui/           main_menu/  save_load/  settings/  hud/  inventory/  pronoun_select/
  cutting_minigame/   overworld/   story/   dialogic/   addons/        (existing)
  docs/         framework-spec.md   (this file)
```

---

## 13. Build order (steel-thread sequence for Fable)

Each phase is independently testable; prove persistence before building on it. gdUnit4 is available in this project — add tests at the marked points.

- **Phase 0 — Spine.** Autoloads `Events`, `Settings`, `Game`, `SaveManager`. `GameState.to_dict/from_dict`. New-game → mutate a trivial value → save → quit → load round-trips. **Test:** save/load round-trip equality. *This is the single most important phase; everything hangs off it.*
- **Phase 1 — Locations.** `SceneRouter` + `LocationDef` + spawn points. Convert title → intro → overworld to route through it. Door triggers between two stub locations. Player position resumes from save.
- **Phase 2 — Time + content DB.** `Clock` (Persona segments: `spend_segment()` advances exactly one, free vs costed actions, `skip_to()` for discrete jumps, `day_started`/`day_ended`). `Database` indexes content Resources by id.
- **Phase 3 — Economy & harvest bridge.** `Wallet`, `Inventory` (items + materials). Add `HarvestResult` + `Events.harvest_completed`; wire the existing cutting minigame into inventory; spend a segment per job. **Test:** harvest yields persist across save/load.
- **Phase 4 — Relationships & quests.** `Relationships`, `QuestLog`, the `Condition` tree. Ship the demo quest: *acquire chainsaw + talk to Snips → quest completes → reward granted*, proving both state-triggered and action+state resolution and reload-safety. **Test:** condition evaluation incl. order-independence across a reload.
- **Phase 5 — Progression surface.** `Tools`/mods, `Progression` (upgrades/permits/crew), the `Crafting` system + `RecipeDef`s (one reversible transform covering refinement, construction, and salvage — demo a craft *and* its inverse), and a job-board UI that offers `LocationDef` jobs gated by quests/upgrades.
- **Cross-cutting (any phase):** full Settings menu + save/load menu + pronoun/body select on new game.

---

## 14. Open questions, collected

1. **Save format** — hand-rolled versioned JSON (my lean) vs a Resource-based save addon. (§5) — *bears on the adopt-vs-build decision in §15.*
2. **Narrative engine + state boundary** — which dialogue engine (Dialogic if GDScript; Ink/GodotInk or Yarn if C# — see §15), and whether it owns narrative vars while we mirror flags (my lean) vs our flags being the single source of truth. (§5, §15)
3. **Quest authoring surface** — quests as inspector-edited Resources (my lean) vs driven from Dialogic timelines, and whether to adopt a quest addon or hand-roll. (§8, §15)
4. ~~**Platform/input target**~~ — **RESOLVED:** desktop + controller primary, mouse planned, mobile future. (§11)
5. **Adopt a base template?** — whether to build the menu/settings/scene-transition/save spine on Maaack's Game Template or assemble it ourselves. This is the highest-leverage decision and should be made first, because it reshapes §3/§7/§11. (§15)
6. **Implementation language** — GDScript vs C#. Now roughly neutral: web isn't a target, desktop is fully C#-mature, and C#-native narrative engines (Ink/Yarn) remove the Dialogic-interop objection. Decide on engineering ergonomics; the only residual C# seam is one GDScript shim for the slice plugin. (§16)

Everything else above I'm comfortable building on as written — but flag anything that doesn't match your mental model; I've inferred plenty and would rather correct it now than in code.

---

## 15. Off-the-shelf building blocks (candidates)

Per the directive to reuse vetted work, here's what currently exists for each subsystem, with an honest fit assessment. **Compatibility caveat:** the project is on Godot 4.6; most of these advertise 4.3–4.4+ and will *probably* work, but each must be smoke-tested against 4.6 before committing — I'm not certifying 4.6 support from a listing.

| Subsystem (spec §) | Strong candidate | Fit assessment / recommendation |
|---|---|---|
| **Menus + Settings + Scene transitions + Save plumbing** (§3, §7, §11) | **Maaack's Game Template** | Bundles main/pause/options menus (video, audio buses, keybinding — keyboard **and** gamepad), a scene loader for transitions, UI sound + music controllers, and game-saving scaffolding. Game-agnostic, 4k→640×360. This is the single biggest shortcut and matches our desktop+controller+mouse target. **Recommend adopting early or not at all** — it brings its own autoload/scene conventions, so retrofitting later is painful. |
| **Per-entity state machines** (cutting minigame) | **Godot State Charts** (`derkork/godot-statecharts`) | Idiomatic node/signal statecharts; avoids FSM state-explosion; has a `StateChartSerializer` for save. Good fit to replace the hand-rolled `enum State` in `cutting_minigame.gd`. Note: this is *behavioral* FSM, **not** our global event bus — `Events` stays a trivial hand-written signal hub. |
| **Inventory** (§4, §6) | **GLoot** (`peter-kish/gloot`); **expressobits/inventory-system** | GLoot is the most-used universal inventory (slots, constraints, serialization), but it's **grid/slot-oriented**; our bulk-materials-as-quantities + heterogeneous crafting may be simpler hand-rolled on top of `GameState`. expressobits includes crafting + multiplayer, closer to our `RecipeDef` idea. Caveat: GLoot v3 introduced breaking changes — version churn is real. **My lean: evaluate GLoot for the discrete part-items, keep bulk materials + recipes hand-rolled.** |
| **Quests** (§8) | **shomykohai/quest-system** (resource-based, modular); **TheWalruzz/godot-questify** (visual graph editor) | shomykohai aligns with our resource-based `QuestDef`; Questify gives designers a node-graph authoring UI. **Honest caveat:** quests are our most game-specific logic, tightly coupled to the `Events` bus + `flags` + Dialogic. An addon may fight that integration. **My lean: hand-roll the thin `Condition`/`QuestLog` layer** (it's small and we control it), but borrow patterns — or Questify purely for authoring if you want a visual editor. |
| **Save/load file I/O** (§5) | **SaveMadeEasy** (`AdamKormos`); **Addon Save (4.x)**; **Thoth** | If we don't adopt Maaack's saving, these handle the file plumbing (nested vars, Resources, encryption, backups, screenshots). They don't solve **schema migration** — that stays ours. **My lean: use one for plumbing, keep our versioned `GameState` dict as the payload** (preserves the JSON/migration decision in OQ1). |
| **Dialogue / narrative** (§8) | **Ink + GodotInk** (`paulloz/godot-ink`); **Yarn Spinner** (`YarnSpinnerTool/YarnSpinner-Godot`); **Dialogue Manager 4** (`nathanhoad`); **Dialogic** *(current)* | Dialogic was a prototype convenience and is **disposable**. If we go C#, switch the narrative layer to a C#-capable engine: **Ink/GodotInk** is the most C#-native fit (MIT, .NET-flavour Godot, every feature usable from C#; Ink is proven in shipped narrative games); **Yarn Spinner** has an official Godot *C#* integration and a huge track record (Night in the Woods, DREDGE) but its Godot port is still beta and "may break/change"; **Dialogue Manager 4** is GDScript but ships an official C# wrapper and is lighter than Dialogic. All three are plain-text, version-control-friendly scripting (good for writers) and integrate cleanly with external game state via variables/commands/functions — ideal for relationship/quest hooks. **Lean if C#: Ink/GodotInk** for stability, Yarn if writer-callback ergonomics win out. |
| **Time / Persona-style segments** (§4) | **World Time & Game Calendar** (Chris' Tutorials, ~\$30) | **Likely a poor fit, flagging honestly.** It's built around a *continuous real-time* day/night clock with time-scaling and object-aging — the opposite of our discrete one-segment model. The *calendar/EventDay* piece is reusable, but the engine assumes continuous time. **Recommend: hand-roll the discrete `Clock`** (it's tiny — day counter + segment index + `skip_to`); skip the plugin. |
| **Reference projects** (whole-game study) | `gdquest-demos/godot-open-rpg`; `nilold/farmer-game`; vegetato farming template | Useful to read for RPG/farming patterns, **not** dependencies — treat as study material, not infrastructure. |
| **Discovery** | `godotengine/awesome-godot` | The curated meta-list; first stop when a new subsystem need appears. |

**Net recommendation.** The highest-value adoptions are **Maaack's Game Template** (kills most of the boring menu/settings/transition/save spine) and **Godot State Charts** (cleans up the minigame and any future stateful entity). Inventory and quests are judgment calls where a *thin hand-rolled layer over `GameState`* probably beats fighting an addon's assumptions — but GLoot/Questify are worth a timeboxed evaluation. The time system and event bus are small enough that addons add more coupling than they save. None of this changes the §13 build order; it changes *how much of each phase is assembly vs authoring*.

---

## 16. Language: GDScript vs C#

Godot lets both languages coexist in one project, so this isn't all-or-nothing — but the cross-language boundary is **dynamic** (`Call("method", …)`, no compile-time type safety, a small per-call cost), so a mixed project pays a tax at every seam. The decision matters less for day-to-day coding ergonomics than for **export targets and addon interop**, which is where it bites *this* project specifically.

**What C# would gain:** static typing, stronger refactoring/IDE tooling (Rider/VS), the NuGet ecosystem, and better CPU performance for heavy logic. There's also a mature **C#-native** stack (Chickensoft — LogicBlocks state machines, serialization, SaveFile, dependency injection) that overlaps several subsystems here, and Godot State Charts supports C# directly. So in pure "systems code in isolation," C# genuinely offers *more* and nicer options.

**Target is Steam/desktop, web is explicitly not a goal** — which removes what would otherwise be C#'s biggest disqualifier (Godot 4 can't export C# to web/WASM). On desktop, **C# is fully mature and ships fine.** So the language choice here is a near call about interop friction and ergonomics, not a hard platform blocker.

**What C# still costs us, given where this project already is:**

- **Mobile export: experimental** for both Android (.NET 7+, arm64/x64 only, some APIs e.g. SSL crash) and iOS (NativeAOT, reflection can break at runtime) — flagged experimental in the export UI. **Mobile is only a future/maybe goal**, so this is a lower-weight risk now (and C# mobile may mature by the time it matters) — but if mobile becomes real, GDScript is the lower-risk path.
- **The core mechanic's native plugin** (`GodotPolygonSlicePlugin`, a GDExtension) **is not directly callable from C#** — Godot doesn't generate C# bindings for GDExtensions. We'd need a GDScript bridge to call our own slicing code. Friction on the single most important system.
- **Dialogic has no official C# API.** It must be autoloaded, and from C# you reach it through GDScript interop (dynamic calls, no type safety). Dialogic is central to the narrative layer, so we'd live in that seam constantly.
- **The entire existing prototype is GDScript** (`cutting_minigame`, `svg_loader`, `player`, `overworld`, `utilities`). Switching means rewriting it or accepting a permanent mixed-language project.

**Lean (updated): the balance has shifted to roughly neutral, with the tiebreaker now being which language *you* are faster and happier in.** Two facts moved it. First, web is not a target and desktop is fully C#-mature, so there's no platform blocker. Second — the decisive one — **Dialogic is disposable, and there are first-class C#-native narrative engines** (Ink/GodotInk, Yarn Spinner, or Dialogue Manager's C# wrapper; see §15). That dissolves the "persistent Dialogic-interop tax" that was the main remaining argument for GDScript.

**What still slightly favors GDScript:** the addons we'd most likely adopt (Maaack's template, GLoot, the quest systems) are GDScript, so an all-GDScript stack stays in one typed world with zero interop seams. **What now makes C# clean:** with a C#-native narrative engine, the only remaining cross-language seam is **one** GDScript bridge around the `GodotPolygonSlicePlugin` GDExtension — a single wrapper, not a pervasive tax. Pair that with the **Chickensoft** C#-native stack (LogicBlocks, serialization, SaveFile, DI) for state/save/FSM and a C# project is coherent and arguably nicer to maintain at scale.

**Decision framing:** the existing prototype is small and explicitly disposable, so the rewrite cost is low and now is the cheapest moment to switch. **If you lean C# for engineering ergonomics, the path is clear: C# game code + Ink (or Yarn) for narrative + Chickensoft for systems + a thin GDScript shim for the slice plugin.** If you're indifferent, GDScript remains the lowest-friction default. I no longer have a strong directional lean — this is genuinely your call, and the engineering-comfort factor (which I can't weigh for you) should probably decide it.

*Uncertainty flags:* YarnSpinner-Godot is a beta/unofficially-supported port (Ink/GodotInk is the more stable Godot integration); and I haven't verified Godot 4.6-specific C# mobile-export maturity — only relevant if/when mobile becomes live. Verify both against 4.6 before committing.
