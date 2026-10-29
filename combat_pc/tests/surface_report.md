# M15 surface-pulse verification

Date: 2026-10-05 UTC. Engine: Godot 4.6.3 stable official.

## Result

- Focused surface adapter: **98 checks / 19 scenarios passed at 60 Hz**, and **98 checks / 19 scenarios passed at 120 Hz**
- Retained sonar regression: **63 / 63 checks passed**, executed once against an isolated project copy so the original sonar report was preserved
- No script errors, warnings, leaked-object messages, or failing assertions in the final three logs
- **15 / 15 SHA-256 comparisons exactly match the preserved v18 delivery**, covering the PC scene/motor, legacy movement motor, Health, DefeatResponse, NoiseRelay, NoiseBus, and original contour view/geometry/canvas/tuning resources
- Production source hashes stayed unchanged during each focused run and match the final runtime adapter (SHA-256 ca948fbe41cfc8913c2f1f1f57901580f9138231ab0617888e1312eec6302993)

## Focused coverage

The integration cases instantiate the actual reusable PC, physical floor, unchanged NoiseRelay and a local unchanged NoiseBus. Walking, falling onto the floor and entering an active strike each produced one immutable actor receipt, one relay delivery and one accepted surface event, preserving origin, kind, loudness and source identity. No fake direct movement or strike emission is used in those cases. Hitpause adds no replay.

The same real engine callback driver compares attached and absent components through movement, jump, roll, shield, strike, recovery, and movement after removal. It observed **zero mismatched motor ticks across 204 samples at 60 Hz and 408 at 120 Hz**. Immediate disable, unbind and free preserve motor state. The driver also verifies one sample per real physics callback and the requested delta.

The independent contour fixtures deliberately emit directly into the explicit local bus to isolate geometry and adapter contracts. They contain real collision bodies and cover:

- Distance-ordered near and far arrivals; top-to-side-to-underside travel around corners; no premature full silhouette
- Empty-space zero, immutable emission origins, independently additive overlap clamped to white, complete fade to zero
- Parent rotation and nonuniform scale, actual rigid translation/rotation, edited shapes, disabled shapes, deleted bodies, actor/Area2D/ignore-group exclusions
- Zero autoload subscription or event intake, no forwarding back to autoload, foreign/null/detached/queued source rejection and malformed-event rejection
- Local simulation pause and SceneTree pause freeze both intake and ages; resume advances and accepts fresh events
- Enable/disable, explicit reset by rebind/unbind, old bus detachment, retained callback invalidation, repeat binding without duplicate subscriptions, detach/reattach and failed binding cleanup, including live non-Node dependencies
- Queued/freed actor, world, bus and surface dependencies; earlier synchronous bus subscribers that free the source/actor/world or replace the binding; fully freed surface cleanup
- Actual headless draw submission restricted to surface fragments even if inherited blackout/body/origin/contact/threat settings are enabled; no persistent outline after expiry

## Measurements

Both rates yielded identical deterministic contour schedules:

- Near face: 0.150070 s; far face: 0.513706 s
- Top, side and underside: 0.150070 s, 0.268531 s, 0.386993 s
- Draw-budget probe: 10 active fragments, with zero blackout, body cue, origin marks, labels, threat marks or contact marks
- Actual integration noise sequence: footstep, land, strike; surface accepted count 3

A transformed-shape fixture is separate from the rigid-motion fixture: rotating a child below nonuniform parent scale changes the world-space shape and legitimately rebuilds its schedule. Emission-time schedule preservation is asserted on genuinely rigid motion.

## Reproduction

From the project root:

The baseline comparison requires your retained **v18** MOKSHA-Two-Level-Project.zip (its entries begin with MOKSHA/). Pass its location explicitly; the archive is not bundled inside this delivery. Omitting the option uses the original developer backup location, which is only a convenience for that workspace. Missing, unreadable, malformed or incomplete archives exit nonzero with an explicit error and leave prior reports untouched. A source mismatch also exits nonzero. The included hash report records the successful comparison performed during this verification; it is historical evidence, not a new comparison on the recipient's machine.

```sh
python combat_pc/tests/surface_verify_baseline.py --baseline-zip /path/to/retained-v18/MOKSHA-Two-Level-Project.zip
mkdir -p /tmp/moksha-m15-test-runtime/data60 /tmp/moksha-m15-test-runtime/cache60 /tmp/moksha-m15-test-runtime/config60
XDG_DATA_HOME=/tmp/moksha-m15-test-runtime/data60 XDG_CACHE_HOME=/tmp/moksha-m15-test-runtime/cache60 XDG_CONFIG_HOME=/tmp/moksha-m15-test-runtime/config60 godot --headless --path . --script combat_pc/tests/surface_regression.gd -- --hz=60
mkdir -p /tmp/moksha-m15-test-runtime/data120 /tmp/moksha-m15-test-runtime/cache120 /tmp/moksha-m15-test-runtime/config120
XDG_DATA_HOME=/tmp/moksha-m15-test-runtime/data120 XDG_CACHE_HOME=/tmp/moksha-m15-test-runtime/cache120 XDG_CONFIG_HOME=/tmp/moksha-m15-test-runtime/config120 godot --headless --path . --script combat_pc/tests/surface_regression.gd -- --hz=120
```

The unchanged existing tests/sonar_regression.gd was run once in /tmp/moksha-m15-test-runtime/retained-sonar-project with separate writable XDG directories; its JSON and log are retained here with the surface_ prefix.

## Evidence and limits

See surface_results_60hz.json, surface_results_120hz.json, surface_baseline_hashes.json, surface_retained_sonar_report.json and the corresponding surface_*.log files. Test source is surface_regression.gd; baseline verifier is surface_verify_baseline.py.

These are focused headless collision, integration, lifecycle and draw-command checks. Native screenshot/visual review belongs to the parent task. No claim is made for a broad levels, NPC, blindness, audio, or complete motor regression pass.
