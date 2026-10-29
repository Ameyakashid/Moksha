# One actor, different intention sources

## Implemented boundary

`actors/shared_actor.tscn` inherits the existing `combat_pc/player.tscn` without
changing its script, sweep, action arbitration or defense implementation. Both
player-driven and NPC-driven instances use this exact scene. It composes the
same Health, DefeatResponse, NoiseRelay, HearingSensor and PhysicalImpactReceiver
(the same DEFENDED_ATTACK response). The raw controller remains the physical
owner. Godot 4.6.3 remains the engine.

`actor_intent_driver.gd` is the sole scheduler for this composition. Keep the
actor's `automatic_physics = false`. The driver calls `physics_tick(dt, raw)` at
most once per engine physics frame; a host-retained admission frame also fences
same-frame driver replacement. A second live scheduler cannot claim the actor.
A fresh driver may replace a queued-for-deletion owner. Removing the only driver
without replacing it intentionally stops scheduled simulation; do not disable
it by removing it when neutral input with continuing gravity is wanted.

Set `IntentDriver.enabled = false` to supply neutral input while the existing
controller continues braking, gravity, committed actions and collision. This is
not an immediate action cancellation or physical freeze. Missing/disabled input
sources also yield neutral input. Global pause and disabled host physics stop
scheduling. Reset, pause, source changes and source/policy process-mode changes
clear queued intentions and require neutral/release observation before a held
action can be newly admitted. Held movement axes may resume normally. Explicit
full-tap raw edges cannot bypass the first neutral quarantine sample.

The driver, source and policy validate ownership before calling reset hooks.
A path pointing into another actor cannot read or clear that actor's intention.
Callbacks that remove, disable, rebind or reset a source/policy invalidate its old
sample. No policy or source writes transforms, velocity, grounded state, health,
attack state or action timers. Setting initial fixture positions and an explicit
actor reset in tests are setup/lifecycle boundaries, not gameplay outcomes.

## Adapter and configuration contracts

- A source is a child of the actor and implements `sample_raw(actor, dt)` and an
  optional `reset_intent()`. The result is the controller's ordinary raw frame:
  strengths `left/right/up/down`, held `jump/roll/attack/shield`, and optional
  `_pressed`/`_released` Boolean edges. Nonfinite/invalid strengths become zero.
- `player_input_source.gd` samples the actual `cp_*` InputMap actions.
- `npc_input_source.gd` is a direct child of its actor. Its policy is another
  descendant of that same actor, with `sample_intent(actor, dt)` returning a
  finite Vector2 `move` and held action Booleans. The adapter converts these to
  the same raw schema. Held transitions are then resolved by the controller.
- `patrol_intent_policy.gd` uses real local terrain rays, actual grounded state
  and optional target range/clear-terrain-ray evidence. It does not receive a
  predeclared success path or move the actor itself. It brakes/turns before
  observed obstacles, falls when support is lost, and requests inward motion
  if external momentum carries it beyond its patrol interval. Its probe is a
  local observation, not navigation/reachability or swept-path proof.
- `actor_capabilities.gd` contains actor-local permission settings. The driver
  duplicates the resource and existing movement/combat/shield profiles for each
  actor. Call `configure_capabilities(resource)` for a runtime configuration
  replacement; it adopts a private copy and clears input. Actor reset reapplies
  these settings because the preserved controller resets weapon permissions.
  Do not expect in-place edits to a previously supplied resource to take effect.
- Jump, roll, attack, shield, movement, turning, drop, dive, climb, wall-running
  and hearing are exposed as configuration. They are not role branches. This
  resource does not replace transient main-action capabilities or implement an
  independent general-purpose ledge-grab switch.

## What the checks prove

`tests/shared_actor_regression.gd` runs at 60 and 120 Hz. Manual raw-input and
NPC-intent fixtures drive equivalent translated terrain and compare every
paired tick's displacement, velocity, support and action states. The tested
motion includes variable jump release, air jump, direction reversal, crouch,
roll, attack, shield, ramp ascent, a solid wall, actual support deletion and an
incoming impulse boundary. The tolerance is 0.05 pixels for translated collision
position and 0.025 pixels/s for velocity; measured maxima are 0.007489/0.033627
pixels at 60/120 Hz and zero velocity difference. This is numerical conformance
under equivalent inputs/configuration, not proof that separate gameplay roles
must always choose the same actions or that every environment is covered.

Separate tests use actual InputMap key events, genuine falling cargo contacts,
common Health debits, actual noise-bus/hearing receipts and autonomous terrain
and LOS observations. Lifecycle tests cover source/policy removal/rebinding,
foreign paths, pause (including ALWAYS process mode), host physics disable,
held/tap rearming, invalid input, scheduler uniqueness/replacement and both-side
patrol recovery after real impulse. Counts include repeated per-tick assertions;
they are not thousands of independent gameplay scenarios.

`movement_sandbox.tscn` runs alone or as gym stage 04. Player A/D, Space, Shift,
J/K use raw input. The second actor patrols equivalent terrain through its own
policy. R reloads the whole stage, Esc returns to the gym, F12 captures it.

## Movement checkpoint and subsequent bridge

The immutable Shared-Movement archive preserves the movement-only checkpoint:
it inherited layer 2/combat_pc membership and did not receive peer melee. The
current composition adds the independently tested incoming-strike bridge and
role-neutral ContactConfig described in `STRIKE_CONTRACT.md`. The controller
itself is still unchanged. Movement tests now smoke-test actual peer damage and
configured layer/group membership instead of asserting the old missing bridge.

The immutable movement checkpoint retained all legacy mission solvers. Current
F5 now uses the shared controller for ordinary sentinels and listeners; ranged
enemy and Warden remain legacy. See `SENTINEL_CONTRACT.md` and `LISTENER_CONTRACT.md`. No
universal physical realism, acoustic propagation, finished game feel, corpse
behavior or complete asset extraction is claimed.

## Next production integration, bounded and gated

1. Implemented in the current strike slice: a detachable, generation-checked
   incoming-strike bridge for this actor.
   Actual ContactAdapter shape overlap/terrain occlusion must admit the contact;
   the bridge must map the live source's strike serial, origin, contact point,
   damage and impulse into the existing `receive_attack` contract. Health remains
   a receipt observer and the controller remains the only motion/defense owner.
   Never synthesize a successful contact or manually assign health/knockback in
   a brain. Decide the explicit source epoch/reset identity boundary before
   mapping serials so a reset/replacement cannot replay an old hit.
2. The bridge acceptance slice drives real attacks from raw input in both
   directions and NPC-to-NPC, with equal capability/config outcomes. Cover
   frontal guard/parry/roll, absent shield capability, blocked/out-of-range/self
   contacts, fresh vs duplicate attacks, source and receiver disable/removal,
   reset/replacement/callback retirement, and lethal Health/Defeat/Noise paths.
   ContactAdapter now verifies exact source binding and current strike generation.
   Explicitly exclude the source actor's own child hurtbox. Collision layers,
   target masks and actor/faction groups must be generic per-instance settings,
   not player/NPC branches or implicit reliance on `combat_pc` membership.
3. Prove shared shield-counter admission first: the initial strike bridge
   explicitly sets counterable=false. Once that contract and the incoming bridge
   are independently reviewed/frozen, migrate the ordinary sentinel
   composition first through a thin mission-facing facade. Preserve mission
   creation/configuration (`kind`, overrides, bounds, `configure(player,bus)`),
   `defeated`, `dead`, health/reveal/sonar and room-clear behavior. Keep AI choices
   in an intent policy and remove its direct velocity/attack-outcome writes.
   Preserve listener/ranged/Warden implementations until their own bounded tests
   justify migration. Verify actual sentinel strike/contact/health/sound and
   defeat, shield counter admission and sight/hearing behavior.
4. Before each production migration checkpoint, run both-rate actor/enemy/ranged/
   Warden/integration suites, all gym lifecycle checks, the historical aggregate
   and all four 60/120 × retained/sacrificed-sight mission routes. Compare real
   behavior and configure tuning deliberately when the new solver differs;
   do not weaken a route by forcing outcomes. Freeze/archive that slice before
   migrating another archetype.
