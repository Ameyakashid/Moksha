# MOKSHA: current production module map

**Snapshot: 20 October 2026; Field Cache presentation-and-contour extraction**  
**Scope:** the default First Ascent mission, including the shared Warden, actor–cargo interaction and common world boundary. Source paths below are relative to the project root.

## At a glance

The player and every authored NPC now use the same actor movement, action, defense and damage controller. Production actors share cargo obstruction, grounded pressure and support transport; equipped melee actors reach cargo through the same canonical contact protocol. The world boundary now uses a shared observation → controller → Health → Defeat path, with an explicit retirement capability for cargo.

This establishes shared rules with visible configuration differences. It does not imply identical abilities, identical freely rotating trajectories, a complete rigid-body character simulation, physical acoustics, or fully separated visual assets. **Background/skyline/windows/pipes/rain compose one reusable backdrop. Every production `data.platforms` rectangle now instantiates `simulation/world/static_platform.tscn`, with physical support and optional `demo/views/platform_view.tscn`. Every floor rectangle now composes `simulation/world/floor_segment.tscn`, reusing static support with a separate floor view. All 14 decorative world signs, all eight onward/LIFT markers, both Exchange stations, all eight relay markers and all five Field Caches are now placeable assets. Cache/relay/station/onward gameplay policy remains mission-owned; HUD presentation remains to extract.**

The sealed boundary checkpoint passed all 14 aggregate gate groups, including four complete input-driven routes, with its own frozen-source, preservation and clean-import evidence. Those counts belong to that archived checkpoint. The preceding backdrop checkpoint passed its separate 17-group aggregate on 602 frozen source files: the existing 72-stage foundation, both focused rates, stock/held/Health, historical and four full routes. Corrected native evidence adds 98 exact pixel comparisons and six rendered-isolation checks. Its historical index is `simulation/evidence/room_backdrop_acceptance.json`; its detailed reports are in `simulation/evidence/room_backdrop_gates/`.

## 1. What the default mission actually instantiates

`project.godot:15` starts `demo/mission.tscn`. `demo/mission.gd` composes the room, actors and services from `demo/mission_data.gd` and the Freight Lock / Relay Works area modules. The only autoload is `NoiseBus` (`project.godot:18–20`). One sector is active at a time; these totals describe authored placements across the campaign.

| Sector | Sentinel | Listener | Sentry | Warden | Ordinary cargo |
|---|---:|---:|---:|---:|---:|
| Rainline District | 5 | 1 | 0 | 0 | 5 |
| Quarantine Intake | 5 | 0 | 3 | 0 | 4 |
| The Exchange | 1 | 4 | 1 | 0 | 5 |
| The Freight Lock | 1 | 1 | 1 | 0 | 2 |
| The Cistern | 3 | 2 | 2 | 0 | 5 |
| Relay Works | 4 | 5 | 4 | 0 | 10 |
| The Lift Warden | 0 | 0 | 2 | 1 | 3 |
| Above the Rain | 0 | 0 | 0 | 0 | 0 |
| **Total** | **19** | **13** | **13** | **1** | **34** |

Additional authored composition:

- **46 NPC placements**, all selected into shared scenes; one player per loaded sector.
- **35 initial cargo placements:** 34 ordinary crates plus one designated freight crate. Freight replacement creates a new lifetime, so this is not a lifetime-spawn limit.
- **4 moving lifts, 10 climbable sensors, 4 physical shutters:** three relay shutters and one freight shutter.
- **8 relay points, 5 caches, 2 sight-trade stations and 8 onward/lift markers.**
- **One boundary hazard per loaded room**, including the ending room; eight room compositions in total.

Inventory anchors: `demo/mission_data.gd:6–46`, `demo/areas/freight_lock.gd:4–12`, `demo/areas/relay_works.gd:5–22`. Factory anchors: `demo/mission.gd:159–185`; boundary composition: `demo/components/mission_room.gd:28–30`; backdrop composition: `:19–27`.

The factory retains an old generic-enemy fallback at `mission.gd:160`, but none of the current 46 specifications selects it. New archetypes should be added to the shared-factory coverage explicitly rather than relying on that fallback.

## 2. Actual runtime ownership

### Actor composition

The NPC scene chain is:

- `shared_actor.tscn` inherits `combat_pc/player.tscn`.
- `shared_sentinel.tscn` inherits SharedActor. Listener uses this same scene with `listener_archetype.tres`.
- `shared_sentry.tscn` and `shared_warden.tscn` inherit the shared sentinel composition.
- The sentinel facade extends `combat_pc/player.gd`; the sentry and Warden facades extend that facade.

The player also uses `combat_pc/player.tscn`, but its components are assembled by the mission. **Controller ownership is shared; scheduling and scene composition are not identical.** The mission calls the player's `physics_tick` directly (`demo/mission.gd:115–158,207–224`). NPCs use `ActorIntentDriver`, which owns one tick per physics frame and accepts input from `NPCInputSource` (`simulation/components/actor_intent_driver.gd:90–137`). Policy supplies intentions, not velocity or combat outcomes.

| Module | Production asset / source anchor | Responsibility and interface |
|---|---|---|
| Actor controller | `combat_pc/player.gd`; `combat_pc/player.tscn` | Movement sweeps, gravity, support, action clocks, attack snapshots, defense, recoil, damage admission and committed noise. Public composition interfaces include `physics_tick`, `receive_attack`, `reset_actor` and observation snapshots. |
| Shared NPC assembly | `simulation/actors/shared_actor.tscn:2–31` | Health, DefeatResponse, NoiseRelay, HearingSensor, PhysicalImpactReceiver, IntentDriver, IncomingStrikeReceiver, ContactConfig, ShieldCounterReceiver and BoundaryReceiver. |
| Player assembly | `demo/mission.gd:115–158` | Same controller; Health 60, DefeatResponse, semantic NoiseRelay, incoming melee, ContactConfig, cargo impact, boundary and projectile reception. It has no NPC HearingSensor or IntentDriver. |
| Input / abilities | `simulation/components/npc_input_source.gd`; `actor_intent_driver.gd`; `simulation/resources/actor_capabilities.gd` | Sanitized raw intentions, private ability configuration and single scheduler ownership. Human input and NPC decision policy remain replaceable providers. |
| Contact and material configuration | `simulation/components/actor_contact_config.gd:15–36`; `demo/resources/player_contact.tres`; `sentinel_contact.tres`; `actor_material.tres` | Private collision/query masks, groups, hurtbox and shared optional material response. No mission outcome authority. |
| Grounded rigid-body pressure | `simulation/resources/actor_material_profile.gd:6–39`; `combat_pc/player.gd:3458–3504,3580–3605` | A real side sweep may spend the per-tick force budget through `RigidBody2D.apply_impulse` at the actual contact point. Godot owns the subsequent rigid motion. |
| Support / transport | `combat_pc/player.gd:3548–3579,3610–3700` | Local contact anchor, rotation-aware committed carry, actual collision-solved displacement, walkable geometry and lifetime checks; ordinary gravity resumes on loss. |
| Melee contact | `combat_pc/components/contact_adapter.gd:106–205`; `simulation/components/incoming_strike_receiver.gd:167–225` | Canonical active sweep, obstruction ray, once-per-swing confirmation and current target permit. Incoming actor contact delegates to the common controller. |
| Shield counter | `combat_pc/components/shield_contact_adapter.gd`; `simulation/components/shield_counter_receiver.gd` | Genuine ray/one-use counter admission; target response still goes through `receive_attack`. |
| Health / defeat | `combat_pc/components/health_component.gd:84–118,135–183`; `defeat_response.gd:72–82` | Scalar Health consumes admitted damage receipts. DefeatResponse owns the defeated lease. Optional guarded debit fences the new boundary delivery without replacing ordinary nested receipt ordering. |
| Projectiles | `simulation/components/projectile_emitter.gd`; `shared_projectile.gd`; `projectile_receiver.gd` | Committed action and muzzle, real swept flight, owner-changing reflection and registered receiver. The carrier inherits `combat_pc/fixtures/guard_projectile.gd`, which is active production code despite its directory name. |
| Cargo | `scenes/props/crate.tscn`; `demo/components/mission_prop.gd:1–12`; `simulation/components/physical_cargo.gd` | Real rigid solver, canonical melee launch, charged impact qualification, charge transfer, noise and retirement. The mission applies collision mask 43. |
| World boundary | `simulation/components/boundary_hazard.tscn/gd`; `boundary_receiver.tscn/gd`; `simulation/resources/boundary_profile.gd` | Non-solid sampled geometric constraint, current one-use observation and configured actor-Health / cargo-retirement response. |
| World-scope lifecycle | `simulation/components/boundary_scope.gd`; `demo/mission.gd:1,48–49`; `demo/components/mission_room.gd:1` | Synchronous scope invalidation when production roots transform or leave their world. |
| Freight / shutters / lifts | `demo/components/freight_receiver.gd`, `freight_cradle.gd`, `relay_shutter.gd`, `mission_lift.gd` | Physical seating predicate, explicit replacement, actual door collision state and prescribed moving supports. |
| Noise, hearing, sonar, audio | `scripts/sensory/noise_bus.gd`; `combat_pc/components/noise_relay.gd`; `simulation/components/hearing_sensor.gd`, `hearing_query.gd`; `scripts/sensory/sonar_view.gd`; `scripts/systems/audio_director.gd` | Shared event provenance, separate decision hearing, player visualization and positional audio. |
| Static platforms | `simulation/world/static_platform.tscn/gd`; `demo/components/mission_room.gd:46–57` | Center-origin rectangle, layer 1/mask 0 and private shape. Mission supplies placement, size, original height <=18 one-way rule and theme paint; Godot and the shared actor controller determine support and passage. |
| Platform appearance | `demo/views/platform_view.tscn/gd`; `platform_appearance.gd` | Optional paint-only view; local dimensions and colors, no role/host lookup. Hiding/removing paint retains support and sonar geometry. |
| Floor segment | `simulation/world/floor_segment.tscn/gd`; `demo/views/floor_view.tscn/gd`; `floor_appearance.gd` | Center-origin Node2D composes existing StaticPlatform Support and optional floor View. Authored hatch reference preserves int phase; insertion order preserves backdrop/floor/platform/foreground. |
| Decorative signs | `simulation/world/world_sign.tscn/gd`; `demo/views/world_sign_view.gd` | Independent text/font paint, no collision or interaction. All 14 mission signs preserve authored placement and draw order. |
| Onward / Exchange / relay markers | `simulation/world/onward_marker.tscn`, `exchange_station.tscn`, `relay_marker.tscn`; separate views and appearance resources | Placeable presentation plus original enabled, nonblocking sonar contours. Host supplies onward open/ending and relay active state. Mission retains E eligibility, sight trade, relay activation/noise, shutters and completion. |
| Presentation / mission | Actor view scripts; `demo/components/mission_room.gd`; `mission_hud.gd`; `demo/mission.gd` | Backdrop, terrain, signs and the three marker kinds have separate assets. Cache drawing and HUD remain centralized; progression remains mission-owned. |

## 3. Shared laws and explicit differences

### Cargo contact now agrees across production actors

| Configuration | Player | All shared NPCs |
|---|---:|---:|
| Body layer | 2 | 32 |
| Body mask | 9: terrain + cargo | 9: terrain + cargo |
| Terrain / support queries | 9 | 9 |
| Incoming melee hurtbox layer | 64 | 4 |
| Outgoing melee targets | 12: opposing hurtboxes + cargo | 72: opposing hurtboxes + cargo |
| Melee and shield-counter obstruction | 9 | 9 |
| Material response | Private copy of `actor_material.tres` | Same material configuration |

Sources: `demo/resources/player_contact.tres:6–14`, `sentinel_contact.tres:6–13`, `simulation/components/actor_contact_config.gd:24–36`.

Faction target masks remain different intentionally. Cargo is included for both melee-equipped roles. Sentry has its melee ContactAdapter disabled because it carries the projectile weapon (`shared_sentry.tscn:20–21`); it still has the same physical support, pressure, incoming impact and boundary capabilities. AI may avoid an obstacle instead of choosing to push it. That decision does not change the physical response when the same valid input/contact occurs.

### Grounded pressure is an authored motor model

The shared material permits pressure only during a real ground-following side sweep, ordinary locomotion, idle weapon and voluntary walking/crouching into the surface. Its maximum impulse budget is **1400 × physics dt**, shared across all sub-sweeps in that actor tick. Effective mass, inertia, real contact offset and angular contact-point velocity constrain the impulse. A separating body faster than the voluntary command receives none. There is no direct rigid velocity, angular velocity, charge or transform assignment in this response (`actor_material_profile.gd:6–39`).

A private one-frame demand can preserve continued walking pressure after the collision has projected away the blocked velocity. It cannot itself move cargo; a new real sweep is required. Actor generations, material/body configuration, lifecycle, neutral/reversed input, air/hurt/attack and static obstruction retire it (`player.gd:3274–3292,3458–3504,3580–3605`).

This is sustained motor pressure, not a general momentum-conserving collision model for characters. Free rotation can select different contact offsets and torque. Existing one-second traces report PC/NPC cargo displacement of **118.553/119.593 px at 60 Hz** and **102.517/118.168 px at 120 Hz**. Separate equal-configuration nonrotating controls match within each rate. These prove the common path and force bounds without promising identical trajectories across roles, instances or rates. See `simulation/ACTOR_CARGO_CONTRACT.md` and `simulation/evidence/actor_cargo_acceptance.json`.

### Support includes rotation, with collision checks

The grounded and hurt-pause paths carry the actor using the committed transform of its observed local contact anchor. Actual solved displacement is recorded; requested carry is not substituted. Rotated-away geometry, removal, broken supports, excessive displacement and wall/ceiling blockage release support. Committed and pending Animatable motion are bounded separately. Existing ledge/wall/climb contracts remain distinct from this grounded-carry slice (`player.gd:3548–3579,3610–3700`).

### Cargo launch and damage are separate operations

A mission crate now implements `receive_strike`. The ContactAdapter chooses that canonical receiver before the legacy prop-launch fallback. Geometry capture covers body identity, world, lifecycle, transforms, shapes and PhysicsServer shape data; direction and launch strength belong to the current source permit. Confirmation callbacks cannot move or replace cargo and reuse the stale overlap. A successful launch retires that old sweep; another launch needs another valid swing/contact (`physical_cargo.gd:63–129`; `contact_adapter.gd:155–205`).

Cargo damage requires a **charged** body and real relative normal contact speed of at least **80**, then applies authored damage **3** through PhysicalImpactReceiver and Health. Ordinary pushing and uncharged falling do not create damage authority. Chain momentum is solver-owned; the explicit charge transfer adds charge without launching or synthesizing motion (`physical_cargo.gd:153–184,256–321`; `mission_prop.gd:4–8`; `resources/tuning/prop_tuning.gd:18–19`).

A qualified returning crate can damage its original launcher. Guard/parry/roll use the same configured controller rules. The fragile mission-crate policy can consume a crate after an accepted defense as well as a damaging hit; this is an explicit source policy, not an actor-role exemption.

### Abilities and encounter data still differ

- Player Health 60; sentinel Health 3, listener Health 2, sentry Health 2, Warden Health 16.
- NPC jump, roll, shield, drop-through, dive and climb permissions are explicitly disabled by `sentinel_capabilities.tres:5–10`. The underlying rules remain in the shared controller.
- Listener speed, sight cap and hearing-memory duration differ through `listener_archetype.tres`.
- Warden cut/sweep timing, reach and brace threshold are authored melee-step data. Bracing still admits Health damage; it suppresses ordinary recoil/interruption below the configured0.70 stun threshold. A genuine counter is configured at 0.78.
- Below half Health, Warden observes the current genuine Health receipt and requests its shared pending-recovery update; it does not own another action timer or damage implementation (`shared_warden.gd:28–61`; `warden_melee.tres:4–58`).

No active actor role-only bypass was found within the inspected and tested production contact, damage and boundary paths. In particular, pressure, canonical cargo launch and boundary admission contain no actor-kind exemption. Shared rules are intentionally qualified by these visible capabilities and source/target filters.

## 4. Common boundary and terminal outcomes

Every room places a non-solid boundary at **room y = 420** (`mission_room.gd:28–30`). The default witness is **body origin with zero offset** for all receivers. Actor origins are at their feet; cargo origins are at their centers. This is a consistent configured point rule, not whole-body containment or shape-overlap detection.

`BoundaryHazard` samples registered live receivers after ordinary physics, with priority 100. Its unsafe half-plane is local y>0; exactly on the line is safe. Initial outside occupancy and observed crossing are distinguished. A crossing requires consecutive eligible safe/outside samples with unchanged source geometry. This does not claim swept detection between every sample (`boundary_hazard.gd:34–36,77–131`).

The default response is lethal-current-Health; fixed nonnegative damage is also configurable. One outside episode reserves one attempt before callbacks. Remaining outside, replacing a receiver or refilling Health does not rearm the same lifetime; a genuine safe sample does. Actor reset starts a new generation. Disabled/missing receivers are explicitly ineligible.

For actors, the receiver calls `receive_attack` using its exact current one-use permit. Guard, parry, roll and committed bracing cannot exempt a body from this constraint. The response retains current velocity rather than inventing a launch. Health locally revalidates the sealed scalar receipt immediately before debit, so an earlier callback cannot reset/rebind the target and apply an old lethal amount to its new state (`boundary_receiver.gd:103–144`; `health_component.gd:84–118,135–183`; `player.gd:2919–2965`).

For cargo, `CARGO_RETIRE` invalidates pending contacts and charge, advances its epoch and marks it non-simulating before emitting the terminal destroyed fact. Nested launch/break or a held contact cannot revive that source (`physical_cargo.gd:324–344`). Designated freight uses the same mission-prop receiver; the replacement service remains available through its existing rules (`freight_cradle.gd:85–99`).

The player now observes the current DefeatResponse lease and zero Health before invoking mission loss. There is no player-only y-position failure test (`mission.gd:207–224,376–388`). NPC defeat feeds the existing room-clear accounting. The actual Cistern gap is unlocked; the locked-gap review is a separately labelled fixture, not an extra campaign level.

Repositionable reusable hosts must preserve the lifecycle contract: production mission/room roots use `BoundaryScope`. Other ancestors need that hook or an explicit invalidation before repositioning. Equality checks alone cannot detect every arbitrary move-and-return callback on an uninstrumented ancestor. This is a component contract, not protection against hostile scripts modifying private state.

## 5. Physical sources, filters and limits

| Source / object | What is physically observed | Current rule or limitation |
|---|---|---|
| Melee | Real active overlap, obstruction ray and canonical source confirmation | Faction masks differ; cargo shares admission. Old generic fixture fallback remains available outside the active shared path. |
| Projectile | Real swept carrier, current owner and registered body receiver | NPC receivers accept player layer 2; player accepts NPC layer 32. Peer bolts stop physically but are damage-filtered. Terrain, cargo and other unregistered surfaces retire the bolt without projectile impulse/durability response (`shared_projectile.gd:112–115`; `projectile_receiver.gd:142–161`). |
| Cargo | Rigid contact-point velocities, normal closing speed and live source/receiver binding | Charged-only authored damage and recoil; not a universal impact-energy/durability system. Legacy splash/take_hit damage is disabled in shared cargo (`physical_cargo.gd:130–138`). |
| Freight receiver | Current designated intact body, basin overlap, bounded speed/spin/local position and actual upward contact with its own floor | Latch is a real settling observation. Designated identity is an explicit puzzle rule; arbitrary crates are not interchangeable (`freight_receiver.gd:82–123`). |
| Lifts | Real moving one-way support and observed carry | Motion is a prescribed cosine path. No force-driven motor, load stall, crush or durability simulation (`mission_lift.gd:10–29`). |
| Shutters | Actual collider enabled/disabled with committed open state and noise origin | Current mission opens them monotonically. Occupied closing/crush response is not established (`relay_shutter.gd:69–88`). |
| World boundary | Current configured witness position | Sampled point constraint and configured damage/retirement, not a solid wall or general environmental damage engine. |
| Defeated actors | Health depletion and shared defeated lease | NPC facade retires collision/scheduler; player loss pauses the mission. No common physical-corpse simulation (`shared_sentinel.gd:202–219`; `mission.gd:376–388`). |

Relays, caches, sight stations and onward markers are mission interactions using E plus proximity, without a line-of-sight requirement. Relay state and sight trade are authored services; cache/sight Health refill is explicit (`mission.gd:286–362`). Onward markers are not physical doors. Intro spear/catch timing is presentation, not gameplay projectile evidence.

## 6. Perception: shared event origins, distinct consumers

The event pipeline preserves world origin:

1. Controller captures committed origin with generation and serial (`player.gd:4281–4292`). NPC semantic aliases do not relocate it (`shared_sentinel.gd:176–181`).
2. NoiseRelay forwards `receipt.origin` (`combat_pc/components/noise_relay.gd:73–94`).
3. NoiseBus records and emits that same origin (`scripts/sensory/noise_bus.gd:11–27`).
4. HearingQuery retains it while calculating listener-relative evidence (`simulation/components/hearing_query.gd:16–34`).
5. Sonar stores it and builds contour tracks from it (`scripts/sensory/sonar_view.gd:120–155`); positional audio receives it (`demo/mission.gd:390–402`; `audio_director.gd:31–45`).

Cargo contact noise, moving-lift hum, shutter transition and freight seating are tied to their actual world sources. Q tap uses the player's baton offset. Relay and cache interaction sounds still use their authored points with the room as source (`mission.gd:284,304,318`); sight trade emits at the player offset (`:357`). These are completed interactions, not collision proofs or invented listener-centered emitters.

**Current defaults remain explicit:**

- NPC hearing range 340 at unit loudness, gain 1, loudness scaling clamped 0.2–2.0. Terrain attenuation is **off**. If enabled, the straight-ray terrain mask is 1 and blocked range multiplier 0.25 (`hearing_profile.gd:3–15`). This is stylized audibility, not propagation/reflection/diffraction.
- Sentinel/listener/Warden decision LOS uses terrain 1; sentry uses terrain+cargo 9 (`sentinel_policy.gd:30–31`; `sentry_policy.gd:7–8`). Actual production attack obstruction uses 9 regardless of that decision-policy difference.
- AI peer-source filtering and hearing-memory responses are configured policy. Sentry holds its lane without a visible target rather than investigating every audible source.
- Player sonar is a separate visualization of the same evidence, not the NPC hearing sensor. Current sighted/traded base range is 370/440 and trail 0.53/0.67 (`mission.gd:198–205`). Its radial/contour timing has no wall occlusion. The sight trade also retains its authored 25% run/roll increase.

## 7. Remaining visual asset extraction

Current room art is partially assetized. Backdrop, static platforms, floor
segments, decorative signs, onward/LIFT markers, Exchange stations, relay
markers and Field Caches are independent reusable scenes. Their views own paint; the marker
roots retain the original layer 0/mask 0 enabled contour proxies. The mission
still owns all E proximity rules, activation, sight trade, noise, shutters,
Health changes and completion. A placeable marker is not a reusable interaction
controller. HUD presentation is the remaining bounded visual work.

| Priority | Current owner | Extraction target |
|---|---|---|
| 1 | `mission_hud.gd` → `demo/mission.gd` HUD drawing | Actual HUD/menu/panel presentation assets; retain orchestration in the host. |
| Deferred | Lift, shutter, freight and cargo scripts | Further optional paint separation only if separately scoped; no campaign growth is required. |

Relay contours are 22 × 31 at local (0, -15.5), with no groups. Their physical
insertion order remains station → singular relay → cache → plural relays → onward.
Paint is independently ordered onward → station → plural relays → singular relay
→ cache → dynamic children. The mission uses plural relay objectives exclusively
when that key exists, while drawing both keys in a mixed fixture. The extracted
room preserves this distinction and observes mutable/aliased activation arrays.

Each new view should load independently, repeat and transform through parameters, and observe state without writing Health, physics or progression. Preserve exact collision geometry, layers, masks, one-way settings, layout and interaction rules. Verify sighted/blackout presentation and existing full routes. No new levels or balance changes are required for this extraction.

## 8. Verification and acceptance pointers

The evidence below has different scopes; historical fixture success alone is not proof of current production composition.

| Evidence | Established result |
|---|---|
| `simulation/evidence/warden_acceptance.json` | Prior completed Warden/shared-factory checkpoint. All four current NPC archetypes use the common controller/receiver composition. |
| `simulation/evidence/actor_cargo_acceptance.json` | Completed actor–cargo checkpoint: 69 foundation stages, 10 stock combinations, 19 historical stages, four complete routes without deaths/retries. New actor–cargo checks 466/676, production defense 79 per rate, independent request 178 per rate. |
| `simulation/evidence/boundary_foundation_report.json` | Sealed boundary foundation **72/72 passed**; its 528-file manifest names the pre-backdrop source freeze. Includes production factory, cargo, projectile, Warden and new boundary coverage. |
| `simulation/evidence/boundary_production_boundary_60.json` and `_120.json` | **51 scenarios /174 checks each**, zero failures. Actual gravity, defenses, shared factory/freight, occupancy/reentry, callback/lifecycle and current mission defeat/retry coverage. Direct setup/API probes are labelled separately. |
| `simulation/evidence/boundary_compatibility.json` | **10/10** stock combinations passed. |
| `simulation/evidence/boundary_held_60.json` and `_120.json` | **333 checks per rate**, zero failures; preserves the held-input contract. |
| `simulation/evidence/boundary_{health_regression,defeat_regression,defeat_health_compatibility,health_shield_compatibility}_{60,120}.json` | Four Health/Defeat/shield compatibility suites at both rates:182,187, 182 and 214 checks respectively, zero failures. |
| `simulation/evidence/boundary_historical_report.json` | **19/19** stages passed, completed01:18:50 UTC. Compatibility and preservation of historical behavior remain distinct from production proof. |
| `simulation/evidence/boundary_route_summary.json` | Four sealed-boundary-source routes complete, zero deaths/retries/failures:60 retained 178.20s;60 traded 159.2667s;120 retained 175.55s;120 traded 167.625s. Written 01:23:55 UTC; all 528 manifest entries match that sealed boundary snapshot. |
| `simulation/evidence/boundary_final_gates.json` | **14/14 aggregate groups passed**, unchanged during the run; all 592 source-manifest entries match that sealed boundary snapshot. |

The sealed boundary index is `simulation/evidence/boundary_acceptance.json` (01:24:45 UTC). `boundary_handoff_verification.json` confirms the same 592-source set for final gates and the clean copy, a verified independent manifest, and clean import plus both boot checks. Independent boundary review records 26 scenarios / 95 checks per rate, plus ordinary Health compatibility and additional reproducers: 576 executed checks in total. Preservation records confirm all 15 previous ZIPs unchanged, 1,256 preceding reports/documents byte-identical, three intentional documentation-index updates and no unexpected changes. New archive creation remains a separate delivery step.

Native evidence is narrower than automated evidence. `boundary_native_review.md` records the labelled locked-gap fixture: ordinary fall to Health 0, defeat, retry and disappearance of airborne guards/cargo. Exact per-role accounting, timing and callback fences are automated proof. `actor_cargo_acceptance.json` explicitly does not establish native top-standing, NPC cargo launch or exact force/defense thresholds. Neither checkpoint claims a complete native campaign playthrough or an acoustic-mix review.

### Legacy boundaries

The old root actors/world and old `demo/components/enemy`, ranged and Warden implementations remain compatibility fixtures. Shared cargo disables their legacy body-damage/splash path; shared NPC `take_hit` is a documented stock-prop compatibility shim. Current mission actor and cargo contacts use the registered shared interfaces. Conversely, the projectile's fixture-directory base is genuinely live production code. Source ownership, rather than directory names or old test counts, determines this map.

### Contract references

- `simulation/ACTOR_CARGO_CONTRACT.md`: pressure, support, canonical launch and trajectory limits.
- `simulation/BOUNDARY_CONTRACT.md`: witness rule, outside episodes, guarded Health delivery and cargo retirement.
- `simulation/VERIFICATION.md`: checkpoint-scoped historical and production evidence.

**Current conclusion:** shared production actor, cargo and boundary rules are implemented and exercised. Configuration differences and simulation limits remain explicit. The reusable backdrop, static-platform, floor-segment, decorative-sign, onward/LIFT, Exchange, relay and Field Cache assets are extracted. HUD visual extraction remains open; mission interaction policy is still intentionally centralized.


### Current backdrop checkpoint addendum

`room_backdrop_final_gates.json` records all 17 groups passed with no source drift,
the native pixel gate accepted and all preceding reports restored. There are
97 focused checks at each rate, 72 foundation stages, 10 stock combinations,
333 held-input checks per rate, eight Health/Defeat/shield compatibility runs and
19 historical stages. All four new full routes complete with zero deaths or
retries: 60 retained 178.050s, 60 traded 158.917s, 120 retained 175.283s and
120 traded 167.808s of active simulated time. The current source freeze is 602
files (537 Godot source/assets); only mission_room.gd modifies an existing code
file. The earlier boundary evidence remains valid for its sealed archive.

The corrected native run compares all eight room compositions, display states,
rain times/wrapping, hidden and blackout states, and transformed repeated views.
It has 98 zero-pixel-difference results plus six isolation checks. A harness-only
canvas-registration error found through expanded debugger inspection was fixed
and rerun; its earlier matching-image run is explicitly superseded. Current
native diagnostics contain environment audio/VSync messages and lint warnings,
without that renderer error. Live layout and first-instance hiding were observed;
precise clock timing is automated evidence. No native audio, frame-rate budget or
full human campaign-playthrough claim is added.


### Current static-platform checkpoint

All 19 aggregate groups pass on the unchanged 614-source freeze, terminal exit 0.
Focused physical checks pass 172 at 60 Hz and 292 at 120 Hz. The preceding backdrop
checks, 72-stage foundation, 10 stock combinations, held-input and eight explicit
Health/Defeat/shield runs, 19 historical stages and four complete routes pass.
Native evidence adds 100 exact frozen image comparisons and six view-isolation
checks. Corrected live review observes ordinary jumping, hidden-view support,
traversal, S+Space dropping, reset and reuse; literal Down+Space remains unverified.
See `STATIC_PLATFORM_CONTRACT.md`, `VERIFICATION.md` and
`evidence/static_platform_acceptance.json` for exact scope and attempt history.
The two earlier stock SIGKILL attempts remain preserved; their cause is unproven.
Packaging and fresh-directory verification are separate subsequent steps.

## Placeable floor segment slice

`simulation/world/floor_segment.tscn` now composes the existing static support and
an independent floor view. The Node2D root owns placement/configuration; Support
owns the real solid body and shape; View owns only paint. Authored hatch reference
preserves old fractional/int phase under nesting and movement. Mission floor
rectangles use this asset without changing gaps or gameplay. See
`FLOOR_SEGMENT_CONTRACT.md` for scope, ownership and acceptance requirements.
Signs, interactions and HUD extraction remain outside this slice.

Floor checkpoint acceptance: `evidence/floor_segment_acceptance.json` indexes
24 passing aggregate groups, 108 native exact image pairs, six pixel reuse checks,
and preserved diagnostic/recovery history. The bounded route-test helper correction
uses ordinary input for a shared observed ledge dead zone; production mechanics,
level content and completion criteria remain unchanged. Prior live observations
retain their original source hash and explicit correspondence to final production.

## Placeable decorative world sign slice

`simulation/world/world_sign.tscn` is host-independent baseline-anchored text,
with local appearance/font configuration and no collision, sonar or interaction.
All 14 production decorative signs use it in their original drawing order.
Gate/station/relay foreground captions and HUD remain outside this slice.
See `WORLD_SIGN_CONTRACT.md`; native and aggregate acceptance are recorded
separately under the `world_sign` evidence namespace.

## Placeable onward / LIFT marker extraction

All eight authored onward/lift indicators now instantiate
`simulation/world/onward_marker.tscn`. A bottom-center root forwards explicit
open/ending state to separate paint and owns the existing enabled 40 × 76,
layer 0/mask 0 sonar contour. This marker never blocks, detects interaction or
completes a room; actual relay/freight shutters remain separate physics assets.
Mission predicates, strict E distance checks and ending orchestration are
unchanged. See `ONWARD_MARKER_CONTRACT.md` for inputs and verification boundaries.
Exchange/relay/cache presentation and HUD remain unextracted.

### Exchange presentation-plus-contour boundary

`simulation/world/exchange_station.tscn` composes independent view/appearance
and the enabled 32×42 StationContour. The room retains original positions and
traversal slots with host-local paint depths. Trade eligibility, choice, health,
speed/roll, noise and persistence remain in unchanged mission orchestration.
This is not a reusable sight-trade interaction extraction. Relay/cache views
and HUD remain unextracted. See `EXCHANGE_STATION_CONTRACT.md`.


### Relay presentation-plus-contour boundary

`simulation/world/relay_marker.tscn` composes a separate view/appearance with
explicit active paint input and the original enabled 22 × 31 RelayContour.
Mission-only depths preserve all authored paint layers while original root
insertion slots retain physical/sonar traversal. Per-frame and manual-redraw
state sync preserve mutable Array behavior. Activation, room-sourced noise,
matching shutters, gate checks and retries remain unchanged in the host.
See `RELAY_MARKER_CONTRACT.md`; acceptance is indexed separately after execution.


### Field Cache presentation-plus-contour boundary

`simulation/world/field_cache.tscn` owns the bottom-center placement, optional
ink-configured view and original enabled 16 × 18 CacheContour at (0, -9). Found
state hides paint and marks only that contour `sonar_ignore`; hidden/null/removed
paint alone leaves an unfound contour intact. The standalone invalidation signal
supports explicit host refresh; mission still calls its original sonar refresh.
Physical insertion slots and foreground paint order are separately preserved with
mission-local relative depths. Healing, saving, archives, pause, noise, interaction
priority and persistence remain unchanged in `demo/mission.gd`.
See `FIELD_CACHE_CONTRACT.md` for verification scope and lifecycle requirements.
Historical extraction addenda above describe their own earlier checkpoint state;
those older pending statements are superseded by the integrated `ASSEMBLY_CHECKPOINT.md`, explicit-input HUD/body echo, physical scene packages, and current final verification report.
