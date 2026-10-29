# Reference study and original implementation

The current reusable combat PC follows the actual Dead Cells evidence map in
[combat_pc/REFERENCE_CONTRACT.md](../combat_pc/REFERENCE_CONTRACT.md). Its source
confidence, missing algorithms, original tuning and primary visual observations
are explicit. The notes below are historical records of earlier prototype studies,
not the reference target for the current PC.

The user requested a read-only study of public action-game source and decompilation
work. The following sources informed design concepts; no proprietary game code or
franchise assets were copied into MOKSHA.

- Sébastien Bénard's MIT-licensed game-feel demo:
  https://github.com/deepnight/gamefeel/tree/09d24aa05abe1192ad07cd3acd7270e6a5842237
  Hero's input queue and separate capture/consumption suggest preserving intent
  across pauses. Mob/Game illustrate layered impact feedback and short pauses.
- His GDC 2019 presentation on Dead Cells' development:
  https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf
  Intent-friendly traversal and responsive turning guided the control review.
- The Symphony of the Night matching decompilation:
  https://github.com/Xeeynamo/sotn-decomp/tree/968f38954089656494b13e4c9500cdebbcf5918b
  Inspected files declare AGPL-3.0-or-later and the project requires separately
  supplied original game assets. Only broad concepts were used here: explicit
  attack lifetime, movement-state permissions, and careful fast-movement collision.
- Dead Cells Core is a modding API/loader, not complete working game source:
  https://github.com/dead-cells-core-modding/core/tree/31f597bc462e6767f28a62e14ed36d65721e6d46
  It was not used as an implementation dependency.
- The inspected WIP DeadCellsDecomp weapon methods include undecompiled stubs;
  that repository also disclaims an open-source license for the game source:
  https://github.com/N3rdL0rd/DeadCellsDecomp/tree/77c3ad263c4187ade6d048ba77bb61f79e6cec44
  It was not used as a working foundation.

## Resulting MOKSHA changes

Original Godot code captures jump/dash/attack requests before actor-local hitpause,
keeps short input buffers, explicitly cancels pending attacks on dash/damage/death,
uses forward shape overlap plus terrain obstruction for melee, and lets sound
propagation continue during local impact pauses. Regression checks cover thin walls,
overhead ledges and high-speed movement. Timings are MOKSHA tuning choices, not
recovered Dead Cells values.

MOKSHA retains its separately authored reusable controller/rigid-body foundation,
original generated artwork, and original synthesized audio. All tuning can be
changed without importing these external projects.

## Movement-only lab (2026-10-04)

A bounded follow-up inspected Deepnight's functional Hero and Entity source.
Separating input-facing from captured dash direction, retaining direction on
zero input, consuming queued intent, and keeping input, motor and renderer
boundaries informed the original Godot movement lab. No external code was copied.
The lab uses a shared CharacterBody2D motor for the PC and NPC, explicit motion
states, independent adapters, and tunable resources. The WIP DeadCellsDecomp
Hero methods (including shouldTurn) were stubs, so they cannot establish actual
Dead Cells algorithms or timings.

- https://github.com/deepnight/gamefeel/blob/master/src/game/en/Hero.hx
- https://github.com/deepnight/gamefeel/blob/master/src/game/Entity.hx
- https://github.com/N3rdL0rd/DeadCellsDecomp/blob/main/deadcells/src/game/en/Hero.hx
- https://docs.godotengine.org/en/stable/classes/class_node2d.html#class-node2d-property-scale

Godot's documented negative-scale decomposition makes scale.x an unreliable
mirror assertion. The earlier v3 actor used an explicit transform basis and
passed the diagnostic. The new wireframe draws facing markers directly.
