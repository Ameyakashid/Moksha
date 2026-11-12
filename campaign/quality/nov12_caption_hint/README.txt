THERMAL COOLANT CAPTION HINT - CANDIDATE, NOT RELEASED
Base d807d68. Only Thermal coolant authored definition adds caption_side:left.
The existing objective specification carries this optional presentation field;
logic, save IDs, objective positions/radii, dependencies and collisions unchanged.
The catalog explicitly preserves unknown presentation fields. The view accepts
only the string left; missing/type-invalid/unknown hints use the exact old path.

Ownership rationale: local content owns an authored composition preference;
caption rendering owns measured text, HUD safe bounds, icon exclusion and fitting.
No moving-player tracking or generic collision avoidance was introduced.
A left preference is used only when the whole block fits inside HUD safe bounds;
otherwise existing placement/fallback/culling remains authoritative. No state is
written back to content or simulation.

Headless:580 new hint checks cover locked/available/completed text, controller,
wrapped HUD,320/640viewport, left fit, overflow/invalid fallback, golden no-hint,
offscreen and blind ownership. Existing611 safe-caption and151 objective-paint
checks pass, plus23 content checks. Layout text comparison removes only the new
field and is byte-identical to d807, protecting all other authored data.
Native lower/upper ladder, both manifold approaches, wrapped HUD, controller
available and blind fixtures inspected on cab42a7. Scoped visual acceptance passes:
coolant no longer crosses ladder player and does not replace that with own-icon,
other-label or sign overlap in tested views. See native_receipt.json for hashes,
failed available-state setup attempts retained, exact bounds and limitations.
All accepted native runs exit0, only unsupported VSync warning. No resource leaks.
These are staged visual fixtures, not progression, physical controller, Windows,
full-level or FPS acceptance. Frozen d807 and its deliveries remain untouched.
