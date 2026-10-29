# Independent production shared-sentry review

Outcome: no remaining blocker in the reviewed scope on the final source hashes recorded in `review_acceptance.json`.

## Final verification

- 18 final suite runs across 60 and 120 Hz passed without script/runtime errors. All 19 reviewed production source hashes stayed stable and matched the live production freeze.
- The exact production sentry regression passed 35 scenarios / 202 checks at each rate. The generic projectile regression passed 39 / 115 and the preserved legacy ranged regression passed 16 / 74 at each rate.
- Six independent families add 32 scenarios / 153 checks per rate. These include real contact with source-layer/filter mutation during capture, final post-claim hooks, receiver rebinding/reset, ownership mutation, retired reflection scopes, pending pause retirement, release-noise reset, returned-hit reset, emitter replacement, profile isolation and sustained close-range retreat followed by an ordinary facing-correct attack.
- A fresh project copy with no `.godot` cache imported cleanly. The final shared-sentry scene then booted for 300 frames at 120 Hz without errors.
- Legacy ranged scene/controller/carrier/test hashes, the stock combat controller and the stock guard carrier exactly match the pre-migration baseline.

## Findings resolved during review

1. **Source permission was read after receiver capture.** A genuine receiver capture callback could change the source body layer from 32 to 2 and allow an NPC shot to damage a peer in the same captured sweep. The original reproduction debited Health in callback frame 197. The carrier now captures genuine owner/layer before its initial source hook and rejects changes around receiver capture. Final 60/120 probes reject that captured scope; a later genuinely new sweep may use the now-current configuration (frames 100→101 and 197→198). Receiver filter changes are similarly fenced.
2. **The first cargo fixture was unreliable.** It inserted cargo before waiting for sight-based warning, so the correct cargo LOS blocker caused an unchecked timeout. Random launch geometry then sometimes produced a physical bounce without shared damage admission. Independent runs reproduced the same two failures at both rates. The owner corrected the test to observe a genuine warning first, insert the real production mission crate, apply explicit deterministic fixture lift/spin settings, and launch through ordinary one-frame attack input. The unchanged physical requirement now includes one launch, one Health3 debit and pending-shot cancellation. The corrected production suite passes both rates.
3. **Close-range retreat oscillated facing each tick.** The original policy turned toward the target before every decision-delay sample, fighting ordinary retreat movement. An independent 120 Hz probe recorded 42 facing flips in 0.35 seconds and only 3.79 px of retreat. Moving target-facing alignment into the attack-ready branch removes the conflict while retaining ordinary controller input. Final both-rate probes record one initial turn, continuous retreat exceeding 10 px, then genuine facing-correct commitment.

## Exact-source and instrumented tests

The main review project runs unchanged production sources plus independent test scripts. Two isolated variants expose otherwise narrow extension callbacks:

- `postclaim_variant` changes only the emitter's carrier preload to a subclass of the genuine shared carrier. Its one-shot hook runs after the genuine contact claim. Nine cases per rate confirm final-local rejection of source layer, filter, owner, attack identity, reflection flag, disable and reset changes before Health mutation.
- `entry_variant` changes only the production sentry scene's emitter script to a subclass of the genuine emitter. A one-shot live-contact lease hook changes the receiving filter; the original contact is rejected and only a later new physical sweep may apply damage.

No fabricated contact substitutes for a successful shot. Lifecycle calls and callback mutations are explicitly negative/boundary probes. The controller, Health, sweep implementation and production damage paths remain unchanged in those variants.

## Limits

This is independent headless physical/contact/lifecycle and compatibility review. Native appearance, audio/game feel, full mission routes and aggregate historical gates are separate owner reviews. Warden remains an explicitly unregistered physical projectile blocker in both directions, with no fallback damage. Arbitrary emitter replacement proves flight retirement and a fresh genuine emitter action; the sentry facade does not automatically reattach its presentation observers to a manually substituted component. This is a trusted local-script interface, not a security boundary against scripts with direct object access.

## Evidence

- `review_acceptance.json`: runs, hashes, live-source comparison, preservation, instrumentation and extra outcome checks.
- `final_logs/`: final exact-source and isolated-variant logs plus fresh import/boot.
- `checks/`: detailed assertion records for the independent mutation/lifecycle/reflection/spacing families.
- `probes/`: readable nonexecutable `.txt` copies of independent test sources and runner.
- `original_failures/`: original source-layer, spacing and cargo fixture evidence, plus relevant original source snapshots.
