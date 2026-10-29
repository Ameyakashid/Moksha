# Shared physics composition: standalone acceptance

The reusable actor is `actors/shared_actor.tscn`. It composes the existing combat
controller with an intent scheduler, Health/Defeat, contact receivers and optional
hearing/noise adapters. Player input and AI intention are interchangeable inputs;
the controller, not the input provider, owns locomotion and action state. Without
an InputSource it receives neutral input but still simulates gravity and support.
Without a NoiseBus the optional audio/hearing adapters remain inactive.

## Connection contract

- Add an owned child named `InputSource` implementing `sample_raw(actor, dt)`;
  alternatively set `IntentDriver.source_path` to an owned provider. AI adapts its
  intentions through `npc_input_source.gd`. Only the one IntentDriver ticks the
  actor. Do not also enable the controller's automatic physics.
- Configure `ContactConfig` with an actor-contact profile. Default body layer 32,
  mask 1 means terrain blocking, not actor-to-actor blocking. Production profiles
  use PC layer 2/mask 9 and NPC layer 32/mask 9: both block terrain and cargo, but
  actors deliberately remain mutually nonblocking. Hurtbox and strike masks are
  separate, so combat still works while body shapes overlap. This is a current
  gameplay policy/limitation, not a claim that every solid-looking actor blocks.
- Optional physical cargo uses `components/physical_cargo.tscn`; the production
  wrapper `world/mission_cargo.tscn` selects charged-contact behavior and masks.
  Godot owns rigid-body position, rotation and impulses. Health damage and guard
  responses are authored gameplay rules, not energy-conserving physics.
- Static floors, configured lifts and cargo support both actor roles through real
  collision. Root visibility is presentation only; hiding a body does not disable
  collision or stop its physics scheduler.

## Sleeping cargo support correction

A new isolated composition test reproduced a concrete problem in the previous
source: after a crate naturally went to sleep on a floor, freeing or disabling
that floor could leave the crate suspended. Actors fell correctly. The same
unmodified test failed for free/disabled/paused-removal cases with the old source.

The shared cargo now remembers gravity-opposing contacts observed by Godot's
solver. An actual supporting-body exit, or a change to that observed support's
geometry, collision membership or world, wakes the sleeping body once. No
position, velocity, impulse, charge or grounded flag is assigned. The ordinary
solver then decides whether the cargo falls, remains supported, or collides.
Resting on unchanged support can still sleep; removal of a non-supporting side
contact does not trigger this wake. Paused/disabled simulation does not move early.
The change belongs to opt-in shared cargo, not the historical stock `prop.gd`.

## Verification boundary

`tests/standalone_composition.gd` composes two neutral actors, production cargo,
a lift and a floor with no mission and no NoiseBus. It tests actual landing,
private per-instance actor configuration, hidden-art collision and support loss.
Initial placements are fixture setup, not gameplay teleportation.

`tests/sleep_support_regression.gd` uses real resting contacts, then explicitly
changes/removes the fixture support. It covers natural sleep, stable rest,
free/disabled/moved/shape-moved/mask-changed support, paused removal and real
non-supporting side-contact exit. Bounce=0 is declared fixture tuning; it does
not change production tuning. Run both at 60 and 120 Hz.

Existing shared-controller, impact, actor/cargo, pending-pressure, cargo defense,
incoming-strike, footing and boundary suites are rerun separately. These tests
are bounded physical/interface verification, not human game-feel, audible-mix,
visual quality, campaign duration or universal actor collision claims.

`tests/support_geometry_regression.gd` additionally verifies naturally sleeping
90-degree cargo, tilted supports and multiple supporting shape owners on one
body. The wake observer retains all genuinely observed owners; another remaining
physical support can continue to hold cargo. TileMap-backed contacts whose owner
is not a CollisionObject2D are deliberately skipped by this optional observer and
retain Godot's default wake behavior; they are not claimed fixed by this slice.

The existing recording fixture uses two default shared actors (layer 32/mask 1).
It is not the production PC layer 2 / NPC layer 32, both mask 9 configuration.
Its late wall-side overlap demonstrates configured actor-body pass-through, not
wall tunneling or full production contact coverage. Untrimmed evidence is retained.
