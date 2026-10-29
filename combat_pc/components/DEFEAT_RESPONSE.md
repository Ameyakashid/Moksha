# Optional zero-health response

This is one separate policy connected to the Health component. On an actual empty-health transition, it acquires the actor's defeated state. It retires melee/shield actions, discards queued input and blocks movement, facing, jumping and combat admission. Further contacts are rejected before recoil or damage accounting. The same physical body continues to use the existing recoil drag, gravity, swept collision and moving-support transport.

## Place it

Instance `defeat_response.tscn` under a PC that has an independent Health child. Actor Path defaults to the parent; Health Path defaults to `../Health`. The health store must be bound to that exact actor. The base `player.tscn` still requires neither component. `defeat_review.tscn` composes both; the preceding `health_review.tscn` remains a health-only fixture.

`bind(actor, health)` and `unbind()` let a host place the response elsewhere. A health/response pair should be rebound together; changing the Health binding alone does not redirect a defeat already acquired on another actor. Removing the response, removing its Health dependency, or explicitly unbinding releases only the state owned by that component. It cannot release another owner's replacement. A new response bound to an already-empty matching Health store handles that state immediately.

## Reset boundary

Zero health does not run a timer that revives, reloads or removes the PC. The existing host command `reset_actor` releases defeat and resets the actor. Health's existing reset policy refills health separately. Refilling only the health quantity after defeat does not restore control. The review's R key calls the explicit whole-actor reset.

The actor retains the host's `allow_input` value and external weapon permissions. Detaching the response does not grant permissions that the host had denied. Buttons held through defeat/release must be released before they can generate another action; actor reset establishes the ordinary reset input boundary.

## Presentation and physical limits

`visuals/defeat_pose.gd` is an original passive wireframe pose module. It shows an airborne limp response and a grounded collapse/settled pose, mirrored by facing and aligned to the actual floor normal. It never moves the actor or changes collision geometry. The0.36-second collapse is configurable authored presentation timing, not recovered Dead Cells timing. The body keeps its tested collider; this is not a ragdoll/corpse physics system.

The response exposes `active`, `defeat_started` and `defeat_cleared`. The actor exposes owner-checked entry/release and defeat telemetry. Acquisition, release and reset are protected against synchronous callback replacement. High-fall recovery cannot take over and silently revive a defeated PC. Outstanding one-way drop exceptions remain until physical clearance.

## Review

F5 opens `defeat_review.tscn`. Q sends one guided lethal contact through the same real melee instrument as the health review. This fixture uses10 starting health and its unchanged10-point hit. Try A/D, Space, J or K after collapse; R explicitly resets. F requests an ordinary incoming hit in free control. Esc pauses.

This review adds no healing, game-over menu, respawn progression, saved state, new enemy or new level. The source-informed action separation is retained; the terminal policy, values and pose keys are original MOKSHA decisions. Further changes wait for review.
