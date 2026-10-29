# Generic shared hurt capability handoff

Implementation and final acceptance are complete. The implementation writer
returns sole repository write ownership to the parent for immutable packaging.
No production Warden/factory/action migration is included.

## Implemented interface

- `MokshaMeleeStepProfile.hurt_protected_phases`: empty default; authored `windup`
  and/or `active` only. Existing deep action snapshots capture the capability.
- `hurt_interrupt_seconds`: finite, nonnegative; default 0.70. Strictly shorter
  effective stun preserves the committed response while admitting full damage;
  equality or longer uses the existing ordinary hurt path.
- `hurt_response_snapshot()`: defensive scalar-only observation of current
  protection, phase, serial and threshold. No mutable committed resource escapes.
- `receive_attack` distinguishes admission, bracing, recoil and interruption.
  Controller receipt flags are integer scalars; consumers use matching
  `Health.damage_processed.applied` for completed damage, never requested amount.
- `ShieldCounterReceiver.response_stun_seconds`: -1 default omits the override;
  finite 0..5 allowed. Binding capture retires on change. Only a genuine canonical
  ray and one-use claim can admit it. The generic gym uses 0.78 on both actors.
- Health captures a fixed admission floor at binding, protecting replacements
  from older in-flight contacts while accepting nested N+1-before-N delivery.
- Final counter target/source scope reads close independently reproduced stale
  callback-return holes without a public validation loop or another recoil solver.

`../HURT_RESPONSE_CONTRACT.md` is the complete contract. The ordinary `_receive_hurt`
body is byte-identical to the preceding Sentry checkpoint. Existing profiles keep
their empty default; the Health and counter lifecycle corrections are explicit
behavior changes beyond that field. The old Warden bespoke recoil/pause and fake
failed-counter retaliation are deliberately not preserved by this generic API.

## Final gates and evidence

- `hurt_final_gates.json`: all six gate groups pass; 554 frozen source hashes.
- `hurt_foundation_report.json`: 53/53 stages, including seventh-stage boot/lifecycle.
- `hurt_response_{60,120}.json`: 104 scenarios / 398 checks each.
- `hurt_projectile_{60,120}.json`: 12 scenarios / 73 checks each.
- `hurt_compatibility.json`: 10/10 stock combinations.
- `hurt_held_{60,120}.json`: 333 checks each; runner logs record 114 scenarios each.
- `hurt_historical_report.json`: 19/19 stages with preservation checks.
- `hurt_route_summary.json`: all four routes complete; zero deaths/retries/failures.
- `hurt_independent/final-green/final_review.json`: 22 independent isolated runs,
  2,390 checks, exact matching production hashes, no remaining review blocker.
  Sibling red directories preserve the independently reproduced old bugs.
- `native_bracing_review.md`: bounded native observations, including reset/return
  and one Health-backed braced count. Continuous action retention/counter timing
  and audio were not established natively. PNG hashes are separately recorded.
- `hurt_source_delta.json`: 540 unchanged, 8 modified, 6 added, 0 removed sources.
- `hurt_archive_preservation.json`: all 12 preceding ZIPs unchanged.
- `hurt_report_preservation.json`: 645 preceding reports/docs unchanged, excluding
  four intentionally updated documents. New reports retain the `hurt_` prefix.
- `hurt_acceptance.json`: consolidated final acceptance and hash checks.

Reproduce the aggregate with `python3 simulation/tests/run_hurt_acceptance.py`
from the project root using Godot 4.6.3. The runner sets writable `/tmp` XDG paths,
preserves prior reports and checks all source hashes before/after. Independent
harnesses are retained as `.gd.txt`/`.py.txt` evidence rather than live imports.

## Packaging and next checkpoint

Baseline archive: `MOKSHA-Simulation-Shared-Sentry-2026-10-19.zip`.
SHA-256: `9c1f43e31c220e14e7ebd42b7480f51670292e89ee0aad37486b8aa068041294`.

Package a new immutable checkpoint without modifying prior ZIPs, verify CRC and
per-file bytes, then clean-import/boot the extracted gym and Bracing scene. Keep
the source map identical to `hurt_final_gates.json`. Native captures are final;
the CUA session has been released. Warden migration is the separately approved
next slice and still needs its own write transfer, behavior review and gates.
