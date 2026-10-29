# MOKSHA module assembly bench

A small practical assembly of reusable scenes, **not another campaign level**.
Open `sandbox/assembly.tscn` in Godot 4.6.3 and press F6.
The project main scene remains the campaign; F5 starts that mission. Press 1/2/3 to switch stations; R resets the selected station.

## What is actually assembled

- **Traversal:** one shared player actor, static floor/shelf, moving lift, ladder
  with its owned sonar contour, and mission cargo. Each is a scene instance with
  a position and exported configuration in `stations/traversal.tscn`.
- **Combat:** the same shared actor scene twice. The blue actor has the keyboard
  input adapter; orange has the existing NPC input adapter and melee policy.
  Movement/combat, Health, defeat and impact components are not reimplemented.
- **Freight:** cradle, receiver, shutter and player are independent scene
  instances. `freight_link.gd` connects the receiver's real `latched` signal to
  the shutter's `set_open(true)`. The cradle binds and spawns designated cargo.
  The receiver—not the shell—decides whether the real crate settled correctly.

Controls: A/D move, Space jump, J attack/launch, K guard, W/S climb. In Freight,
E near the cradle replaces a lost crate. The standard opening placement is close
enough for one J attack to launch the cargo into the receiver; tests verify that
physical result, rather than assigning a success flag.

## Editing like pieces

Open any `stations/*.tscn` directly and use F6 to run only that station. Move,
remove or replace its instance nodes in the editor. Resize static support via
`platform_size`; configure lift `travel`, `period`, `platform_size`; ladder
`height`/`width`; receiver basin dimensions; shutter size. Do not scale physics
bodies to resize them. The shell does not generate level geometry.

`actors/player.tscn` and `actors/npc.tscn` are thin compositions of the same
`simulation/actors/shared_actor.tscn`. The NPC policy's target NodePath is explicit.
The freight link's three NodePaths are explicit, and its behavior is only wiring.
It does not set Health, apply movement, forge contacts, or force receiver success.

These are reusable Godot scenes, not a packaged Godot EditorPlugin. Some physical
components still draw their own appearance; this bench does not claim the entire
art/physics separation project is finished. There is no new enemy mechanic,
mission/save logic, campaign progression, audio mixer or new AI in this assembly.

## Verification and limitations

`tests/assembly_regression.gd` checks actual moving support carry (with labelled
initial player placement), shared actor/scheduler identity, live NPC approach,
ladder contour, genuine E replacement and J launch through receiver success to
shutter opening. `tests/navigation_regression.gd` dispatches real key events to
switch/reload stations and verifies missing-player handling. Results are in
`evidence/`; read the recorded rate and failures rather than inferring a pass.

No native visual review or human-play pacing is implied by headless tests. This
sandbox does not satisfy or measure the earlier 30-minute campaign target.
