# MOKSHA movement and combat wireframe

An original 34-pixel articulated character for the reusable MOKSHA motor. The visual has a foot origin at local y=0 and faces right for `facing=1`. Its separate hip, ribcage, shoulder, head, elbow, palm, knee, heel and toe geometry creates readable action silhouettes at game scale.

The motor owns position, velocity, collision dimensions, clearance decisions, facing and ledge movement. The visual only observes that information. It never moves the actor, changes its collision shape, delays an input or starts a physical action.

## Evidence and authorship

The reference audit identifies Thomas Vasseur's [2018 primary animation article](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) as evidence for purposeful pose-to-pose keys, correctly timed impact silhouettes and interpolation around those important keys. This implementation applies that design principle with original MOKSHA art and parameters.

The article's published movement example was also inspected. Qualitative observations: pronounced alternating knee recovery and leg reach, opposing arm swing, a relatively steady head/torso, and forward lead that keeps direction readable. The new wireframe was checked against those broad principles. No pose coordinates were traced and no original assets were imported. The inspected media's 35 frames and 40 ms encoded frame duration describe that published media; they are not adopted as a gameplay tick, stride rate, or recovered clip timing.

All rig dimensions, keys, nominal visual transient durations, gait curves, contact rules and interpolation choices here are **original MOKSHA authoring**. No complete original player animation graph, sprite timeline or frame-event data was recovered. This module makes no exact Dead Cells pose/feel parity claim.

## Files and ownership

- `wireframe.gd`: `@tool` Node2D `MokshaWireframe`; motor observation, transient selection, stance anchors, phase signals and drawing
- `wireframe_keys.gd`: explicit original key targets, held/snap/eased segments, dimensions and visual timing parameters
- `wireframe_pose.gd`: pure geometry evaluator, two-bone IK, gait and ledge poses
- `combat_keys.gd`: original compact roll, weapon and hurt key targets and normalized phase timing
- `combat_pose.gd`: pure combat key evaluation, airborne/low variants, tumble geometry and attached blade
- `descent_keys.gd` / `descent_pose.gd`: original drop, dive brace, descent, real-contact impact and recovery keys
- `climb_keys.gd` / `climb_pose.gd`: original attachment, stationary/up/down, top exit, blocked and release poses with geometric rung contacts
- `wall_keys.gd` / `wall_pose.gd`: original wall ascent, finite slide/end and outward-kick keys, wall-normal feet and explicit sliding/plant contact kinds
- `landing_keys.gd` / `landing_pose.gd`: original ordinary/dive hard impact and compact recovery, fitted to the motor's real floor contact
- `slope_pose.gd`: passive inclined-floor joint compression, reachable foot targets and normal-aligned soles for ordinary and explicitly supported special poses
- `shield_keys.gd` / `shield_pose.gd`: original six-phase shield keys, reported guard-band outline, anatomical grips and presentation-only floor occlusion
- `tests/visual_regression.gd`: headless visual contract, geometry, support and lifecycle fixtures
- `tests/render_previews.py`: independent offline rendering of exported pose vectors

The visual is a child named `Visual` in the reusable player scene. It auto-connects the parent's `movement_event` signal on ready. It has no dependencies on the archived controller study or other game-specific sprite APIs.

## Runtime API

```gdscript
Visual.present(dt, motor.telemetry())
# update_visual(dt, telemetry) is an equivalent alias.
Visual.event("landed", {"preimpact_speed": impact_y_speed})

var local_bones = Visual.get_bones()
var world_bones = Visual.get_bones(true)
var inspectable_pose = Visual.get_pose()
Visual.reset_presentation() # after teleport/spawn reset
```

`bone_positions`, `get_bones()` and `get_pose()` return independent copies, so consumers cannot mutate the animation's internal pose. `evaluate_pose(mode, phase, telemetry)` performs pure evaluation without a scene. It is suitable for replay inspection and tests.

`phase_event(name, payload)` emits authored `pose_key`, `foot_plant` and `hand_grip` markers. These are observable presentation events, not requests to change motor state. Each payload identifies the key or contact and carries `authored=true`. Climbing additionally emits `hand_release` and `foot_release` when a step, reach limit, geometry edit or owner change ends a contact.

Supported motor events: `ground_jump`, `air_jump`, `landed`, `brake`, `turn`, `crouch_enter`, `crouch_exit`, `ledge_catch`, `pullup_begin`, `ledge_step`, `pullup_end`, `ledge_release`. The aliases `takeoff`, `land`, `pull`, `step`, and `release` are accepted. Crouching and ledge selection still follow authoritative telemetry; merely sending an event cannot override a clearance or movement decision.

## Snapshot fields

| Field | Use |
|---|---|
| `position` / `world_position` | Authoritative actor foot/root world position |
| `velocity` | Direction and speed intensity; never written back |
| `facing` | -1 or +1, independent of velocity; mirrors evaluated joints only |
| `grounded`, `move_x` | Stance eligibility and visual start/brake/reversal response |
| `pose` | Motor pose: idle/run/brake/turn/jump_rise/jump_apex/fall/land/crouch/ledge_* |
| `crouched`, `body_height` | Controller clearance result; crouch is selected immediately |
| `main_action`, `action_phase`, `phase_progress` | Physical action/ledge progress; not inferred from a guessed clip duration |
| `palm_target` / `ledge_anchor` | World-space edge/grip point |
| `hang_target` | Actual per-arrival hanging root target, including shallow assisted arrivals |
| `support_id`, `support_displacement` | Preserve world soles on moving supports |
| `run_reference_speed` | Active motor profile speed for gait intensity |
| `preimpact_speed` | Optional explicit landing intensity; event payload is preferred |
| `tick_id` | Optional duplicate-update guard |

`pull_target`, `step_target` and other extra motor fields may remain in the snapshot; the renderer never modifies them. All inputs are deep-copied.

The source motor's standing body is 16×34 and its crouched body is 16×20. The authored head top is approximately -34 standing and -19.3 crouching. Limbs can extend beyond the body's lateral hitbox, as arms/feet normally do; rendered geometry does not create collision.

## Authored movement language

**Grounding.** Start loads the rear leg before extending into the first stride. Continuous running has contact, weight, pass and flight keys. Distance-driven phase changes cadence with real travel, while slow/fast stride and stance parameters change knee lift, reach and arm amplitude. Soles retain world anchors during attainable supported stance. Shoulder/head movement remains smaller than limb movement.

**Braking and reversal.** Brake plants a leading heel and brings the torso behind the moving root. Reversal retains existing world foot anchors while the new facing guides head/shoulders and the rear leg drives the new direction. Neither response changes velocity or facing. The motor remains responsible for its braking distance and turnaround rules.

**Jump.** Ground jump uses a compressed wind-up silhouette, a deliberately held extension key and an asymmetric rising pose. The visual wind-up occurs alongside the already-authorized movement; it does not delay takeoff. Air jump has its own folding/recoil, sharp drive and reopening poses. Apex and fall are velocity/state-driven holds rather than clips with invented mandatory durations.

**Impact.** Landing holds its compression key before recovering. A moving landing drives directly toward the next run contact. Hip drop, torso pitch, rib width and knee flexion express impact without scaling or moving the physical actor. Crouch snaps to a silhouette that fits the motor's reduced clearance envelope.

**Ledge.** Catch loads the grip, hang keeps both palms at the actual ledge, pull bends elbows and brings chest/body over the edge, then step plants the lead foot and recovers the rear foot before settling. The lead leg tucks upward outside the wall before reaching over its top. The supplied edge plane also chooses a clear elbow/knee IK solution, without querying collision or moving the root. The far palm releases when the body passes the ledge; the near palm releases before the standing torso would exceed its reach. Foot plants follow the motor's physical step progress. Shallow arrivals adapt toward a body-over pose instead of forcing the character down into a full hang. No mantle root displacement is authored in this visual.

Original visual transient durations are explicitly in `wireframe_keys.gd`: start 0.14 s, jump 0.12 s, air jump 0.16 s, landing 0.18 s, brake/turn 0.16 s. Ledge catch/hang/pull/step use supplied physical phase progress. These are MOKSHA choices, not recovered reference timings. Roll and weapon action durations also belong to the motor; their visual keys consume normalized motor phase progress.

## Combat phase contract

The motor supplies `roll_phase` (`start`, `travel`, `recovery`, or empty), `roll_phase_progress`, `roll_direction`, `weapon_phase` (`idle`, `windup`, `active`, `recovery`), `weapon_phase_progress`, `attack_facing`, `attack_serial`, `hurt_progress`, `hurt_direction`, `paused`, and `hitpause_remaining`. The optional strike rectangle fields `strike_center` and `strike_size` describe collision for inspectors; the renderer does not create or alter that rectangle.

Selection priority is hurt, roll, weapon, then ordinary movement/ledge selection. These actions follow authoritative phases immediately, including cancellation. `roll_direction` and `attack_facing` are latched values supplied by the motor, not direction decisions made by the visual. `body_height` and `crouched` select low attack/hurt variants that stay within the 20px body envelope. Airborne attacks keep their weapon phase and use airborne leg targets. A landing event compresses the action's hips and torso without replacing its weapon pose.

Additional observed events are `roll_started`, `roll_phase_changed`, `roll_finished`, `roll_cancelled`, `attack_started`, `attack_phase_changed`, `attack_finished`, `attack_cancelled`, `strike_confirmed`, `hurt_started`, `hurt_finished`, and `hitpause_started`/`hitpause_ended`. Action start/cancel clears obsolete presentation transients. No event starts a physical action. The blade is visible during the weapon phases and immediately leaves the action silhouette when that action ends or is interrupted.

**Roll.** Entry compresses and folds the body, travel rotates a complete articulated folded pose once, and recovery opens into a low exit. Head, trunk, palms and feet rotate together; the actor Node2D never rotates. A local bone offset keeps the rolling silhouette tangent to the authoritative foot plane. The entire authored body remains under 20px until the motor resolves standing clearance. `roll_fold`, `roll_shoulder`, `roll_inverted` and `roll_unfold` keys expose the rotation's quarters for inspection; none describes an invulnerability interval.

**Weapon.** Windup loads the torso and raises the blade behind the hand. Active starts with a decisive forward contact key held through 66% of the motor's active phase, then follows through. Recovery holds that follow-through briefly before returning toward the ready key. The 18px blade, guard and grip are code-native original geometry and stay attached to the near palm. The default contact tip is inside the default motor strike rectangle; the blade is not used as a collision shape. A confirmed strike adds three short line marks at the blade tip for an authored 0.07 actor-seconds.

**Hurt and pause.** Hurt starts with a held recoil, moves to a protective guard, then releases to the next motor action. The supplied knockback direction controls the recoil orientation. During `paused=true`, the visual clock, gait and confirmed-hit mark lifetime stop, including if a caller accidentally supplies nonzero delta. Updated root/support displacement still transports existing support contacts with a moving carrier. Pausing does not stop the motor's input sampling or alter its buffer rules.

The combat poses use the same broad pose-to-pose design principle from the primary Vasseur article. Its attack example was inspected qualitatively: loaded anticipation, stretched commitment, a distinct impact/follow-through and recovery. No original pose coordinates, media cadence, attack hit windows or cancellation timings were imported. The motor's action parameters and the visual's normalized holds are original MOKSHA authoring.

## Drop and dive phase contract

The new observation fields are `drop_active`, `drop_phase`, `drop_progress`, `drop_target_id`, `dive_phase` (`startup`, `descent`, `impact`, `recovery`), `dive_phase_progress`, `dive_serial`, `dive_direction`, `dive_fall_distance`, and `dive_impact_speed`. The renderer selects drop only when `pose` or `main_action` says `drop`. A target collision exception can remain live after the action ends or is interrupted, so `drop_active` alone never owns the visual. The explicit motor pose `drop_blocked` uses a quiet compact hold. A cleanup-blocked notification alone does not override another action.

Roll and hurt interrupt dive immediately. Dive/drop replace any interrupted weapon geometry. Events `drop_started` and `dive_started` clear old jump, melee-contact and locomotion transients; `dive_impact` starts fresh support anchors, and `dive_finished`/`dive_cancelled` discard obsolete ordinary-landing transients. The motor owns the fresh Down+Jump classification, collision exception, ability gates, descent acceleration, phase duration and contact test.

**Drop release.** The hips settle downward, soles release near the foot plane and hands stay below the shoulders. There is no upward launch silhouette or delayed jump event. The clear key opens slightly into downward travel.

**Dive.** Startup holds a compact brace and snaps toward a narrow, feet-first committed descent. Descent is a held state, even if it lasts indefinitely; elapsed visual time and falling speed cannot manufacture an impact. Only the motor's actual contact phase selects the deeply compressed, planted impact key. Impact holds through that entire physical phase. Recovery unfolds through a rebound key to standing or crouch according to current clearance. The low variants preserve the 20px body limit. This adds no damage area or impact effects.

The audit's drop/dive/landing rows explicitly identify missing source bodies and unavailable original timelines. All new joints, brace/contact silhouettes and normalized holds here are original MOKSHA authoring. The motor's 0.08s startup, 0.06s impact and 0.14s recovery are authored tuning, not recovered source-game timing.

## Ladder and vine contract

The motor supplies `main_action=climb`, `climb_active`, `climb_phase` (`align`, `idle`, `ascend`, `descend`, `top_exit`, `blocked`), `climb_phase_progress`, `climb_axis_x`, `climb_top_y`, `climb_bottom_y`, `climb_width`, `climb_type`, `climb_target_id`, `climb_velocity`, `climb_distance`, and `climb_transport`. All axis, width and end coordinates are world-space geometry. `climb_rung_spacing` and `climb_rung_origin_offset` are also world-space values: the component transforms its local 12px spacing and ladder4px/vine8px bottom offset by its positive vertical scale.

Climbing has a pure two-rung travel cycle. The phase comes from actual root height relative to the climbable's rung origin, not elapsed time or input intent. One hand and the opposite foot alternate supported contact with an outward recovery path at the default pitch. Narrow vine grips and ladder grips use separate authored lateral targets. Idle and blocked states hold their current travel phase without cycling. Ascending leads upward; descending looks down and shifts its weight back. Alignment reaches toward the supplied axis while the motor performs its physical sweep.

During a planted interval, the target's world position is exactly on its rung. Root and sensor co-transport leave the local pose unchanged, including during local hitpause. Hand and foot centers remain inside narrow rungs. Changes to target identity, width, pitch, offset, type or height release and resample contacts. Translation alone does not invalidate them. Unreachable targets are released and the limb remains within its authored reach; the renderer does not enlarge a limb or alter the physical root to reach an unusually large rung interval.

Top exit uses the actual top coordinate and motor progress. Hands release as the sensor passes out of reach; the rig does not invent an unseen floor or lateral mantle. `climb_detached` with `top_exit`, `bottom_exit`, `floor_exit`, or `horizontal_release` permits a short original 0.10s release silhouette. Feet plant only if the motor has found ground. Jump, roll, dive, attack, hurt and renewed climb ownership take precedence immediately. Low release/climb variants stay within the 20px clearance envelope. `climb_attached` clears obsolete jump and contact transients, and reset discards every stored contact.

The reference audit identifies declared ladder/climb APIs with unavailable implementation bodies and official ladder-top/jump-exit improvements. That establishes a feature surface, not original rung gait coordinates or exact clip timing. All climb bodies, contact-recovery paths and visual release timing here are original MOKSHA art. This module adds no wall-run, root motion, traversal permission or physical attachment.

## Wall traversal contract

The bounded [wall evidence and motor policy](../reference/WALL_TRAVERSAL_CONTRACT.md) records the developer's historical approach → upward wall contact → outward kick → higher landing demonstration. It does not establish current-version frame art, exhaustion/slide behavior, reattachment policy or numeric timing. The new silhouettes, 24px visual stride, 38% planted stride portion and normalized kick keys are original MOKSHA authoring. Motor phases determine their duration; this visual adds no wall action timer, stamina, movement budget or ability gate.

The snapshot supplies `main_action=wall`, `wall_phase` (`run`, `slide`, `kick`), `wall_phase_progress`, `wall_active`, `wall_side`, `wall_normal`, `wall_plane_x`, `wall_contact_point`, `wall_contact_id`, `wall_top_y`, `wall_bottom_y`, `wall_relative_travel`, `wall_support_transport`, `wall_episode_serial`, `wall_kick_direction`, and `wall_kick_progress`. Plane/end coordinates and transport are world-space. Signed downward relative travel excludes carrier motion. The extra motor budget/rearm/grace fields remain inspectable but cannot start a pose or contact by themselves.

**Run and slide.** Alternating foot recovery and planted drives use actual relative travel. During a planted interval, a sole stays at a fixed world height on the supplied wall face. Ankle, heel and toe geometry uses a wall-normal basis before knee IK. Recovery lifts and retracts the foot; no elapsed-time running occurs if physical travel stops. A guiding palm can slide upward with the actor. In the finite slide phase, the body sits back and prepares to release, while touching palms/soles move along the face. Sliding touches are explicitly not reported as world-planted grips.

**Outward kick and facing.** The motor's kick phase immediately retires every wall contact. A held compressed key snaps to an outward extension, holds the push, then opens into flight using motor kick progress. Kick direction, wall side and body facing remain separate. If host permissions lock facing toward the wall, the rig still pushes outward while preserving the supplied facing flag. Free toes and fingers, not just joint centers, retain clearance from the wall. No supported pose is kept alive during a post-release kick-grace window.

**Handoff and lifecycle.** `wall_attached`, `wall_detached`, `wall_kick`, `wall_ledge_handoff` and changed contact identities retire old support markers. A coplanar `wall_support_changed` transfers the marker identity without resetting travel or restarting the pose. Real ledge poses/targets take precedence immediately over stale wall fields. Roll, attack, dive, hurt and climb ownership replace wall rendering; reset clears its bindings. Paused swept carrier transport preserves the local pose. Contacts outside actual wall top/bottom bounds or beyond anatomical reach are released.

The observer emits `foot_plant` for a real visual stance interval, `hand_touch`/`foot_touch` with `contact_type=sliding` for moving touches, and matching release markers. Payloads include the world point, wall surface and authored status. These are presentation observations and never authorize movement or change collision. Contact identity changes retire the old marker even when the new geometric point is identical.

## Hard-contact recovery contract

The high-fall audit supports a separate ordinary landing/stun path, but supplies no recovered threshold, duration or animation data. All impact poses, normalized holds, body compression and recovery shapes here are original MOKSHA authoring. The motor's optional rule and authored 0.06s impact / 0.12s recovery remain outside the renderer. No visual event or accumulated fall time can enter this action.

The motor supplies `main_action=hard_land`, `pose=hard_land_impact` or `hard_land_recovery`, `hard_land_phase`, `hard_land_phase_progress`, `hard_land_progress`, `hard_land_kind` (`ordinary` or `dive`), `hard_land_skidding`, `floor_normal`, `floor_contact_point`, `floor_relative_velocity`, and the existing support identity/displacement. Floor point and normal describe actual world contact. Relative velocity and skid exclude carrier transport. Outside the authoritative owner, leftover hard-landing fields cannot retain its pose.

**Original keys.** Soft landing retains the taller, quick compression established in movement. Ordinary hard impact sits much lower with a guarded chest and separated feet. Dive-derived hard impact folds farther forward, lowers the head and arms and holds the committed contact. Both hold the entire motor impact phase, retain that key for the first 12% of recovery, gather by 58%, then unfold only to the existing compact crouch. The whole recovery stays within the current 20px body; only the motor can restore standing clearance. `landing_keys.gd` stores this art separately from `landing_pose.gd`'s pure geometry.

**Contacts.** Each sole, toe and heel lies on the actual supplied floor plane with the ankle offset along its normal. While the motor reports skid, feet follow physical relative travel and emit `foot_touch` with `contact_type=sliding`; they never emit a planted claim or stretch toward an obsolete anchor. Once actual skid stops, contacts become planted and follow only support transport. Surface changes, unreachable host edits and cancellation retire or resample contacts. Headless fixtures cover mirrored normals, translated carriers and clearance; they do not grant new collision support for arbitrary terrain.

**Ownership.** A high dive still emits its physical impact event, then hard landing owns the sole visual response. The adapter adds no effect, damage, sound or duplicate impact event. `hard_land_started` clears old takeoff, landing, melee-contact and locomotion transients. Finish/cancel retires contact markers and ordinary-landing residue immediately. Hurt and the motor's next movement, jump, roll, attack, climb or ledge pose replace it. Impact and recovery use current motor facing; the renderer never chooses when a turn becomes legal. Hitpause freezes motor progress and visual clocks while validated carrier transport remains coherent. An actual short-jump apex or descent now takes priority over any remaining authored takeoff transient, including a jump released from recovery.

## Passive ordinary slope support

The pre-correction probe in `tests/slope_visual_defect_baseline.json` records the actual visual defect: ordinary support ignored the supplied floor point/normal and held horizontal soles above or across a sloped plane. Mirrored 26.6° and 45° fixtures produce idle sole gaps of 2.24–7.78px. A rectangle resting on its uphill corner can leave the central floor outside an otherwise unchanged standing leg's reach, so simply projecting a foot downward is insufficient.

`slope_pose.gd` fits only real grounded poses with an inclined `floor_normal` and supplied world `floor_contact_point`. Original hip, trunk, head and arm joints compress vertically by at most 4px; the actor's transform, collider, facing, velocity and action progress remain untouched. Soles are fitted along the floor tangent within the original two 8px leg segments. Ankles offset 1.4px along the floor normal, and heel/toe segments follow its tangent. Knee solutions remain above the plane. Unreachable targets lose their planted flag and retain anatomical reach; legs are never stretched to force contact. Flat poses retain their exact existing geometry.

Ordinary idle, run, start, brake, turn, soft land and crouch use this fit. Grounded roll entry/recovery, melee windup/active/recovery and hurt use it only when their authored key already claims at least one planted foot. The fit adds no new support to airborne or unplanted rolling/recoil phases. It preserves the upper-body shape and moves every weapon point with the same bounded joint compression so the grip stays attached. In the current mirrored fixtures, the largest weapon/contact displacement relative to the unchanged motor strike geometry is 2.39px downward. Its bound is 4px; it never edits the hit area. Unplanted special keys retain a measured worst toe-center crossing of 0.42px against a synthetic 45° plane. This is an explicit residual of preserving those original free-body phases, not a claim that every special silhouette is terrain-conforming.

The adapter keeps reachable stance soles fixed in world space until their authored step or reach limit releases them. Support identity, normal changes and parallel-plane changes revalidate the binding, including crests and valleys on one collider. Updated carrier displacement transports supported feet; a paused actor does not advance its gait. Contact release clears old locks before air, climb, ledge, wall, hard landing or another unsupported owner takes over. No collision query, root offset or motor compensation is introduced.

`tests/slope_visual_results.json` verifies the mirrored plane/normal and leg-length bounds, bounded joint compression, world stance drift, same-collider plane changes, idle hold, carrier pause, explicitly supported special phases, attached weapon geometry and immediate departure. `tests/slope_special_pose_audit.json` preserves the pre-extension limitation measurements. `tests/slope_motor_visual_results.json`, when produced on a stable motor, compares real continuous-course snapshots against a shadow view with the former flat support behavior. The checks constrain contacts to the reported plane; they do not reconstruct unreported adjacent surface extents or authorize a different physical floor.

Accepted M6 result/sample files retain their snapshot bytes. M7 reruns of those suites are saved separately as `*_compat_m7.json`, including the repinned hard-landing integration. `tests/m7_visual_evidence_manifest.json` records both sets of hashes and the intentional production visual source hashes. Rerunning an older test writes its traditional output name; preserve its result under a new compatibility name and restore the historical file before packaging. New slope evidence uses separate names throughout.

## Shield, parry and effect feedback

The shield audit distinguishes held guard, incoming parry and successful outgoing retaliation/reflection. Historical [developer update 4](https://deadcells.com/patchnotes/4) supports that qualitative split; original animation data and complete current timing remain unavailable. These wireframe keys and their normalized holds are independently authored MOKSHA art. The renderer does not derive a defense window or cooldown from its keyframe progression.

The motor supplies `shield_active`, `shield_phase` (`raise`, `parry`, `hold`, `miss_recovery`, `success_recovery`, `release_recovery`), `shield_phase_progress`, `shield_serial`, current `shield_facing`, world `shield_center`, `shield_size`, `shield_normal` and `shield_parry_open`. A live authoritative `shield_*` pose selects the module. Extra lock/buffer/holdability/outcome fields remain motor telemetry; they cannot synthesize a visual action by themselves. The shield layer replaces the sword immediately. Finish, cancellation, hurt and reset remove its outline and contact feedback before the next presentation update.

Raise unfolds a low folded arm into an extended presentation key. The finite parry holds that committed key before gathering into the held brace. Hold is stationary indefinitely unless actual ground travel drives the existing leg gait. Miss briefly overextends and drops the guard; incoming success uses a held backward deflection; release lowers the arm without suggesting an impact. All six phases follow motor progress and current permitted facing. Rising, apex and falling guard retain different free leg targets. Airborne feet never become planted. A real soft landing compresses the hips behind the live guard while its reported band stays fixed. Low variants preserve the motor's 20px clearance; grounded contacts reuse the accepted passive slope fit.

The outlined shield matches the reported band, while its separate forearm strap ends at the near palm. The arm solver preserves its 6px/5.8px limb lengths, including terrain compression. Default bands are reachable in all tested standing/low/air/mirrored contexts. An unusual custom band outside arm reach remains in the raw metadata and reports `attached=false`; the limb is bounded rather than stretched or the physical root moved. `shield.center`, `size`, `normal`, `outline` and `raw_outline` retain the full authoritative geometry. `visible_segments` clips only drawn outline edges against a real reported floor while grounded. This is presentation occlusion, not a change to defense geometry or collision eligibility. Airborne poses ignore stale floor data; no adjacent terrain or replacement floor is inferred.

Only accepted `defense_resolved` events with `guarded` or `parried` outcomes create incoming-contact marks. The event's world contact point, normal, serial and facing are frozen; later actor turning or carrier transport does not move that contact. Guard shows a short tangent mark and parry shows three short outward ticks. A confirmed counter arrow or reflected-path mark appears only after its corresponding `shield_counter_confirmed` or `shield_reflection_confirmed` event. These separate marks denote accepted effects at the reported contact, not a fabricated hit on an unreported remote target. A failed counter leaves incoming parry success visible without a counter marker. Duplicate contact/kind events cannot repeat feedback within an attempt, and old attempt serials cannot affect a new one.

Feedback has an original 0.10 actor-second presentation lifetime, unrelated to the motor's defense intervals. Local hitpause freezes it and the motor-driven key, while current band geometry continues to follow validated actor/carrier transport. `last_defense_outcome` and `shield_effect_pending` alone never create success marks. The view emits no attacks, impulse, damage, defense results or gameplay transitions.

`tests/shield_visual_results.json` covers every phase with standing/low, air rise/apex/fall, mirrored normal and slope contexts, exact raw band bounds, reachable limbs, floor occlusion, phase boundaries, held keys, real-travel gait, turning, frozen contact facts, separate effect confirmation, pause/carrier transport and immediate cancellation/reset. Earlier M7 result/sample files retain their accepted bytes; M8 reruns are separate `*_compat_m8.json` files recorded in `m8_visual_evidence_manifest.json`. Existing non-shield vector outputs remain byte-identical in those compatibility runs.

`tests/shield_motor_visual_results.json` adds real 120Hz actor/fixture integration in both facings: held/tapped phases, crouch, airborne admission and soft landing, swept melee counter, rejected counter, physical projectile reflection and guarded contact. It checks the actual band, palm attachment, frozen world marks and local hitpause, and rejects runs when relevant source hashes change. The initial soft-landing cancellation failure and the later source-changed candidate remain separately named evidence; the accepted result is pinned in the M8 manifest. This is headless integration evidence; native replay remains a separate check.

## Original M9 three-step melee presentation

`combo_keys.gd` and `combo_pose.gd` add three original light-chain silhouettes: the accepted M2 forward slash, a low-coil upward backhand, and an overhead down-forward finisher. Their anticipation, held contact and follow-through differ in torso pitch, hand placement and blade arc. The artist/source study supports purposeful pose-to-pose design; no commercial animation track, exact frame timing or asset was recovered or copied.

The motor supplies `attack_pose_id` (`slash`, `backhand`, `finisher`), `attack_step_index`, `chain_serial`, `attack_serial`, current body `facing`, committed strike `attack_facing`, `weapon_phase` and `weapon_phase_progress`. The nine poses are `attack_<pose_id>_<windup|active|recovery>`. The view does not inspect input queues, choose a next step or derive readiness from animation completion. Generic `attack_windup/active/recovery` remains the exact earlier fallback when no chain pose identity is supplied. A stale chain field cannot reclaim an explicitly supplied replacement pose.

The chain body/head/stance follow current `facing` in every phase. Windup and recovery blades follow that body; recovery has no live strike. During an explicitly configured active body turn, the blade retains `attack_facing`, with the near arm solved toward the committed side within its anatomical reach. The active blade can therefore shift inward (measured maximum palm adjustment9.78px) while keeping its direction and attached grip; no hitbox moves. Pose metadata exposes `combo.body_facing`, `strike_facing`, `weapon_facing` and `arm_reach_adjustment`. Default active turning remains motor-locked. Previously the entire recovery body incorrectly inherited the old strike facing; `combo_facing_motor_results_candidate_a1_before_facing.json` and the parent's native before capture preserve that defect. `combo_facing_motor_results.json` proves the correction using a real right strike followed by left recovery input without a queued step, plus a custom active-turn profile with a real right-side contact and frozen hitpause feedback. Early chaining captures the displayed recovery facing rather than the old strike facing.

All keys use normalized motor progress. The slash holds its active contact through 0.66, backhand through 0.62 and finisher through 0.72 before interpolating to follow-through. These fractions are original rendering choices, not active-hit windows. A committed next step captures the last presented recovery key and blends toward its new anticipation over the first 0.45 of windup. This does not postpone the motor's active phase. A standing reversal preserves the entry's world palms, soles, pelvis and blade; the shoulder-side assignment responds to the newly committed facing, bounded by the 4.6px shoulder span. A low reversal immediately adopts the motor-facing compact torso, so its palm can move with that torso; its sole supports, anatomical reach and complete blade-clearance envelope remain constrained. New-step events retire prior foot anchors and impact feedback.

Grounded feet use the accepted support/terrain solver. Air legs retain rise/fall context and claim no planted support; a real soft landing can compress the body while the attack continues. Low-clearance keys retract a forward blade and lower the raised palm without expanding the body. The whole interpolated arc stays inside the 20px vertical envelope; a rear-to-front planar rotation would pass through the roof or floor between otherwise valid endpoints. Ordinary keys retain the full blade length. During a low-clearance reversal only, an explicitly labeled edge-on projection turns the blade between its two horizontal directions; the full-length active strike and physical geometry are unchanged. The original 6px/5.8px arms and 8px/8px legs remain anatomically bounded. The near palm is always the actual blade grip. Slope fitting moves joints by at most the existing 4px bound and never offsets the physical root.

Only a matching `strike_confirmed` serial with a reported world contact creates the new chain's impact mark. Its location remains frozen across facing changes and carrier travel. Local hitpause holds the current key and feedback lifetime; starting another step, cancellation, hurt, shield or reset cannot inherit the old strike mark. The marker denotes incoming confirmed contact, not a second hit or a target-selection instruction.

`weapon.blade_a`, `blade_b`, `tip`, grip and strike geometry always remain raw. `visible_blade_segments` provides drawing-only occlusion against the reported supporting floor when grounded. Airborne poses ignore stale floor data. No closing edge, adjacent terrain extent, contact rule or collider is invented. The measured raw blade can cross an uphill 45-degree floor during follow-through; the drawn segments stop at the supplied plane. Neither correction nor occlusion changes contact eligibility.

The new preview set is `tests/combo_actual_scale.png`, `combo_contact_sheet.png`, `combo_slope_sheet.png` and `combo_transition_preview.gif`. The GIF is an offline fixed-root normalized-key sequence, showing forward chaining, an intermediate reversal and low clearance at 1:1 beside enlarged detail. It is not a gameplay recording. `combo_pose_samples.json` retains raw authored vectors and transition observations. `combo_visual_results.json` records anatomy, grip, held keys, phase/step entry, real-contact metadata, slope/low/air context, pause/carrier and cancellation checks. Earlier accepted outputs are restored byte-for-byte from the M8 snapshot; M9 compatibility outputs are separately named `*_compat_m9.json` and recorded in the M9 manifest.

`tests/combo_motor_visual_results.json` pins the final actor and visual sources and observes twelve actual 120Hz scenarios: both facings on flat/slope terrain, a jump through soft landing, a real low roof, an intermediate reversal, and a low-roof reversal. Normal chains deliver three real target contacts; reversals correctly miss the middle swing. The harness checks the exact motor-selected family/facing, actual grip, floor sole, world contact mark and local hitpause. The low reversal checks the newly turned recovery body and its complete blade under the roof. Turning during recovery already updates the displayed body before a queued next step begins; that path correctly needs no additional entry projection. The low entry projection remains covered by the focused boundary tests for a facing change at new-step admission. `combo_motor_pose_samples.json` contains those headless vector observations; the first90d5 candidate is preserved separately. Native visual/feel review remains a distinct parent-owned check.

## Original M10 optional held loading and thrust

`charge_keys.gd` and `charge_pose.gd` add an explicitly optional `attack_charge` loading pose and three `attack_charged_thrust_<windup|active|recovery>` poses. The accepted M9 key modules are unchanged. Held-repeat uses those existing light-chain poses and new motor strike identities; the view neither synthesizes a press nor chooses whether to repeat. Default M9 pose/sample outputs remain byte-identical in the M10 compatibility runs.

The motor owns the optional held-input profile, starter Slash, uninterrupted-hold identity, admission, release cancellation, charge duration and single automatic thrust commitment. Loading reads `weapon_phase=charge`, `charge_phase`, `charge_progress`, `charge_serial` and `charge_role`; the thrust reads `attack_pose_id=charged_thrust` and the existing phase, serial and facing fields. The view does not derive readiness from its own clock, infer charging from a held button, or start a release attack. `charge_started`, `charge_cancelled` and `charge_committed` retire the previous presentation contacts and feedback. Stale `ready` or progress fields cannot reclaim another pose owner.

The original loading keys draw the blade close to the torso and transfer weight rearward, with gathered shoulders at progress0.35 and a held loaded silhouette from0.82. A short entry blend uses the preceding displayed recovery key. Charged windup begins at the same loaded key; its active phase snaps to a straight extended thrust and holds through0.56 before follow-through. The rear foot reaches the reported ground before the lead foot unloads. Above-plane interpolated feet are never labeled planted. These normalized rendering fractions are authored MOKSHA art, not recovered game frames or changes to the physical active interval.

Loading retains a travel-driven gait below the braced upper body, including a compact low shuffle and backward movement relative to current facing. It uses actual actor displacement minus carrier transport; blocked or stationary actors do not march from held intent, and local hitpause does not advance the gait. Air poses keep rising/falling legs without floor plants; real soft landing can compress the loading or thrust body. The new grounded families use the supplied floor plane to fit even an unplanted swing foot, without inventing support or moving the root.

Body/head/stance use current `facing`. Only the live active thrust blade uses committed `attack_facing`; the accepted anatomical arm fitting and recovery-turn rules remain in force. Ground-only blade occlusion retains raw weapon and physical strike geometry. The measured complete low blade arc stays between−14.35px and−5.64px, and the low body remains inside20px. No graphic rectangle, new texture, visual root motion, invulnerability or contact authority is added.

Loading explicitly suppresses contact/confirmed feedback. Only a real `strike_confirmed` event with the charged strike's matching serial can create its frozen world mark. Old starter confirmations cannot carry into the thrust. Local pause holds the pose/feedback; release, shield, roll, hurt and other authoritative ownership changes retire the loading blade immediately.

`tests/charge_actual_scale.png`, `charge_contact_sheet.png` and `charge_moving_preview.gif` are inspected offline vectors. The moving preview intentionally holds charge progress at0.60 while varying the independent travel phase, making standing/low foot motion visible. It is not a gameplay recording or a recovered animation track. `charge_visual_results.json` and `charge_pose_samples.json` cover mirrored geometry, held keys, phase boundaries, moving/stationary feet, low/air/landing/slope context, serial feedback, pause/carrier transport and cancellation.

`tests/charge_motor_visual_results.json` observes real120Hz optional-profile ticks and swept passive contacts in both facings: stationary/moving load, a real low roof, low shuffle, air load and thrust through landing, recovery reversal, release and shield cancellation, and held-repeat returning through the existing three light poses. It verifies actual progress, grip, body/strike facing, world contact marks and local hitpause, and rejects changing source hashes. Accepted M9 result/sample bytes are restored from the M9 snapshot; M10 reruns are separately named `*_compat_m10.json`. The final actual-motor rerun passes 18 mirrored scenarios and 9,401 checks on actor `c7c18b726210665df2304ff4aba190edda54816eaeb6fded1b44a63751f1987d`, after the isolated strike hold-provenance correction. The previous `ca632f15` result, samples and manifest are preserved as `*_candidate_ca632f15.json`; production visual GD sources and prior visual evidence remain unchanged. The exact source/result hashes are in `m10_visual_evidence_manifest.json`.

## Editor and offline previews

Because the node is `@tool`, select `Visual` in the editor and change `preview_pose`, `preview_phase` or `preview_facing` to inspect a static pose. The preview does not run the motor or move the actor. `show_contact_marks` makes sole/palm intent visible.

The generated files are explicitly offline vector previews:

- `tests/actual_scale_preview.png`: 640×360, one authored source pixel per image pixel
- `tests/pose_contact_sheet.png`: enlarged pose/key inspection
- `tests/pose_samples.json`: underlying original movement vectors and snapshot fixtures
- `tests/combat_actual_scale.png`: combat silhouettes at one pixel per authored pixel
- `tests/combat_contact_sheet.png`: ground/air roll, weapon and hurt inspection
- `tests/combat_pose_samples.json`: original combat pose vectors and snapshots
- `tests/descent_actual_scale.png` / `descent_contact_sheet.png`: original drop/dive standing and low pose inspection
- `tests/descent_pose_samples.json`: underlying original descent vectors
- `tests/climb_actual_scale.png` / `climb_contact_sheet.png`: original ladder/vine and low-clearance inspection with supplied rung guides
- `tests/climb_pose_samples.json`: underlying original climb vectors and geometry fixtures
- `tests/wall_actual_scale.png` / `wall_contact_sheet.png`: original mirrored run/slide/kick and low/locked-facing inspection
- `tests/wall_pose_samples.json`: wall pose vectors with authoritative plane fixtures
- `tests/landing_actual_scale.png` / `landing_contact_sheet.png`: original soft versus ordinary/dive hard-contact comparison and compact recovery
- `tests/landing_pose_samples.json`: underlying landing vectors and floor fixtures
- `tests/slope_actual_scale.png` / `slope_contact_sheet.png`: ordinary slope fits at game scale and enlarged normal/contact inspection
- `tests/slope_special_contact_sheet.png`: existing supported roll/melee/hurt keys with the same passive terrain fit
- `tests/shield_actual_scale.png` / `shield_contact_sheet.png`: original six shield phases at 1:1 and enlarged phase inspection

They are not gameplay screenshots or evidence that native input, collision and camera integration were tested. Native-flow verification belongs to the integrated player/lab checks.

## Focused verification

```sh
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/visual_regression.gd
python moksha/combat_pc/visuals/tests/render_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/combat_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_combat_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/descent_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_descent_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/climb_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_climb_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/wall_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_wall_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/landing_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_landing_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/landing_motor_visual_smoke.gd
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/slope_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_slope_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/slope_motor_visual_smoke.gd
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/shield_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_shield_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/combo_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_combo_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/charge_visual_regression.gd
python moksha/combat_pc/visuals/tests/render_charge_previews.py
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/charge_motor_visual_smoke.gd
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/combo_motor_visual_smoke.gd
XDG_DATA_HOME=/tmp/moksha-visual-data XDG_CACHE_HOME=/tmp/moksha-visual-cache XDG_CONFIG_HOME=/tmp/moksha-visual-config godot --headless --path moksha --script res://combat_pc/visuals/tests/shield_motor_visual_smoke.gd
```

The current measured result is in `tests/visual_results.json`. Tests evaluate distinct silhouettes, finite and reachable geometry, left/right symmetry, held impact keys, opposing run limbs, steady head motion, foot plants across speeds, moving support, authoritative palm anchors and no limb-segment crossings below the edge at full and shallow arrivals, reset/teleport hygiene, immutable snapshots, and actual draw notifications inside a headless scene.

`tests/combat_visual_results.json` adds roll envelope and full-spin boundaries, reachable limbs, directional mirroring, held contact keys, palm/weapon attachment, air/low variants, landing under an active weapon phase, hitpause and carrier transport, restart/cancel/hurt/reset transitions, and drawing for all seven combat families.

`tests/descent_visual_results.json` covers the five new families, mirroring, low clearance, root-plane alignment, anatomically reachable joints, held impact and continuous phase boundaries, motor-only impact selection, weapon removal, roll/damage cancellation, hitpause, safe blocked-pose selection and lingering exception cleanup.

`tests/climb_visual_results.json` covers anatomical reach, left/right mirroring, ladder/vine and low bodies, actual-travel rung plants, reversal, stationary holds, paused sensor transport, top/bottom release and immediate combat/jump detachment. Scale fixtures cover 0.1× through 3× vertical scale and0.8–64px world widths; geometry-edit fixtures verify contact release/resampling.

`tests/wall_visual_results.json` adds reachable geometry, mirrored and host-locked facing, wall-normal soles, free-finger/foot/head/stroke clearance, low bodies, actual-travel plants, moving slide touches, finite transformed wall bounds, paused carrier transport, coplanar seam transfers, explicit contact retirement, and immediate ledge/other-action handoff. The mirrored 1:1 preview was inspected separately from the numerical checks.

`tests/landing_visual_results.json` covers distinct soft/ordinary-hard/dive-hard silhouettes, held impact and continuous phase boundaries, anatomical reach, 20px clearance, mirrored floor-normal soles, true skid versus stationary support, carrier transport, paused impact, immediate action ownership/cancellation, queued jump release and early short-jump apex/fall. Its game-scale and enlarged sheets are independent vector inspections.

`tests/landing_motor_visual_results.json` records an additional actual 120Hz physics smoke with the reusable player scene: mirrored ordinary and dive high falls, real phase ownership, ordinary skid-to-plant on a moving support, floor-plane agreement and immediate release. It pins the motor hash and rejects a run if the motor changes during observation. This remains headless integration evidence, not a native gameplay recording.

The measurements establish those fixture behaviors. They do not establish every possible slope, ledge geometry, future motor profile or future combat state. Additional actions should add their own original key targets and explicit ownership contract rather than reuse an unrelated pose by default.
