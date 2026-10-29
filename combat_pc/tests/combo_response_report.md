# M20 fresh-tap combo response verification

PASS at 60 and 120 Hz on Godot 4.6.3-stable (official). The same 79 focused scenario definitions pass at each rate. Recorded physics samples are evidence, not additional test cases.

## Observable result

- An early second tap at 16.67 ms (60 Hz) or 8.33 ms (120 Hz) now queues one Backhand. The preserved resource rejects that tap until 35 ms. A matching early Backhand tap queues one Finisher.
- Three taps at 0, 50, and 230 ms produce Slash → Backhand in the baseline profile and Slash → Backhand → Finisher in the candidate at both rates.
- Finite 1.6-second bursts at 6, 10, 18, and 30 taps/second each produced two ordered three-strike cycles. Every admitted stroke consumed a unique fresh press. Stopping a burst drained at most one already-pending input and left no backlog.
- Holding Fresh attack produces one stroke. Native J held through reset or reconfiguration does not resurrect canceled intent; release and a new key press still work. Held Repeat and Held Charge retain their separate behavior and never use the new Fresh restart route.
- The late-finisher restart window opens for the last 120 ms of recovery. One accepted request uses the existing 140 ms attack buffer and starts a new Slash only after the full, unchanged finisher recovery. Before-window, first-open, last-live/completion, and post-completion boundaries are separately tested.

## Focused safety and ownership checks

Real production actor and shared collision fixtures cover early/native taps, finite spam, press/release wholly inside actor-local hitpause, queue-full refusal without deadline refresh, deadline's last-valid and expiration callbacks, attack permissions and independent reuse locks. Input-disabled capture is refused and disabling input clears existing pending intent.

Hurt, shield, roll, jump, reset, forced finish, resource/input-profile swaps, and explicit buffer clearing discard a pending restart. At queue admission, attack completion, and completed-chain reset callbacks, synchronous reset, hurt, resource replacement, resource round-trip, and recursive physics entry are tested. No stale restart escapes; nested physics entry creates no new physical press identity.

Whiffs, one target, two targets, and terrain occlusion run in both directions. Eligible targets receive exactly one effect per distinct strike; contact receipts match actual effects, and hitpause is spent once per strike. Identically timed baseline and candidate combos preserve exact recorded movement and action ownership on the original, agile-ground, and agile-air profiles, on the ground and in the air.

All per-step phase, damage, movement, cancellation, shape, pose, and feedback values match the preserved resource. Only Slash/Backhand follow-up opening time differs. Existing follow-up deadline and idle retention are unchanged. The restart field defaults to zero on the preserved resource, and invalid negative/nonfinite values are refused.

## Regression layers

- Preserved v23 controller and byte-identical original combo harness: 295 scenario definitions pass at both rates
- Current controller with original light-chain resource and original combo harness: same named scenario outcomes at both rates
- Preserved v23 controller and byte-identical original held harness: 114 scenario definitions pass at both rates
- Current controller with original resources/modes and original held harness: same named scenario outcomes at both rates
- Current controller, preserved baseline profile comparison: 13 scenario definitions pass at each rate

Historical harness execution changes only output destinations; original harness bytes are never edited. Archived compatibility uses the actual controller extracted from the pinned archive, not a simulated baseline. Current compatibility uses the actual current controller and compares named scenario assertions with the archived runs.

## Provenance and reproduction

Preserved archive SHA-256: 51365050b5e1086a94290aa7629b3e07a4f31dffcc63964ba05b0882de0e2ad6

The source audit checks 341 original .gd/.tres/.tscn/.py files. Authorized differences are combat_pc/player.gd, combat_pc/resources/melee_chain.gd, combat_pc/reference/generate_parameter_ledger.py, and the packaging-only tools/package_project.py change. No unexpected original-source changes were found. Final candidate trace hashes and current-controller compatibility hashes match current source bytes.

Run from the project directory:

    python combat_pc/tests/combo_response_run.py --baseline-zip /path/to/preserved-v23.zip --godot-bin /path/to/godot
    python combat_pc/tests/combo_response_build_report.py

GODOT_BIN or the command on PATH also works. The runner accepts --hz, --suites, and --output-dir for targeted runs; full acceptance requires both rates and all six suite selections. Source audits, per-run summaries, and compressed full traces use the combo_response_ prefix. The final machine-readable summary is combo_response_acceptance_summary.json.

These are deterministic headless input, physical contact, and ownership checks. Animation feel, rendered visuals, and subjective satisfaction require the separate native review; no executable equivalence to another game is claimed.
