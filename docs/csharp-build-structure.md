# Kaiju Breakdown — C# Build Structure (for dev discussion)

**Target:** Godot 4.6 **.NET/C#** · Desktop (Steam) · controller-first + mouse · web not a target, mobile a future maybe.
**Narrative:** Yarn Spinner (Godot C# integration).
**Principle:** adopt vetted C#-native libs for the generic stuff; build the game-specific systems ourselves over one serializable `GameState`.

---

## Adopt (off-the-shelf)

| Dependency | Role | Lang | License | Notes |
|---|---|---|---|---|
| **Yarn Spinner for Godot (C#)** | Dialogue / narrative scripting | C# | **MIT** | Writer-friendly `.yarn` scripts; commands/functions hook game state. The C# Godot integration (YarnSpinnerTool/YarnSpinner-Godot) and core YarnSpinner libs are MIT — only the older GDScript port is YSPL. Verified against v0.3.22 LICENSE (MIT, Secret Lab Pty Ltd & contributors). Still **bundle the MIT license text** when shipping. |
| **Chickensoft LogicBlocks** | Serializable state machines | C# | MIT | Cutting-minigame states + top-level game flow. Auto-generates state diagrams. |
| **Chickensoft SaveFileBuilder** | Save composition | C# | MIT | Compose save chunks from across the tree into one file → our versioned JSON. |
| **Chickensoft Serialization** | JSON (de)serialization + versioning | C# | MIT | Backs the save format + schema migrations. |
| **Chickensoft AutoInject** *(optional)* | Dependency injection | C# | MIT | Reflection-free node DI. Adopt only if we feel the wiring pain. |
| **Chickensoft GoDotTest** *(or gdUnit4)* | Testing | C# | MIT | gdUnit4 already in repo and supports C#; pick one. |
| **Chickensoft GameTemplate / GodotGame** | Project scaffold (CI, testing, debug, **Steamworks.NET**) | C# | MIT | Start the repo from this. Engineering boilerplate — **not** menus/UI. |

---

## Build ourselves (C#, over `GameState`)

- **`GameState`** — one serializable model: calendar, wallet, inventory (part-items + bulk materials), tools, upgrades, crew, relationships, quests, flags, location.
- **Systems** (façades + signals): Inventory, Wallet, Tools, Progression, Relationships, **Crafting/Recipes** (any item/material/tool/money as input or output).
- **Events bus** — global C# signal hub decoupling producers from consumers.
- **Clock** — discrete Persona segments: `SpendSegment()` (always 1), free actions, `SkipTo()` for jumps, `DayStarted/Ended`.
- **QuestLog + Condition tree** — event-driven re-evaluation; handles state ("have $5000") and action+state ("own chainsaw AND talked to Snips") via durable flags.
- **SceneRouter + LocationDef** — discrete location scenes, named spawn points, fade transitions.
- **Settings** — video / audio buses / input remap / language / profanity → `user://settings.cfg` (+ menus if not using Maaack).
- **Harvest bridge** — cutting minigame emits typed `HarvestResult` → Inventory; spends one segment.
- **HarvestLevelDef + SVG loader** — author levels as tagged SVG layers (`outline`/`flesh`/`bone`/`hazard`/`regen`). Port existing `SvgLoader` to C# *or* keep as a small GDScript util.
- **Yarn ↔ state glue** — `VariableStorage` backed by `GameState.flags`; register Yarn commands/functions for quest, relationship, and inventory hooks.
- **Polygon slicing (port of our own code)** — rewrite the in-house GDExtension slicer to **C#** and add **Windows/cross-platform** builds. Owned by our slicing dev; the demo's GDExtension was written for approachability, not portability. Porting to C# removes the last cross-language seam.

---

## Cross-language seams

**None planned.** Maaack is dropped and the slice plugin is being ported to C#, so the whole stack is C#. (Only exception: if we keep `SvgLoader` as a GDScript util instead of porting it — see below.)

---

## Proposed layout

```
res://
  game/            # C#: core/ state/ systems/ defs/
  narrative/       # .yarn scripts + C# dialogue presenter
  minigames/cutting/
  overworld/
  content/         # item/tool/quest/location/recipe/level defs
  addons/          # YarnSpinner-Godot
```

---

## Open for the team

1. **Save:** **Chickensoft SaveFileBuilder/Serialization** vs hand-rolled JSON?
2. **SvgLoader:** port to C# vs keep as a GDScript util (the only thing that would reintroduce a seam)?
3. **Existing GDScript prototype** (cutting minigame, overworld, player) — rewrite to C# now while it's small/disposable. (Recommended: yes.)
4. **Slice-plugin port** — confirm timeline with our slicing dev for the C#/Windows rewrite.
