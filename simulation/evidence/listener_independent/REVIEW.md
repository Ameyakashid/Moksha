# Independent listener configuration review

Result: no production defect found in the bounded listener migration.

Engine: Godot 4.6.3 stable, official 7d41c59c4, Linux headless.
Immutable baseline: MOKSHA-Simulation-Shared-Sentinel-2026-10-19.zip.
SHA256: 480c3ff3cb9075cef3e4efb399f70a29dd7d7e7c9bdee6906c4b2d7d08713a57.

## Verified results

- Production listener regression: 38 scenarios, 173 checks, zero failures at60 and120 Hz.
- Independent supplementary review: 8 scenarios, 35 checks, zero failures at60 and120 Hz.
- Baseline comparison found only the intended four modified production scripts and two added resource files. The three test-file changes/addition are separate. The shared scene, authoritative player controller, intent driver, hearing query/sensor, incoming strike receiver, counter receiver/adapter and contact profile are unchanged from the immutable sentinel archive.
- All reviewed source files matched the live frozen source at review completion. Exact hashes are in final_review_hashes.json.

The independent probes cover two actual player sword contacts depleting an unoverridden listener from2 Health, once-per-receipt HIT and once-per-life DOWN, physical retirement, an actual timed lethal counter bounded by remaining2 Health, intervening-peer counter obstruction without redirected damage, genuine sentinel/listener windup sounds filtered after sensor admission, default foot-origin Euclidean340 hearing with a real wall present, explicit hearing-profile precedence, reset/resource isolation, and rejection of a queued sound source.

The production suite independently rerun here also covers the full inherited real-contact/guard/parry/recoil/lifecycle suite, strict86 sight boundary and additional detection-range cap, sight-before-noise priority,3.2-second memory expiry, real contact-generated crate sounds, optional single-ray attenuation, all13 mission listener placements, and physical mission sword/sonar integration.

## Important observed behavior, not a defect

A listener between the PC and attacking listener can physically obstruct the shield counter ray. The PC still parries the incoming strike, but neither listener loses Health through a fabricated or redirected counter. The existing adapter correctly requires reaching the actual attacker’s hurtbox. This behavior is retained and documented in the independent JSON observation.

## Reproduction

Use a copy of the reviewed project. Copy listener_independent_review.gd.txt to simulation/tests/listener_independent_review.gd in that copy.

Run each command with --hz=60 and --hz=120, setting XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME to isolated temporary directories:

    godot --headless --path <project-copy> --script res://simulation/tests/listener_regression.gd -- --hz=60
    godot --headless --path <project-copy> --script res://simulation/tests/listener_independent_review.gd -- --hz=60

Results are written to simulation/evidence/listener_<hz>.json and listener_independent_<hz>.json. All four final logs and JSON reports accompany this review.

An initial snapshot contained the already-known test assertion expecting7 listener placements rather than13. Only the corrected test was recopied from the sole production writer, and both rates were rerun successfully. No production edit was made by this reviewer.

## Scope and limits

This review used an isolated project copy and did not run Godot against or modify the live production/test tree. It is not an independent full-mission route, rendered visual, human playability, audible-mix, or acoustic-propagation review. The separate parent acceptance pipeline owns those other gates. The default hearing policy remains radius-based and unoccluded; the optional attenuation remains an existing single-ray radius reduction. No general navigation, new friendly-fire rule, second controller, or separate listener scene was introduced.
