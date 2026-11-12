# Original scent foundation: current prototype, not the whole game

The delivered baseline is a five-level, 32-district prototype with sight sacrifice, reactive intellect text and durable run history. Historical staged-build plans are historical, not the current feature inventory. At this slice's original baseline, hearing sacrifice and local ladder touch had not yet been added. Later source integrates both, as described in [the current inventory](CURRENT_PLAYABLE_STATE.md). Scent sacrifice, general blind/deaf navigation, adaptive runs and unresolved original lore branches remain incomplete. Blind plus deaf is not enabled or prohibited as permanent canon.

## Source intent and responsibility mapping

`docs/MOKSHA-source.md` explicitly describes smell indicating nearby/offscreen enemies, blood and treasure, and overlapping senses becoming less cluttered as senses are sacrificed. Broad eight-direction sectors, a nondirectional here category within32 units, two distance bands, 420-unit life / 300-unit supply reach, 140-unit near band, four samples per second, six displayed groups and a 150ms arrival fade are original tuning decisions, not user quotations or measured balance.

The pinned Dead Cells developer diary and Team Cherry map-design interview in NOV12_OPENING_LAYOUT.md inform quiet exploration, optional discoveries and encounter progression, not a copied room or scent implementation. The actual prior shapez REA/source investigation in REFERENCE_FOUNDATION.txt grounds domain/adapter ownership only; it is not recovered Dead Cells code or evidence of an existing smell algorithm. No third-party code or art was copied.

- `perception/local_scent_query.gd`: pure detached facts to capped coarse groups. No nodes, files, state changes or terrain query. Exact offsets are input only; output has bearing (-1 here or0..7), band, life/supply and wounded boolean, never target coordinates, IDs, health, count or attack timing.
- `perception/scent_observer.gd`: weak current-room registrations; authoritative health reads and actual prerequisite/reward-ledger checks; room/session/modal/death retirement. No collision, actor input, damage, audio, global NoiseBus, persistence or objective authority.
- `perception/scent_view.gd`: original operator-relative wisps/patches and diamonds, not silhouettes at enemy positions. Split wisps denote blood without relying on colour. New marks fade in; invalidated/retired marks disappear immediately. Pure presentation guard prevents old room/session marks being drawn between updates. Placement consumes the actual HUD caption-safe rectangle; a cue may move inward on its coarse ray to fit, never flip bearing. Whole patch extents are protected. If no safe location exists outside the inner24-unit contour, the cue is omitted rather than painted over UI.
- Host: creates the adapter and retires it before replacing a district. Existing journal includes a category legend without optional reward coordinates. No new panel or notification stream.

## Actual scope and limits

Life sources are living, current-room enemies with committed health. Supply sources are unclaimed field caches and available optional recoverable reward objects, excluding already awarded sector/objective identities even after retry. Mandatory controls, lore terminals without rewards, unavailable dependencies, corpses and retired rooms do not generate supply/life marks. Scent intentionally works through nearby walls; it is not sight or physical smell simulation. Only the current district is sampled, not future rooms.

Registration and query are capped at64 source records; rendering at6 aggregated marks. Existing authored district populations fit this cap. Overflow takes registered enemies before reward records and may omit supplies; this is a bounded prototype limitation, not a promise of arbitrary large-level support. Bands and aggregation intentionally discard information. Scent does not reveal safe terrain, ladders, doors, precise enemies or perfect parry timing. Sonar, body echo and the companion remain separate. It does not make blind-and-deaf navigation playable.

No new save fields or preference persistence are introduced. Scent is available by default in sighted and blind+sonar modes; disabling the observer is a QA comparison, not a shipped sense sacrifice or settings menu.

## Validation and honest status

`campaign/quality/nov12_scent_contract.gd` covers pure quantization/schema, bounded output, real-host optional reward claim/retry, actual health-path wound change, disabled/menu/death/room/session retirement and no health writes. It uses explicitly seeded positions and a real compatibility damage call; it does not claim physical collision or natural traversal. Logs must be rejected on script errors even if a summary marker says passed.

Early adapter checks found a QA assumption about enemy health-node placement and a typed empty-array return error. Both attempts were retained externally and rejected; neither is a clean pass. An initial import omitted explicit XDG config/cache roots and logged permission errors; fresh isolated import corrected the runner environment, not source access policy.

Required native acceptance remains separate: compare faint sighted and blind+sonar readability, ordinary-input optional exploration and blood cues, journal clearance, no combat/HUD obstruction and meaningful perception versus a disabled comparison. Bot completion and seeded screenshots alone are not proof a person can interpret scent. Do not label the entire original game complete.

Native review of bed0580 found that an overly conservative hardcoded top margin removed the upper supply cue. The follow-up replaces that margin with actual HUD bounds and tests north-cue retention, inward placement and full-patch clearance. The first external native fixture also had actor process-mode toggle errors and stale staged scenery placement; its run is rejected, not gameplay/contrast acceptance. The repaired external fixture must be reviewed again.
