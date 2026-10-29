# Shared production charged-cargo simulation checkpoint

Open `simulation/gym.tscn` in Godot 4.6.3 and press F6 for the reusable gym.
The five independent stages cover footing, hearing, physical cargo impact, shared
actor movement and actual-contact shared melee/counter. The same actor/controller
accepts player input and NPC intentions. The default mission now uses this shared
composition for ordinary sentinels and all thirteen listener placements, with
authored differences in a private per-instance profile. See
`simulation/SENTINEL_CONTRACT.md` and `simulation/LISTENER_CONTRACT.md`.
Mission crates/freight now use shared real-contact, charged-only admission. The
player is deliberately cargo-vulnerable, and crate-to-crate collisions can transfer
charge without synthetic launches. Existing guard/roll and Warden bracing remain
capability responses. See `simulation/MISSION_CARGO_CONTRACT.md`.
See `simulation/README.md` and `simulation/VERIFICATION.md` for tests and remaining gaps.
The prior mission entry is still F5; its historical delivery description follows.

# MOKSHA — The First Ascent delivery

Open `project.godot` in Godot 4.6.3 and press F5. No external assets or add-ons are required.

- `README.md`: controls, finite mission, sight trade and honest scope/duration limits.
- `demo/`: complete mission host, seven areas and ending, local checkpoints, enemies, lifts, route-changing relay shutters, physical cargo receiver/cradle and sensory adapters.
- `combat_pc/visuals/lithe_*`: detachable connected-body animation improvement; the approved controller and old view remain available.
- `demo/docs/VERIFICATION.md`: checked results, native review, actual automated route timing and remaining limits.
- `demo/evidence/`: compact JSON results and actual native Godot screenshots. Review-state captures are not represented as playthrough evidence.
- `demo/tests/`: deterministic component checks, route bot, lifecycle checks and native review/profile fixtures.
- `docs/V26_ARCHIVE.md`: previous README, retained as historical documentation. Its historical F5 entries are superseded by `demo/mission.tscn`.
- Original scenes/components/assets remain for separate reuse; no proprietary Dead Cells assets are included.

This is a shorter complete demo, not a thirty-minute validated play session or the full proposed multi-floor game. Godot editor/import caches, previous ZIP deliveries and large transient traces are excluded from the source archive.
