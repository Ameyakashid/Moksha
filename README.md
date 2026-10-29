# MOKSHA — Five Ascents

A side-on cyberpunk action campaign built on the preserved MOKSHA Godot movement, physical combat and sonar foundation. An older operative crosses the city and four tower floors, opens civilian routes, breaks centralized control and chooses how the districts receive the tower's records and authority.

**Five levels / 32 authored districts.** The requested **15–20 minutes per level remains a design target, not validated human playtime**. Automated route times are reported separately, with no multiplier. The original story's unresolved time-loop/immortality variants are not claimed resolved by this campaign's local political ending.

## Play

Open `project.godot` in **Godot 4.6.3** and press **F5**. The default scene is `campaign/campaign.tscn` (not the old demo).

On the title, **1** Neutral, **2** Strength, **3** Agility selects a starting lens. **Enter** starts; **C** resumes your last district checkpoint. The opening can be skipped with Enter/Space. Each district starts at full health.

| Action | Key |
|---|---|
| Move | A/D or left/right |
| Jump, then air jump; release for short jump | Space or C |
| Fresh-press three-hit combo; break marked circuit housings | J |
| Raise timed parry, hold guard | K |
| Roll | Shift |
| Climb ladder | W/S |
| Drop through thin support / aerial dive | S + Space |
| Sound tap: maps actual nearby contours | Q |
| Use nearby item, routing console, install, rescue pod, relay or exit | E |
| Field journal / return | Tab |
| Retry district | R |
| Pause / resume | Esc |
| Mute | M |
| Original wireframe presentation toggle (no rule changes) | F8 |
| Screenshot when a real renderer is available | F12 |

Routing consoles begin **UNROUTED** and cycle **0 → 1 → 2 → 0**. Match the engraved target; dependencies must be complete. **Cross-braced breaker housings require real J strikes, not E.** Pressure plates accept physical cargo; they are optional so a broken prop cannot deadlock the campaign. Freight receivers require the intact marked cargo to land and settle from real movement/contact; E at its cradle replaces lost cargo without healing or resetting enemies.

## The five levels

1. **City Without a Master** — Rainline badge, clinic supply/rescue loop, electrical tram depot and physical brake breaker, squad records, evacuation branches and the Quarantine lancer.
2. **Exchange / Foundry** — optional sight trade, power routing, actual freight transport, stamping and coolant circuits, welded restraint and the dispatch keeper.
3. **Cistern / Residences** — fixed/lift drainage routes, flooded market, clinic and rooflines, refuge options, seized sluice and a committed lancer.
4. **Memory Works** — provenance and sound baffles, physical surveillance breaker, cargo transfer, memory/crew branches, three independently routed Works circuits and a keeper's departure seal.
5. **The Crown** — exposed ascent, witness records, physical authority feed, refuge and coolant safeguards, the Warden confrontation and a final public-record/local-custody decision.

Ordinary guards may survive most district exits. Four captain seals require only their named captain, not every guard. Captains use two genuine new shared-controller policies: a long committed charge and a retreating long thrust. The final Warden retains its existing bracing, commitment and parry rules. There are no repeated-wave or elapsed-time progression gates.

## Builds, sight and checkpoints

- Neutral: 60 health, ordinary run/damage.
- Strength: 75 health, +40% base strike damage, −6% run speed.
- Agility: 50 health, +12% run speed.
- At each of the four level exits choose **J Force** (+25% base strike), **K Agility** (+10% base run), or **L Vitality** (+15 capacity).
- Optional one-time augments add +8% base strike, +3% base run, or +5 capacity. Live capacity augments do not heal. Changes apply from base resources, never multiply again on retry.
- Sight trade remains optional: +25% run/roll and stronger sound traces, while ordinary world paint disappears. Objective contours and machinery warnings are genuine sound-revealed geometry. No hearing/smell/intellect trade is claimed implemented.

Retry resets the current district's guards, circuits, objects and local objectives; preserves the lens, sight choice, upgrades and recovered archives. Continue resumes the district start, not the middle of a jump or puzzle. Campaign saves use `user://moksha_five_levels_v1.json`; legacy demo saves are untouched. Results use a separate JSON. After completing the game, Continue replays the final district; New starts a fresh run without deleting previous results.

## Build with the modules

See `campaign/docs/EDITOR_WORKFLOW.md` and `campaign/docs/LAYOUT_CONTRACT.md`.

- `campaign/layouts/level_01.gd` … `level_05.gd`: district placements, dependency graphs, encounters and text.
- `campaign/logic/`: orchestration/save/build state; reusable `.tscn` objective, door and hazard modules.
- `campaign/enemies/`: isolated lancer/keeper policy, attack resources and scenes.
- `campaign/presentation/`, `campaign/views/`, `campaign/assets/`: removable scenery, actor paint and theme resources, no collision/game rules.
- `campaign/module_workbench.tscn`: editor-placeable instances of the reusable physical and campaign modules.
- `campaign/district_entry.tscn`: choose a stable district ID in the Inspector and F6 for a save-disabled playable review.
- `sandbox/assembly.tscn`: original independent physics/actor module bench.

The original Oct23 demo is still playable at `demo/mission.tscn`; its historical README is `docs/OCT23_BASELINE_README.md`. Original approved player/controller and simulation source remain preserved.

## Evidence and limits

See `campaign/docs/VERIFICATION.md` for current tests and exact source identity. Headless contracts, isolated chapter input routes, complete input campaigns and native visuals are different evidence categories. Native pixel/feel review and audible mix review require the user's local renderer/audio device; the current executor cannot start its display server. Human first-play timing is unverified.

Original MOKSHA assets are reused separately from gameplay. Actual MIT Beehave blackboard code is wired into campaign objective/build context with its license and pinned source recorded in `campaign/vendor/beehave/`. No proprietary game/decompiled commercial art or code is included; REA is tooling, not a license to copy a commercial game. See `campaign/docs/REUSE.md`.
