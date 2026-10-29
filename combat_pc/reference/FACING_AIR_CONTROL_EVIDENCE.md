# Dead Cells combat facing and airborne-control boundary

Read-only research, 2026-10-04, pinned to [N3rdL0rd/DeadCellsDecomp `77c3ad263c4187ade6d048ba77bb61f79e6cec44`](https://github.com/N3rdL0rd/DeadCellsDecomp/tree/77c3ad263c4187ade6d048ba77bb61f79e6cec44), identified by its README as PC v35 / `50edff4`. This is **research only**, not authorization to expand MOKSHA's three-step melee pass. No runtime, art, level or NPC changes.

**Finding:** there is a real per-cycle branch around auto-aim, real charge-turn defaults/overrides, and targetable/team bookkeeping. There is no recovered target chooser, aim-sampling schedule, or target-conditioned air-control implementation. Official Update 23 confirms a conditional airborne feature but does not specify its physics. Keep any future implementation and numbers labeled original MOKSHA policy.

**BODY** means an inspected nonempty body, not runtime-equivalence proof. **CALL** means an actual dispatch with an unavailable callee. **DECL** means fields/signatures/stubs. **PRIMARY** means the developer's historical statement. Source hashes and narrowly stated facts are in [FACING_AIR_CONTROL_SOURCE_FACTS.json](FACING_AIR_CONTROL_SOURCE_FACTS.json).

## Source-confidence matrix

| Question | Evidence | Strict boundary |
|---|---|---|
| Is there any useful auto-aim body? | **BODY/CALL:** [ElbowBlades 21–27][elbow] reads the cycle, returns false at cycle zero, otherwise invokes the base auto-aim. The base cycle getter really returns `_cycle` at [Weapon 39–41][weapon] | This concrete step bypasses the base routine. Later cycles do not necessarily aim successfully. The Boolean's permission-versus-success meaning and when callers invoke it are unrecovered |
| Is aim universal? | **BODY:** [TPSword 44–46][tp] returns false to auto-aim. **DECL:** [Weapon 101–103, 160–170][weapon] lacks base auto-aim, special-mode aim, bow-target angle and hit eligibility | Distinguish actor facing, target selection, projectile angle and automatic attack triggering. A Boolean return is not a recovered targeting algorithm, and an angle method name supplies no cone or sampling time |
| Can the character turn during attacks? | **BODY:** [Weapon 141–143][weapon] defaults charge-turn permission to true; [TPSword 30–32][tp] and [WiggleWhip 72–74][wiggle] return false. **DECL:** [Trident 36–41][trident] has missing turn permission and owner-turn callback | Weapon-specific charge permission is real. No general rule for active/recovery frames, queued-next-step facing, turn-to-target priority or roll direction follows. Trident's initialized turn counter does not recover an allowed count |
| When is facing sampled or applied? | **DECL:** [Hero.shouldTurn 143–145][hero], [Entity.lookAt 504–505 and isFacing 684–686][entity], and Weapon.onOwnerTurned 98–99 are missing. Hero.fixedUpdate 868–869 is empty. [HeroWeaponsManager 147–162, 179–199][manager] lacks admission/update/auto-hit bodies | No established ordering between fresh input, current facing, target choice, windup start, active contact, combo commit or hitpause. No recovered latch/retarget moment |
| Which entities are eligible? | **BODY/CALL:** [Entity 200–232][entity] updates team membership when team/targetable changes, conditionally on being outside the quadtree. [Entity 613–618][entity] defines alive as positive life and not destroyed. **DECL:** `isOpponent` 235–237 and `canBeHit` 889–891 are missing; `canBeHitBy` and `canReceiveAttack` merely delegate to the latter at 893–900 | Targetability, team, life and hit reception are separate concepts. No implemented aim caller proves which are required. Team add/remove and quadtree query implementations are also missing; bookkeeping is not the chooser |
| Are distance/front/sight/props considered? | **DECL:** [TargetHelper 20–106][targets] names area, distance, importance, sight, angle, front, untargetable, global-shield and breakable filters/scorers; all are empty/stubbed. `getBest` is missing. [Team 5–11, 18–32][team] and [QuadTree.query 58–60][quad] do not complete the pipeline | These are candidate interfaces only. Their presence does not prove every weapon applies every filter, a filter order, nearest-target priority, wall rejection, or prop exclusion. Targeted code searches found no implemented callers of the inspected filter methods |
| What is the strike zone? | **BODY:** [Area 14–25][area] sets absolute or entity-relative position. **DECL:** shape dimensions/circle flag are at 4–9, but construction and contact math are absent. Weapon areas/canHit/doAreaEffect are unavailable | Unknown whether eligibility uses visual bounds, attack area, expanded pre-hit query, swept volume, or a different probe. No inferred radius, height tolerance, facing cone, center-vs-edge rule or wall policy |
| Is airborne control implemented? | **DECL:** [Weapon.airControlOwner 175–176][weapon], [Hero.airControl 764–765][hero], [PureNail.airControlOwner 58–59][nail] are empty. PureNail directional queries, attack and update bodies are missing. [Beheaded.moveControlled 53–55][beheaded] is a stub | No recovered acceleration, drag, velocity cap, gravity change, impulse, duration, phase gate or continuation rule. PureNail's separate animation query returning false is not a recovered hover/movement allowance |
| Do managers/main skills reveal jump or roll coupling? | **DECL:** [HeroMainSkillsManager 19–26, 69–83][mainmanager] lacks updates/arbitration. [JumpBeheaded 11–15][jump] and [AirJumpBeheaded 11–15][airjump] lack launch behavior. **CALL:** [AirJump 44–46][airbase] invokes a missing setter with zero when climbing begins | No attack-to-air-jump refund or airborne-combat reset is established. The climbing call is neither an attack event nor proof of remaining/used counter semantics. Base main-skill default permissions do not establish final actor policy |
| Does a ranged specialization fill the gap? | **DECL:** [ThrowingKnife 9–15][knife] lacks origin/execution; [LightningWhip 17–26][lightning] lacks next-target selection and quadtree-on-path behavior; [BaseBow 60–78][bow] lacks shoot/update behavior | Historical ranged targeting examples cannot fill the ordinary melee controller. No ranged aim formula or target-conditioned movement is recovered here |

## What Update 23 actually establishes

The [official March 4, 2021 notes][p23], Balancing, say: “All weapons now have a bit of air control if an ennemy is in the strike zone.” This establishes a developer-described feature with an **enemy-presence/strike-zone condition** in that historical update.

It does **not** identify the physics meaning of air control, affected axis, numerical strength, required input, attack phase, sampling frequency, duration, or whether the condition persists after a target leaves. Presence in a zone is not the same statement as a confirmed hit. No successful-contact requirement, hover, slowed gravity, extra jump, jump refund, fall-risk reset, invulnerability or universal effect against props can be inferred. Even whether the relevant enemy must currently be damageable, visible or unobstructed is missing.

The earlier [Update 4.2, 2017][p4] removed Lightning Whip air control. Update 23 is later and broader; do not treat the old exclusion as current v35 policy or infer the later effect's mechanics from it. Exact v35 behavior still needs matching-build observation or missing source/data.

## Other primary evidence, narrowly applied

- [Sébastien Bénard's GDC 2019 slides, page 17][gdc] identify free turnaround and auto-aim as combat control features. This confirms intent, not permission at every phase or a target-selection algorithm. Text was inspected; no video frame or input trace was measured. The PDF screenshot tool failed, so no visual measurement is claimed.
- [Update 1, 2017][p1] mentions increased elite/boss priority for some weapons, including throwing knives. That establishes a historical weapon-specific priority, not nearest-target selection or a universal melee ranking.
- [Update 4, 2017][p4] adds slight bow auto-aim while describing shots as horizontal and easier against small/lower enemies. Do not reduce all aim assistance to actor turnaround or assume a recovered projectile-angle algorithm.
- [Update 29, 2022][p29] adds optional auto-hit using the primary melee weapon against nearby enemies. This is distinct from ordinary manual attacks with aim assistance. [AssistModeData 12, 19][assist] contains a mode-auto flag initialized false, but no inspected call graph maps that flag to every aim path. Record assist/input settings for any future observation.
- [Update 14.7][p14] adjusts Giant Whistle's preference away from shielded enemies when unshielded ones are available. It illustrates per-item eligibility/ranking; it does not prove generic shields are excluded from melee aim or the airborne condition.

## Future passive-fixture implications, not an implementation request

If separately authorized, keep three decisions independently observable: **whether this weapon/step runs an aim routine; which candidate it chooses; whether eligible presence enables an air modifier**. Do not reuse a successful-damage flag as all three. Prefer a query result with a target identity, rejection reason, query geometry, sample tick and weapon/step generation. Those interfaces are MOKSHA design proposals.

| Fixture | What it must distinguish |
|---|---|
| No target / target enters and leaves | Presence before windup, during active contact, during recovery and during hitpause; no presumed persistent bonus or successful-hit prerequisite |
| Mirrored front/back/above/below | Manual input facing, target-facing suggestion and committed strike facing; equal-X and edge-of-zone tie cases; no retroactive rotation of an existing swept strike |
| Two targets / changed order | Near versus far, current facing versus behind, equal score, one removed mid-query; deterministic authored ranking without claiming it is Dead Cells' ranking |
| Eligibility variants | Live enemy proxy, dead/destroyed/untargetable proxy, ally, shielded/invulnerable proxy, prop and projectile. A damageable prop does not automatically count as an enemy |
| Occlusion and geometry | Same target behind solid wall, one-way platform, boundary contact and moving carrier; distinguish selection eligibility from eventual hit/occlusion |
| Cycle and permission | A step bypassing the aim routine, another using it, explicit external turn/movement denial, queued next step, roll/shield cancellation. No target selection may silently override current action authority |
| Air physics | Rising/apex/falling, target absent/present/unhittable, successful hit versus whiff, landing and cancellation. Compare horizontal/vertical traces separately and verify unchanged jump budget/fall history unless a later explicit policy says otherwise |
| Assist settings | Manual attack/held-repeat/auto-hit are distinct modes; target appearance alone must not trigger an attack unless that mode is deliberately implemented |

For current M9, retain its documented authored facing and aerial behavior. This study does not establish that its values match v35 and does not request any change. Remaining unknowns are aim-query admission/call time, Boolean return semantics, candidates/filter order/scoring/ties, exact strike-zone geometry, direction sampling/latching, airborne modifier mechanism/lifetime, target validity conditions, phase/cancel ordering, and all gameplay numbers.

[weapon]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx#L39-L176
[elbow]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/ElbowBlades.hx#L21-L27
[tp]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/TPSword.hx#L30-L46
[wiggle]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/WiggleWhip.hx#L72-L74
[trident]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/Trident.hx#L36-L41
[hero]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L764-L765
[entity]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/Entity.hx#L200-L237
[manager]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroWeaponsManager.hx#L147-L199
[targets]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/TargetHelper.hx#L20-L106
[team]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Team.hx#L5-L32
[quad]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/quadTree/QuadTree.hx#L58-L60
[area]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Area.hx#L4-L25
[nail]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/PureNail.hx#L42-L63
[beheaded]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/hero/Beheaded.hx#L53-L55
[mainmanager]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroMainSkillsManager.hx#L19-L83
[jump]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/JumpBeheaded.hx#L11-L15
[airjump]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJumpBeheaded.hx#L11-L15
[airbase]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJump.hx#L44-L46
[knife]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/ThrowingKnife.hx#L9-L15
[lightning]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/LightningWhip.hx#L17-L26
[bow]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/BaseBow.hx#L60-L78
[assist]: https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/AssistModeData.hx#L12-L19
[p1]: https://deadcells.com/patchnotes/1
[p4]: https://deadcells.com/patchnotes/4
[p14]: https://deadcells.com/patchnotes/14
[p23]: https://deadcells.com/patchnotes/23
[p29]: https://deadcells.com/patchnotes/29
[gdc]: https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf#page=17
