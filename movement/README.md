# MOKSHA movement foundation

This is the current working scene: one wireframe player, one wireframe NPC and
editable collision pieces. Run the project with F5, or open movement_lab.tscn
and press F6. F8 opens the preserved two-level build; run the project again to
return here. This movement motor is a separate candidate foundation, so changes
can be judged without altering the delivered art/combat/sonar build.

## Reference-backed behavior

The primary reference for this pass is the implemented player controller in the
Symphony of the Night commercial-game decompilation, pinned to a specific commit.
[SOURCE_STUDY.md](SOURCE_STUDY.md) maps exact functions and branches to our Godot
code and tests. Dead Cells' incomplete decompilation is not the motor foundation.

The default PC now directly adopts these identified behavior patterns: immediate
ground speed/stop, explicit state/action permissions, separate launched-jump and
walk-off control, ledge jump grace, capped upward speed when jump is released,
and apex gravity assistance only while holding an eligible ordinary jump. Air
jump, ceiling contact and external interruption block that apex assistance.
Godot performs swept collisions instead of the original game's tile-sensor loop.
Absolute speeds, jump impulses and timer lengths remain project tuning.

Smooth acceleration remains an optional resource setting and the NPC's default.
Forward/air dash, input buffering and forgiving landing recovery are explicitly
MOKSHA extensions, rather than claims about SOTN or recovered Dead Cells behavior.

## Evaluate the movement

- A/D or arrows: move. The white nose and arrow show facing; the gold foot line
  shows horizontal velocity. Direction changes immediately with nonzero input,
  even while braking, airborne, paused by impact or externally pushed.
- Space/W/Up: jump. Hold for height, release for a short hop; press again for the
  optional air jump. A ground jump can be requested just after leaving a ledge
  or just before landing. Walking off spends the ground jump after grace ends.
- K/Shift: dash. Travel direction is captured at start; turning the face does not
  steer that dash. One air dash is available before landing. After the initial
  45 ms, a valid jump can cancel a dash. Walls end dash travel immediately.
- R: reset both actors. Esc: freeze/resume. H: a short local hit-pause probe to
  test buffered input. I: an external impulse to test interruption and recovery.
- 1: double jump; 2: air dash; 3: coyote time; 4: variable jump; 5: input buffers;
  6: NPC chase. Switches are per-instance and do not edit shared resources.
- F9: record eight seconds of actual viewport frames and input/velocity/facing
  telemetry in delivery/. F12: capture the current viewport.

The first lane tests reversals and NPC following. Continue right for the slope,
ledge, catch floor, one-way steps, six-pixel wall and low ceiling. The camera has
a vertical dead zone to keep landing surfaces visible during small jumps.

There is no attack state in this lab yet. Landing is a brief observable state,
not a movement lock. A held jump never repeats automatically. Dash is buffered,
not repeated from holding its button. Collision uses Godot CharacterBody2D at
120 Hz; the visual wireframe cannot move or scale the collision body.

## Reusable parts

- actors/player.tscn and actors/npc.tscn are independent placeable scenes
- components/movement_motor.gd owns movement, collision, facing and state
- components/player_intent.gd and npc_intent.gd supply intent through set_intent()
- components/wireframe.gd reads the same authoritative motor; it can be replaced
  by animation later without taking control of facing or physics
- resources/player.tres and npc.tres expose acceleration, braking, reversal,
  gravity, jump, air control, snap, slope, grace, buffers and dash tuning
- geometry/test_surface.tscn keeps an editable polygon and drawn outline linked;
  points, one-way collision and a label are Inspector properties

NPC movement uses the same motor. It patrols, acquires visible targets in its
lane, chases, holds at a stopping distance, resumes beyond a hysteresis margin,
and reacts to walls and edges with predictive rays. It brakes before a gap and
never teleports or follows through walls. It does not yet navigate between
platforms or jump toward targets; that is a later behavior decision.

Facing and travel direction are deliberately different values. With zero input,
the actor retains its face. With the default player profile, facing and ground velocity reverse on the same
physics tick. With optional smooth response, velocity crosses zero under the
configured reversal acceleration. During dash,
facing still follows current input while dash_direction remains captured.

## Evidence and limits

The prior v3 reversal report could not be reproduced in a focused diagnostic:
326 assertions passed, and the three inspected actor files matched the delivered
ZIP. Godot decomposes a negative X transform into a rotation plus negative Y
scale, so scale.x alone is not a valid facing check. The lab instead draws its
forward markers directly from the motor's facing field.

The independent motor suite checks actual physics, not just property assignments:
143 checks include real parsed input, coyote and landing buffers, jump height,
dash limits and cancellation, collision extremes, slope grounding, hit pause,
and impulse recovery. The NPC suite covers ten patrol/chase/obstacle cases. Another 63 lab checks cover
scene composition, resource isolation, scene save/reload, toggles, pause and reset.
They caught four cases where pending jump/dash events survived reset or pause;
the adapter now clears those events together with the motor buffers.
Rendered direction and room traversal are also checked through the native game.
Those tests establish behavior, not that the tuning is already the desired final
feel. All numeric values here are MOKSHA tuning, not recovered Dead Cells values.

See ../docs/REFERENCE_NOTES.md for primary-source study and license boundaries.

## Capture provenance

The included movement video and native input trace show the first wireframe pass,
before the later SOTN reconciliation changed default steering and jump response.
They verify the visible facing relationship and room layout at that checkpoint.
The source-grounded revision has a separate headless regression record. A native
editor refresh was blocked by automatic approval review, so this later tuning
pass is not represented as newly playtested on the desktop.
