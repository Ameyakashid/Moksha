# November 12 editor metadata checkpoint

This source-only follow-up to `fe9936a` records 156 missing editor sidecars:
80 script `.uid` files and 76 image `.import` files (78,773 bytes). No runtime
logic, assets, ignore rules, or original `combat_pc/` / `simulation/` files change.
The delivered `fe9936a` Windows build is not rebuilt or replaced by this change.

## Policy and rationale

Commit script UID sidecars and asset import settings; keep generated `.godot/`
caches ignored. The three production script sidecars are for
`controller_bindings.gd`, `audio_feedback.gd`, and `campaign_sonar.gd`.
Their current references use file paths, so omission did not block play; keeping
UIDs stabilizes editor identity and avoids a dirty clone after import.

Official guidance:
- [Godot script UID guidance](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/)
- [Godot 4.6 import process](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/import_process.html)
- [Godot 4.6 project organization](https://docs.godotengine.org/en/4.6/tutorials/best_practices/project_organization.html)

Do not globally ignore `.uid` or `.import`. Do not blanket `.gdignore` the
quality tree: `nov6_transition_stress/transition_stress.gd` dynamically loads
its mutation fixtures, and `cumulative_upgrade_lifecycle.gd` extends that script
through `res://`. Ignored resources cannot be loaded with `load`/`preload`.
Selective archival-folder changes require a separate reference audit.

## Verification

A fresh worktree from `fe9936a`, with these sidecars copied before import, was
imported using Godot `4.6.3.stable.official.7d41c59c4`:

```sh
godot --headless --editor --import --path /path/to/checkout
```

Use writable XDG data/config/cache directories in restricted environments.
The first attempt inherited unwritable data/config locations and reported
editor-directory errors. After isolating all XDG directories and moving that
attempt's `.godot` cache aside, one clean import exited 0 with no errors or
warnings. Neither attempt changed tracked source bytes or copied metadata.
The clean import produced no additional untracked UID/import sidecars.
All 688 script UID sidecars are unique. All 156 additions match the previously
inspected metadata byte-for-byte; no absolute machine paths are present.
No native desktop test, gameplay test, export, or rebuild was run for this
metadata-only change.

## Existing packaged-product audit

Read-only parsing of the delivered `fe9936a` `MOKSHA.pck`:
- Size: 10,590,412 bytes; 784 directory entries; parser consumed exact EOF.
- SHA-256: `1e2a6480d0cb68caae2ede905f6e7ec03be864c823a3081fa862560ab7bc7a36`.
- No `quality`, `tests`, `evidence`, `history`, or `qa_audit` directory entries.
- No `.mp4`, `.avi`, `.webm`, or `.mov` entries.
- Source-stage provenance contains 831 files and six image files, all in
  `assets/` or `campaign/assets/`; no archived QA images or videos.
- The filtered packager excludes QA/evidence trees, rather than exporting the
  whole editor checkout. It conservatively retains legacy `combat_pc` fixtures
  and `NATIVE_CAPTURE.json`; these are not archived QA-media leaks.

This audit establishes package contents and clean editor import behavior, not
new Windows execution or gameplay coverage.
