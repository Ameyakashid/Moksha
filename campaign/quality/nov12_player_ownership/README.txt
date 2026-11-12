Detached player assembly verification
Baseline: frozen fe9936a, Godot 4.6.3 Linux headless.

Production scope: demo/mission.gd delegates its existing detached configuration
and component attachment to demo/assembly/player_assembler.gd. Host instantiation,
health selection, room activation, runtime binding, reset and lifecycle policy
remain in their original order. combat_pc/ and simulation/ tracked bytes unchanged.
See campaign/docs/PLAYER_ASSEMBLY.txt for source-reference mapping and constraints.

baseline-corrected.txt was run using the exact fe9936a mission implementation;
new-corrected.txt uses the extracted helper. Output is byte-identical, covering
both demo and campaign hook state, child entry order, actor readiness and final
nested topology. The baseline exposed two faulty initial test assumptions:
campaign skin is added after ready, and campaign build application duplicates
the chain. Assertions were corrected to preserve those existing behaviors.

Detached contracts inspect actor/tree state, health not yet bound, child order,
receiver parent/configuration, health capacity, profile isolation and initial
shared chain. Negative controls deliberately removed movement-profile copying
and swapped defeat/relay insertion order. Both failed the intended assertions;
helper restored exactly and detached contract passed again.

Reproduce the final acceptance suite:
  python3 campaign/quality/nov12_domain_checks.py
The runner isolates HOME and all XDG save/config/cache paths. Its16 stages include
both new contracts, content/domain checks,32-district smoke and60/120 Hz health
assembly, real-contact damage, live-build, save-feedback and adversarial-save
fixtures. summary.json records every result and source hashes.

Limits: source/headless acceptance, not a new full playthrough, native capture,
Windows test or performance benchmark. No desktop was used because an independent
video run owned it. This does not resolve the earlier native fixture shutdown
warning or migrate district/enemy/objective assembly. No proprietary/GPL code
or assets copied. Frozen fe9936a was not rebuilt or modified by this work.
