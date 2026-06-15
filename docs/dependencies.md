# Kaiju Breakdown — Dependencies at a Glance

**Stack:** Godot 4.6 (.NET/C#) · Desktop/Steam

## Dependencies to adopt
- **Yarn Spinner for Godot (C#)** — dialogue & branching narrative (**MIT**; the C# Godot integration + core libs are MIT — only the older GDScript port is YSPL)
- **Chickensoft LogicBlocks** — serializable state machines (minigame + game flow)
- **Chickensoft SaveFileBuilder + Serialization** — save/load + versioned JSON
- **Chickensoft AutoInject** *(optional)* — dependency injection
- **gdUnit4 or Chickensoft GoDotTest** — testing (C#)
- **Chickensoft GameTemplate / GodotGame** *(project scaffold)* — C# repo boilerplate: testing, CI/CD, debug configs, **Steamworks.NET ready**. (Not menus/UI.)
- *(Menus/settings: built in C# ourselves — no Maaack. Ref: Chickensoft **GameDemo**.)*

## Current code to port, replace, or rewrite
- **PolygonSlicePlugin** (slicing, **our own code**) — **port** GDExtension → **C#** + add **Windows/cross-platform** builds; owned by our slicing dev. Demo version was written for approachability, not portability.
- **Dialogic** (prototype dialogue) — **replace** with Yarn Spinner
- **SvgLoader** (SVG→polygon importer) — **port to C#** or keep as a small GDScript util (only remaining seam if kept)
- **Existing GDScript prototype** (cutting minigame, overworld, player, utilities) — **rewrite to C#** while small

## Build ourselves (C#)
- `GameState` + systems: inventory (parts + materials), wallet, tools, progression, relationships, crafting
- Events bus · Clock (Persona segments) · QuestLog + conditions · SceneRouter · Settings
- Harvest→inventory bridge · HarvestLevelDef (tagged-SVG levels) · Yarn↔GameState glue
