# Reactive companion and durable runs

This integration combines the original intellect companion slice with run identity and completion-history boundaries. It does not finish the planned story, add new sense sacrifices, or change the controller, world geometry, combat or simulation.

## Ownership

- The campaign lifecycle allocates/persists run identity and advances `session_generation` exactly once after successful New or Continue. Failed New and district retry do not advance it.
- The companion observes that generation. It owns only session-local chatter eligibility, consumed line IDs and a nonphysical mote. It cannot write checkpoints, goals, actors or inputs.
- The HUD owner validates both completion-history fields and companion line IDs before forwarding a snapshot. Its acknowledgement means accepted presentation, not proof of rendered pixels.
- Run history remains separate from mutable resume state. Record-first/checkpoint-second recovery is explicitly not a cross-file atomic transaction.

The reference mapping and its limits remain in `RUN_HISTORY_BOUNDARY.md`, `../../docs/INTELLECT_SLICE.md` and `REFERENCE_FOUNDATION.txt`. Implementations and prose are original; references are studies, not copied third-party implementations or assets.

## Acceptance boundaries

`campaign/quality/nov12_reactive_integration.gd` exercises actual host menu handlers and isolated production saves, with a deliberately seeded chatter-memory fixture. It checks one generation increment, same-frame Continue, failed-New preservation, retry behavior and the combined typed HUD. It is not a level completion or visual test.

Earlier companion-only native footage proves the opening reminder and mote on its labelled revision. Its headless routes cover a subset of the 14 authored beats. In particular, the captain introduction has not yet been observed during traversal. Source assertions, fixture coverage, native pixels and full input routes are separate evidence categories; none implies the others.

Integrated regression, fresh-run and legacy-Continue acceptance must be recorded against the exact integrated revision before a new playable release is claimed. Previously delivered builds and source checkpoints remain valid separate artifacts.

## Migration and limitations

The checkpoint path is unchanged but its envelope is v2. Older builds cannot read v2; use the preserved legacy bytes in a separate backup if deliberately returning to an older build. Never use two game processes to write the same save directory. Retained partial/conflicting records are preserved for recovery and are not automatically deleted just to make Retry succeed. Windows-native validation and power-loss durability are not established by Linux testing.
