# Production shared sentry handoff

Implementation and frozen-source acceptance are complete. The writer returns
sole repository write ownership to the parent for immutable packaging and
extracted-copy validation. No new checkpoint ZIP was created by this writer.
All eleven preceding ZIPs remain unchanged.

## Result

- All 13 actual mission-factory sentries now compose the shared actor, canonical
  projectile emitter, dedicated intention policy and cyan ranged view.
- The unchanged shared controller owns movement/action phases and root Health
  owns damage. Decision delays are distinct from the action clock. Outgoing
  melee contact is explicitly disabled. Windup 0.72 / recovery 0.95 remain.
- Locked world aim, release LOS, true same-carrier reflection, registered NPC/PC
  receivers, exact-once Health/noise and lifecycle fences are exercised through
  actual Godot physics. Mission damage and return are 12; standalone is 1/2.
- Production masks 43/43 physically include peers and cargo. Explicit configurable
  actual-owner layer filters reject friendly damage without peer passthrough.
  Owner/filter changes cannot borrow an older contact's permission.
- Legacy ranged and Warden implementations are preserved. Warden is temporarily
  a physical projectile blocker with no projectile damage receiver; no broad
  compatibility fallback is hidden in the shared components.

## Completed gates

- Production focused: 35 scenarios / 202 checks at 60 Hz and 120 Hz.
- Foundation 48/48; stock 10/10; historical 19/19.
- Four full mission routes: all complete, zero deaths/retries/failures.
  Retained/sacrificed at 60 Hz: 177.483 / 166.350 simulated active seconds.
  Retained/sacrificed at 120 Hz: 171.283 / 161.117 seconds.
- No source changes during complete serial acceptance; all 548 final live
  source hashes rechecked. Delta: 9 modified, 10 added, 529 unchanged, 0 removed.
- Independent: 18 final runs, six extra families with 32 scenarios / 153 checks
  per rate, all 19 reviewed hashes match; clean import and 300-frame boot pass.
  Original source-layer, cargo-fixture and retreat-facing failures are retained.
- Native isolated initial Intake scene: cyan bow/warning/aim, ordinary shield
  display, actual sword Health reduction and defeat, R retry. Free-flight bolt,
  projectile damage, reflection, blocker/filter contact and audio remain native
  unverified. No full native traversal is claimed. Automated physics covers
  those projectile outcomes. Full limitations are in native_sentry_review.md.

## Evidence and source contracts

- `../SENTRY_CONTRACT.md` and `../VERIFICATION.md`
- `sentry_acceptance.json`, `sentry_final_gates.json`
- `sentry_source_delta.json`, `sentry_changed_sources.diff`
- `sentry_archive_preservation.json`
- `sentry_{foundation,stock,historical,routes}_runner.log`
- `sentry_historical_report.json`, `route_summary.json`
- `sentry_independent/REVIEW.md` and `review_acceptance.json`
- `native_sentry_review.md`, `native_sentry_capture_hashes.json`
- `sentry_initial_gate/` and `sentry_independent/original_failures/`

Independent review packet, also copied as readable evidence above:
`/tmp/moksha_sentry_review/moksha_shared_sentry_independent_review.zip`
SHA-256: `3dccd13694c8c6ce286d5def2fa49ac933ec9490b470859eb67107de69141c39`.

Preceding immutable baseline:
`/workspace/shared/MOKSHA-Simulation-Shared-Projectile-2026-10-19.zip`
SHA-256: `be02dd87a9e63ff370ee56dd14566977690b181c51a0bbc43c65f0bbaca5c631`.

## Remaining bounded limits

Warden receiver/controller migration is pending. Arbitrary manual emitter
replacement does not automatically reconnect this fixed facade's presentation
observers, although physical retirement and a fresh component action are tested.
The shared callback API assumes trusted local scripts, not a sandbox against
direct object rewriting. Corpse physics, complete acoustics, balance and further
capability work are outside this sentry slice.
