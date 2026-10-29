# Modular authoring, not flattened game code

- F5: `campaign/campaign.tscn`, the five-level game.
- F6: `campaign/district_entry.tscn`; choose any stable district ID in its Inspector. This playable chapter fixture never writes campaign saves.
- Open `campaign/module_workbench.tscn` in the 2D editor: independent placeable platform, one-way platform, recovery ladder, moving lift, physical receiver, objective, objective-linked door and telegraphed hazard scene instances. Move/duplicate an instance and edit its exported properties without editing its implementation. This is an editor composition example, not a separate playable level.
- `sandbox/assembly.tscn` remains the playable original actor/physics module bench.

## Three layers

1. `campaign/layouts/level_01.gd` through `level_05.gd`: editable coordinates, objective graph, encounters, text, recovery routes. A district dictionary describes placement; it never owns movement/combat rules. Raw Godot Rect2/Vector2 values are deliberately simple to edit. These layouts instantiate the same .tscn modules shown on the workbench. They are not LDtk files and no LDtk importer is claimed installed.
2. `campaign/logic/`: campaign/save/build state, placeable objective/door/hazard scripts and scenes. `simulation/world/*.tscn`, `demo/components/*`, and `combat_pc/*` continue to own established platform, ladder, cargo, enemy and player contracts.
3. `campaign/presentation/`, `campaign/views/`, `campaign/assets/`: replaceable paint. No collisions or gameplay in scenery. Five independent theme resources. Removing scenery changes no route or objective.

## New objective workflow

Add a local unique ID + kind + at position to a district's objectives. Supports must already exist below it. Dependency IDs are local to that district; the runtime rejects interaction until prerequisites are complete. Use objective_doors for consequential physical routing. Console channels are numbered **0,1,2**. All required goals gate the onward marker, so making rescue goals optional is a conscious narrative/gameplay decision. Props can break: plates should be optional unless a reliable local cradle exists. Placeable scene exports make the same mechanics available to hand-authored scene builders; bind a host exposing goal_done, room, player and state for live play.

`route` arrays are test navigation hints, never autoplay in the shipped game. Checkpoints are per district and retry resets its local circuits and enemies, but retains collected archives, lens, sense choice and one-time upgrades. Legacy save filenames are never touched.
