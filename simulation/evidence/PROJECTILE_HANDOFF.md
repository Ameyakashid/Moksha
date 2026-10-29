# Shared projectile adapter acceptance handoff

Status: accepted opt-in boundary, ready for a new immutable checkpoint archive.
Production sentry migration is a separate next slice; no factory was switched.

- Run: `python3 simulation/tests/run_projectile_acceptance.py`
- Final gates/source hashes: `projectile_final_gates.json`
- Focused 39 scenarios / 115 checks per rate: `projectile_60.json`, `projectile_120.json`
- Foundation 45 stages: `foundation_report.json`
- Historical 19 stages: `projectile_historical_report.json`
- Four zero-death/retry routes: `route_summary.json`
- Independent proof: `projectile_independent/REVIEW.md` and `review_acceptance.json`
- Cargo-baseline code delta: `projectile_source_delta.json`
- Only two existing production seams: `projectile_controller_accessor.diff`
  (read-only sample accessor) and `projectile_stock_carrier_seam.diff`
  (unchanged legacy dispatch extracted behind optional genuine sweep scope)
- Ten immutable archive hashes: `projectile_archive_preservation.json`
- Native: `native_projectile.png`, `native_gym.png`, with exact interpretation in
  `../VERIFICATION.md`; screenshot is earlier than the observed NPC debit.
- Reusable action/emission/contact/lease contract: `../PROJECTILE_CONTRACT.md`

The legacy carrier fallback and existing production ranged/Warden hosts remain.
The new shared scene requires explicit ProjectileReceiver participation; absent
receivers never gain silent fallback damage. Default masks include cargo.
One-use sample/launch/contact authority, registered typed source ownership,
geometry/lifecycle fencing and observed Health receipts were independently
challenged and corrected before the frozen final gate.

No gameplay source changes occurred during final acceptance. Packaging must not
replace any previous ZIP. Parent owns packaging and the next writer transfer.
