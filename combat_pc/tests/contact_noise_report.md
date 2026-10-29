# M16 independent physics contact-noise QA

**PASS: 255 assertions across 47 focused scenarios at both 60 Hz and 120 Hz.**

Godot 4.6.3 stable, official Linux build (`7d41c59c4`). Both final runs exited 0 and produced no errors or warnings. The two result files record the same current implementation hashes. All 21 protected actor, motor, health, defeat, noise relay, local bus, surface/contour, and original prop dependencies match the retained v19 delivery exactly.

## Method

The suite runs the actual Godot 2D solver at fixed 1/60-second and 1/120-second physics steps. A separate read-only, high-priority probe records each body's synchronized direct-state contact points, normals, both contact-point velocities, shape identifiers, sleeping state, and physical trajectory. It executes before the optional adapter. Every ordinary emitted receipt is checked against an independently stored same-frame physical contact and against the local NoiseBus event. No contact receipts or collision responses are synthesized for physical acceptance.

Bodies are plain RigidBody2D instances with real CollisionShape2D geometry, plus one actual composed `contact_noise_prop.tscn` test. Linear/angular damping is explicitly set to REPLACE with zero damping where controlled initial speeds matter. Reset cases use the physics server's body transform setter to establish an actual host reset; subsequent collisions remain real solver contacts.

Resource validation and binding-contract assertions are separate from physical acceptance. Before-deferred lifecycle cases use a second, lower-priority probe: it waits until a real contact has already been sampled and queued, then performs the host lifecycle operation before the deferred delivery runs. Callback cases mutate bindings during the real local bus callback.

## Results

| Physics rate | Assertions | Scenarios | Physics ticks | Failures |
| --- | ---: | ---: | ---: | ---: |
| 60 Hz | 255 | 47 | 2,511 | 0 |
| 120 Hz | 255 | 47 | 4,725 | 0 |

- Actual floor and wall throws emit one event per qualifying shape-pair episode. Multiple manifold points are coalesced. Sustained tangential contact and settling produce no chatter
- Actual floor origins lie on y=90, wall origins on x=90, and rotated/translated surface origins transform exactly back onto the struck collider face. Receipt origin, normal, shape IDs, closing speed, loudness, source, frame, and serial agree with the independent oracle and local bus
- 140 px/s floor impact produces loudness 0.583333 and contour radius 327.806915 px. A 360 px/s impact produces loudness 1.5 and radius 525.660499 px at both rates. The unchanged SurfacePulse receives one pulse per real contact and retains the original contact origin
- Lone instrumented movers and lone instrumented struck targets both report. A stationary sleeping target struck by an uninstrumented body reports the waking impact. Two instrumented props emit exactly one event for the shared shape pair
- Opposing body velocities +220 and -160 px/s produce measured closing speed 380 px/s. Rotating-body and rotating-collider cases verify contact-point angular motion, including a rotating rod impact with 377.652832 px/s normal closing speed
- Simultaneous floor and wall shapes belonging to one StaticBody2D produce two distinct same-frame receipts. Two compound instrumented props retain both physical shape-pair events while suppressing both symmetric peer duplicates
- The bouncing body records seven energetic bounces at 60 Hz and six at 120 Hz before settling. The difference is the normal discrete solver trajectory at the two time steps. Subsequent two-second rest, actual sleep, and quiet wake add no event; a new physical upward impulse and re-impact do
- Actual queued contacts are retired by disabling, local simulation pause, unbinding, tree detachment, history reset/teleport, rebinding, emitter/body/bus/collider destruction, explicit body sleep, body freeze, and SceneTree pause
- Real paired bus callbacks can unbind/rebind or queue-free the emitter, free its peer, reset diagnostics, or reset history without duplicate publication. Diagnostic copies cannot mutate stored receipts
- SceneTree pause/resume and local emission pause/resume do not replay an old impact. Local emission pause leaves physical simulation running. A fresh post-resume physical collision still emits
- Fresh near-surface spawns and known pre-solver host resets preserve the first subsequent actual contact. The documented `before_physics_step=true` contract is exercised in the known host-physics phase
- Explicit declarative bus paths bind during `_ready`; absent bus paths never discover the autoload. Null, detached, incompatible, duplicate-observer, and cross-World2D bindings are rejected
- Nonfinite/negative profile inputs and an empty kind are rejected. A null profile safely falls back to defaults. The default reporting capacity is 16, extreme requests clamp to 128, and a real one-slot corner collision exposes capacity saturation rather than inventing unreported contacts. Reporting ownership restores host settings on unbind
- The inherited composed prop reports exclusively through the local optional child; its suppressed legacy route adds no autoload duplicate
- Five identical rotating rigid-body runs compare observer absent, attached, removed before simulation, removed midflight, and removed after impact. Maximum position, velocity, rotation, and angular-velocity error is **0.0** at both rates, stricter than the 0.001-unit / 0.00001-radian tolerances

## Defects found and resolved before acceptance

1. Looking up missing registration metadata emitted a Godot error on ordinary bodies. Registration now checks metadata presence first
2. An unconditional wake fence lost a genuine incoming impact. A further 60 Hz case established that `RigidBody2D.sleeping` can remain true for one frame while synchronized direct state is already awake with a valid 220 px/s collision. Sampling now uses direct-state sleep, and delivery uses authoritative physics-server sleep state
3. Collider-level candidate aggregation masked simultaneous floor and wall shapes on one static body. Candidates now preserve shape-pair identity, and symmetric arbitration matches reciprocal shape IDs

All three fixes are covered by the final passing physical suite.

## Scope and limits

This is focused headless physical and contour-integration QA. Native visual review is separate. It does not claim full NPC behavior, audio playback, material acoustics, a sliding/rolling sound model, or a broad actor regression. Origins are the solver's collider contact points; normal solver penetration is expected. A finite engine reporting buffer can omit contacts beyond its capacity, which the diagnostics expose.

The adapter's reset/bind phase matters: default calls conservatively reject stale reports across an idle/deferred boundary. Pass `before_physics_step=true` only from a known host `_physics_process` before the next solver step, as exercised here. Final reports retain implementation hashes and full same-frame receipt/oracle evidence.

## Reproduce

Run from the project directory:

```sh
python combat_pc/tests/contact_noise_verify_baseline.py --baseline-zip /path/to/retained-v19/MOKSHA-Two-Level-Project.zip
mkdir -p /tmp/moksha-m16-test-runtime/config /tmp/moksha-m16-test-runtime/data /tmp/moksha-m16-test-runtime/cache
XDG_CONFIG_HOME=/tmp/moksha-m16-test-runtime/config XDG_DATA_HOME=/tmp/moksha-m16-test-runtime/data XDG_CACHE_HOME=/tmp/moksha-m16-test-runtime/cache godot --headless --fixed-fps 60 --path . --script res://combat_pc/tests/contact_noise_physics_regression.gd -- --hz=60
XDG_CONFIG_HOME=/tmp/moksha-m16-test-runtime/config XDG_DATA_HOME=/tmp/moksha-m16-test-runtime/data XDG_CACHE_HOME=/tmp/moksha-m16-test-runtime/cache godot --headless --fixed-fps 120 --path . --script res://combat_pc/tests/contact_noise_physics_regression.gd -- --hz=120
```

The verifier defaults to the original retained local v19 backup path. If that archive is unavailable, supply it explicitly; the verifier fails without claiming a comparison.

## Evidence files

- `contact_noise_physics_regression.gd`: focused physical and lifecycle suite
- `contact_noise_physics_probe.gd`: independent read-only direct-state oracle
- `contact_noise_results_60hz.json`, `contact_noise_results_120hz.json`: full assertions, measurements, contact receipts/oracles, implementation hashes, and protected-source hashes
- `contact_noise_physics_60hz.log`, `contact_noise_physics_120hz.log`: clean final engine output
- `contact_noise_verify_baseline.py`, `contact_noise_baseline_hashes.json`: 21-file v19 comparison
- `contact_noise_final_hashes.json`: final QA/runtime evidence manifest
