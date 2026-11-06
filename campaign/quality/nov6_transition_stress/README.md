# Bounded campaign transition stress tests

These tests exercise campaign state and persistence boundaries. They do not change production files or the preserved demo, controller or audio sources.

## Reproduce

Requires Linux, Python 3.12+ and Godot **4.6.3** on PATH. The supplied save isolation uses Linux XDG directories; native Windows/macOS execution is not supported by this runner. From the project root:

```sh
python3 campaign/quality/nov6_transition_stress/run.py \
  --source . \
  --revision b2e7f352b96b11e9a5137145416ddeaf4a974e27 \
  --output /tmp/moksha-transition-stress-b2e7f35
```

Use a new or empty output folder outside the source. The runner archives the exact Git revision, installs these test-only fixtures in the copy, imports it and runs there. It never tests a moving checkout. For a source ZIP without Git metadata, omit `--revision`; the runner copies the files and rejects any before/copy/after hash mismatch. Such a run is identified by its file manifest, not a guessed Git commit.

The default suite runs at 60 and 120 Hz, repeats the 60 Hz commands, checks two deliberately broken implementations, verifies refusal of non-isolated saves, then runs cumulative upgrade cases at both rates. Allow roughly 15 minutes on the tested cloud computer; this is execution time, not game playtime. `--godot /path/to/godot` selects an executable.

For a smaller diagnostic command stream, use `--seeds 2 --steps 16 --skip-replay --skip-cumulative`. This still runs the targeted modal fixtures and is not the full default acceptance matrix.

## Evidence and verdict

Output is separate from source:

- `evidence/summary.json`: aggregate verdict, exact commands, counts and command-stream digests.
- `evidence/source_manifest.json`: immutable source revision or stable-copy identity plus every archived file hash.
- `evidence/fixture_manifest.json` and `engine.json`: tested fixture and engine identity.
- Per-run JSON and raw `.log` files, including import diagnostics.
- `runtime/`: independent XDG data/config/cache folders, including disposable test checkpoints.

A passing JSON sentinel alone is insufficient. The runner also requires the expected exit status, no engine/script errors or leaked-object diagnostics, no source/fixture drift, and identical seeded command/state digests at both rates and on replay. Save-writing fixtures refuse to start without the isolation marker and a user-data path inside the supplied XDG data root.

Negative controls must fail the intended guard:

- `mutations/input.gd` removes modal input capture. A held direction leaking through the intro must be detected.
- `mutations/rollback.gd` removes rollback of a queued level upgrade. Returning to the old district while retaining that upgrade must be detected.

The deliberately broken classes are instantiated directly. They are never installed into production files or substituted for scripts on an existing live campaign instance.

The runner's filesystem and diagnostic guards have six small unit tests: `python3 campaign/quality/nov6_transition_stress/runner_test.py`.

## What is tested

Default `transition_stress.gd`, per rate:

- 128 seeded sequences × 128 basic keyboard/joy/focus/disconnect commands, checked against an independent state model.
- 128 seeded sequences × 48 upgrade-transaction commands, including independent expected checkpoint contents.
- 40 explicit upgrade interruption/retry/title sequences across the four authored level exits.
- 120 keyboard/controller held-input cases across intro, journal, pause, title Continue, focus, disconnect, retry, sight choice, archive and upgrade boundaries. Release and fresh press must rearm.
- 150 save/title/Continue cycles across three lenses and both sight choices, with unchanged-save byte idempotence, stable build values, old room retirement and current-room deferred presentation records.
- Six genuine gravity-boundary death/retry sequences, plus 16 active-input room-replacement cases.

`cumulative_upgrade_lifecycle.gd` adds 36 cases per rate: three actual title-selected lenses × retained/traded sight × six four-upgrade orders. It checks all four earned upgrades, immutable-base arithmetic, repeated Retry, focus interruption, title Continue, fresh-host Continue and explicit New. Sight is traded through the real station after entering level two.

## Fixture boundaries and limits

Keyboard and joy commands enter through `Input.parse_input_event` and normal scene dispatch. Focus and controller disconnection use the corresponding actual engine signals. These are event-injection tests, not physical keyboard/controller or OS-focus tests. Gameplay joy assertions use logical device 0, matching the preserved actor InputMap. Other device IDs can navigate menus, but that does not establish gameplay movement support for those IDs.

The basic suite disables automatic host callbacks and invokes the production campaign physics callback at actual physics-frame boundaries with a fixed delta. The shared actor and surrounding world retain their production simulation. Automatic intro timeout and rendered HUD appearance are not covered by this suite.

Modal-entry fixtures initialize an actor at an authored cache, sight station or exit. Completed-exit fixtures initialize required objectives and remove defeated guards before the measured commands. They are not claims that the preceding district or boss was played. The cumulative suite earns its upgrades through the actual choices; its approaches and preceding objective completion remain fixtures. The death fixture starts beyond the left floor edge but above the authored lethal boundary, then lets real gravity and the authenticated boundary adapter cause death. It does not write health or force the dead state.

This evidence does not establish full-campaign traversal, human duration, combat balance, audible/rendered quality, native Windows/controller behavior, exhaustive action interleavings, or filesystem power-loss durability.

## Deliberate finale replay

The game documents that Continue after completion replays the final district. Completing that district a second time adds another final-district and level-five completion record, with more active time and no extra upgrade. This is a separate completed replay, not an accidental duplicate write from one completion. It is not used as a failure in this suite.
