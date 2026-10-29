# Independent request-retention experiment review

## Decision
Do not merge the frozen experiment yet. The shared request-retention model is supported by the physical tests, but five stale-request cases must be fixed for each role. The experiment test window is finished and core ownership has been returned to the production owner. No production or experiment core file was edited by this reviewer.

## Frozen source and exact fixture
- Frozen player.gd SHA-256: 1468d9d19969ec3848332861a61f374b83d328bcbcfbeb013c228b895168ee92 (verified before and after runs).
- Independent fixture SHA-256: 52744e5719e2648e5de57128a54563ad4ef97032c3e7376e50db193fffc2f580.
- Fixture: /tmp/moksha_actor_cargo_request_experiment/simulation/tests/actor_cargo_request_regression.gd.
- Final frozen evidence: simulation/evidence/reviewer_frozen_request_60.json/.log and reviewer_frozen_request_120.json/.log in that experiment.
- Exact fixture snapshot and evidence hashes: reviewer_frozen_request_fixture.gd.txt and reviewer_frozen_request_sha256.json in the same evidence directory.
- Each run: Godot 4.6.3, --headless --fixed-fps HZ, --script res://simulation/tests/actor_cargo_request_regression.gd -- --hz=HZ; reviewer-specific writable XDG paths.
- The fixture's frozen_player_sha256 field identifies this original experiment, not a later corrected implementation. Later runs must additionally record their actual core hash externally.

## Results at both 60 and 120 Hz
178 checks per rate; 168 pass and 10 fail. All failures are the same five cases for PC and NPC:
1. A real receive_attack followed synchronously by finish_main_action before the next tick can reuse the old request. The action is again locomotion but its generation changed. The first acceleration uses 218 px/s rather than fresh 51.6667 at 60 Hz or 25.8333 at 120 Hz.
2. Cargo lifecycle invalidation can reuse the old request.
3. Cargo shape geometry changes can reuse it.
4. Cargo mass changes can reuse it.
5. Cargo physics-material changes can reuse it.
These are labelled lifecycle/configuration API mutations after real repeated Godot contacts, not fake contact receipts. Fix with actor action/weapon/reset generation binding and a value-only rigid-body configuration/lifecycle signature. Recheck before reusing the cached acceleration base; no pose/velocity signature, because actual moving cargo remains eligible. Every impulse must still require a new real sweep.

## Substantive passing gates
Both roles pass neutral, reverse, jump, attack, ongoing hurt, reset, crouch clamp, actor force/config replacement/disable, body removal/freeze, moving-away/no remote impulse, and a later actual static-side obstruction. Ground pressure remains uncharged; actual uncharged cargo contact does not damage. Autonomous sentinel-to-cargo-to-PC and Warden-to-cargo-to-NPC each produce one canonical launch and exactly 3 damage through actual contact. The independent moving-carrier observer sums actual carried displacement rather than production diagnostics; its receipt-accounting error is exactly zero at both rates.

Pinned wall and wall/ceiling corner use a real unfrozen crate. Every actual side-blocked frame exposes horizontal output velocity exactly zero. There is no penetration. Total displacement during a one-second observation is 0.912247 px at 60 Hz and 0.979538 px at 120 Hz, within the initial one-pixel wall gap. Maximum actual per-tick step is 0.539108 / 0.273193 px. The nonzero 218 px/s output on occasional gap/recovery frames has no actual side hit; it is retained requested motor motion on an unobstructed final sweep, not a measured whole-frame displacement velocity. The initial overbroad assertion conflated those cases and is retained separately as invalid diagnostic evidence.

All repeated contacts share the 1400*dt impulse budget: maxima 23.333333 and 11.666667. Pinned contact duty differs (40/60 versus 119/120 actual side-blocked frames), so total force at a perfectly constrained body is not claimed identical across rates.

A nonrotating, low-friction law-parity control produces exactly equal PC/NPC displacement within each rate: 152.295776 px at 60 Hz, 153.769562 px at 120 Hz. Total impulse is 315.755875 / 316.202947. This supports the same shared law and removes the old inverse-rate pressure collapse. It does not prove identical rotating-contact trajectories, and no such claim is approved. Preserve ordinary rotating observations without weakening their reported measurements.

## Fixture validity and retained corrections
The observation-only actor subclass records actual movement/contact results and calls super; it does not assign motion outcomes. Actors use real RawSource/NPC input ownership. Initial geometry/material setup and direct lifecycle mutations are labelled. The corrected later-static-wall fixture puts its near face 0.005 px in front of the actor so the static body, rather than the nearly coincident rigid, is the first actual hit at both rates. The earlier 120 Hz miss and the initial all-frames pinned-velocity assertion are preserved as reviewer_before_static_correction_120 and reviewer_initial_request_60 evidence.

## Read-only route observer review
Compared demo/tests/expanded_mission_route_bot.gd to the pristine Warden extraction. Only a generic supported-waypoint projection helper, three internal staging checks, and navigate's planning target changed. No gameplay position, health, damage, physics, or mission success gate changes. Projection preserves target X, requires the original point inside the live current support, and requires the first ray hit to be a walkable surface on that same body within the existing foot probe. The existing staging tolerance still applies to actual actor feet. Successful staging projections are logged with original/projected coordinates and support ID.

This is a sound observer correction for a waypoint inside newly solid cargo. Acceptance remains conditional on the fresh four-route runs and pristine-Warden-with-observer-only control runs, preserving observer/core hashes and projection events. This reviewer did not run or modify those routes.

## Corrected experiment follow-up, 2026-10-20 00:25 UTC

Conditional adoption approved for the exact corrected shared request-retention implementation, subject to the still-pending focused, production, full regression, and four production route gates. This is adoption approval for the bounded change, not final acceptance of the entire actor/cargo slice.

Read-only inspection confirms generation/configuration checks are performed before a previous request can become the acceleration base. The cache is bound to actor action, weapon, and reset generations; the rigid body signature contains exact shape resources/RIDs/server geometry, owner transforms and disabled flags, collision configuration, mass/inertia/local COM, rotation/integration/damping settings, physics-material identity/values, and cargo lifecycle/epoch. Body pose and velocities remain dynamic. Every impulse continues to require a new genuine contact. No newly introduced blocking defect was found in this narrow diff.

Fresh unchanged-fixture reruns passed 178/178 at both 60 and 120 Hz. The owner confirmed exact --fixed-fps commands, sessions 49545 and 90028, both exit 0. This reviewer independently read both result files and verified the source hashes after completion. The initial unfixed-fps 120 Hz rerun had an extra physics tick in its comparison control; it was preserved separately and is not acceptance evidence.

Corrected source hashes:
- combat_pc/player.gd: 5742ab882f71a110ed4aae98a0f882d01f407fdc3fcdd228e1f85140b3e9488c
- simulation/resources/actor_material_profile.gd: b40c7012419930e1e1029c0972c484caf61c1c3be509f6bbe2aaf770c65eda5d
- simulation/tests/actor_cargo_request_regression.gd: 52744e5719e2648e5de57128a54563ad4ef97032c3e7376e50db193fffc2f580

Fresh result provenance:
{
  "60": {
    "checks": 178,
    "failures": 0,
    "trace_sha256": "ba9b29d5550bdab0d0fb42d2c499ef769ffb9f18926a521c87090a9686c0e438"
  },
  "120": {
    "checks": 178,
    "failures": 0,
    "trace_sha256": "2598b212b0bdc17918aa097c744adb16ed3e70097cb752c1e78ede397c43c2a9"
  }
}

The prior failing experiment results and critique above are intentionally preserved. The fixture metadata field frozen_player_sha256 still names its original baseline; the actual corrected hashes above and reviewer_post_signature_source.json establish the new core provenance.

The adapted observer-only pristine-Warden controls also completed all four routes with no deaths, retries, failures, or source drift. Its 506 recorded source hashes differ from the original source manifest only in demo/tests/expanded_mission_route_bot.gd, whose current reviewed hash is 708c7da615c160755660328378c1e409b2128b5d75abbc4d9b3f0add4413b5eb. This establishes the observer control; production routes must still run on adopted code.

## Final main-tree scoped acceptance, 2026-10-20 00:43 UTC

APPROVED for the bounded actor/cargo production slice. No remaining blocking correctness finding was identified. Final clean-directory import/package verification and archive delivery remain the owner's delivery checkpoint, rather than claims established by this review.

The exact experiment corrections were adopted into main. Read-only final audit found no role-specific motor, launch, damage, or support shortcut. Production differences remain authored contact/faction/ability configuration; the shared controller and genuine Godot contact receivers determine outcomes. The existing four mask assertions were updated from 64 to 72 without weakening their other requirements. Mission.gd only adds the PC ContactConfig composition. The preserved foundation wrapper retains all old 62 stages and adds six rate-specific actor/cargo stages and one native review boot.

Independently verified final artifacts:
- actor_cargo_final_gates.json: all six groups passed, exit 0 and no logged errors; all 580 source hashes equal the freeze and current tree.
- Foundation 69/69; stock compatibility 10/10; held 333 checks at each rate with no failures and stable production hashes; historical 19/19 with all stages run and no diagnostics.
- Production actor/cargo suites 466 checks at 60 Hz and 676 at 120 Hz, defense 79 at each rate, independent unchanged request fixture 178 at each rate; all pass.
- Four production routes complete with zero deaths, retries, failures, or source drift: 178.600 / 159.267 seconds at 60 Hz and 176.383 / 168.217 seconds at 120 Hz, retained/sacrificed sight respectively. The 120 Hz retained route logs actual feet y242.1789 and the justified internal waypoint projection y270 to242.1784. No objective success condition was changed.
- Eight native JPEG hashes verified. Independently viewed walk-push and J-launch captures. Native top-standing, NPC launch, incoming damage, and exact physical thresholds are not claimed. The stable unexpanded Debugger24 entries remain an explicit scope limitation, not an identified runtime defect or a blocker to scoped acceptance; the native run is not called error-free.
- All 14 prior archive hashes independently verified. Direct read-only comparison with the Warden ZIP found all 1021 archived report/document members present, with only the four intentional index/contract updates changed. The separate broader preservation report records 1039/1043 preceding files unchanged, exactly those four intentional changes, no missing or unexpected changes.

Final documentation is consistent with the tested scope: blocked normal projection rather than universal zero motion; actual solved carry scoped to grounded/hurt support; role-neutral force law separated from deterministic freely rotating trajectory claims; native limits explicit. The ordinary rotating outputs and tiny initial-angle/contact-point observations remain visible. No tuning was used to force their trajectories to match.

Exact final audited revisions:
- combat_pc/player.gd: 5742ab882f71a110ed4aae98a0f882d01f407fdc3fcdd228e1f85140b3e9488c
- simulation/resources/actor_material_profile.gd: b40c7012419930e1e1029c0972c484caf61c1c3be509f6bbe2aaf770c65eda5d
- simulation/tests/actor_cargo_request_regression.gd: 52744e5719e2648e5de57128a54563ad4ef97032c3e7376e50db193fffc2f580
- simulation/tests/actor_cargo_regression.gd: c64dbb5c4f6f61dad2df2014eff8497cf6e12352a984ea35a04b7ee5dde4538a
- simulation/tests/run_actor_cargo_acceptance.py: 85905852d07f84497d3f3ecb0ab8208b66eac052d066ba05bc53c983cdfb0c0d
- simulation/ACTOR_CARGO_CONTRACT.md: f9ac74fefe6da0c9619a6a528091a23fe9b39e9e1795985fab78e50347dd19ab
- simulation/VERIFICATION.md: c8514faff46950bb4e412208774d46326bf7c08d4845884c731468003c3e6ae8

This report preserves the initial failing findings, conditional correction review, and final acceptance rather than replacing the history. Reviewer edits were limited to the authorized experiment fixture and reviewer-prefixed evidence/report files; no production/core source was edited and no additional main-tree test process was run by this reviewer.
