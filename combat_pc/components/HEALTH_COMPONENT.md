# Optional PC health component

This checkpoint adds one piece: a scalar health store attached to the already-tested incoming-defense result. It does not change movement, attacks, recoil, guard absorption, parry/reflection, roll protection or their timing. M12 preserved the old resolver body behind a small observing wrapper. The optional M13 defeat policy subsequently adds an early rejection for an already-defeated actor; its behavior is documented separately in DEFEAT_RESPONSE.md.

## Place and reuse

Instance `health_component.tscn` beneath `combat_pc/player.tscn`, or place it elsewhere and set Actor Path. The reusable base player scene has no mandatory Health child; the review scene explicitly attaches one. Set Maximum Health in the Inspector; it is sampled on the next reset. Default100; the review uses40. Invalid/nonfinite capacities fall back to100. Reset with Actor defaults on and can be disabled by the host.

The component owns current_health and capacity, both read-only. `bind_actor`, `unbind_actor` and `reset_to_full` are explicit host APIs. Binding does not silently refill health. Removing/unbinding the component leaves the PC motor available.

## Accounting contract

- The actor resolves the whole original defense/effect pipeline first, then publishes an immutable scalar `damage_resolved` receipt
- Guard debits its existing residual damage even though it never enters hurt recoil
- Hurt debits only when the controller confirms an admitted damaging response. The later optional committed-bracing capability can admit full damage without recoil; see `../../simulation/HURT_RESPONSE_CONTRACT.md`.
- Parry and roll evasion publish zero loss; rejected/duplicate/stale contacts do not publish a receipt
- Identified contact uniqueness remains owned by the motor. Legacy unidentified calls remain distinct applied hits
- Reset/removal during resolution cannot debit a new actor generation. For providers with `damage_admission_sequence()`, binding captures a fixed minimum serial, so an older in-flight contact cannot debit a newly bound/rebound store on the same generation. Providers without that accessor retain legacy behavior.
- Admission serials are reserved before resolution callbacks and remain monotonic across reset. Rejected/duplicate calls may leave gaps. The binding floor is fixed, never a last-seen high-water filter: nested callbacks can deliver a higher serial before a lower one and both valid hits count.
- Health clamps at zero. `depleted` fires once when positive health crosses zero; further hits do not repeat it. Reset makes a later depletion possible

`health_changed(current, maximum)` and `damage_processed(receipt)` let a host attach its own UI. The latter includes amount, actual applied loss, before/after values and original outcome. State commits before notifications, and reset/rebind callbacks cannot be overwritten by the retiring notification.

## Scope and provenance

This is original MOKSHA health accounting. It consumes existing source-informed defense outcomes; it does not claim to reproduce Dead Cells health rules. Capacity40 and the review layout are authored test choices. The existing10-point fixture hit and75% guard absorption remain unchanged. Healing, death animation/input policy, temporary immunity, armor and whole-game integration are not added in this review.

Run `combat_pc/health_review.tscn`:1 hit,2 guard,3 parry,4 roll;Q runs those four guided comparisons. The replay drives ordinary PC input through the existing swept-contact fixture; it never writes a health result. Free control usesA/D, F to request an attack, K shield, Shift roll, R reset and Esc pause.
