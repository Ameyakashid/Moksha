# Controller composition and lifecycle review

This is a read-only-source, headless Godot 4.6.3 review of the campaign controller adapter. It includes frozen historical scripts for paired evidence. It does not replace the campaign traversal, packaging, visual, audio, or physical-controller playtests.

## Reproduce

From a checkout containing commit `b2e7f352b96b11e9a5137145416ddeaf4a974e27`:

```sh
python3 campaign/quality/nov6_controller_independent/run.py \
  --repository . \
  --candidate . \
  --output /tmp/moksha-controller-independent-new-run \
  --expect-candidate campaign/quality/nov6_controller_independent/candidate_hashes.json \
  --paired-reentry-controls
```

If running directly from this handoff, replace the script and hash-file paths with this folder. `--candidate` can point to the frozen candidate directory instead of the checkout. `--output` must not already exist. The source repository and candidate are never written to.

The runner archives the fixed b2 commit, captures the candidate campaign host, controller helper, and gamepad navigation files with before/copy/after SHA checks, stages the fixtures, and imports that new snapshot. All runs use private XDG data/config/cache directories. Gameplay fixture hosts disable saves. Reports retain the full engine output and exact commands. Both physics and fixed frame rates are 60 or 120 together. Any unexpected engine/script diagnostic or change to an archived source or staged fixture fails acceptance. New Godot UID sidecars are recorded separately.

## Reviewed candidate

Base: `b2e7f352b96b11e9a5137145416ddeaf4a974e27`.

- `campaign/input/controller_bindings.gd`: `8001ab7042cfc146a9a49bcf57a04ff2db529c330d3cf2ea16f4e53fb74862e4`
- `campaign/logic/campaign.gd`: `d14adf19f101d6f22df9177db074f426236a84a2d5e713dad4fefd9942b8bd4a`
- `gamepad_navigation.gd` is unchanged from b2; its captured hash is in `candidate_hashes.json`.

The original actor, demo, damage, physics, and audio files come byte-for-byte from the archived base. The candidate changes campaign composition only.

## Contracts and evidence

`review.gd` performs 4,582 assertions at each rate:

- Real `Input.parse_input_event` keyboard and joy events on device IDs 0, 1, and 3, including aggregate jump/strike/guard/roll edges, opposite keyboard/pad/analog directions, and release order.
- Independent aliases across overlapping hosts; starting or replacing a host while keyboard, Dpad, analog, jump, strike, guard, or roll remains held; repeated held events; release then fresh press; overlapping-host teardown while another host remains held.
- Original InputMap action identities, event identities, all stored event properties, event ordering, and exact engine-stored deadzones. Custom layouts at entry and live remapping retain their original bindings.
- Whole-alias adoption after binding insertion, identity replacement, removal, deletion, a key-equality collision, and large or tiny representable deadzone/axis edits. The assertions capture engine values, not an approximate decimal literal. Adopted aliases retain their ordered identities, contents, deadzone, and held state. Test cleanup happens only after inspection.
- Removing a held host, releasing while detached, and re-adding it; active and unrelated disconnects and focus notifications while detached; ordinary active disconnect/resume after re-entry.
- Unentered-scene disposal compared with the exact pre-pass campaign script. The pre-pass and accepted candidate each create zero orphan Nodes. The frozen b2 script separately demonstrates the known gamepad-navigation orphan, which is explicitly cleaned up by the test, not counted as acceptable parity.
- A 70-frame keyboard movement/jump/guard/roll/strike trajectory against the byte-identical b2 campaign script. Every frame compares actor position, velocity, input fields, action/weapon/shield states, and health.
- Jump release during pauses lasting 1, 2, 5, or 8 frames, with keyboard/device 0/1/3 behavior paired against the same b2 keyboard reference.

`cache_lifecycle.gd` performs 31 assertions at each rate. One hundred **synthetic event IDs** verify the 64-integer bound, duplicate handling, neutral pruning, and held-device transfer between lifetimes. It also performs 100,000 samples across ten lifetimes and checks flat Resource/Object counts and complete original InputMap restoration. This is not a claim of testing 100 connected physical controllers.

The reviewed v5 runtime passes all 9,226 assertions at matching 60/120 rates, without engine diagnostics or source/fixture drift.

The identical 4,582-assertion main fixture on frozen v4 records 37 failures per rate, covering four corrected defect classes: approximate ownership comparisons, held alias state after re-entry, pre-mounted held-input leakage, and detached focus/disconnect handling. These are retained as negative evidence, not counted as passing gameplay tests. Earlier v2 receipts preserve the edited-alias collision and added unentered-helper orphan findings. Older observer errors are labeled separately.

With `--paired-reentry-controls`, the runner also constructs two separate snapshots and runs the same compact `reentry_held.gd` against frozen v2 and v4 helpers. Both receive an actual device-1 press, detach, receive release while detached, and re-enter with the same alias name. V2 correctly returns strength 0; v4 incorrectly returns 1. The runner expects v2 exit 0 and v4 exit 1 and reports those as **expected control outcomes**, separately from positive acceptance.

## Fixture setup and limits

The tests start controlled campaigns through `start_new(true)`. They do not force an impossible combat state or claim full route traversal. Custom remapping, alias adoption, unentered disposal, overlapping hosts, and detached-tree cases are deliberate API lifecycle fixtures rather than player-menu actions. Disconnects use the engine's joy connection signal; no hardware was physically disconnected.

The b2 campaign reference is loaded from its exact saved script while its unchanged shared dependencies come from the archived project. The exact pre-pass `9e22722ebc5835bec0aed003ea71de47463fc324` script is instantiated and freed without entering the tree solely to compare constructor ownership. It is not used to claim historical full gameplay parity.

The existing explicit campaign `input_override` API remains separate. Direct `Input.action_press("cp_...")` or `InputEventAction` injection into the original action names does not feed private aliases and is not claimed as a supported physical-input path. No such campaign/demo/simulation usage was found in the reviewed source.

Do not edit the frozen reference scripts to make a result pass. For future candidate changes, omit or replace only the explicit candidate hash file, retain the baseline references, and compare new evidence with the saved receipts.
