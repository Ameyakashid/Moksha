# Listener independent evidence

- REVIEW.md: findings, reproduction commands, scope and limits.
- summary.json: both-rate check counts and baseline identity.
- listener_independent_review.gd.txt: supplementary isolated Godot probe source; retained as text, not executable project source.
- listener_independent_60.json / listener_independent_120.json and independent_60.log / independent_120.log: supplementary results.
- listener_60.json / listener_120.json and listener_60.log / listener_120.log: independently rerun production regression results.
- final_review_hashes.json: exact reviewed source SHA256, current-live equality and baseline status.
- archive_source_delta.json / archive_source_delta.patch: frozen sentinel archive source comparison.

No extra Python runner is required. The reproduction commands in REVIEW.md run the Godot probes directly in an isolated project copy.
