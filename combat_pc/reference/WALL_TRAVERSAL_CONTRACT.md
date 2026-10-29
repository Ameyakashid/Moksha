# Wall traversal: evidence and MOKSHA policy

The primary reference is the developer's [14 November 2017 announcement](https://store.steampowered.com/news/posts/?enddate=1510678900&feed=steam_community_announcements), which embeds an actual [wall-jump/grab/climb demonstration](https://imgur.com/cdkBTwq). Its frames show an airborne approach to the right wall, an upward wall run with a distinct contact pose, a leftward kick across the shaft, and a higher landing on the left. That connected sequence is the target of this pass. The encoded 1.92-second clip does not establish a simulation rate, controlled inputs or current-version constants.

The pinned public decompilation is `N3rdL0rd/DeadCellsDecomp@77c3ad263c4187ade6d048ba77bb61f79e6cec44` (PC v35 according to its README). Its [Hero wall-grab query](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L717-L723), [climb entry/exit operations](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/en/Hero.hx#L781-L797) and [main-skill manager](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/hero/HeroMainSkillsManager.hx#L69-L79) expose useful integration surfaces but lack their movement and arbitration bodies.

The [AirJump climb callback](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/mainSkills/AirJump.hx#L44-L46) writes zero through a missing setter. Whether that counter represents used or remaining jumps is unresolved; the write does not prove a refill rule. [Official patch notes](https://dead-cells.com/patchnotes/33) establish Spider Rune-dependent access. The lab grants an independent wall ability; it does not implement the game's item progression.

## Deliberate adaptation

The reusable actor has a separate wall ability gate. The lab grants it and exposes G to switch it during play. A valid airborne approach with input toward a supported solid wall begins a finite upward run. A controlled downward slide/end, supported outward kick, and existing ledge handoff complete the connected action. Root movement remains collision-owned; wireframe hands and feet read contact telemetry and cannot move the body.

The ascent limit, slide response, input thresholds, kick impulse, short commitment, release grace, cancellation order and rearm conditions are authored MOKSHA policies. They are tunable and documented alongside the actual motor in `../MOTOR_CONTRACT.md` and `MOKSHA_PARAMETER_LEDGER.json`. The promotional clip does not demonstrate those details. A real wall contact does not silently refill the actor's ordinary air-jump, roll or dive budgets in this implementation.

Contact identity and the current ascent budget are separate from the action name. A held contact, collider seam or attack phase change cannot restart the finite run. The default rearm policy requires genuine separation and recontact after a delay; an alternative ground-only policy is configurable. Neither is claimed as a recovered v35 rule. [A historical performer's guide](https://www.speedrun.com/deadcells/guides/oo8vv) describes special same-wall renewal via items and attack/jump cancellation, but its applicability to v35 is unverified. That exploit is not implicitly implemented by resetting state.

The initial collision contract supports dedicated upright solid rectangular wall bodies. One-way platform sides, mixed/multiple wall shapes and rotated walls are refused safely. That restriction is an explicit Godot implementation boundary, not a claim about Dead Cells geometry support. The test course keeps its walls as independent editor-placeable bodies; later geometry adapters can extend support without changing the player/view interface.

## What must be demonstrated

- Native connected approach, upward wall motion, outward kick and opposite higher landing in both directions, plus a real ledge handoff
- Ability and host/weapon permission gates; no duplicate jump consumption or stale supported kick after contact invalidation
- Finite run/end, genuine recontact and repeated same-instance use, with the configured policy visible in evidence
- Collision-safe thin walls, one-way junctions, changing supports, hitpause transport and blocked headroom
- Accepted roll, attack, dive and damage retire the previous contact owner; denied actions leave it coherent
- Independent 60/120Hz physics checks, preserved earlier acceptance, and a minimal project boot without the old game's autoloads

This contract identifies a progressive implementation target. Acceptance is recorded separately after native and physics verification; it is not a declaration that the full Dead Cells PC is already implemented.
