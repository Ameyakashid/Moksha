# Independent sentinel production-boundary review

Status: PASS for the final reviewed source. No unresolved blocker within this review's scope.

## Independent execution

Godot 4.6.3, real physics callbacks, isolated project copy, 60 Hz and 120 Hz.
No production repository files or repository evidence were changed by this reviewer.

At each rate:

- Main independent suite: 9 scenarios, 55 checks.
- Hearing retirement and recovery: 8 scenarios, 16 checks.
- Real configured one-way drop removal cleanup: 1 scenario, 2 checks.
- Missing/disabled hearing fence and sensor: 4 scenarios, 8 checks.
- Total: 22 scenarios, 81 checks, zero failures. All final logs are free of script/parser/runtime errors.

The main suite drives actual PC attacks, sentinel intent attacks, held guard and timed parry. It verifies exactly one Health-backed HIT, lethal counter and completed parry/facade receipts, no fallback damage without the PC bridge, three synchronous reset boundaries, the full 4-by-4 sentinel/listener/ranged/Warden hearing partition, and disabled/paused lifecycle.

The drop-removal test explicitly changes a private capability configuration to permit drop, supplies ordinary down+jump input through the sole IntentDriver, observes a genuine one-way exception, and removes the actor. It does not inject internal motor state. Other lifecycle callback probes are explicitly named and do not stand in for successful physical contacts.

## Findings discovered and resolved

1. An earlier hearing observer could reset/reconfigure/pause the sentinel and its later policy callback would retain the stale sound. The facade now binds its delivery callback to its binding and actor generation, validates sensor identity/live state and public current receipt, and checks an explicitly PAUSABLE fence. This also retires pause/resume cycles under ALWAYS hosts.
2. The first sensor-epoch fix rejected fresh events after direct sensor rebinding. Public current-receipt validation fixes both retirement and recovery. All tested interruption variants accept a later genuine event.
3. The facade's initial `_exit_tree` override omitted base controller cleanup. An actual configured one-way drop left its collision exception active after removal. Calling the inherited cleanup now clears both the live exception RID and PhysicsServer exception.

An additional pre-test compatibility observation, dynamic hearing_range updates, was corrected by a facade setter.

## Ownership and preservation

Read-only review confirms the facade inherits the authoritative combat controller without overriding physics_tick or receive_attack. The sole IntentDriver owns scheduling; the policy returns intentions only. Explicit production contact configuration is body 32, hurtbox 4 and attack target 64. The mission PC adds only IncomingStrikeReceiver to its existing composition/scheduler. One committed-noise relay carries semantic events; only a positive Health receipt creates the sentinel HIT sound.

The final 28 reviewed production files exactly match the isolated tested copy. All 11 frozen-counter source hashes still match the preserved independent counter manifest. Source comparison with the Shared-Counter archive shows only four pre-existing production assets changed: mission composition, legacy enemy hearing-peer filtering, and ranged/Warden hearing-group scene configuration. The other archetype controllers remain unchanged.

Final facade SHA-256:
6a4f068424ac4f54ef4b639711746f28972ec80f563e049f7ab26bd3bfbcda9f

Frozen combat controller SHA-256:
7a7c7a483f88ac3b55e4e5f8d9498e02acf779a73dc03e48af0303ce1d5c1ca9

Immutable archive hashes checked:
- Shared-Counter: 524820ce4bbf7b3305a8f5f257c2a450587abcddbf433a9da29440ac207e808b
- Shared-Strike: fff9e5423029e449bf41bc6119e28be9f54b3a70d0659e4800f187efedee0d0a
- v28 Expanded: 153fd2824303354b1f70dea66c7ba91b27bc204da9c16a05f9b1a27a29955937

## Evidence and limits

`review_summary.json` contains the complete final assertion reports and archive hashes. `final_source_hashes.json` records final source stability. `final_*.log` are the eight final execution logs. The four runnable test sources are retained under `project/simulation/tests/sentinel_*_review.gd`. Earlier failing logs preserve the distinct before-fix reproductions.

This independent review did not perform native visual/audio review or rerun the full historical aggregate and all mission routes. Those remain the implementation owner's separate final gates. This pass does not claim arbitrary configuration parity, physical corpses, acoustic propagation, or migration of other archetypes.
