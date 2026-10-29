# Campaign authored-layout contract

Five levels: street prologue, Exchange foundry, submerged residences, memory works, crown. Each level is a sequence of 6–8 substantial independently checkpointed districts. Design target 15–20 minutes per level is NOT verified duration. Never fill with waiting, enemy-health inflation, or cloned rooms.

Each `campaign/layouts/level_0N.gd` extends RefCounted and provides `static func sectors() -> Array[Dictionary]`. Every district uses existing `demo/mission_data.gd` dictionary schema (`id`, `title`, `subtitle`, `width`, `theme`, `platforms:Array[Rect2]`, `enemies`, `props`, optional relays, shutters, ladders, lifts, freight, cache, station, signs, top, gate_y). IDs must be unique. Add `level: int` (1–5), `level_name: String`. Width typically 3500–8500 with genuine upper/lower route choices, safe recoveries, occluding structures and mixed encounter situations. One-way platforms <=18px thick; fixed solids >18. Ground y300. Ladder [x,bottom,height]. Platforms use raw Rect2. Spawn defaults75,300; exit at width-45,gate_y(default300). No enemy-all-kill gate except district boss. Existing stats untouched. Use low-pressure approach at spawn.

New supported extension: `objectives:Array[Dictionary]`. Each has unique local `id`, `label`, `kind`, `at:Vector2`, optional `requires:Array[String]` (local prerequisite objective IDs), `optional:bool` default false, `text` (short environmental finding), `reward` (optional "vitality", "force", "agility"; one-time minor build reward). Kinds:
- `recover`: E picks up a named item/data; move elsewhere to install it.
- `install`: E after required recovered item(s), physically opens linked door.
- `route`: E cycles a switch 0→1→2→0; `target:int` desired circuit 0..2. Visibly labeled target and position. Actual target setting satisfies it; can be changed again until district departure.
- `rescue`: E opens evac pod after prerequisites. Changes visible NPC/pod state; non-repeatable.
- `terminal`: E performs a named actual objective after prerequisites (e.g. isolate manual reset).
- `breaker`: two real strike-damage units through the approved ContactAdapter/StrikeHealth; J/contact only, E cannot complete it. Opens linked objective doors.
- `plate`: requires an ordinary movable prop at `at` within48px (NOT player / no E activation); an authentic prop-placement objective. Place accessible props near it, no mandatory jump of cargo.
Add `objective_doors:Array[Dictionary]` with `at`, `size:Vector2`, `requires:Array[String]`. Physical StaticBody blockers open only when all those local goals complete. Ensure player can reach goals before their gates and recover on both sides. Shutters remain relay-driven and independent.

Optional `hazards:Array[Dictionary]`: `at`, `size:Vector2`, `period:float` (e.g.3.6), `duty:float` default0.5, `phase:float`, `damage:float` default8. Telegraph0.5sec before active. Dodgeable electrified floor/beam with alternate route and no required wait. Keep at least70px safe staging either side. Optional `boss_name:String`: rename existing warden fiction; do not clone a boss five times without distinct arena/encounter setup.

All required objectives plus ordinary relay/freight conditions gate exit; optional objectives grant only optional rewards. No objective may require another district's transient objective. Content workers own only assigned level files and accompanying `campaign/docs/level_0N.md` with authored beats, route rationale and walkthrough waypoints. Do not edit runtime or original demo/core. Include `route:Array[Vector2]` waypoint hints on each dictionary for automated feasibility; not player autopilot, no teleports. Author supports for each waypoint. Gameplay logic and paint stay separate from layouts.
