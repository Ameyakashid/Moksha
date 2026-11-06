# Campaign transition stress acceptance — b2e7f35

Source: exact immutable commit `b2e7f352b96b11e9a5137145416ddeaf4a974e27`, Godot 4.6.3. All eight planned runs pass. No source/fixture drift, engine/script errors or leaked-object diagnostics occurred in accepted runs.

- Main matrix: 444 scenarios, 23,790 event steps and 202,265 assertions at 60 Hz, 120 Hz and an identical 60 Hz replay.
- Cumulative upgrades: 36 cases and 5,292 assertions per rate.
- Both deliberately broken negative controls fail their exact guards cleanly. Non-isolated save tests refuse before writing.
- Six Python runner guard unit tests pass.

See `summary.json`, `counts.json`, `source_manifest.json`, `fixture_manifest.json`, `engine.json` and `runner_unit.log`. Raw per-run diagnostics, as-tested QA sources, per-file archive hashes and separate diagnostics are in `nov6-transition-stress-b2e7f35-evidence.tar.gz`. SHA256: `af02fa4b8bb0b1a478a8e627bf594d617264a08b0347db9dcb0f43a0a134ca87`.

Reproduce with the runner and README under `campaign/quality/nov6_transition_stress`. It archives a revision or verifies a stable file copy, then runs only in that isolated snapshot. Original demo, actor/input and audio source files were not edited.

## Scope

This is headless event/state/persistence evidence using declared authored modal-entry and completed-exit fixtures, not full campaign traversal, physical-controller/native Windows testing, audible/rendered review, human timing or power-loss durability. Positive totals include the explicitly repeated run, not additional unique coverage.

The separate finale uniqueness hypothesis was rejected: deliberately completing the final district again after Continue adds one replay completion record and active time, matching documented and inherited behavior.

This b2 fallback still has the separately diagnosed nonzero controller-ID gameplay mapping limitation. Device 0 gameplay passes; IDs 1 and 3 select campaign prompts but do not move the actor with the preserved default InputMap. Any later controller compatibility candidate requires its own verification.
