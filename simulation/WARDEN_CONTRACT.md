# Production Warden on the common controller

The actual `demo/mission.gd` factory now selects
`demo/components/shared_warden.tscn`. This closes the last production enemy
controller migration: sentinel, listener, sentry and Warden all inherit
`combat_pc/player.gd` and the same production actor composition. The original
`demo/components/warden.gd/.tscn` and `demo/tests/warden_regression.gd` remain
unchanged legacy artifacts. Their 15-scenario suite is not production evidence.

## Authority and authored differences

Warden inherits one IntentDriver, one root Health, DefeatResponse, HearingSensor,
NoiseRelay, actual-body incoming melee, registered counter, physical-cargo and
projectile receivers. Its intention policy requests movement/attacks only.
The facade observes genuine Health and configures future actions; the view draws
observed state. Neither owns velocity, damage, an attack phase or a second phase
clock. Controller code contains no Warden/role conditional.

Private per-instance resources author Health16, movement70, hearing memory1.8
and peer-hearing group `mission_warden_hearing`. Body32/mask9/terrain9,
hurtbox4, outgoing melee target64 and projectile accepted-owner-layer2 preserve
explicit faction membership. Positive health, movement, windup and damage
encounter overrides retain precedence; windup/damage override both patterns.

| Independent action | Windup | Active | Recovery | Size | Center offset |
| --- | ---: | ---: | ---: | --- | --- |
| Cut | 0.78 | 0.14 | 0.90 | 57 x 27 | (32.5,-22) |
| Sweep | 1.014 | 0.18 | 1.10 | 73 x 27 | (40.5,-22) |

Both do18 damage with impulse(130,-65). Both are terminal actions with no combo
successor, voluntary movement, turning or cancellation during committed phases.
Sweep windup is1.30 times the configured cut windup. Physical external response,
collision/depenetration and gravity still belong to the common controller/engine.

`fresh_start_steps=[0,1]` is optional chain configuration, empty by default.
Only an actual independent fresh-chain commitment consumes the actor-owned
cursor. Rejected requests do not; an admitted attack later interrupted does.
Reset/reconfiguration restores the opening index. Lifetime attack serial stays
monotonic. Held-repeat/charge and ordinary linked combo semantics are unchanged.
The cursor advances before synchronous commitment callbacks, so callbacks cannot
misadvance a reset actor or replacement configuration.

`attack_plan_snapshot()` returns copied scalar/vector/rectangle observations,
never a Resource or mutable clock. During a valid commitment it describes the
copied active action; idle describes the next valid independent/retained/charge
opening. The production facade's windup, reach, damage and elapsed accessors use
this common observation, including the longer sweep. Invalid/replaced resources
fail closed; all previous production profiles and stock input modes are covered.

## Bracing, counter and real Health phase

Only committed windup+active are protected against responses strictly shorter
than0.70 seconds. Ordinary melee, returned bolts(default0.5) and cargo(default0.42)
still debit their full actual Health amount, produce shared hitpause and semantic
noise; short recoil/attack cancellation is suppressed. Recovery is punishable.
An actual authenticated counter has response0.78 and interrupts either pattern.
Equal0.70 is not protected. Lethal Health depletes normally and retires the attack.
A parry whose counter is absent, disabled or out of range does not fabricate
attacker recoil. Guard leaves4.5 damage from18; a valid roll evades.

One genuine bound Health `damage_processed` receipt with applied>0 and
0<after<maximum/2 latches pressure phase2. Exactly8of16 and lethal0 do not.
The source cut/sweep recoveries become0.64/0.80; Health capacity, windup, active,
damage, geometry and facing do not change. Reset clears the latch.

For a currently committed windup/active, the generic
`set_pending_recovery_duration(serial,configuration_epoch,seconds)` can change
only that exact action's not-yet-entered copied recovery. It rejects retired
identity, reset/reconfiguration, invalid duration, pause/disabled processing and
recovery already entered. It detaches the step before mutation, preserving
reusable chain/charge copies and elapsed warning. It does not shorten the phase
already visible on screen.

`Health.damage_receipt_is_current(receipt)` recognizes only the exact immutable
Dictionary during its synchronous real delivery, with current binding, change
and actor generation. Forged/equal copies, replay, nested damage, equal-value
reset and same-object unbind/rebind cannot authenticate stale observations.
Warden rechecks this authority plus its semantic-observer binding and authored
chain identity after noise callbacks. Reset/removal/pause/disable/reconfiguration
cannot let old work change a new life. Nothing follows the phase_changed signal.

The old legacy recoil scaling/cap, source pause copying, and fake0.75 response
when a counter did not really occur are intentionally replaced by the common
controller's canonical impulse/shared authored pause and genuine counter receipt.

## Projectiles and cargo

The inherited registered ProjectileReceiver closes the earlier Warden blocker
hole. An NPC-owned outbound sentry bolt physically intercepts on the Warden and
returns `source_layer_filtered`, without damaging it or passing through. A
PC-owned genuinely reflected return physically intercepts and applies the full
canonical returned damage, clamped only by actual remaining Health. There is no
Warden projectile fallback, fabricated counter or special damage rule.

Real rigid cargo uses the common contact source/receiver. Admission is based on
Godot contact-point relative normal closing speed, including the engine's reported
kinematic collider/depenetration velocity, not visual COM speed or momentum
realism. The preserved diagnostic shows source241 minus target201 =40, below the
authored80 threshold: a fast-looking physical collision correctly admits no
damage. Qualifying opposite-side contacts measured above80 and apply3 damage.
Phase-response assertions first require this real qualifying contact; they do
not claim every fast-looking collision damages. No physics or threshold was
changed to make the fixture pass.

## Evidence and scope

Production tests are distinct from the preserved legacy suite:

- `simulation/tests/attack_plan_regression.gd`: generic independent sequence,
  snapshots, pending recovery, defaults and synchronous Health authority.
- `simulation/tests/warden_regression.gd`: real cut/sweep, brace/thresholds,
  six genuine counter input-only duel, guard/roll/escape/wall/recovery/lethal,
  private overrides, actual cargo and adversarial receipt callbacks.
- `simulation/tests/warden_projectile_regression.gd`: actual sentry emission,
  timed PC reflection and full actual Warden damage in windup/active/recovery,
  including lethal return. Initial actor placement/input-source fixture is
  explicit; successful contacts are never assigned.
- `simulation/tests/warden_factory_regression.gd`: actual factory all four kinds,
  one shared controller/Health and every registered receiver; selected authored
  final room then only ordinary raw inputs until all three enemies die, seal
  opens once and exactly three kills are recorded; explicit fresh retry follows.
- Existing production sentry/cargo and mission-contract suites now exercise
  shared Warden. Their clearly labelled legacy cases remain separate.

`simulation/warden_review.tscn` inherits the real mission host, initially selects
sector6 with bounded spawn920 and disables saving. The three real factory foes,
ordinary player controls and room gate run unchanged thereafter. This is an
isolated initial configuration, not a completed campaign route. Native review
saw the distinct crown/gold bracing shoulders, directional warning/active
rectangles, real J Health loss, roll movement and R restoring PC60/all three foes.
Exact alternation, continuous brace retention, successful timed counter, defeat
and room clear were not established natively. Automated mechanics use canonical
observations/exact timing and do not prove human timing or game feel. Audible mix
was not validated. Five saved native frames support only the stated observations.

The original full-route planner's close sword pressure could reach9.45px spacing:
although already parrying, the real contact landed0.55px behind the shield's
front rectangle. The source still faced forward and facade elapsed exactly
matched canonical elapsed. That was a valid uncovered contact, not a shield or
facade bypass. Preserved unchanged-route failures and the approved generic
protected-capability-aware raw-input strategy are reported separately. Neither
objectives, timeouts, outcomes, combat geometry nor enemy rules are weakened.

Frozen acceptance results, exact source hashes, independent review, original red
diagnostics and retained/sacrificed60/120 full-route results are indexed in
`VERIFICATION.md` and `evidence/warden_acceptance.json`. Earlier ZIPs remain
immutable. Decorative asset extraction, physical corpses, acoustic propagation,
final balance and human full-campaign timing remain separate work.

Final current-production acceptance completes all four full routes with stable
sources. Exact durations, deaths/retries and the independently verified baseline
comparison are recorded in `VERIFICATION.md`; canonical timing tests remain
separate from native usability.
