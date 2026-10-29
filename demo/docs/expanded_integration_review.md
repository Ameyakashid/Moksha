# Expanded mission integration review

The independent production-host fixture passes **68 checks at 60 Hz and 68 checks at 120 Hz**, with no failures. Godot 4.6.3 executes actual physics callbacks. The fixture does not edit production files and restores any checkpoint bytes present in its test user-data directory.

Final rerun on 19 October 2026 at 13:44 UTC covers the Relay Works recovery ladders, top dispatch shelf and caption-placement update, while retaining the **40 px receiver Backstop**. Both rate reports were regenerated against those final sources, and all recorded source hashes match the checked files. The independent preserved-core archive comparison was also rerun: **11/11 files remain unchanged**. This rerun retains the existing integration scope; compartment recovery routes, PC pull-up and native visual checks are separate.

Final checked source SHA-256 values:

- `demo/areas/relay_works.gd`: `4d73aef6c03d70804dee756147da6e2451cf3c60339ac08accdb4466decb0069`
- `demo/components/freight_receiver.gd`: `a86406967b12c52389479753604a8be08af2caf784a535d7a99a66ab3a8570c1`

## Verified

- The production host has eight sectors, with Freight Lock and Relay Works at their expected identities.
- The expanded checkpoint uses its separate filename and schema 3. A legacy schema in that filename is rejected; all new-game, checkpoint and Continue writes preserve a sentinel v27 checkpoint byte-for-byte.
- The actual sight-trade and archive interactions persist choice and archives. A newly constructed host continues the correct area, restores counters and serialized sector metrics, restores full checkpoint health, and rebuilds local freight/circuit objectives.
- A genuine PC active strike, through the unchanged ContactAdapter, launches designated freight in the production Freight Lock. The real rigid-body solver seats it in the receiver and opens the physical shutter and onward gate at both tested tick rates.
- Cargo replacement preserves damaged player health, enemy instance identities, sight choice and archives. It retires the old cargo before binding its replacement. Replacing delivered cargo is blocked.
- Cargo replacement, cache collection and shutter opening remove their obsolete sonar contours. Even before geometry refresh, disabled open-shutter shapes are not live renderable contours.
- A valid source retained outside a retired room cannot reveal geometry or trigger mission audio in the next room. Area transition clears old acoustic history.
- Each relay opens exactly its matching shutter; all three circuits are required for the exit. Repeated activation is idempotent. Retry and fresh-host Continue rebuild closed circuits.
- Rapid reload before deferred cargo spawn creates exactly one live current cargo, without an orphaned prior-generation spawn.
- Eleven preserved player/contact/health/defeat/noise/shield/strike/movement/prop source or scene files are byte-identical to the v26 baseline archive. The separate hash evidence records each comparison.

## Scope limits

This is an integration and lifecycle fixture, not a complete route playthrough. It explicitly positions the PC at the cargo launch stance and interaction points, disables unrelated enemy decisions, and uses a labeled damage-API boundary probe to test health preservation. Cargo launch, flight, contact, settling and gate release use real production physics; no cargo teleport, impulse injection, direct latch or direct shutter-open assignment is used to establish delivery.

The fixture also directly exercises checkpoint and provenance boundaries. It does not establish first-time human navigation, human pacing, difficulty, accessibility or rendered visual quality. Other route and native-visual tests own those claims.

## Reproduce

From the project root, run with isolated writable XDG data/config/cache directories:

    godot --headless --path . --script res://demo/tests/expanded_integration_regression.gd -- --hz=60
    godot --headless --path . --script res://demo/tests/expanded_integration_regression.gd -- --hz=120

Reports:

- `demo/evidence/expanded_integration_60hz.json`
- `demo/evidence/expanded_integration_120hz.json`
- `demo/evidence/expanded_integration_preserved_core.json`

The first draft's only failing assertion compared an integer-containing in-memory metrics dictionary against JSON-decoded numeric fields with strict Dictionary equality. Recorded values were identical; the fixture now compares against the expected serialized round-trip representation. This was a harness correction, not a production save defect.
