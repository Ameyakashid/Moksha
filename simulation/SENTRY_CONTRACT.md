# Production sentry on the shared actor and projectile boundary

This checkpoint migrates all thirteen authored `sentry` placements through the
actual `demo/mission.gd` factory. The original `ranged_enemy.gd/.tscn`,
`ranged_projectile.gd/.tscn` and `demo/tests/ranged_regression.gd` remain unchanged
and continue to exercise the legacy implementation. Warden was not migrated in this checkpoint; the later `WARDEN_CONTRACT.md` closes that gap.

## Composition and authority

`demo/components/shared_sentry.tscn` inherits the existing production shared
sentinel scene. Its short facade extends `shared_sentinel.gd`, which still inherits
the unchanged `combat_pc/player.gd`. It reuses the same IntentDriver, NPCInputSource,
Health, DefeatResponse, HearingSensor, NoiseRelay, actual incoming melee/counter
and physical-cargo receivers. There is no second motor, Health store, action clock,
hurtbox or damage emitter. The ranged facade adds only observed projectile
signals/counts and visibility; the separate view observes real state.

The existing archetype resource supplies health 2, speed 58, windup 0.72 and
recovery 0.95 with cyan tint. The role-neutral projectile chain supplies a
FRESH_ONLY action, minimal sampled active 0.001, no successor, zero phase travel,
locked phase facing and zero inherited melee loudness. Positive encounter
health/speed/windup/damage overrides keep precedence. The actual mission still
sets damage 12. Body 32/mask 9/terrain 9 and incoming sword hurtbox 4 remain explicit.
Jump/roll/shield/drop/dive/climb capabilities remain off for this authored NPC.
`ContactAdapter.enabled=false` removes outgoing melee admission entirely.

All movement and attacks enter as ordinary intention. The policy inherits shared
support/edge observations and peer-hearing admission. Its independent decision
delays are initial 0.6, post-finished 0.30 and post-hurt 0.45; these never drive or
write action phases. Recovery belongs entirely to the shared controller.
The policy remembers hearing but holds its lane without a visible target,
matching legacy ranged behavior. Sight requires horizontal distance <= 430,
vertical difference < 80 and actual terrain+cargo clearance. Below 115 it requests
retreat at 0.75 strength during a decision interval; beyond 170+65 it approaches
at 0.65; otherwise it holds. Once ready, even a close target gets a full committed
warning. Alignment uses ordinary turn input immediately before commitment.
It does not fight ordinary retreat-facing on every cooldown frame.

Real shared braking/recoil replaces legacy immediate velocity assignments.
External momentum and lost support can carry the sentry off a ledge. Disabling
AI decisions supplies neutral input; an already committed action continues.
Ordinary hurt cancels a pending warning through the controller and introduces the
post-hurt decision interval; no legacy independently timed recovery is recreated.

## Aim, release and shared physical flight

The same typed/registered emitter observes the genuine attack-start identity and
canonical synchronous action sample. It captures one world-space target point
at target position + (0,-20); release velocity points from the current real muzzle
(x = 15*facing, y = -22) to that old point. It cannot home after commitment.
`pending_aim_snapshot()` is a defensive presentation view, never launch authority.

The role-neutral profile adds `require_clear_aim_on_release`, default false for
previous opt-in scenes and true for production sentry. It rechecks real
muzzle-to-locked-point clearance, in addition to the existing spawn-circle and
body-to-muzzle checks. Obstruction mask 9 includes terrain 1 and cargo 8. A door or
falling crate that closes the line during the genuine warning prevents release
and its sound. Cargo blocks acquisition and subsequent outbound/return flight.
These are deliberate shared-world differences from legacy terrain-only masks.

The preserved stock circular move_and_collide sweep remains the sole carrier
motion solver. No controller, stock carrier or Health code changes in this slice.
Speed 245, radius 3, lifetime 2.2 and the shared return response remain authored data.
Standalone damage 1 returns max(1,2)=2; actual mission damage 12 returns max(12,2)=12.
An applied return may be clamped to a target's remaining Health. Its reported
amount is observed applied damage, not an invented twelve-point debit.

## Physical interception and explicit damage filtering

The production profile uses outbound 43 and reflected 43: terrain 1+ PC 2+cargo 8+
NPC32. This deliberately replaces the legacy peer passthrough behavior. A peer
physically intercepts a shot even when its gameplay damage policy rejects it.
There are no role-string exemptions or generic direct-damage fallbacks.

The registered receiver has configurable `accepted_source_layers`; zero admits
any genuine owner and preserves the previous gym defaults. Production shared
sentinel/listener/sentry receivers accept owner layer 2, and the mission PC accepts
owner layer 32. Therefore an outbound NPC bolt is physically consumed by an NPC
peer without a Health debit. A genuinely reflected PC-owned bolt can damage any
registered shared NPC it actually strikes. Another PC body can intercept a return
without friendly damage. Other games can author different masks/policies.

Owner identity/layers are captured at actual collision-dispatch entry before
source extension hooks. Receiver binding/filter are captured before receiver
callbacks. Those values, the canonical owner and the existing geometry/contact
permit are rechecked afterward. The receiver finally rechecks current local
filter, source layer, actual carrier owner/attack identity and reflected state
after the last extension hook. Configuration setters retire captures. Changed
permission cannot be borrowed by the old contact; a later genuine physical
sweep can use the new configuration. This remains a trusted local-script API,
not a security sandbox against scripts that directly rewrite objects.

The physical reflection changes the same carrier's owner, increments its attack
identity once, removes the original shooter's collision exception and installs
the current defender's. No fake return projectile is spawned. Same-life completed
Health facts survive lethal source retirement; source reset prevents those facts
from leaking into the new life. The facade proxies the actual carrier result.

At the Sentry checkpoint, Warden still used legacy StrikeHealth/Health and could not bind this root-Health
receiver without its next controller migration. Its body 32 physically blocks
outgoing and returned shots, with no projectile damage or hidden bridge. This
explicit temporary vulnerability gap matches its previous reflected-shot
limitation and was tested. The later Warden checkpoint replaces that factory scene,
adds the inherited registered receiver, and proves filtered outbound interception
and full actual reflected-return damage. The original checkpoint evidence remains preserved.

## Host, sound, view and lifetimes

Existing configure/bounds/kind/enabled/ai_enabled/dead/health/defeated/
attack_resolved/reset/reset_at/blind interfaces remain inherited. `shots_fired`
is a lifetime count of observed genuine emissions; `projectile_launched` observes
that real carrier. `projectile_epoch` projects the emitter's lifetime binding.
The facade does not implement a role-specific return-damage method.

One default-preserving shared facade flag turns off its generic windup event for
this scene. The emitter alone commits enemy_windup at the real muzzle and
successful enemy_attack at release. Zero phase loudness and disabled melee
admission prevent duplicate attack sound/contact. The inherited actual
Health/Defeat observers retain enemy_damage/enemy_death. The no-bus semantic
pipeline, reveal, sonar geometry and explicit mission_ranged_hearing peer
partition are reused. The cyan bow/antenna, orange ring/!, short locked aim line,
Health bar, damage flash and defeat fade read actual controller/emitter state.

Existing emitter lifetime rules remain: normal recovery and nonlethal hurt keep
an already launched flight; source reset/defeat/exit and emitter retirement remove
owned sibling carriers. Pause freezes flight and retires pending warning scopes.
Receiver configuration, replacement and reset invalidate old contact permits.
Scene/retry disposal leaves no carrier or reflector fence. Arbitrary manual emitter
replacement retires old flights and the new component can fire through the shared
API, but this fixed production facade does not automatically reconnect its view/
telemetry observers to a manually substituted emitter. No corpse capability
or acoustic propagation change is added.

## Verification and native entry

`simulation/tests/sentry_regression.gd` runs actual production scenes and all
thirteen real factory placements at 60/120. Successful attacks/defenses use
ordinary input and real Godot contacts. Direct lifecycle probes and initial
world setup are explicitly labelled. It covers standalone/mission return damage,
true guard/parry/roll/jump, peer and third-actor interception, exact-once
Health/noise, lock/release timing, door/falling-cargo obstruction, real sword and
production sword-launched cargo, sustained retreat, physical recoil off support,
resource isolation, hearing partitions, reset/exit/pause and factory kill/retry.
A corrected cargo fixture first observes real windup before inserting its crate;
explicit zero launch lift/spin makes that fixture deterministic. Initial failed
fixture evidence is retained under evidence/sentry_initial_gate.

The separately runnable `simulation/sentry_review.tscn` inherits the real mission
host/factory and selects the unchanged authored Quarantine Intake sector with an
explicit initial spawn at (790,135). Saving is off. All actors/AI/Health/terrain/
cargo and ordinary controls run normally. It contains no post-spawn teleport,
scripted action, AI disabling or forced result. This isolated review entry is
not a claim that a human completed the full route; four automated full-route
gates remain separate. Native findings and limits are recorded in VERIFICATION.

Run `python3 simulation/tests/run_sentry_acceptance.py` for frozen-source
foundation, stock, historical and four full routes. It preserves historical
non-simulation evidence. Independent adversarial review and immutable archives
are separate gates. No claim of universal actor parity, Warden migration,
finished balance, full acoustic physics or completed asset extraction is made.
