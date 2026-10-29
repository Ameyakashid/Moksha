# Shared actor / cargo physical interaction

This bounded production slice adds PC cargo support/obstruction and NPC melee cargo targeting. It does not change mission geometry, damage thresholds, AI decision rules, faction membership, sonar, or boundary hazards. The shared swept character controller remains motion authority; Godot remains rigid-body authority.

## Production composition

| Host | Body layer / mask | Terrain | Hurtbox | Melee targets | Melee obstruction |
| --- | --- | --- | --- | --- | --- |
| PC | 2 / 9 | 9 | 64 | 12 | 9 |
| NPC | 32 / 9 | 9 | 4 | 72 | 9 |

Both contact resources select the same private `actor_material.tres`. The mission PC composes `ContactConfig`; NPCs retain their existing composition. Stock player and generic gym profiles do not acquire production push capability implicitly. Sentry still explicitly disables melee. Melee faction differences remain authored target masks; cargo is now included for both equipped roles.

Policy perception is separate from physical admission. Melee policy LOS1 and sentry LOS9 retain their authored meanings. Every actual production melee sweep uses obstruction9 and excludes only its actual target RID and source RID. A crate can obstruct a swing toward another crate or actor. The policy may choose to avoid cargo rather than push it; matched-input physical tests are distinct from genuine autonomous intent tests.

## Authored motor pressure

The optional material response requires an actual grounded ground-following side sweep, ordinary locomotion, idle weapon, and a live voluntary walking/crouching command into that surface. Walkable floor contacts, ceilings, airborne motion, attacks, hurt/recoil and neutral carrier movement do not spend the ordinary pressure budget. Frozen, disabled, retired and foreign-world rigid bodies reject it.

The shared budget is 1400 force units times elapsed physics dt, aggregated across every sub-sweep in one actor tick. The impulse is unilateral, delivered through `RigidBody2D.apply_impulse` at the real Godot contact point. Actual mass, inertia, contact offset, angular point velocity and the solver's subsequent contacts determine its effect. No rigid velocity, angular velocity, charge or transform is assigned by this motor response.

This is sustained authored motor pressure, not kinetic collision-impact transfer. Its speed cap compares the existing voluntary ground-speed command, plus only actually solved carrier velocity, with the rigid contact-point velocity. A body separating faster than that command receives no pressure. Instantaneous collision-clipped motor approach is retained separately in diagnostics and does not become a false per-timestep terminal-speed limit. Walking force does not create weapon charge or damage authority.

After an admitted pressure contact, a private one-frame horizontal motor request may seed the next ordinary acceleration step. It is bounded by the current voluntary speed and matching direction, and is distinct from exposed collision-projected velocity. New impulses still require a new genuine side sweep. The blocked normal component is projected out; horizontal output is zero in the vertical-wall/corner fixtures, while valid tangential sliding remains possible. No movement or rigid-body velocity is imposed to preserve the request. Neutral/reversed input, attack/air/hurt, later static obstruction, expired frame, actor action/weapon/reset generations, material configuration changes and cargo lifecycle/shape/mass/material changes retire the request. Moving body pose and velocity remain dynamic rather than invalidating their own motion. Controlled nonrotating role fixtures compare equal configurations; freely rotating production contacts remain measured separately without claiming identical trajectories across rates.

## Observed support and transport

A genuine floor observation captures a local contact anchor and normal. Rigid carry follows the committed transform of that anchor, including rotation. Animatable carry accounts for its committed pose and the independently planned pose; a planned surface must still be walkable. Large committed and pending stages are bounded separately, so opposing large movements cannot cancel the bound.

For the grounded and hurt-pause support paths in this slice, every carry uses the existing collision sweep. Reported support displacement is the movement actually solved, rather than the requested delta. Unchanged ledge/wall/climb paths retain their existing contracts. Wall/ceiling blockage retires the carried support instead of teleporting through it. Support lifetime/world/collision membership and actual walkable geometry are rechecked, including after synchronous landing callbacks. Removed, broken or rotated-away supports cannot keep grounding an actor. Ordinary gravity then owns falling.

During local hurt hitpause, the already observed support may still transport the actor, while action clocks remain paused. Small valid rotation follows the same local anchor; lost geometry, excessive transport or blockage retires it. Already solved Animatable pending displacement is retained for one frame when forming world-relative pressure velocity; unsolved desired carry is never substituted.

## Contact selection and trajectory limits

Shared law does not guarantee identical freely rotating trajectories across separate instances or rates. The preserved ordinary fixture settles to tiny opposite signed crate angles: about +1.98e-6 and −1.98e-6 radians at 60 Hz. Godot then selects a first contact at y199.98 for PC and y172.21 for NPC, despite the same 218 motor command and 23.333 impulse. Different real contact offsets produce different torque. At 120 Hz the initial angle is about ±5e-7 with small subsequent contact-point velocity differences. These are measured solver observations, not a claim of a proven general cause for every later divergence.

Over one second, free-rotation displacements are PC118.553/NPC119.593 px at 60 and PC102.517/NPC118.168 px at 120. Separately labelled nonrotating, equal-configuration controls give exactly equal PC/NPC displacement within each rate: 116.414 and 120.079 px with production friction; independent low-friction controls give 152.296 and 153.770 px. The force cap and role-neutral path are tested, without promising deterministic cross-instance or cross-rate trajectories.

## Canonical melee to cargo

`physical_cargo.gd` opts into the canonical ContactAdapter protocol. Before source confirmation it captures exact body identity/RID/world, lifecycle/epoch, layer/mask, node and committed transforms, shape-owner transforms/flags, shape identity and actual PhysicsServer shape data. Confirmation callbacks cannot move, resize, disable, freeze, retire or replace that geometry and still launch from the old overlap.

The live canonical source scope also binds direction and launch strength. No fabricated, mutated, later-replayed or unrelated packet may borrow it. Rejection has no legacy launch fallback. The normal existing prop launch commits once, advances its source epoch and retires the old sweep. A new released input/new swing can launch again if a new real contact is reachable.

Launch presentation uses a local post-commit token captured before extension callbacks. Each burst, sound, text, noise and final launch step rechecks it. Cargo's receipt signal uses that original expected-epoch token too. Nested launch is an independent committed physical operation; it cannot refresh the outer operation's presentation scope. A completed value-only receipt does not authorize subsequent live feedback after retirement.

## Damage and physical qualification

Mission damage remains charged-only, threshold80 and authored damage3 through the existing physical receiver and Health. Ordinary pushing, uncharged falls and support carry do not manufacture damage. Guard/parry/roll use the same configured controller defenses; a real returning crate can damage its original launcher.

The free-chain and wall-backed-chain fixtures intentionally differ in physical constraint. With a free production PC, real contact can move the character enough that relative contact-point speed falls below80; the rejected contact is retained as evidence. A real wall behind the same actor constrains that movement and can produce a qualified impact. Neither fixture lowers the threshold or forces a debit. Initial zero-spin/zero-lift and constrained-wall setups are labelled test materials/geometry, not claims that every randomized production launch hits.

## Evidence scope

`actor_cargo_baseline/provenance.json` identifies corrected prechange observations against the untouched Warden archive. Invalid instrumentation iterations remain explicitly labelled. Final fixtures assert driver ownership, exact tick count and delivered input, rather than infer successful input from a test name.

`actor_cargo_regression.gd` uses genuine PC raw frames, NPC intent conversion, real support/motion and autonomous production sentinel/listener/Warden decisions. Lifecycle and direct material API probes are labelled separately. `actor_cargo_defense_regression.gd` repeats defense, source lifecycle, real chain and wall-return cases with production PC contact/material configuration. The unchanged independent `actor_cargo_request_regression.gd` is also run in final gates. Its historical frozen-player field labels the original experiment; corrected and final source manifests identify the actual implementation under test. Final full gates and native review are recorded separately; isolated experiments are not acceptance proof.

The input-only mission observer projects a requested stance only when its original point is inside the current live solid support and a real first-hit walkable ray proves a nearby supported surface. It preserves X, existing staging tolerance and all objective success conditions, and records original/projected targets and support identity. Untouched-Warden controls with only this observer changed pass all four routes; the four pre-adaptation candidate traces remain preserved.
