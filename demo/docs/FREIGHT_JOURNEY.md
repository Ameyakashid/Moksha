# Freight journey — bounded campaign assembly

This replaces sector 04's short single-launch puzzle with three connected demands using unchanged production modules:

1. **Acquisition court:** ground combat or maintenance-roof flank. An ordinary crate can make real noise while the player takes the roof; this is optional, not a required diversion or a new noise gate.
2. **Transfer deck:** secure or navigate live threats, return above the marked cargo to its loading side, then repeatedly strike and follow the same physical body. Walking back through loaded cargo can push it down: careless staging has a real consequence.
3. **Receiver/interlock:** seat one intact cargo in one physical receiver, then leave through its released shutter. No extra deliveries, enemy-health changes, timed waiting gates, or forced outcomes.

## Reuse and manual recovery

The level is plain data in `demo/areas/freight_journey.gd`; `mission_data.gd` selects it only for sector 3. Cradle, receiver, shutter, platforms, ladders, player/NPC controllers, hearing, damage and cargo solvers remain production assets. The continuous floor beneath the transfer deck leads back to ladder 1180 and the original cradle. E there replaces only the designated cargo; it does not restore health or enemies. Ordinary props are not replacement cargo. The roof ledges allow return to the loading side without pushing the marked body backwards.

The 860 px deck journey was chosen only after actual-input capacity trials: flat/downhill layouts at 60/120 Hz and three random-spin seeds (12 cases) seated the original intact cargo with 3–4 strikes and 0–1 hard impacts. No upward-step cargo assumption was made. Early downhill trials seated cargo but failed observer egress from an overly high basin; this room instead uses the established receiver height 270 over floor 300. Capacity evidence is not room/encounter acceptance.

## Evidence boundaries

`freight_journey_route.gd` supplies raw controller buttons and ordinary proximity interaction, never positions/velocities, forced kills, AI disabling or objective setters during a measured route. Direct and optional-noise approaches deliberately choose different controller tactics. The noise approach omits automatic Q while approaching/striking its ordinary prop; footsteps and genuine hearing remain enabled. Reports include actual sensor receipts and quarter-second acquisition traces. Motion during a latest-prop-receipt window is observation, **not proof that the prop caused every movement or necessarily cleared the lane**. The guard survives the noise route; delivery and exit remain the decisive physical outcomes.

The review scene explicitly starts sector 3; its traded-sight variant is an initial fixture, not a real Exchange decision. `--full-campaign` instead loads the normal mission and reaches the actual Exchange choice. Independent lifecycle probes use labelled initial placements and are not route evidence.

Preserved failures include the first room pilot walking backwards through unstruck cargo and losing it from the deck, and a rejected metadata matrix with an invalid observer property. Neither is counted as a clean acceptance run. Recovery observer intentionally recreates physical mishandling using movement only, then uses the local replacement path.

Run an isolated route:

```
godot --headless --path . --script res://demo/tests/freight_journey_route.gd -- --hz=60 --approach=noise
```

Use `--sacrifice` for traded sight; use `--full-campaign` for the genuine whole campaign. Recovery uses `res://demo/tests/freight_journey_recovery.gd` with `--hz=60` or `120`. All timings are deterministic bot active time, not novice duration. The roughly 30-minute first-play goal remains unvalidated; this is one meaningful bounded increment, not a claim of completion.

## Fresh isolated acceptance (2026-10-23)

- 8/8 clean route cases: direct/noise × retained/traded sight × 60/120 Hz. Each reaches the next sector after intact delivery; 3–4 launches, zero deaths. All four noise cases leave one guard alive. One case naturally uses local replacement, then completes.
- 2/2 dedicated input-only recovery cases: deliberately push original cargo off the transfer deck, step onto the lower floor, climb back, use E at the original cradle, launch the replacement four times, latch and exit. Zero deaths. Earlier recovery observer attempts did not achieve their intended setup (safe navigator avoided mishandling; then observer stopped atop cargo); their failed logs/reports are retained.
- Independent rules/lifecycle review: 24 checks per rate, including genuine charge/hearing, pause, boundary loss, remote-E rejection, local replacement and retry. Its labelled placements are separate from the input-only recovery routes.

Authoritative clean normal matrix: `demo/evidence/freight_journey_matrix02/`. Recovery inherits base report filenames, so use the archived matrix rather than the top-level normal filenames after a recovery run. Dedicated final reports: `freight_journey_recovery_60hz.json` and `freight_journey_recovery_120hz.json`, with `attempt03` logs. Full campaign regressions and native video review are separate parent-owned acceptance stages, not implied by these isolated passes.
