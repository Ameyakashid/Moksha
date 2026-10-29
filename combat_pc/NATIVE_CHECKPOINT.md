# Movement checkpoint: native play and packaging

Recorded 2026-10-04 in Godot 4.6.3 on the cloud Linux desktop, using real keyboard input through the supported desktop controls. The current player is the original MOKSHA wireframe; one player is instantiated, with editor-placeable collision fixtures and no NPC.

The final recorded continuous flow includes acceleration, repeated reversal, release/braking, a ground jump into ledge catch/pull/step, airborne steering, another jump and a left-facing landing. The 6.8-second preview preserves the captured frame timestamps; only the idle tail is trimmed. HUD direction and velocity make the reversal observable. The source PNG sequence and trace are local capture artifacts, not prerecorded movement driving the actor.

Additional native checks exercised inspection resets, a blocked low-roof mantle approach, a two-jump crossing of the moving-platform gap, pause, and return to normal movement. Native screenshots do not by themselves establish moving-platform contact correctness; the actual-physics regression suite tests tracked moving ledges, obstruction, removal and invalidation separately.

The final wireframe was reloaded in Godot and captured after its leading-foot path was corrected to stay outside the ledge until above the top. The passive view reads movement state and never drives root position or facing.

## First-checkpoint scope at the time of capture

This is the first connected movement pass, not a finished Dead Cells controller. Roll, attacks, damage, dive, ladder/wall-run abilities and combat interruption are pending. Exact original-game timing parity is not claimed. Motor values are authored MOKSHA tuning; private primary-reference media is excluded from the project.

The earlier two-level MOKSHA game remains accessible by opening main.tscn and running that scene. The default project run opens combat_pc/lab.tscn. Original EMBERWAKE and the standalone asset package remain separate.


## Second checkpoint: coupled roll, melee and hurt

The final actor was reloaded natively after the paired physics acceptance and warning cleanup. The connected sequence uses actual keyboard events: run into range, strike, roll through, reverse, strike back, jump/air attack, roll, land and return to movement. Passive target counters distinguish contacts from misses; held attack does not repeat automatically. Separate native checks exercised hurt/recovery in the timed pulse, pause during hurt and resumed control. Invulnerability boundary and moving-carrier safety are established by the independent physics tests, not inferred from a screenshot.

The visible test instruments have no AI or movement controller. The scene still contains one PC. The real existing crate scene was separately hit through the new adapter in the physics regression, establishing that reuse boundary without adding NPC/art scope to this lab.

A clean isolated project containing only the combat_pc folder and minimal project settings imported and booted successfully without the earlier game's autoloads, art or controllers. The old two-level game remains unchanged. The full delivered project also receives a fresh extraction/import/boot check.

Native Godot's remaining diagnostics are the cloud graphics driver's unsupported VSync setting and unavailable audio device/dummy audio fallback. New script warnings were corrected. The preview is silent; no native audio quality is claimed.

Capture files record actual monotonic timestamps. Encoding retains those timings and trims the idle tail; it does not speed up movement. The capture target is60Hz, with achieved rate recorded in the adjacent delivery metadata. This checkpoint adds one melee weapon and a roll/hurt contract; pending surfaces are itemized in COVERAGE.md.


## Third checkpoint: targeted drop and downward dive

The final native recording uses controller6ed04e06 and the44px stacked fixture. Two fresh down-jump presses drop through the upper and lower platforms separately. A roll meets the adjacent thin solid wall without passing it. Two ground jumps feed into two real dive impacts; the latter recovery is canceled into roll, followed by melee and resumed movement. This clip does not claim to show a mid-descent roll cancel; that distinct case is verified by the real-physics suite. The capture contains no station reset after recording starts and retains actual frame timing.

Native spot checks also verified that holding one down-jump does not fall through the entire stack, that the40px test spacing safely keeps the body crouched, and that the44px native spacing permits standing. A down-jump on ordinary solid ground visibly reports refusal. Local pause and station reset remain available. Final capture metadata is NATIVE_CAPTURE.json.

The portable source archive omits generated per-tick trace JSON; the separate verification-traces archive retains it. Regression scripts and acceptance summaries remain in the project.


## Fourth checkpoint: ladder/vine traversal and action detachment

The final controller3595e1b9 was reloaded in native Godot after independent acceptance. One unbroken keyboard-driven recording climbs the ladder, stands on its separate one-way top, re-enters from above, jumps from the grip, reverses through another jump, detaches into melee, rolls, reattaches, dives to actual floor contact, then confirms a melee hit. The trace records five attachments and five detachments; no inspection reset occurs after recording begins. The 8.46-second preview retains actual timestamps, at about50 captured frames per second. It is silent because the cloud audio device remains unavailable.

Native play exposed a real adjacent-key issue: pressing a horizontal direction one physics tick before jump released the grip and consumed the air jump. A single-use60ms grip-jump grace now recognizes that short input sequence while preserving the existing air budget. The final native trace records a supported from-climb jump after horizontal release. Independent tests cover both directions, expiry, spent budgets, removed/disabled sensors, action interruption and permission locks.

Additional native checks exercised stationary grip hold, deliberate top re-entry and finite top exit without an automatic regrab loop. The rendered hands and feet use the actual sensor rung spacing; the view is passive. Moving/scaled sensor contacts, geometry mutation, clearance, collision cleanup and60/120Hz compatibility are established separately in climb_verification.md. This checkpoint implements upright ladder/vine sensors; it does not establish wall-run, shield/parry, complete Dead Cells timing identity or a production animation asset set.


## Fifth checkpoint: gated wall traversal and connected actions

The final native recording uses controller1484ba48. One uninterrupted input sequence runs up the wall, reaches its finite slide, kicks outward and lands on the higher opposite platform. It then reverses into a ledge catch/pull/step, dives onto the opposite platform, returns through a left-facing ledge traversal, and cancels a melee swing into an airborne roll and physical landing. No inspection reset occurs after recording begins. The preview retains actual timestamps (about51.5 captured frames/s) and trims only the idle tail. It shows a leftward supported wall kick; a separate native trace verifies the mirrored rightward kick and higher landing. Both retain the ordinary air-jump budget.

Native replay exposed a real cooldown-boundary defect after the first automated pass: a fresh jump just before regrab eligibility spent an air jump, then automatic attachment canceled its ascent on the following tick. Valid supported intent now waits in the existing queue for that transient gate. A genuinely unavailable wall kick preserves the accepted ordinary jump's ascent. A related queued-tap release issue under a temporary host jump lock is also corrected. Neither fix changes grace, speed or profile tuning. The revised physical acceptance retains both reproductions and tests the interval before, at and after regrab expiry.

Additional native checks verify the opposite approach/facing, G ability-off refusal, inspection reset and global pause/resume. The lab grants the ability; the standalone actor starts locked. The final live lab is left ready at station9. Stations9 and0 provide both wall approaches and the separate wall-to-ledge fixture. The native trace files are in the companion evidence archive; NATIVE_CAPTURE.json describes the delivered flow.

A fresh minimal Godot project imported and ran only the player, its runtime components/resources/visuals, and minimal_host.tscn. It has one PC and ordinary scriptless StaticBody2D terrain, with no lab, fixture scripts, old-game autoloads, source-art or former-controller dependency. The isolated actor grounded correctly and its loaded source hash matches the verified controller. The final portable full project receives its own fresh extraction/import and PC/city/interior boot checks.

Supported wall geometry is deliberately bounded to dedicated upright solid rectangles. The original wireframe, finite run/slide, cancellation and rearm parameters are MOKSHA choices; the developer's historical clip establishes the core wall-run/kick/higher-landing sequence, not current-version numerical parity. General high-fall recovery and shield/parry remain pending.


## Sixth checkpoint: optional high-fall recovery

Controller55dd19f5 was reloaded after paired physical acceptance. Separate native keyboard trials compare a190px ordinary drop, a420px hard drop, a420px dive, and a dive canceled into a live roll. The high ordinary landing selects a compact impact/recovery pose and accepts one released jump tap into its existing queue; the jump starts on the same physics tick that recovery ends. The low drop remains ordinary. The high dive emits one physical impact, then yields to hard recovery. The qualified live roll reaches the floor with fall protection and no hard recovery. These are controlled fixture trials with resets between them, not one continuous level route. Their loaded-source hashes and raw input/event traces are retained in landing_native_*.json.

A native rule-off high drop, pause/resume and station reset also pass. The lab exposes B/N height comparisons and H as the optional rule toggle. The reusable actor defaults the rule off. All dimensions, speeds, phase times and poses are authored MOKSHA choices; the historical Dead Cells live-stomp-to-roll exception is source-qualified in HARD_LANDING_CONTRACT.md. The cloud capture remains silent.

This checkpoint is retained locally before the next ordinary-slope correction. During testing, the inherited soft-land solver was found to project falling velocity into unwanted downhill motion and lose support at some physics rates. That defect is recorded separately and blocks publication of the next runnable ZIP until corrected. The hard-recovery path already preserves incoming horizontal momentum and confirmed floor-tangent braking.


## Seventh checkpoint: slope momentum and continuous support

The final actor4aa41326 was reloaded in native Godot after the collision and callback corrections. One continuous real-keyboard trial traverses both inspection hills in both directions, including26.6° and45° inclines, level joins, crests and valleys. It covers worldX2500 to3193.67 and returns to a stationary inclined stance with no sampled support loss or spurious landing event. A separate unbroken flow couples three ground jumps, an airborne roll into landing, left-facing melee on an incline, another landing and a grounded downhill roll. The second jump press in that recording occurs after touching higher terrain; it is a ground jump, not air-jump evidence. Capture files retain raw inputs, loaded-source hash, floor normals and actual timestamps. No station reset occurs inside either recording.

Native replay found the intermediate crest stall that simple plane tests missed. A normal sampled at a shared vertex could select the adjacent downhill face before the trailing footprint cleared the flat top. The final policy confirms that face under the actual supporting corner. Independent fixtures retain the failed candidate and test both directions and rates. The existing2px floor probe and0.02px collision margin remain unchanged. The final same-ownership ceiling guard was additionally checked by the physical callback matrix.

The final native build also rechecks high-fall recovery: a released jump tap remains queued and starts on the recovery-finish tick. A qualified live dive-to-roll reaches the actual floor with fall protection and no hard recovery. Earlier M6 controlled trials preserve the low-drop, rule-off, ordinary/dive pose, reset and pause checks. Final compatibility results distinguish their original checkpoint from current-controller reruns.

The passive view now fits supported feet to the reported plane on ordinary and explicitly planted special poses, preserving leg lengths and bounded joint compression. It does not move the physics body. Flat and airborne geometry retains its established behavior. Unplanted tumble/recoil poses are not forced onto terrain; the documented small synthetic toe crossing remains a presentation limit.

The PC fixture previews contain no recorded audio. Numerical tuning, contact policy and wireframe poses remain original MOKSHA work. This is a connected movement/action checkpoint; pending combat and ability surfaces remain listed in COVERAGE.md.


## M8 — directional shield and physical returns (2026-10-04)

The native Godot run loaded controller `69b74005a5e2bae8e89287e1c089795de910bc4ebfcace2ecf880aad418cc7e4`. These observations exercise the production actor, adapters and actual passive instruments:

- Held frontal melee guard: damage10 resolves to2.5; a later fresh timed press fully parries and the source receiver confirms one counter. A reset between takes clears all visible contact counters.
- Ordinary bullet: the timed parry changes its physical direction; it travels back into its emitter, whose return counter becomes1. The earlier deliberately mistimed attempts separately record full hurt and held guard.
- Rigid crate: actual Godot solver contact is parried, its real velocity changes, and the returning crate contacts its source receiver. No NPC or timed fake impact produces that result.
- Rear-facing guard: face left while a blade arrives from the right; the actual rear contact produces full damage10 and retires the guard through hurt.
- Jump with held shield: the same shield serial stays in hold across the real soft landing. Separate left/right guard presses turn the body and band consistently, followed by an ordinary horizontal roll after release recovery.
- Incoming rigid prop paused in midair: repeated screenshots approximately10seconds apart show the same position, and F requests no further attack while paused. Resume continues the original physical contact. This native observation is complemented by the exact physical pause checks in the component and independent reports.
- Editor reuse: opened `fixtures/guard_course.tscn`, inspected the melee instance's exposed direction, telegraph, damage and eligibility settings, duplicated the scene instance, moved it80pixels independently, and undid both changes. The scene returned to an unmodified state; neither instance attacked inside the editor.

`delivery/MOKSHA-PC-Defense-Flow.mp4` contains four separate native excerpts in order: held guard then timed counter; bullet return; rigid-crate return; jump/held landing/left-right guard/roll. Cuts connect separate inspection takes. Each excerpt preserves its recorded monotonic timing, with only idle tails trimmed. The combined1280×720 H.264 clip is13.4205seconds/629encodedframes (about46.9frames/s), with no audio. It is not a60fps recording or an uninterrupted traversal of the course. The still `MOKSHA-Shield-Counter.jpg` is an actual captured contact frame showing confirmed counter and hitpause.

Evidence is `tests/shield_native_*.json`. Files ending `_candidate` refer to the earlier623955eb actor and are retained as development evidence, not final acceptance. Final native files carry the69b74005 hash. The pause-resume test includes an unshielded resumed hit; it does not claim that a press made while paused creates a buffered shield.

Fresh source-ZIP extraction imports and boots the PC lab, city and arcology with clean Godot logs. A second fresh project contains only the reusable PC runtime, profiles, components, original view and scriptless minimal host: it imports, settles onto terrain and enters held guard with no old-game autoload, fixture or lab dependency. `delivery/M8-PORTABLE-CHECK.json` records log hashes. The earlier two-level game's broader play acceptance remains at its preserved checkpoint; these are compatibility boots.


## M9 — chained melee and visible recovery reversal (2026-10-04)

The final native run used controller `a1f37be07965aa1956dfb73d372b24579371a0178df44e7cc3805097a5550b99` after restarting Godot with the corrected, frozen view. These are actual keyboard-driven observations, separate from the paired physical report:

- Run, release/brake, reverse, then jump into a real ledge catch, vertical pull and horizontal step. The final recording contains `ledge_catch`, `pullup_begin`, `ledge_step`, `landed` and `pullup_end` in sequence.
- Three fresh J presses deliver Slash, Backhand and Finisher, with independent strike serials and exactly three target hits. Holding J for1.4seconds produces only the first swing.
- Turning the middle attack gives right/left/right facing, a genuine middle-step whiff, then a right-facing finisher. No target is hit merely because the chain advances.
- A short-hop Slash makes its first real contact while falling, before the soft landing; Backhand and Finisher continue after landing. This is an airborne-to-ground chain, not three wholly airborne hits.
- Buffered roll input cancels Backhand recovery and clears the pending chain. A separate take transitions two attacks into a timed shield, then physically parries the incoming blade and confirms its counter.
- A recovered presentation defect was caught in the native game: the controller reported FACE LEFT and VX−174 during recovery while the original wireframe still faced right. The identical input after correction visibly turns the body and recovery blade left. The committed old strike direction is unchanged and inactive. Optional active body turning is covered by the separate actual-motor/view test, not claimed as a native default-profile observation.

Before/after frames are `delivery/MOKSHA-Recovery-Facing-Before.jpg` and `MOKSHA-Recovery-Facing-After.jpg`. The corresponding traces are `tests/combo_native_recovery_facing_before_view_fix.json` and `combo_native_recovery_facing_final.json`. Final other takes use `combo_native_*_final.json`; earlier candidate hashes and the pre-view-fix a1 recording are retained under distinct names.

`delivery/MOKSHA-PC-Movement-And-Chain.mp4` is a20.7275-second,1280×720 H.264 cut of seven native excerpts: run/reverse/mantle; three-step chain; middle-step reversal; corrected recovery reversal; airborne landing chain; roll cancellation; and attack-to-shield counter. Cuts separate inspection takes. Each excerpt preserves the recorded monotonic frame intervals, with idle tails trimmed and a20ms final-frame hold. There are950 source captures and957 encoded frames because the final frame is repeated once per excerpt. The average encoded rate is about46.2fps. No speedup, interpolated gameplay or audio track is added.

The fresh source archive imports and boots the PC lab and preserved city/arcology scenes with clean engine logs. A second project containing only the PC runtime, profiles, components, passive view and minimal scriptless host runs all three chain steps and held guard, without any original-game autoload, lab or fixture dependency. It prints `ISOLATED_PC_CHAIN_AND_SHIELD_OK` with the same controller hash. `delivery/M9-PORTABLE-CHECK.json` records the checks and final archive comparison.

These observations establish the default MOKSHA example on the cloud Linux Godot4.6.3 editor. Authored source gaps, special weapon variants and target-dependent air/aim behavior remain explicitly listed in the coverage ledger. The held-repeat and charge branches are not present in this light-chain example.

## M10 — Explicit held input and charge (2026-10-04)

Final native run: controller `c7c18b726210665df2304ff4aba190edda54816eaeb6fded1b44a63751f1987d`, Godot 4.6.3 on the cloud desktop. Y visibly switches Fresh Chain / Held Repeat / Held Charge; T uses the same passive contact instrument. The default remains Fresh Chain. The independent source facts and authored policy are in `reference/M10_CHARGE_INPUT_ADDENDUM.md`.

Six actual keyboard-operated takes are preserved as `tests/held_native_{fresh,repeat,charge,release,air,reverse}_final.json`:

- Fresh: a 1.6-second physical hold starts one ordinary Slash
- Repeat: the same hold produces five admitted steps, including the finisher and a new cycle; release stops further requests. Request IDs change while their physical hold origin remains stable
- Charge: one 1.4-second hold gives Starter Slash, visible loading and one Charged Thrust, with two actual target receipts. Continued hold does not rearm it
- Release: a 0.4-second hold enters loading, then release cancels it. Only the Starter Slash contacts the target
- Air: simultaneous jump and attack starts the Slash airborne, visibly loads while falling, retains that load across the ordinary landing and commits the Thrust afterward. No hover or air-budget refill is added
- Reversal: rightward travel followed by leftward held attack gives left-facing starter, moving load and Thrust. Body-facing and permitted movement correspond throughout the inspected frames; the final thrust is allowed to whiff after passing the instrument

The source traces record physical inputs, current held identity, committed strike hold origin, pending request identity, weapon/main phases, actual velocity/support and charge progress. Earlier 195c9087/ca632f15 candidate captures are retained separately and do not substitute for the final run.

`delivery/MOKSHA-PC-Held-Input-Flow.mp4` is a 16.2975-second concatenation of these six native takes: 1280×720, 752 source captures and 758 encoded frames. Actual monotonic frame intervals are retained; idle tails are trimmed. There is no speedup or interpolation. Each segment repeats its last frame once with a 20 ms final hold. No audio is included. `delivery/M10-NATIVE-CAPTURE.json` records exact hashes and timing. Loading/contact stills come from the final native capture, not the offline vector previews.

Native pause/resume and station reset were checked. The running game was restored to Fresh Chain at station 1, unpaused. The charge profile was also opened in Godot's actual Inspector; its enum, load controls and independent nested Thrust step were readable and editable without changing the files. A separate clean project containing only the reusable actor, components, resources, view and minimal host passed fresh chain, held repeat, charged execution, early release and later shield use without old-game autoloads. Clean source-archive imports and PC/city/arcology boots passed; `delivery/M10-PORTABLE-CHECK.json` records this separately.

Strict per-tick cancellation, hitpause, simultaneous-action and callback cases are covered by the paired-rate physical acceptance, rather than inferred from this short footage. No source-exact Dead Cells charge/release timings or animation tracks are claimed.

## M11: optional attack-entry facing

The final native Godot session uses actor `123058595238d83090cead600dc0934df527f5cd4a18c555d4da52ea971abaa1` and host `954acdc61aa6ea97c5b954090e9795d986ef6f1ac538927c475c6101b5dd29ec`. The actual loaded script hashes are included in each raw trace.

- With assistance off, the neutral right-facing swing misses the marker behind the PC. With the host enabled, the first fresh attack turns left and confirms one real contact
- Hiding the marker and withdrawing its perception attestation produces no offer and leaves facing right. Explicit right input also wins without a provider query
- Holding through a repeat chain queries only once on the initial fresh attack; later derived repeats do not query. The charge example likewise queries for Starter Slash, then automatically commits the thrust without re-querying

The three raw traces are `tests/entry_native_comparison_final.json`, `tests/entry_native_hidden_manual_final.json` and `tests/entry_native_continuations_final.json`. The delivered comparison joins their actual viewport frames at captured timing. `delivery/M11-NATIVE-CAPTURE.json` pins the segments, timings and hashes. Manual frame-exact changes during windup are covered by physical regression rather than claimed from human-paced native input. Audio capture is unavailable in this cloud session.

The reusable host is independently placeable and binds explicitly to an actor and one registered candidate. Native inspection uses the existing passive marker, not a new NPC. The independent project proof additionally exercises the actual PC and host with a plain Node2D candidate and ordinary terrain, without old-game autoloads or fixture scripts; detailed logs are in the M11 evidence archive. The clean full-project proof boots the PC course and both preserved city/interior scenes. See `delivery/M11-PORTABLE-CHECK.json` for the exact booted runtime hashes and final archive comparison.

After inspection, the native course was left running at the ordinary run start in Fresh Chain mode, entry assistance off, target perceived and detailed overlays closed. The viewport confirms zero contacts and an idle right-facing PC.

## M12: one detachable health component

The native review contains one PC, a Health child and the existing swept melee contact instrument. Inspector review confirmed Actor Path, Maximum Health40 and Reset with Actor. Four guided replays drive ordinary PC input and actual physical contact: direct hit40→30, held guard40→37.5, parry40→40, roll40→40. Each comparison resets the same actor to the same starting health. Manual K+F also confirmed37.5; pause blocks F and now displays PAUSED immediately. R restores health and the contact fixture.

A lifecycle test found that queueing Health for deletion from its change callback could still emit stale damage/depletion notifications. The final component adds a notification lifetime fence; the original failing probe and fixed regression are preserved. The existing actor resolver body is unchanged behind a small completion observer.

The final native clip is a guided comparison, not a claim of hand-timed parry input. It preserves captured frame timing and has no audio. A separate clean Godot project imports the same PC/component and reproduces all four real-contact outcomes without old-game autoloads. Focused health and existing shield groups run at60/120Hz; the entire previous movement matrix was not rerun for this observer addition. See tests/health_report.md for exact coverage and hashes.

This is the review checkpoint for health accounting. No subsequent component is implemented until review.

The final reloaded build also passed manual F damage40→30, native pause feedback and blocked paused input. It was left reset at40 health in free control. The clean portable source archive boots the new health review, established course and both preserved game scenes.

## M13: one optional zero-health response

The new review composes the existing Health fixture with DefeatResponse. A real10-point swept contact empties its10 starting health, the wireframe goes prone, and held movement/jump/attack/shield input cannot restart control. The recording displays the actual pressed inputs. Explicit R resets health and control; native movement and a new attack were observed after reset.

The final clip uses actual captured viewport intervals, without interpolation or speed-up. Its raw trace and loaded script hashes are in delivery/M13-NATIVE-CAPTURE.json; delivery/M13-NATIVE-VIDEO.json records the encoded clip and verifies the held-defeat/post-reset observations. The cloud audio driver remains unavailable, so the clip is silent. Native diagnostics showed that existing audio/sync limitation and pre-existing shadow-variable warnings; new defeat parameter-shadow warnings were removed before final validation. No runtime script error was observed.

Focused defeat and unchanged health cases passed at60/120Hz, including lethal guard chip, retiring active/held combat, high falls, carrier transport, removal/replacement, reset callbacks and mirrored slope-aware pose samples. The full older movement matrix was not rerun; see tests/defeat_report.md for precise coverage. A separate clean project reproduced physical lethal contact/reset and airborne settling using these reusable scenes, with no old-game autoloads.

This response retains the tested body collider and passive presentation. It does not implement a ragdoll, healing, game-over flow or automatic respawn. The existing whole-actor reset remains an explicit host action. Further implementation pauses at this review checkpoint.

## M14: one optional PC sound-event relay

Work resumed from the verified Library v17 archive after the workspace rollback. The archive's exact SHA-256 was checked before extraction; stale local files were preserved separately. Health, DefeatResponse, the existing defeat pose and NoiseBus remain byte-identical to v17.

The restored project was imported through native Godot's Project Manager. Inspector review showed Health, DefeatResponse and NoiseRelay as independent children; the relay explicitly targets the Player and the local SoundEvents bus.

Native walking, jumping/landing and a sword swing delivered four events. With the relay disconnected, the PC moved while the received count remained4. Reconnection and another swing produced event5 at the weapon origin. Source markers remain at captured positions rather than following the PC. Pause blocked further input/events; R cleared the review and restored its start. The scene was left connected, reset and running.

The final silent clip preserves captured viewport timing. delivery/M14-NATIVE-CAPTURE.json records loaded script hashes, exact source origins, input and bus counts; M14-NATIVE-VIDEO.json checks no duplicate delivery and movement with an unchanged count while disconnected. It is an event-origin inspection, not surface propagation or audible sound design.

Focused noise checks passed at60/120Hz, alongside the unchanged Health/Defeat test cases under new result names. The new lifecycle cases cover reset/teleport/pause callbacks, nested sounds, detach/rebind/free and malformed receipts. The full older movement matrix was not rerun; attached/absent exact motor parity was checked. A separate project with no global autoload reproduced walking, disconnection and restored swing delivery through the same local bus. See tests/noise_report.md.

This is the review checkpoint for the relay. No new sensory layer is stacked onto it before review.
# M15 surface-pulse review — 2026-10-05

The current F5 scene is `combat_pc/surface_review.tscn`. It was opened and run
through the existing cloud Godot editor. The editor exposes SurfacePulse as an
independent sibling with geometry-root, excluded-actor, event-bus and enabled
settings; the PC retains separate Health, DefeatResponse and NoiseRelay children.

The final continuous native recording is 11.158 seconds at 1280×720. It shows
one swing producing a nearby floor contact and later block-edge travel, walking,
a real landing on the raised block, another swing, view disconnection while the
PC moves and produces noise, then reconnection and a new pulse. It uses actual
captured intervals, no cuts, speed-up or interpolated frames. Disk capture sampled
229 frames over11.137 seconds; this is capture cadence, not a gameplay frame-rate
claim. The encoded file adds one duplicate final frame and a20ms final hold.
Audio playback is not part of this component or silent cloud clip.

Observed source origins include strike(274,249.98), footstep(299.84,269.98),
landing(410,201.98), then strike(434,181.98) above the block. Each connected
event reaches the surface once. During39 disconnected samples, the PC moves
108.87 pixels and noise count advances4→6 while accepted surface count stays4
and active fragments stay0. Reconnection accepts a new strike as pulse5.
The final silent frame has zero active fragments and zero live pulses. No
blackout or static guides appear anywhere in that clip.

Separate native checks showed the G guides with their explicit label. Esc
froze a live pulse and PC: before/after viewport PNGs remained byte-identical
while D+J was held for500ms. R cleared counts and traces. The app is left
connected, unpaused, guides off, counts0, with the PC reset to(250,270).

Focused headless checks pass98/98 at each60/120Hz and the preserved sonar suite
passes63/63. Fifteen protected engine/component files match v18 exactly. A clean
archive imports and boots the current review, three earlier component reviews,
the full PC course and both preserved game scenes without errors. An isolated
copy with no autoload imports, boots and accepts real movement/strike events;
disabling only the surface view preserves movement/noise, pause freezes intake
and time, and coordinated reset clears traces. These focused checks do not
claim a new complete movement, NPC, two-level gameplay or audio regression.

The final adapter SHA-256 is
`ca948fbe41cfc8913c2f1f1f57901580f9138231ab0617888e1312eec6302993`.
The PC SHA-256 remains
`24d453e53737c74d3c747e323cea5901c101b223f12592ab80a9a69b4c1cbe1a`.

The effect preserves the existing stylized distance/contour abstraction. Separate
colliders receive independent contacts, with no occlusion or room propagation
graph. It does not apply a blindness/sacrifice state. This component stops here
for user review; further sensory features have not been stacked onto it.
# M16 physics-contact source — 2026-10-05

The current F5 scene is `combat_pc/contact_noise_review.tscn`. Its numbered
fixtures apply one initial impulse to the existing rigid prop implementation;
all subsequent flight, rotation, momentum transfer and contacts come from Godot.
An independent child observes the actual contact data and feeds the same local
bus and surface-pulse component as the PC. The original PC, prop, Health, Defeat,
NoiseRelay and SurfacePulse scripts remain unchanged.

The final continuous native clip is18.247 seconds at1280×720, with338 captured
frames over18.226 seconds. Actual intervals are preserved; there are no cuts,
speed-up or generated intermediate frames. Encoding adds one duplicate final
frame and a20ms hold. Capture cadence is not a gameplay frame-rate claim. This
sound-event visualization clip is silent; audio playback is a separate feature.

The native sequence shows floor drop/bounces, wall throw, two physical props,
source disconnection with continuing physical motion, then reconnection and a
repeat. The first floor contact reports528.6px/s closing speed at(302.07,270).
The wall contact reports456.2px/s at(612,214.56). The prop-pair contact reports
102.6px/s at(449.12,242.41). Recorded floor origins lie exactly on y270 and wall
origins on x612. Every admitted impact in the main clip produces one local bus
event and one surface pulse; reciprocal shape-pair reports never duplicate in
the same physics step.

The runs have5 floor-test,6 wall-test and8 prop-test admitted impacts. The muted
repeat has no events over40 sampled frames while bodies move. The reconnected
prop repeat has the same eight contact coordinates/strengths as the first run.
At the end both bodies are asleep,4.36 seconds have passed since the last impact,
and no pulse remains. This does not claim identical bounce trajectories across
different physics rates; the focused suite explicitly records the small60/120Hz
solver differences while requiring the same admission/lifecycle guarantees.

Separate native checks paused an airborne prop, then held D+J for500ms. Before
and after viewport PNGs were byte-identical. R cleared the old bodies and counts.
The existing PC also walked up to the settled prop and pressed J: its original
launch impulse visibly sent the body right/up, followed by a fresh real floor
contact. The new HUD layer keeps underside traces from crossing control text.
The app is left unpaused, sources enabled, labelled guides on, floor case selected,
no spawned props, counts0 and PC at(92,270).

Independent physical acceptance passes255 checks across47 scenarios at each
60/120Hz. A separate direct-state oracle verifies same-frame contact provenance.
Twenty-one protected files exactly match v19. Attached/absent/removal comparisons
have zero position/velocity/rotation/spin error. A clean source extraction boots
the current review, four earlier component reviews, full PC course and both
preserved game scenes. An isolated no-autoload project using only13 observer,
view, bus and resource files plus a plain-body smoke host imports and receives
real contacts; disabling the observer preserves motion, then a fresh reconnected
impact arrives normally.

The first portable import encountered a Godot engine thread-notification crash
while importing a font. A fresh extraction, without the simultaneous viewport
capture, imported cleanly and passed all scene boots. No source change or cache
reuse was used to obtain that retry. Both logs are retained in the evidence.

Contact observer SHA-256:
`d6a69d4f47ed3db0987b62394479182c9a5852a7cd3c9353fbfdf9b158a9c012`.
Native review SHA-256:
`40b940e7a63822358ccc606223ff4b2b7afbccbb3fc24771755ac347cdacf76e`.

Limits remain explicit: loudness is an authored closing-speed mapping, contact
reporting has a finite capacity, one concave shape shares an episode across its
faces, and first-step reset correctness requires the documented host physics
boundary. Continuous scrape/roll sound, break-event integration and enemy
footsteps remain separate next pieces. This checkpoint stops for review.
# M17 NPC footstep source — 2026-10-05

The current F5 scene is `combat_pc/npc_footstep_review.tscn`. It contains the
preserved PC at rest and one wireframe NPC using the existing NPC test motor.
A small bridge brackets real motion for the optional CharacterFootsteps child;
the source does not control movement or AI. The passive gait view remains
animated when the sound child is muted or removed.

The final continuous native clip is 20.706 seconds at 1280×720. It contains 311
captured frames over 20.685 seconds, preserving actual capture intervals without
cuts, speed-up or generated intermediate frames. Encoding adds one duplicate
final frame and a 20 ms final hold. This capture cadence is not a gameplay
frame-rate claim. The sound-event visualization clip is silent; audio playback
remains separate.

The sequence shows start/stop/reversal, a hop with no airborne footsteps and one
separate landing, grounded slope traversal, quiet passive riding, walking on the
moving floor, source disconnection while the NPC keeps moving, then reconnect
and stop. Every accepted source event reaches the local bus and surface view
once. Flat origins lie on y=270, slope origins match the actual polygon surface,
and moving-support origins lie on its current y=214 top.

The main recording contains nine events in the flat case, including one landing;
seven on the slope; and nine on the moving support. Its nine airborne samples
contain no new walking step. During 26 initial passive-riding samples the NPC
travels 56.88 world pixels while the noise count stays zero. During 23 muted
samples it travels 67.42 pixels while the count stays four. Walking and the
passive leg animation continue; reconnection admits fresh events. At the end
the NPC is idle on its still-moving support and every pulse has expired.

A separate native check froze an actual airborne hop with zero steps/landings.
An attempted jump while paused left byte-identical before/after viewport PNGs.
Resuming that same flight produced exactly one landing at (280,270), with no
walking-step burst. The final reset leaves the scene unpaused, source enabled,
labelled dim guides on, flat case selected, NPC idle and all counts zero.

The late-air pause regression caught a real source defect before delivery:
clearing flight history during pause lost an otherwise qualified touchdown.
`suspend_motion()` now fences tokens while retaining the frozen flight's first
position/world anchor. The focused suite reproduces the former failure and
verifies both SceneTree pause and motor hit-pause. Teleport/reset/mute still
retire history; unannounced frame gaps do not invent catch-up steps.

Final physical acceptance passes 211 checks across 29 scenarios at each 60/120
Hz, plus 18 paired/source checks. Forty-eight protected v20 files remain byte
identical; original/composed motor position and velocity error is zero. A clean
final archive imports and boots this review, five earlier component reviews,
the full PC course and both preserved game scenes. A separate no-autoload
project using 23 source/mover/view/bus/resource files proves real walking,
quiet idle, muted motion, re-enabled steps, a real landing and removal while
the NPC continues moving. These are focused checks, not a new full-game or AI
acceptance claim.

Final component SHA-256:
`1f2e506e43bc50668d63d26360185e41717591e4f08a4fd914fd9bc741def39e`.
Native review SHA-256:
`edfff1a5cf62b96ff39d8ffd14bfd63f5e207bd837a8767b836c5fe0b5087e27`.

Origins are current queried support points, not skeletal foot plants. Actor
transforms must remain upright and unscaled; dynamically rotating/skewing
supports and TileMap-owned floor bodies remain outside this component.
Ambiguous floor/wall platform ownership is suppressed until support is clear.
Immediate Object.free() inside callbacks is unverified; queue_free and detach
are covered. Continuous scraping/rolling and break-event integration remain
separate work. This one source component stops for user review.


## M18: ground response comparison, 2026-10-05

The 18-second final native clip applies the same explicitly labelled input sequence to the prior and candidate profiles. Both physically run, stop, reverse, jump, roll and attack. The candidate reaches its existing speed cap sooner and retires turn/start poses promptly. The final capture waits for the completed draw before reading the viewport and state; source hashes match the packaged implementation. It contains no speed-up, interpolated frames or cuts. Cloud audio is silent.

Separate manual native input covered both directions, repeated short reversals, slope ascent/reversal, translating support, jump/shield, pause and repeated profile/course/reset selection. Pause rejected reset/profile changes. The old profile is preserved for direct comparison.

Physical and connected visual checks passed at 60/120 Hz. Clean source extraction imported and booted ten scenes, including the new review, six preceding component reviews, the full PC course and both preserved game levels. A standalone host copied 38 required runtime files and no autoloads: it reached cap, stopped, faced/reran left and removed both optional profiles back to baseline. All 214 runtime files in the clean full extraction match the final source. The final archive may additionally contain later documentation/test reports; no later runtime edits were made.

The ordinary ground profile changes no run cap or air constants and only applies outside crouch, weapon, shield and other action owners. The user is reviewing the response preference; new air/agility/sensory mechanics are not included in this checkpoint.


## M19: ordinary air steering, 2026-10-06

The final native clip uses the same explicit input sequence for the previous air profile and candidate, both with the reviewed ground response. It shows mirrored airborne corrections, unchanged neutral drift, a held jump, a short jump and the existing air jump. The body follows admitted facing while the gold momentum arrow shows the finite reversal. The dim trajectory is actual travel, not a driven animation or sound pulse. The completed-draw capture has 354 source frames across 18.065 seconds; the 18.086-second encoded clip preserves native intervals with no speed-up, cuts or interpolated frames. It is silent.

Manual native checks covered both correction directions, slope jumping/landing, moving-floor departure, airborne pause/resume, rejected profile/reset while paused, and repeated profile/course/reset. The final native scene is unpaused on the flat candidate. All recorded loaded-script hashes match packaged files and every captured body/view facing agrees.

Clean extraction imports and boots eleven scenes, including both preserved levels, the full PC course and each recent independent review. All 218 runtime source files match the final implementation. A separate 40-file PC host with no autoloads physically starts an air jump, reaches the unchanged cap, turns before momentum reverses, reaches the opposite cap while airborne, then removes only the air option while keeping the reviewed ground option.

Fixed-rate tests establish the vertical-motion and owner-preservation claims. Native frames sample at varying render times and are not used to claim identical captured apex pixels. The response values are authored calibration because the relevant Dead Cells routine is absent. This one piece stops for review.


## M20: fresh-tap three-strike response, 2026-10-06

The final native before/after clip applies the same early-tap, rapid-tap and held-button trials to both resources, with an explicit public reset between labelled trials. Early input reaches only Slash/Backhand in the previous profile and reaches Slash/Backhand/Finisher in the candidate. Rapid input produces two complete cycles; a held button gives one strike in either profile. All 19 displayed contact events carry distinct actual strike identities. The original contact feedback, phase/pose system, hitpause and damage remain in use.

The completed-draw capture contains 329 source frames over18.320 seconds. Its18.341-second encoded video preserves native intervals, with no cuts, speed changes or generated interpolation. Camera zoom is a review-only1.5× view. The clip is silent. Native body/view facing agrees throughout.

Manual native checks cover repeated fresh taps, a1050ms hold producing one strike, target disconnection producing whiffs without fake hits, pause, refused reset/profile selection while paused, resume and repeated reset. The final game is unpaused on the responsive profile with contact enabled and an empty queue.

Clean source extraction imported and booted twelve scenes, preserving all previous component reviews, the PC course and both original game levels. Its221 runtime sources match the final project. A separate41-file PC host without autoloads exercised early three-strike input, held Fresh input producing one strike, and chain removal returning to the single-strike fallback while retaining approved ground/air resources.

Fixed-rate candidate, current-controller baseline and archived-controller comparisons are documented separately. The source archive protects337 of341 original code/resource/scene/helper files byte-for-byte; only controller integration, chain configuration schema, the provenance generator and a packaging exclusion changed. This one input-response piece stops for review.


## M21: detachable physical strike knockback, 2026-10-07

The native comparison applies the same three actual strikes with the receiver response off, then on, across labelled open-floor, right-wall and mirrored left-wall trials. Each trial explicitly resets the actors. All18 real contacts remain visible; only the nine enabled contacts apply motion. The target body stays still with the response off, travels38.39px across the three enabled open-floor hits, and stops against either wall with its whole collider outside terrain. Source and target remaining pause clocks match throughout the enabled recorded flow. The finisher uses the existing larger signed impulse.

The continuous18-second clip preserves544 completed native viewport frames and their measured intervals, about30frames/s, without cuts, speed changes or generated interpolation. Its camera is1.5x for inspection. The clip is silent. Manual native checks also cover a fresh strike off/on, mirrored response, repeated case/profile/reset selection, pause, refused attack/reset during pause, and resumed control. The final review is left unpaused with response enabled on open floor.

The original PC, contact adapter, existing targets, movement motor, health/defeat and sensory sources are byte-identical to the recovered v24. Focused real-physics acceptance passed at60/120Hz, including pause alignment, actual collision, unique strike identity, interrupted delivery and absent/disabled/unbound parity. No earlier full-suite rerun is claimed. A separate copied minimal host, with no autoloads, applies one real strike, settles, detaches the component, then accepts another contact without a new impulse. Clean full-source extraction imports and boots all13 preserved review/course/game scenes.

The reusable receiver assigns bounded velocity through the existing motor; it is not an additive mass simulation or an NPC health/AI implementation. Its scale/stun values are authored MOKSHA tuning because public Dead Cells response bodies and constants are absent. Moving carriers and arbitrary custom motor schedules are outside this checkpoint. This one piece stops for review.
