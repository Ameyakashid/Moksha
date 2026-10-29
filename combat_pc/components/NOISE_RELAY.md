# Optional PC noise relay

This is one small connection toward the sensory system. The PC already produced footsteps, landings, rolls, weapon swings, defense contacts and hurt noises. NoiseRelay forwards committed events into the existing NoiseBus contract. It does not create a second movement/emission scheduler, play audio, trace surfaces or reveal unseen geometry.

## Place and connect

Instance `noise_relay.tscn` under the reusable PC. Actor Path defaults to the parent; Event Bus Path is intentionally empty until the host chooses a bus. Point it at a Node using `scripts/sensory/noise_bus.gd`, or an implementation of that same `emit_noise` / `noise_emitted` contract. The bus may be scene-local; the PC has no autoload requirement. The base player scene still does not require this component.

The review composes a PC, the already-reviewed Health and DefeatResponse, NoiseRelay and one local SoundEvents bus. It observes the relay's completion signal for markers and the actual bus count for traffic. It does not also observe the actor's legacy signal or the global bus, which would count the same routed sound twice.

`bind(actor, event_bus)` and `unbind()` set explicit weak references. `enabled` disconnects/reconnects the source signal and invalidates old callbacks. Disabling or removing the relay leaves movement, combat, health and defeat unchanged. Previously emitted events remain real events; disabling the route does not erase them. `reset_diagnostics()` clears only the relay's count/last snapshot and invalidates an in-flight completion notification.

## Event contract

The new actor receipt contains six scalar/value fields: actor_id, generation, serial, origin, kind and loudness. It is read-only. The origin is captured where the event occurred; the relay never substitutes the actor's later position. Only finite origins, nonempty kinds, positive finite loudness and positive integer serials are accepted. The source must match the currently bound live actor and its reset generation.

The existing `noise_requested` signal still runs once, with its original argument shape. After its synchronous listeners return, the actor publishes the committed receipt only if that generation remains alive. A legacy callback that resets the actor therefore cannot forward an old sound into a new life. The relay checks generation again, so earlier receipt listeners can also reset safely.

Footstep, landing and roll feedback previously allowed callback resets to change an old sound's location. Those sites now capture origin/kind/loudness before callbacks and fence resets. Hurt also retains its admitted origin across a same-generation teleport. Normal event kinds, loudness values, timing and the NoiseBus implementation are preserved. These lifecycle corrections are authored MOKSHA behavior, not recovered game timing.

Hitpause does not invalidate an already-produced sound. Frozen simulation does not repeat the source event. A defeated body can still make one real landing noise; the relay does not invent footsteps while it is stationary. Nested sounds may deliver receipts out of serial order, so there is no highest-serial deduplication rule.

The relay commits diagnostics before bus callbacks. Its `forwarded(event)` notification occurs after the bus call only while its binding, actor generation and component/bus lifetimes are still current. The immutable receipt and captured origin survive later motion; the optional inspection markers have their own short lifetime.

## Review controls

F5 opens `noise_review.tscn`. A/D moves, Space jumps, J swings and Shift rolls. E disconnects/reconnects the route while the PC stays controllable. R resets the PC and clears this review's event history/markers. Esc pauses.

White rings mark event origins and fade. They are a diagnostic view of noise emission, not sound propagation or surface mapping. This checkpoint intentionally stops before the blind/sonar display or sound design, so this one connection can be reviewed independently.
