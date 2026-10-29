# Dead Cells combat source audit

Read-only inspection, 2026-10-04. No MOKSHA gameplay implementation changed. Public repository `N3rdL0rd/DeadCellsDecomp`, commit `77c3ad263c4187ade6d048ba77bb61f79e6cec44`. No reuse license for the game implementation is established here; observations below describe interfaces and behavior, not permission to copy source.

## Verified findings

1. `WeaponSkill` exists as a secondary class at `Weapon.hx`275–285. It inherits `OldSkill`. The absent separate WeaponSkill.hx is not evidence that the class itself is missing. The constructor only calls its base; cast-speed method is a stub. BaseMelee.hx is absent from the complete1888-entry pinned tree.
2. `OldSkill.hx`6–25 declares charge and cooldown frame counters, control-lock seconds after use, hit-frame and attack-animation completion fields, movement-during-charge and ignore-interrupt flags. Its prepare69, execute73, interrupt76, and update111 implementations are absent. These declarations establish distinct concepts, not the ordering, numeric values, or cancellation rules. `dynHasCooldown`128–130 is implemented as a true default; it does not reveal a particular weapon's cooldown length.
3. `Skill.hx`112–115 dispatches owner locking to both hero and mob helpers. Those helpers118–122 are empty. Opponent-contact handling171–173 calls the hit routine with the area/list and a null reference argument; the hit routine182 is empty. This is interface/call-graph evidence only. It does not recover actual PC movement locking, hit detection, damage, or hitpause algorithms. This Skill class is not the base of the WeaponSkill above; OldSkill is.
4. `BaseShield.hx`25–30 refuses cancellation when canBeHeld is false, otherwise delegates to Weapon.tryToCancel, which is a stub. This preserves a real outer gate while leaving the successful cancellation conditions unknown.
5. `BaseShield.hx`60–71 constructs counterattack data, applies numeric tag identifiers13,25,1,2 using the fullParry flag, calls a pre-hit hook, attacks the source entity, and dispatches its success callback only when that counterattack succeeds. The tag identifiers are left uninterpreted here. Start/end/holding/initialization methods are absent; no numeric parry duration, invulnerability, damage or movement restriction can be inferred from them.
6. `BroadSword.hx`13–19 stops critical-feedback presentation when its cycle becomes0 and then assigns the cycle. Execute9, incrementCycle22 and hitFromWeapon25 are absent. The implemented setter does not establish combo timing or attack trajectories.

## Implication for the PC contract

The source supports separating locomotion actions from weapon charge/execute/cooldown/interrupt state, explicit owner movement permission, attack-animation event timing, target-contact routing and shield hold/parry outcomes. It does not support filling missing numbers with another game's constants or calling guessed movement/cancellation logic a port. The next implementation map must tag each row as recovered body, declaration/call-graph evidence, primary developer behavior evidence, or a MOKSHA tuning proposal awaiting observation.

## Exact sources

- [Weapon and nested WeaponSkill](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/Weapon.hx#L275), blob5515da6ac74a18b7188d1670e3611c14168e58ac
- [OldSkill](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/skill/OldSkill.hx#L6), blob5790f28b83d361415972fdc2cbaf34c034d7415c
- [Skill lock-owner dispatch](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/skill/Skill.hx#L112), blob1c6b3cd1a4d749ffe75cd6312f43a6168a6e3212
- [Shield cancel gate and counter dispatch](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/BaseShield.hx#L25), blob7237528fde8dbf1decb7a55a4c0b890d0fb1b013
- [BroadSword cycle setter](https://github.com/N3rdL0rd/DeadCellsDecomp/blob/77c3ad263c4187ade6d048ba77bb61f79e6cec44/deadcells/src/game/tool/weap/BroadSword.hx#L13), blobade798068e188c4f352c41c86e63c2e14973754c
