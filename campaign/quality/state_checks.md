# Bounded objective and checkpoint guards

These checks supplement—not replace—the existing `campaign/qa_audit` gameplay,
damage, door-physics and save-lifecycle fixtures.

## Objective state exploration

`state_explorer.gd` constructs each district's real objective scripts and explores
every reachable finite combination of local objective states. Each ordinary
interaction uses production `interact()`, including failed interaction attempts,
route cycling away from a correct setting, and latched downstream installs.
The checks assert prerequisite admission, no unrelated state mutation, route
cycle semantics, persistence of latched goals, and existence of paths to required
and all-objective completion.

A successful physical plate/breaker event is an **abstract fixture edge**, admitted
only with satisfied prerequisites. The explorer does not simulate cargo placement,
strikes, movement, captain seals or old mission relay rules. Empty-objective rooms
are valid single-state graphs. This is executable bounded state exploration, not a
TLA+ proof, full campaign proof, or proof of collision/nav feasibility.

Godot 4.6.3 result: 32 districts, 626 states, 3,332 attempted action edges and
24,285 assertions. Output is a `STATE_EXPLORER_RESULT` JSON line.

## Adversarial saves

`state_save_adversarial.gd` must run with a temporary XDG data directory and the
explicit `--isolated-save-tests` flag plus `MOKSHA_QUALITY_ISOLATED=1`. The
actual Godot user-data path must be inside the explicitly supplied XDG data root. It also restores pre-existing checkpoint
bytes defensively. It tests 51 malformed object/schema/value cases, four truncated
JSON inputs, no live mutation after rejected Continue, an orphan partial pending
file, replacement by a successful atomic save, and stable-ID roundtrip/cleared
local goal state for all 32 districts. Those district fixtures intentionally dirty
local goal state before Continue; they are not gameplay traversal.

Godot 4.6.3 result: 173 assertions at each of 60/120 Hz. Output is a
`STATE_SAVE_RESULT` JSON line. The runner must additionally reject engine/script
errors; a test sentinel alone is insufficient because Godot can abort an invalid
function call yet let its caller continue.

The new tests reproduced two errors in `_read_checkpoint`: truncated JSON emitted
engine errors via `JSON.parse_string`, and a string campaign version (`"1"`)
caused an invalid String/int comparison. The narrow fix uses the already-existing
quiet `Checkpoint.parse` helper and validates an integral numeric version before
comparison. Valid saves and gameplay behavior are unchanged. The rerun has no
engine/script error diagnostics.

This tests orphan-file handling, not real power-loss/filesystem durability. It
makes no server anti-cheat or cryptographic save-integrity claim.

`state_negative_controls.py` injects deliberately broken objective subclasses
without touching production files. Both silent dependency bypass and physical-E
mutation must make the explorer fail with the specific guard diagnostic. It also
checks that the save fixture refuses missing isolation markers before writing a
checkpoint.
