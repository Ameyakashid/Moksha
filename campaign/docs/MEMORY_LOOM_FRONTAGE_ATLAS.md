# Original Memory Loom frontage atlas

Art-only integration after layout `30574317047133f2980e0bb78b6b782c4558df10`. That layout's positions, route order, objective dependencies and mechanics remain unchanged.

The prior panorama-crop frontage was rejected in native review: repeated curved multi-storey tower crops looked like collage when used as local cabinets, and enlarged inhabited glazing was blurry. Preserve the original panoramic painting; use the new purpose-built front-elevation drawers, service alcove and spool racks only for district-local material rendering.

## Provenance and ownership

`campaign/assets/memory/archive_frontage_original.png` is the exact original generated artifact: 1774 × 887 RGBA, 2,168,799 bytes, SHA-256 `549e2293fd3e1be5aaad49ad3544a93fe0a7ee968b22036586da8760075b0c18`. Exact prompt and truthful provenance are alongside it. One generation, original MOKSHA panorama supplied for material/style only; no commercial reference, code or assets. No pixel edits, alpha cutoff or second generation. The requested dimensions/positions were not honored exactly; actual image regions were inspected and mapped instead.

The habitat remains an optional district-owned Node2D behind gameplay: no process callback, collisions, simulation, inputs or saves. Same bounded culling, sight hiding and separate signs. Original drawer/spool art replaces redundant procedural spines/circles/receipts; original counter artwork replaces blurred glazing and duplicate rails.

## Sampling and layers

Guarded regions: archive `(36, 26, 1699, 275)`, commons `(37, 342, 966, 232)`, gallery `(34, 615, 1704, 243)`. Each region uses uniform scaling, never stretch-to-fill. Widths 880 / 460 / 970 world pixels, bottoms 294 / 292 / 74 respectively, all inside existing cluster rectangles. Modulate `(0.82, 0.86, 0.94, 1)` is a restrained cool tint; native review must judge whether foreground silhouettes still dominate.

Commons draws rear bay, eight separate decorative residents, then original foreground counter band `(37, 513, 966, 61)`. Counter top maps to 262.95 world pixels, below heads around 248 and above feet 269. Residents grouped 3 / 2 / 3 at x = 1756, 1780, 1815 / 1880, 1906 / 2012, 2039, 2070, avoiding principal opaque mullions rather than uniformly lining up. They remain decorative, not rescue/interaction targets. No extra animation.

Atlas gutters contain faint stray alpha ≤ 16. No cleanup was applied. Guarded sampling and `clip_uv` restrict spill; actual 640 × 360 native review must judge fringes, material readability, counter occlusion and bright-edge/platform confusion. This is not declared production-clean or native-accepted merely because source math is valid.

## Historical integration checkpoint

At art commit `6a65ac5`, static source/hash and rectangle/aspect checks passed. One official headless editor import exited 0 without parse/script errors and generated tracked atlas import metadata; the PNG bytes remained unchanged. Runtime and native visual acceptance were not established by that import.

The static asset audit at that checkpoint also exposed an existing Market-material budget overrun. The atlas patch added only its exact asset-byte allowance and did not silently rebase unrelated limits. That historical audit is separate from later budget review or acceptance records. Both original panorama and new atlas bytes are hash-pinned. This document makes no final native, performance or fresh-gameplay acceptance claim.
