# MOKSHA — Five Ascents

A side-on cyberpunk action campaign built on the preserved MOKSHA Godot movement, physical combat and sonar foundation. An older operative crosses the city and four tower floors, opens civilian routes, breaks centralized control and chooses how the districts receive the tower's records and authority.

**Five levels / 32 authored districts.** The requested **15–20 minutes per level remains a design target, not validated human playtime**. Automated route times are reported separately, with no multiplier. The original story's unresolved time-loop/immortality variants are not claimed resolved by this campaign's local political ending.

## Play

**Windows PC:** see the [clone-to-play and portable-build quickstart](campaign/docs/PC_QUICKSTART.md). The source launcher is `Play-MOKSHA.cmd`; the portable export remains a separate EXE + PCK download.

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
| Field journal / return; journal pages | Tab; A/D or arrows |
| Retry district | R |
| Pause / resume | Esc |
| Mute | M |
| Original wireframe presentation toggle (no rule changes) | F8 |
| Gameplay screenshot when a real renderer is available | F12 |

Default controls accept any connected controller ID. Controllers use Xbox-style button names: left stick/D-pad move, A jump, X strike, LB guard, RB roll, Y use, B sound tap, Back journal and Start pause. Title and choice screens show their own controller prompts. See [`campaign/docs/NOV6_GAMEPAD.md`](campaign/docs/NOV6_GAMEPAD.md) for the complete map and validation limits.

Routing consoles begin **UNROUTED** and cycle **0 → 1 → 2 → 0**. Match the engraved target; dependencies must be complete. **Marked breaker housings require real J strikes, not E.** Pressure plates accept physical cargo; they are optional so a broken prop cannot deadlock the campaign. Freight receivers require the intact marked cargo to land and settle from real movement/contact; E at its cradle replaces lost cargo without healing or resetting enemies.

## The five levels

1. **City Without a Master** — Rainline badge, clinic supply/rescue loop, electrical tram depot and physical brake breaker, squad records, evacuation branches and the Quarantine lancer.
2. **Exchange / Foundry** — optional sight trade, power routing, actual freight transport, stamping and coolant circuits, welded restraint and the dispatch keeper.
3. **Cistern / Residences** — fixed/lift drainage routes, flooded market, clinic and rooflines, refuge options, seized sluice and a committed lancer.
4. **Memory Works** — provenance and sound baffles, physical surveillance breaker, cargo transfer, memory/crew branches, three independently routed Works circuits and a keeper's departure seal.
5. **The Crown** — exposed ascent, witness records, physical authority feed, refuge and coolant safeguards, the Warden confrontation and a final public-record/local-custody decision.

Ordinary guards may survive most district exits. Four captain seals require only their named captain, not every guard. Captains use two genuine new shared-controller policies: a long committed charge and a retreating long thrust. The final Warden retains its existing bracing, commitment and parry rules. There are no repeated-wave or elapsed-time progression gates.

For a packaged Windows launch, save-file location and a simple real pacing worksheet, see `campaign/docs/LOCAL_PLAYTEST.md`.

## Builds, sight and checkpoints

- Neutral: 60 health, ordinary run/damage.
- Strength: 75 health, +40% base strike damage, −6% run speed.
- Agility: 50 health, +12% run speed.
- At each of the four level exits choose **J Force** (+25% base strike), **K Agility** (+10% base run), or **L Vitality** (+15 capacity).
- Optional one-time augments add +8% base strike, +3% base run, or +5 capacity. Live capacity augments do not heal. Changes apply from base resources, never multiply again on retry.
- Sight trade remains optional: +25% run/roll and stronger sound traces, while ordinary world paint disappears. Objective contours and machinery warnings are genuine sound-revealed geometry. No hearing/smell/intellect trade is claimed implemented.

Retry resets the current district's guards, circuits, objects and local objectives; preserves the lens, sight choice, upgrades and recovered archives. Continue resumes the district start, not the middle of a jump or puzzle. Campaign saves use `user://moksha_five_levels_v1.json`; legacy demo saves are untouched. After completing and returning to Title, Continue replays the final district and its next completion adds another receipt and active time. Closing directly from the ending resumes the last saved checkpoint instead. New initially preserves the separate results JSON, but the next completion overwrites that file. Copy it elsewhere to keep an earlier result. See `campaign/docs/LOCAL_PLAYTEST.md` for details.

## Build with the modules

See `campaign/docs/EDITOR_WORKFLOW.md` and `campaign/docs/LAYOUT_CONTRACT.md`.

- `campaign/layouts/level_01.gd` … `level_05.gd`: district placements, dependency graphs, encounters and text.
- `campaign/logic/`: orchestration/save/build state; reusable `.tscn` objective, door and hazard modules.
- `campaign/enemies/`: isolated lancer/keeper policy, attack resources and scenes.
- `campaign/input/`: campaign controller menus, private default-device bindings and device-aware prompts; the original actor still owns movement and combat.
- `campaign/presentation/`, `campaign/views/`, `campaign/assets/`: removable scenery, actor paint and theme resources, no collision/game rules.
- `campaign/module_workbench.tscn`: editor-placeable instances of the reusable physical and campaign modules.
- `campaign/district_entry.tscn`: choose a stable district ID in the Inspector and F6 for a save-disabled playable review.
- `sandbox/assembly.tscn`: original independent physics/actor module bench.

The original Oct23 demo is still playable at `demo/mission.tscn`; its historical README is `docs/OCT23_BASELINE_README.md`. Original approved player/controller and simulation source remain preserved.

## November 12 playable-source checkpoint

Original neon arcology and background crowds, more deliberate opening routes, validated content/save boundaries and pre-activation health assembly are integrated. See [changes, evidence and remaining limits](campaign/docs/NOV12_PLAYABLE_CHECKPOINT.md). The original controller/simulation is preserved; demo assembly has a small behavior-tested hook.

## November 12 early foundation checkpoint

The reference-led foundation pass adds validated content loading, detached run/save data, isolated checkpoint storage, a Windows source launcher and a caption-layer fix. See [changes and verification limits](campaign/docs/NOV12_CHANGES.md) and the [REA/source responsibility map](campaign/docs/REFERENCE_FOUNDATION.txt). This is a source update; the already-delivered portable Windows build remains `c73159b`.

## November 6 improvement pass

This revision adds campaign-wide controller navigation, a steadier camera, varied district scenery, readable progress and objective labels, safer modal input boundaries with release guidance, focus-loss safety pause and visible checkpoint failures with preservation of invalid originals. Six authored layout corrections make optional cargo rewards require an actual push and clear unsafe or blocked routes. Long-session cache cleanup and timely archive/defeat sounds improve reliability without changing the original actor/controller or simulation rules. See [`campaign/docs/NOV6_CHANGES.md`](campaign/docs/NOV6_CHANGES.md) for the implementation and acceptance record.

## November 2 quality update (historical)

See [`campaign/quality/README.md`](campaign/quality/README.md) for the reproducible quality gate, bounded state/replay checks and asset budgets. Two corrupt-checkpoint error paths are fixed in source. At that time the prior Windows package had **not** been rebuilt and did not include those fixes. Newer package provenance must be read from its own build report. Earlier full-campaign evidence remains historical and hash-bound; this update has its own focused results.

## Evidence and limits

See `campaign/docs/NOV12_PLAYABLE_CHECKPOINT.md` for current source tests and limits; `campaign/docs/NOV6_CHANGES.md` records the earlier build evidence; `campaign/docs/VERIFICATION.md` preserves the historical October 29 report. Headless contracts, isolated chapter input routes, complete input campaigns and native visuals are different evidence categories. Actual native Godot screenshots and bounded manual-input review cover representative areas in all five levels, panels, combat telegraphs and blind concealment; visual defects were fixed and re-rendered. Direct scene fixtures are labelled separately from complete input runs. Full native campaign traversal, audible mix, Windows hardware behavior and first-play human timing remain unverified.

Original MOKSHA assets are reused separately from gameplay. Actual MIT Beehave blackboard code is wired into campaign objective/build context with its license and pinned source recorded in `campaign/vendor/beehave/`. No proprietary game/decompiled commercial art or code is included; REA is tooling, not a license to copy a commercial game. See `campaign/docs/REUSE.md`.
