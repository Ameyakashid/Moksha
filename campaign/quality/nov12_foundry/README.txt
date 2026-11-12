Level2 foundry atmosphere candidate from fe9936a

Responsibility map: follows existing district-owned derived view boundary,
informed by previously inspected public shapez map/map_view lifecycle evidence.
No copied implementation. CampaignScenery owns Architecture/FoundryDepth;
explicit district identity and camera values only. No saves, input, physics,
objectives or actor authority. Entire subtree hides with sight trade.

Original foundry painting and cyan/amber industrial palette replace the sparse
flat bay appearance for Level2. Different Thermal/Freight modulation, distant
crane and service galleries, restrained worker animation. Painting is one shared
plate, not six individually authored district backgrounds. Old procedural paint
is suppressed beneath the opaque plate to avoid duplicate rendering.
Workers are derived paint, max9visible and zero per-person nodes. Camera moves
redraw the bounded visible view;15Hz scheduling applies only to stationary views.
No per-frame asset generation, lighting simulation or physics crowds.

Focused tests: nov12_foundry/contract.gd; existing adapter test expanded explicitly
to Level2 and old scenery contract unchanged. Six new Level2 nodes add6recursive
node assertions (2,575 to2,581), not six new gameplay acceptance categories.
Capture.gd directly stages Thermal/Freight positions and blind view, NOT route proof.
Record_route.gd starts from an explicit district checkpoint, then ordinary
existing automated input. It is not manual play or complete campaign proof.

Budget: one2,221,563byte original PNG addition is explicitly accounted for in
assets_budgets.json inventory_bytes limit only. All other limits unchanged.
This is source inventory allowance, not GPU memory, FPS or installed size.

Validation measurements and limits will be appended after native matched check.
Frozen fe9936a release and delivered artifacts are not modified by this branch.
