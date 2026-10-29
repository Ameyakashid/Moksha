# MOKSHA — Combat PC foundation

## Current review: detachable struck-target health

F5 opens `combat_pc/target_health_review.tscn`. **J** attacks, **A/D** chases, **R** refills and resets, **Esc** pauses. **Q** compares the same three ordinary attack taps with health off, then on. **1/2** select either mode; **F** mirrors the wall trial. Knockback stays on in both modes. The bar and numbers show actual health: the existing Slash, Backhand and Finisher take the target from **3 → 2 → 0.85 → 0**. Zero leaves the passive target available for further strikes; no death or AI policy is added.

The new [confirmed-strike health adapter](combat_pc/components/STRIKE_HEALTH_GUIDE.md) reuses the existing Health component unchanged. The existing contact adapter remains the hit authority; existing player, combo, knockback and movement code/resources are preserved. The optional child can be disabled or removed. Capacity3 and review presentation are authored MOKSHA choices, not recovered Dead Cells health rules.

[Focused verification](combat_pc/tests/target_health_report.md) covers both60/120Hz, lifecycle boundaries, replay rejection, identical movement with health absent/disabled/on, and the actual review scene. This checkpoint has headless functional verification; it has not been rendered or manually playtested in this executor.

## Previous review: detachable strike knockback

Open `combat_pc/knockback_review.tscn` and press F6. **1/2** compare physical response off/on with the same strikes, **J** attacks, **A/D** chases, **F** selects open floor/right wall/mirrored wall, **R** resets and **Esc** pauses. **Q** runs matching three-strike trials. The target flashes on genuine contacts in both modes; with the optional response enabled, its actual collider is pushed and stopped by terrain.

The new [Strike Knockback component](combat_pc/components/STRIKE_KNOCKBACK_GUIDE.md) sends the existing signed strike impulse to the existing passive movement motor. It copies the source's remaining contact pause and adds no player/combo rewrite, new hitbox, AI or health policy. The target's motion, gravity, stun and collisions remain owned by that motor. The recipient is an independently placeable scene, and the response child can be disabled or removed.

The reviewed ground, air and three-strike input resources are preserved. Numerical target-response scaling is original MOKSHA tuning. [Physical verification](combat_pc/tests/knockback_response_report.md) covers both60/120Hz; native review is recorded separately. This one component stops for review.

## Previous review: fresh-tap combo response

Open `combat_pc/combo_response_review.tscn` and press F6. Tap **J** through the existing Slash → Backhand → Finisher. **1/2** compare the previous chain and responsive candidate; **Q** runs the same early-tap, rapid-tap and held-button trials. Each trial resets the same PC and passive contact instrument. **E** toggles target contact, **A/D** moves, **R** resets and **Esc** pauses.

The candidate remembers one early follow-up and one fresh restart near the finisher's recovery end. All strike timings, poses, power and legal commitment points remain unchanged. Holding J in Fresh mode still gives one strike, and rapid taps cannot build an invisible backlog. The reviewed ground and air movement profile is used in both comparisons.

The [combo response guide](combat_pc/COMBO_RESPONSE.md) explains the independent resource, one-slot queue, source gaps and verification. This is original MOKSHA admission tuning where the public Dead Cells scheduler is missing. This one piece stops for review.

## Previous review: air steering

Open `combat_pc/air_response_review.tscn` and press F6. **1/2** compare previous and quicker air steering, both with the reviewed ground profile. **Q** supplies the same ordinary input sequence to both. Use **A/D** to steer and **Space** to jump/air jump; **F** changes the terrain fixture, **R** resets and **Esc** pauses.

This candidate changes one freely steerable airborne acceleration from 1450 to 2300 px/s². The speed cap, neutral drift and full vertical jump calculation stay unchanged. It retains momentum while correcting direction sooner. Special action owners and weapon/shield motion keep their previous response until their ownership ends.

The gold arrow shows actual momentum; the dim line records actual airborne travel. These are review guides. The new optional resource can be removed while retaining the approved ground response. The [air response guide](combat_pc/AIR_RESPONSE.md) explains reuse, source limits and verification. These values are authored MOKSHA calibration because the relevant public Dead Cells bodies are missing. This one component stops for review.

## Previous review: ground responsiveness

Open `combat_pc/ground_response_review.tscn` and press F6. **1** selects the preserved previous profile; **2** selects the candidate. **Q** runs the same input sequence through both, using real physics. **A/D** gives free control; **Space, Shift, J and K** retain jump, roll, attack and shield. **F** changes between flat ground, slope and moving support; **R** resets and **Esc** pauses.

The candidate reaches the same 218 px/s cap sooner, has a shorter stop skid, and reverses sooner. Its optional view exits start/turn poses faster and prevents stale turn poses from interrupting a new start or stop. At 120 Hz: full speed 75 → 50 ms, stop 125 → 83 ms / 11.94 → 7.91 px, opposite full speed 133 → 83 ms. These are measured MOKSHA results, not recovered Dead Cells constants.

Only ordinary standing ground locomotion uses the optional response resource. Air, crouch, roll, shield and weapon-owned response retain their prior rates. The original profile remains available; the reusable actor scene and older review scenes retain their default profile. Assign `resources/ground_response_agile.tres` to the PC's Profile and `resources/ground_presentation_agile.tres` to its Visual's Ground Presentation to opt in elsewhere. Both can be removed independently.

See [ground response guide](combat_pc/GROUND_RESPONSE.md) and [physical results](combat_pc/tests/ground_response_report.md). This one pass stops for review.

Open `combat_pc/npc_footstep_review.tscn` and press **F6** for the preceding NPC source review.

**Previous review: one small NPC-footstep source.**

Press **Q** to start/stop the wireframe NPC, **A/D** to choose direction, and **Space** for a real hop. Footsteps follow actual grounded travel; a landing has its own event. **1** selects flat ground, **2** a slope, and **3** a moving support. Standing on the moving support stays quiet; Q then starts walking relative to it. **E** disconnects/reconnects the source, **G** toggles labelled guides, **R** resets the selected case, and **Esc** pauses.

The optional [Character Footsteps](combat_pc/components/CHARACTER_FOOTSTEPS_GUIDE.md) child sends current queried floor-contact origins through the same local bus and surface view. A small host bridge brackets the existing NPC test motor's actual motion; movement itself is unchanged. Its passive wireframe gait is an inspection cue, not the authority for foot placement. This review adds no NPC combat or AI overhaul. The existing PC and physics-contact pieces remain intact.

Continuous scraping/rolling and break-event integration remain separate work. Supported moving-floor behavior and the conservative limits for ambiguous or rotating supports are documented in the component guide. This one component stops here for review.

Open `combat_pc/contact_noise_review.tscn` and press **F6** for the preceding physics-contact review:

**Previous review: one small physics-contact noise source.**

Press **1** for a dropped prop and repeated bounces, **2** for a wall throw, or **3** for one prop hitting another. Each test applies one initial impulse; Godot handles the resulting collisions. Real contact points start the existing surface pulses, with loudness derived from closing speed. **Q** repeats the selected case. **E** disconnects/reconnects the optional impact observers while physical motion continues; **G** toggles labelled dim collision guides; **R** clears; **Esc** pauses. The same PC can move with **A/D** and hit props with **J**.

The [Physics Contact Noise](combat_pc/components/PHYSICS_CONTACT_NOISE_GUIDE.md) child works with an ordinary RigidBody2D and an explicit local bus. It merges manifold points, prevents both instrumented props from reporting the same shared contact twice, admits energetic repeated bounces, and stays quiet during rest. Its observer leaves physical motion unchanged. The review retains the established PC noise route and surface adapter.

This earlier checkpoint covers discrete impacts. The NPC-footstep source is now an independent review piece; continuous sliding/scraping/rolling sound and break-event integration remain separate work. No NPC AI or new level is included.

Open `combat_pc/surface_review.tscn` and press **F6** for the preceding surface-pulse review:

**Previous review: one small surface-pulse view.**

Press **J once** and watch the white pulse reach the nearby floor, travel along its edges and reach the raised block. Wait and all terrain traces fade. **A/D** moves, **Space** jumps, and those actual footstep/landing noises make their own pulses. **E** disconnects/reconnects only the view while movement and the noise bus continue. **G** toggles labelled collision guides (off by default), **R** resets, and **Esc** pauses. The optional [Surface Pulse](combat_pc/components/SURFACE_PULSE.md) reuses the preserved contour solver through explicit local-bus wiring.

This is a stylized distance-and-contour visualization. It has no acoustic occlusion or connected room graph. This review does not apply a sight-sacrifice state or play audio. Its PC, Health, DefeatResponse and NoiseRelay remain unchanged from v18. The component stops here for review.

Open `combat_pc/noise_review.tscn` and press **F6** for the preceding sound-origin review:

**Previous review: one small sound-origin relay.**

Move with **A/D**, jump with **Space**, swing with **J** or roll with **Shift**. Brief white markers appear where the PC's existing noise events occurred. **E** disconnects/reconnects the optional route: controls keep working while new world events stop/resume. **R** resets this review; **Esc** pauses. The [Noise Relay](combat_pc/components/NOISE_RELAY.md) connects to the existing bus without requiring an autoload.

This earlier piece establishes noise-event delivery; the current surface adapter is independently removable. The blind-state integration and audio design remain separate review steps. Health and defeat are preserved as independent components.

Open `combat_pc/defeat_review.tscn` and pressF6 for the preceding zero-health response:

**Previous review: one small zero-health response.**

Press **Q** for a lethal contact:10 health reaches0, the wireframe collapses, and movement/combat inputs stay locked. **R** explicitly resets the PC. **F** requests another incoming hit; **A/D, Space, J and K** let you try movement, jump, attack and shield before/after defeat. **Esc** pauses. The new [Defeat Response](combat_pc/components/DEFEAT_RESPONSE.md) is a separate optional child of the same PC; it leaves the existing physical motor in charge of settling.

The previous health-only review remains `combat_pc/health_review.tscn` (open it and pressF6). Its four comparisons are described below.

**Previous review: one small health component.**

Press **Q** to replay direct hit, held guard, timed parry and roll against the same physical contact rig. From40 health they leave30,37.5,40 and40 respectively. **1–4** replay each case; **A/D, F, K and Shift** provide free movement, a requested incoming hit, shield and roll. **R** resets, **Esc** pauses. Each guided comparison resets the same PC to full health so the outcomes can be compared directly.

The new [Health component](combat_pc/components/HEALTH_COMPONENT.md) is detachable. It accounts for resolved damage and emits depletion once on crossing zero. The optional defeat response is now a separate review piece. Healing remains future work. Each checkpoint remains independently runnable.

For the established movement/combat course, open `combat_pc/lab.tscn` and press **F6**. Its controls and coverage follow below.

**Established foundation: one reusable wireframe PC and a connected movement course.**
The current checkpoint couples fast run/brake/reversal, normal and air jump,
landing, crouch clearance and swept ledge traversal with horizontal roll,
an optional three-step light chain, explicit held-repeat and charged-thrust examples,
and optional perception-gated attack-entry facing assistance,
hurt recoil, input-aware hitpause, contextual platform drop/dive,
reusable ladder/vine traversal, a gated wall run/kick, optional high-fall recovery and directional shield/parry. The lab has exactly
one PC and passive contact/pulse instruments. Ordinary landings preserve horizontal
momentum; confirmed floor following keeps uphill/downhill control consistent through
continuous crests and valleys. Additional Dead Cells movement
surfaces remain explicitly pending in combat_pc/COVERAGE.md.

Import `project.godot` in Godot4.6.3. F5 opens the current target-health review; F6 runs whichever scene is open.

- **A/D or arrows:** move; permitted facing follows new input while momentum brakes
- **Space/C:** jump, then one air jump; release for a shorter jump. At an eligible wall contact, kick outward
- **W/S near a climbable:** climb/hold; horizontal input releases; Space gives a supported grip jump
- **S/Down elsewhere:** crouch on ground; release a ledge
- **Toward the ledge, W/Up or fresh jump:** pull up from a hang; neutral holds; away releases
- **Shift:** horizontal roll, with a separate timed invulnerability interval
- **J:** in the default Fresh Chain mode, separate presses request Slash → Backhand → Finisher. Holding produces one swing; a queued follow-up respects recovery, movement, shield and interruption rules
- **Y:** cycle Fresh Chain, Held Repeat and Held Charge. Repeat continues while the admitted hold remains valid. Charge performs a starter slash, then loads while the same button remains held and commits one thrust; release during loading cancels it. After a charged thrust or interruption, release and press again
- **T:** inspect the chain against a passive contact target
- **I:** toggle optional entry-facing assistance (default off); **U:** toggle the registered target's perception/visibility; **L:** start beside it facing away. Manual movement takes priority. Only the first fresh attack is eligible
- **K:** fresh raise/parry, then held guard; facing and actual approach matter. A held guard absorbs 75% of an eligible hit; timed parry stops it and can counter or physically return a carrier
- **V:** cycle three passive shield inspection stations; **F:** request one telegraphed attack
- **S+Space:** grounded one-way drop; in air, a fresh chord starts a downward dive
- **R:** reset the current inspection start; **1–9,0:** select an explicit inspection start
- **9:** wall run and higher opposite landing; **0:** mirrored wall approach and ledge handoff
- **G:** toggle the wall ability in this lab; the reusable actor starts with that ability locked
- **B/N:** compare high and low falls; **H:** toggle optional hard-landing recovery
- **M:** inspect continuous slopes, braking, reversal and jump departure
- **Tab:** optional state/input details; **Esc:** pause
- **P:** save a viewport screenshot; **O:** record10seconds of actual viewport frames and trace (target60Hz capture)

Generated test traces and code-drawn pose previews are in the companion verification archives;
[trace instructions](combat_pc/tests/M11_ARCHIVE.md) explain extraction and reproduction.

The actor is `combat_pc/player.tscn`. Its original wireframe view, tunable motion
resources, collision motor and action/weapon permission interfaces remain separate.
`ShieldContactAdapter` can be replaced independently: it requires explicit receiver acceptance for a counter and changes the real carrier velocity for reflection. The stationary shield fixtures and rigid-prop bridge are documented in [shield contacts](combat_pc/components/SHIELD_CONTACT_GUIDE.md).
Place it above collision-layer1 terrain. `combat_pc/components/climbable.tscn` is
an independent bottom-anchored ladder/vine sensor on layer16; use its width/height
properties and keep real top/bottom terrain separate. The sample geometry and motion fixtures
are editor-placeable scenes. Wall traversal initially accepts dedicated upright solid rectangles;
one-way sides and mixed/rotated wall geometry are refused. See [motor contract](combat_pc/MOTOR_CONTRACT.md),
[reference boundaries](combat_pc/REFERENCE_CONTRACT.md), and
[movement verification](combat_pc/verification.md), [combat acceptance](combat_pc/combat_verification.md),
[drop/dive acceptance](combat_pc/traversal_verification.md),
[climb acceptance](combat_pc/climb_verification.md),
[wall acceptance](combat_pc/wall_verification.md),
[hard-landing acceptance](combat_pc/hard_landing_verification.md),
[slope acceptance](combat_pc/soft_slope_verification.md),
[shield acceptance](combat_pc/shield_verification.md),
[chain acceptance](combat_pc/combo_verification.md),
[held-input acceptance](combat_pc/held_verification.md),
[entry-facing acceptance](combat_pc/entry_assist_verification.md),
[native checks](combat_pc/NATIVE_CHECKPOINT.md), and [coverage ledger](combat_pc/COVERAGE.md).

For a minimal reuse example, open `combat_pc/minimal_host.tscn` and run that scene.
It places one PC beside ordinary scriptless Godot terrain. Copy `player.gd`,
`player.tscn`, `components/`, `resources/` and the runtime files in `visuals/`
under `combat_pc/` in another project; this actor needs no old-game autoload,
lab controller, source-art sheet or fixture script. Its host grants the wall
ability and optional hard-landing rule explicitly. Keep or replace its passive Visual child independently.

The optional `melee_chain` property accepts independent step/chain resources. The lab assigns `combat_pc/resources/light_chain.tres`; the reusable scene retains the single-swing fallback when this field is null. Runtime progress and input requests belong to the actor, not the shared resources. See [melee contacts and reuse](combat_pc/components/MELEE_CONTACT_GUIDE.md).

The separate optional `melee_input_profile` selects fresh-only, held-repeat or held-charge semantics. Null preserves fresh-only behavior. `held_repeat.tres` uses the selected ordinary chain; `held_charge.tres` embeds independent starter/thrust step resources and deliberately owns its own two-strike branch. Shared Resources contain configuration only. The example's .06-second recovery branch and .45-second automatic charge are authored MOKSHA choices; the Dead Cells sources do not recover those trigger rules. See [held-input evidence and limits](combat_pc/reference/M10_CHARGE_INPUT_ADDENDUM.md).

The independent [entry-facing host](combat_pc/components/ATTACK_ENTRY_FACING_HOST.md) accepts one explicitly registered opponent with current eligibility, perception and visibility. It defaults off and refuses unknown awareness, hidden/freed candidates, obstruction and manual direction. It may turn only a genuinely new fresh attack; retained chain steps, held repeats and charged follow-ups never retarget. It grants no damage, range, air-motion or tracking privilege. These sampling and eligibility rules are authored MOKSHA policy because the original chooser and consumers are missing.

The actual Dead Cells source audit guides action interfaces and feature intent.
Most numerical motor/animation consumers are absent in that public decompilation.
Every numerical starting value here is labeled MOKSHA tuning; no exact Dead Cells
port or frame identity is claimed. The reference map and primary visual observations
are included under `combat_pc/reference/`; no commercial source/assets are included.

## Preserved two-level demo

The earlier city/arcology game is preserved below and can be opened independently.
Its original controls and art belong to that demo, not the current wireframe scene.
The older one-PC/one-NPC lab also remains at `movement/movement_lab.tscn` as a
historical prototype; it is no longer the main launch or movement target.

Two connected, playable Godot levels: an unpowered city prologue and the first
vertical arcology interior. At its sensory station, trade sight for a configurable
25% speed increase. The world turns black and actual noises draw travelling white
traces along its collision surfaces.

## Run

Open `main.tscn` in Godot 4.6.3 and press **F6** to start in the city. Reach the arcology door and press **E**. The first interior starts sighted;
walk to the station and press E to trade sight and open the ascent route. Climb to
the upper door and press E to finish this two-level slice. Guards can be fought,
bypassed, or hit with scenery.

For direct interior testing, open `arcology_run.tscn` and press **F6**.

- **A/D or arrows:** move and turn immediately
- **Space/W/Up:** jump, press again for the second jump; release for a short hop
- **Shift/K:** roll with a short invulnerability window
- **J/X/left click:** attack; hold for repeated combo strikes
- **Q/C:** tap the weapon; hold to keep making navigation sounds
- **E/Enter:** use a nearby station or door
- **R:** retry the current room, resetting enemies, props and the sight trade
- **N:** start a new run from the city
- **Esc:** pause/resume; **M:** mute; **F12:** save a gameplay screenshot

Keep tapping in the dark, listen/read nearby guard steps, and strike crates,
drums or canisters into the room. Actual impacts and breaks create distinct
noise origins. Silence erases the world again. A small permanent body-position
cue represents proprioception; it reveals no terrain. It now shows the held
weapon, jump and roll posture. A brief **DRAW** arrow marks a guard's audible
windup direction; **STRIKE** marks the actual swing. Both remain at their sound
origin and fade. Tap, footstep and guard-warning sounds are spatially positioned.
Successful contact has brief white **HIT**, **HURT**, **BREAK** or **DOWN** feedback
from the actual sound event. Swings that miss cannot produce a hit confirmation.
Nearby overlapping labels favor the most important event while every surface
wave continues independently. These marks fade and never track hidden actors.

For the first ascent, hold the first jump and press again near its peak. The
second jump now matches the first jump's impulse, giving this introductory
96-pixel rise more clearance. The instruction remains until an actual landing.
The operative also has six separate attack drawings, with the baton following
each pose's measured hand. Body frames follow the existing startup/contact/
recovery timings. Roll and landing still adapt the original starter poses.

## The sight reward

The supplied MOKSHA notes specify overlapping sound pulses, improved sonar after
sight loss, and stronger remaining senses. They explicitly leave the exact power
gains undecided. This build uses the user's later fallback instruction: **+25%
movement speed**, including the roll's travel speed. The station also restores
health for the sensory tutorial. It does not implement strength/agility branches,
other sacrificed senses, further floors, final lore or any destructive save rule.

Change `Sight Speed Multiplier` on the main scene to tune the bonus. Player
instances use a multiplier; the shared base movement resource stays unchanged.

## Reusable pieces

- `scenes/levels/`: placed city and arcology scenes; content is editable in Godot
- `scenes/actors/`: self-contained player and guard bodies/controllers/art
- `scenes/props/`: real rigid-body crate, drum and canister with contact-based noise,
  impact damage, angular motion, bounce and physical chain reactions
- `scenes/environment/`: editable platforms, facade/shaft dressing and signs
- `scenes/interactables/`: station, door and opening barrier
- `assets/`: independent original art, exact atlas regions and SpriteFrames
- `assets/characters/attack/`: six transparent attack body frames; the weapon
  remains separate. `resources/graphics/operative_attack.tres` connects drawings,
  foot pivot and grips through an optional, replaceable graphics profile
- `resources/tuning/`: shared, read-only movement/combat/prop presets; duplicate or
  use Make Unique for a per-instance edit
- `scripts/sensory/` and `resources/sensory/`: optional NoiseBus event service,
  contour geometry, renderer and tunable propagation profiles
- `main.gd`: room loading, proximity interactions, camera, state and presentation
- `hud.gd`, `scripts/systems/`: separate screen information, effects and sound

Drag a prefab into a level, place it, and edit its exposed properties. The level
root and Actors container should retain identity transforms. Player belongs at
Actors/Player, enemies under Actors/Enemies and props under Actors/Props. See
`docs/BUILDING_LEVELS.md` for the complete scene contract.

## How the white pulses work

Each valid noise records its real world position, kind, strength and source. Nearby
collision contours receive delayed arrivals, then the white highlight travels
around top edges, sides and undersides and fades. Moving props keep their current
transform. Simultaneous noises overlap; inactive rooms cannot send ghost pulses.

This is a stylized distance-plus-contour model, not a physical acoustic simulator:
it does not solve wall absorption, diffraction or reflections. It intentionally
maps nearby surfaces through sound without exposing the full level permanently.
Details and tuning are in `scripts/sensory/README.md`.

## Verification and current limits

Run `bash tests/run_all.sh`. Focused tests cover real movement, buffered/cancelled
attacks, wall obstruction, rigid-body contact origins and damage, all route jumps,
scene reuse, transitions, sacrifice, resets and sensory propagation. Native Godot
checks cover the rendered city and blind interior, controls and physical scenery.
See `tests/README.md` and `docs/VERIFICATION.md` for exact scope and results.

Artwork remains a starter kit: the base has 12 source drawings/11 materially
distinct silhouettes per actor, plus six new operative attack drawings. The same
short body sequence supports all three baton strike patterns; these are not
three bespoke full-body combo cycles. The weapon stays a separate asset. Roll,
locomotion cleanup and modular surface joins remain future art work.
The blind view intentionally uses simple white geometry. Synthesized sound is
included; this cloud desktop uses a dummy audio output, so audible playback could
not be assessed here. No save/progression infrastructure or additional floors are
included.

The earlier EMBERWAKE playable foundation and MOKSHA standalone asset checkpoint
are preserved as independent projects. This package is a new playable deliverable.
Reference/provenance notes: `docs/REFERENCE_NOTES.md`. Duplicate source-art sheets remain in the separate base-asset checkpoint; the runtime art is included here.

For art inspection, open `tests/attack_showroom.tscn` and press F6. This developer
study shows fixed contact phases and a live mirrored combo at game scale; it is
not an additional playable level. F12 captures its view into `delivery/`.
