# Freight component contract

## Production files

- `demo/components/freight_receiver.gd`: detachable Node2D, three real StaticBody2D basin pieces and an Area2D detector.
- `demo/components/freight_cradle.gd`: detachable Node2D, physical 52-pixel launch pad and replaceable production cargo.

No player, contact adapter, production prop, prop tuning, or sonar-core edits are needed.

## Coordinates and integration

The receiver origin is the centre of its interior floor at the top of that floor. The cradle origin is the launch floor at the cargo's X position. Verified coordinates are receiver `(500, 300)` and cradle `(254, 270)`: receiver = cradle + `(246, 30)`.

The cradle support extends 26 pixels on either side. The 160-pixel receiver interior begins 80 pixels left of its origin. This yields a 140-pixel floor-to-floor gap and a receiving floor 30 pixels lower. The 10-pixel entry lip occupies part of the gap and is 8 pixels high; the backstop is 68 pixels high and 40 pixels wide, extending rightward from the unchanged receiving face. Its broad top supports the production PC’s same-body ledge pull-up. Keep the actual flight path clear of enemy hurtboxes and extra terrain. Ordinary props break on a charged enemy impact; this component does not alter that rule.

Create both as Node2D, assign their scripts/positions, and call `cradle.bind_receiver(receiver)`. Set `cradle.auto_spawn = false` when the host explicitly calls `replace_cargo()` after adding nodes; otherwise the cradle schedules its initial cargo automatically. Cargo uses the real crate scene with the unchanged mission-prop rendering adapter and the same collision mask 33 as ordinary demo props.

The host handles E only near the cradle and calls `replace_cargo()` or `interact(player)`. The cradle's `can_interact(player)` checks its 58-pixel radius and enabled state. Connect `receiver.latched(prop)` to permanently open the freight shutter and refresh the mission objective. Poll `receiver.is_latched` for completion and `receiver.status` for text (`ready`, `in_transit`, `seating`, `missing`, `delivered`). There is deliberately no receiver interaction method that can complete delivery.

## Guarantees

The bound, intact production RigidBody prop must overlap the detector, be inside the floor bounds, move no faster than 34 px/s, rotate no faster than 2 rad/s, and have an upward real contact with this receiver's floor for 0.22 seconds. Detector overlap, stationary airborne/frozen crates, another crate, player, enemy, and broken cargo do not qualify. Actual rubber-lined collision material absorbs bounce; the receiver never alters cargo velocity, tuning, charge, or position.

Replacement immediately invalidates/hides the old cargo, removes its live freight/prop group membership, and excludes it from sonar collection. Collision removal precedes the deferred new-body spawn. Same-flush repeated requests coalesce. The replacement creates only cargo and never touches actor health, enemies, ordinary props, or mission state. Success permanently latches and disables replacement even if the delivered cargo later breaks.

Completion emits one `NoiseBus` event from the receiver's actual global position with the receiver as source. Existing mission audio maps it to positional prop audio. Basin contours come from actual collision shapes, not the Area2D. Pausing the containing room pauses the objective and rigid-body flight together.

## Verification

Run from the project root:

```
XDG_DATA_HOME=/tmp/moksha-data XDG_CONFIG_HOME=/tmp/moksha-config XDG_CACHE_HOME=/tmp/moksha-cache godot --headless --path . --fixed-fps 60 --script demo/tests/freight_component_regression.gd -- --hz=60
XDG_DATA_HOME=/tmp/moksha-data XDG_CONFIG_HOME=/tmp/moksha-config XDG_CACHE_HOME=/tmp/moksha-cache godot --headless --path . --fixed-fps 120 --script demo/tests/freight_component_regression.gd -- --hz=120
```

The fixed rendering pace accelerates wall-clock execution; actual Godot solver ticks and production PC `physics_tick` run at the selected 60/120 Hz. Evidence is written to `demo/evidence/freight_component_60hz.json` and `freight_component_120hz.json`.

The standalone suite covers real PC J launch in both sight states, 48 randomized ordinary launches and 12 charged/finisher-strength launches per rate, exact spawn-commit uniqueness, 12 rapid replacement cycles, true wrong-way cargo loss and recovery, destruction recovery, global pause/resume, permanent success, real sonar contours, actual-origin noise, fresh-room reload, and actual PC jump→ledge catch→swept pull-up onto the receiver backstop. These are deterministic physical component fixtures, not fresh-player usability observations or a claim that the integrated room route has been reviewed.
