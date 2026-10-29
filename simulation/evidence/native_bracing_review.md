# Native shared hurt/bracing review, 2026-10-19

A separate read-only CUA reviewer used the supported native Godot editor and
ordinary controls. The seventh selector entry opened `bracing_sandbox.tscn`.
The parent relayed the observed controls/results; the implementation writer
also inspected the saved PNG pixels after the session.

Observed:

- All seven selector buttons and footer fit without clipping.
- Stage instructions, both actors and status text are readable and remain in
  bounds. The NPC displayed gold shoulder protection during an active action.
- Ordinary J/K exchanges produced visible damage in both directions. Saved
  `native_bracing.png` shows Player Health 19, one Health-confirmed braced hit,
  locomotion/recovery, and NPC Health 29, locomotion/idle. Both counter counts
  are zero. The image is a later summary frame, not a continuous hit timeline.
- R restored both actors to 30 Health, zero braced-hit/counter counts and initial
  positions. Esc returned to the seven-button selector. CUA was then released.
- The PC pressed against the left boundary during idle attack attempts; neither
  actor was outside the stage bounds.

Not established by this native session: the precise uninterrupted action
retention timeline during the braced contact, a successful timed counter,
projectile/cargo response, exact .70 boundary timing, or audible mix. Automated
actual-contact tests separately establish those deterministic semantics.
The editor's visible Debugger count remained at 9 and was not fully inspected;
this is not an empty-debugger claim. No visible runtime interruption occurred.
The later counter target/source-state fence changes do not alter the observed visuals.
Fresh headless import and source-frozen suites provide current diagnostic gates.

Verified captures: `native_bracing.png` (1280x720, 77,284 bytes) and the updated
`native_gym.png` (1280x720, 115,912 bytes). SHA-256 values are recorded in
`native_bracing_capture_hashes.json`. The earlier six-button selector remains
preserved in the immutable preceding checkpoint ZIP.
