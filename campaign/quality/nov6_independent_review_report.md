# November 6 independent review

Final focused review: **PASS**, Godot 4.6.3, November 6, 2026 at 21:51:49 UTC.

Authoritative receipt: `nov6_independent_results_20261106T215149Z.json`.
It contains the exact tested source hashes, each command, isolated data locations,
engine logs, structured receipts, and an empty reviewed-source drift list.

Twelve stages passed with **2,461 assertions/negative checks**, no engine errors,
and no remaining confirmed finding in this review's scope. Production edits were
made by the responsible implementation workers; this review added only
`nov6_independent*` tests, runner, and evidence.

## Findings caught and regression-checked

1. **Focus-loss races (medium).** Press R and lose focus before the next physics
   tick, choose a level upgrade and lose focus before loading, or lose focus during
   the automatically ending intro. Each could start gameplay in the background.
   The focus guard now suspends all three paths until explicit resume. The intro
   timer is preserved rather than silently skipped.

2. **Canceled upgrade transaction (medium).** At the completed Quarantine exit,
   choose Vitality, lose focus before loading the next level, then select Retry or
   Title. The old exit retained the upgrade and completion receipts, allowing
   repeated awards and eventually invalid upgrade counts. Cancellation now rolls
   back the uncommitted upgrade, district metric, and level receipt. Successful
   resume commits exactly once, and a later retry preserves the committed award.

3. **Release lost during pause (medium, pre-existing device-edge behavior).** Jump,
   pause during ascent, release Space while paused, wait, and resume. The actor
   received an explicit false release flag after the engine edge expired. Measured
   resumed ascent was -332 pixels/second instead of the configured release cap of
   165. Device sampling now preserves true release edges and permits the unchanged
   actor to infer a release from its last held sample. Explicit caller-provided
   input overrides retain their original meaning.

4. **HUD owner forwarding gap (parent's native finding).** The base snapshot owner
   discarded the new campaign fields even though direct-View tests passed. The
   independent replacement test uses the actual host-to-owner-to-View pipeline.
   It validates all 32 district scenes, boot/title appearance and lens, forwarding
   of nine campaign fields, rejection atomicity, unknown-field omission, copying,
   and the unchanged base owner's narrow whitelist.

5. **Floor notice overlap (readability).** An authored two-line completion notice
   covered 12 pixels of the floor actor's legs. The revised layout has zero measured
   intersection with the floor-body rectangle for authored floor objective
   notices. Native visual acceptance remains separate.

6. **Runner false-pass safeguards (medium, verification).** Empty, negative,
   boolean, or absent assertion counts and zero-check presentation receipts were
   accepted. The aggregate runner now rejects them. Independent negative controls
   also verify missing/duplicate/malformed receipts, a false success flag, failure
   lists, nonzero exit codes, and engine errors despite exit zero. Nested layout
   stage results are rewritten after their nested receipt is validated.

## Final independent coverage

At each of 60 and 120 physics ticks/second:

- 67 keyboard/device and modal/focus checks, including alias handling, same-event
  pause/resume, automatic intro completion, and rearming.
- 32 synthesized Joypad event integration checks through the real input pipeline,
  including gameplay actions, menus, held-button rejection, device legends,
  disconnect pause, and explicit resume.
- 13 authored level-exit transaction checks using explicitly initialized
  objective/captain-completion fixtures.
- 1,110 real HUD forwarding and malformed-snapshot checks.
- One real-device paused-jump release regression.

Separately: 15 runner negative checks and a geometric caption-overlap diagnostic.
The original camera, objective, authored-layout, build, and save-feedback suites
were also independently rerun during the review; the final aggregate and full
campaign route receipts are separate evidence owned by the parent task.

## Source identity

Key final SHA-256 values:

- Campaign: `ff2327bd9f086032033cc40cea812f6a40aee28331d1d71c65fca5a15e4d9a2f`
- Input gate: `39e6202cf413a26a95b3c8319e568a67c7bf40aa6bed8ec4be1ffb1d115209df`
- Controller adapter: `04bd49dd82d58310c15ef1c0dfc92ddb1b6be0f9797f2260551eaa05e9afc591`
- HUD View: `5924d49ab270d916505c4301f60e0c4f48d9605bd8b0091b95f959da2988f935`
- HUD owner: `1e2d857911a8ee7a5df18be869cb86a79414fbd42ed7c0a7e0b38e7bdf03eac7`
- Camera rig: `821a2896ab8ced7995d5f50c88d1dbb1db32e568468328d2a7f82b08c27d0196`

Reproduce with `python3 campaign/quality/nov6_independent_run.py`. It creates new
evidence and never overwrites an earlier receipt.

## Limits and retained failures

This is not physical gamepad hardware acceptance, a complete campaign playthrough,
native rendering/audio/performance acceptance, or validated human pacing. Direct
scene/menu/completion initialization is labeled in the tests. Source identity
covers the selected production files and dependencies listed in the receipt, not
a claim that every repository file was reviewed.

The earlier `nov6_independent_results_20261106T214721Z.json` remains a **failed**
interim receipt: a partially landed scenery dependency produced genuine engine
errors while gameplay assertions passed. The runner correctly rejected it. It
must not be used as final acceptance; the later clean receipt supersedes it.

## Final presentation delta and snapshot aggregate

After the broad independent receipt, the HUD received one further presentation
change: remove an exact duplicate `/ J [J]` label before controller translation.
The delta passed the real HUD pipeline (1,110 checks) and presentation contract
(2,496 checks), with no engine errors or relevant source drift. Receipt:
`nov6_independent_hud_delta_20261106T215447Z.json`.
Its HUD SHA-256 is
`315a4e9747cff54bd16cb5c57cfeaa9e7e02a5c8cc2ad453c39c82c4d66cefa2`.
Other key reviewed production hashes above are unchanged.

The parent's complete 27-stage focused aggregate also passed independently against
the immutable round-two candidate, including all five positive/negative layout
cases, with zero source drift. That receipt is at
`/tmp/moksha-independent-round2-20261106T215111Z/summary.json`.
The round-two snapshot predates the final paused-release fix and duplicate-label
cleanup; the clean broad independent and targeted delta receipts above cover those
later changes. This aggregate is still distinct from full input-route or native
acceptance.
