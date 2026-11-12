# Residential optional-cache clarity

Original bounded layout change from `c029797`, not a full district redesign.
`l3_homes` previously placed its optional cache and mandatory courtyard shelter
at the same (2940,300) location, labelled OPTIONAL SUPPLIES. The cache now sits
at (2840,190), on a new one-way landing Rect2(2770,190,150,18). Distance from
shelter is148.66px, greater than the sum of cache45px and objective52px radii.
The shelter sign now says COURTYARD SHELTER; separate OPTIONAL SUPPLIES and
EAST ROOFS > ^ signs distinguish reward and recovery. Mandatory shelter remains
(2940,300). All existing platforms, ladders, enemies, objective IDs/dependencies,
exit geometry and save code are unchanged. No atmosphere changes.

Design hypothesis: make the existing roof-to-courtyard-to-roof journey legible,
with an actual optional side discovery rather than a coincident second E press.
This uses the already documented Dead Cells pressure/relief and Hollow Knight
optional-discovery/reconnection principles, not copied geometry. The new shelf
is not required for the mandatory route. No enemies or mandatory backtracking
were added. No claim of measured improvement in human enjoyment or pacing.

## Focused verification

Godot4.6.3, headless60Hz, explicit district-start fixture and optional pre-run
sight trade. Neutral lens. After setup, real production movement/buttons and E
input dispatch only: no position/health/enemy/goal/gate writes. Archive dismissal
uses the existing modal-input release helper. These are automated district runs,
not manual play or full-campaign completion.

| Choice | Sight | Actual simulated active seconds | Result |
|---|---|---:|---|
| Collect | Retained |35.5167|Exit; cache collected; shelter observed|
| Skip | Retained |37.2333|Exit; cache absent; shelter observed|
| Collect | Traded |31.5000|Exit; cache collected; shelter observed|
| Skip | Traded |28.5667|Exit; cache absent; shelter observed|

All four runs: no source drift across963 existing source hashes, no failures,
clean teardown/exit0 and no engine warnings/errors. JSON files retain raw source
hashes, events, prompt receipts and trace. Collect runs record actual supported
landings at cache shelf, return to courtyard, then existing roof ladder. At cache
interaction proximity the mandatory shelter selector is not selected, and shelter
is outside its radius. Skip runs never enter cache interaction proximity.
Timing differences include combat/navigation variance; not a speed comparison.

`contract.gd`:17 checks pass. Preserves original ladder/enemy/exit/platform data;
checks separated radii and mandatory shelter->roofs->exit dependencies. For all
four cache/sight combinations, previous-layout save data encodes identically and
existing campaign codec decodes the checkpoint with unchanged archive identity.
This is codec compatibility evidence, not a new UI-driven Retry/Continue test.
Contract was added after route runs and does not modify runtime or route fixture.

Reproduce after headless editor import:

```sh
godot --headless --path . --fixed-fps 60 --script campaign/quality/nov12_residential_cache/route.gd -- --collect
godot --headless --path . --fixed-fps 60 --script campaign/quality/nov12_residential_cache/route.gd --
godot --headless --path . --fixed-fps 60 --script campaign/quality/nov12_residential_cache/route.gd -- --collect --sacrifice
godot --headless --path . --fixed-fps 60 --script campaign/quality/nov12_residential_cache/route.gd -- --sacrifice
godot --headless --path . --script campaign/quality/nov12_residential_cache/contract.gd
```

Restricted environments need writable XDG directories. No native render/desktop,
full campaign, Windows run or rebuild performed. Integrated Homes signs versus
the separately developed waterworks-window art still need visual review.
