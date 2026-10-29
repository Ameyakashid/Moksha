# Native isolated actual-factory Warden review — 2026-10-19

Independent native reviewer ran `simulation/warden_review.tscn` in Godot. It uses
the actual mission host/factory, with explicit initial sector6 selection,
spawn920 and saving disabled. Ordinary controls followed; no AI disabling,
Health/phase writes, forced defeat, teleport or gate assignment was used.

Observed: broad orange/gold shoulders and crown distinguish Warden from the two
cyan sentries; warning ring and directional rectangle were readable. Ordinary J
reduced Warden's visible Health bar. A mixed exchange changed PC60→55. Shift+D
moved/rolled behind, then A/J attacked from the other side. A later yellow active
rectangle intersected hurt PC at21. R restored PC60 and all three guards. HUD fit
the viewport. F8 ended the view and desktop control was released.

Five JPEG captures, each1364x1024, show exchange, warning, roll, later phase and
reset. Exact filenames, sizes and SHA256 are in `native_warden_capture_hashes.json`.
The later-phase filename is a viewing moment, not proof of below-half phase2.

Not established natively: exact cut→sweep alternation, continuous bracing through
an incoming hit, successful timed counter, Warden defeat or full room clear.
Those mechanics have separate automated actual-contact evidence. This isolated
entry is not a full campaign playthrough, balance measurement, human reaction
measurement or audible-mix review.

The debugger displayed27 unexpanded entries, stable with no visible interruption.
Before project reload, an old evidence/test probe complained about absent
`review_counter_incoming_mutation.gd`; current references are archived `.gd.txt`
probe text, not active production dependencies. Current clean import/boot logs
are the authoritative separate check; no clean-debugger claim is made from this
native observation alone.

Fresh-directory verification subsequently passed clean import and the actual
review-scene boot without SCRIPT ERROR/ERROR, using exactly the frozen566 source
hashes. See `warden_clean_verification.json`; this closes the missing active-probe
dependency concern without reinterpreting the earlier native debugger display.
