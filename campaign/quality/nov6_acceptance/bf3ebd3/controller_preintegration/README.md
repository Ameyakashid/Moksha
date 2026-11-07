# Controller fix pre-integration evidence

These are the frozen v5 candidate results before integration as `bf3ebd3`, not a substitute for the complete integrated campaign acceptance. The exact two production-file hashes match that commit. Independent review: 9,226 positive assertions, plus preserved paired controls. Owner source: 1,176 checks. Owner actual PCK: 426 device checks plus three identity checks. The baseline fails 54 of 213 checks at each rate, all on devices 1 and 3; device 0 passes.

The independent archive includes raw reports/logs, historical failed candidates, immutable fixture snapshots and a hash manifest. The reusable runner is installed in `campaign/quality/nov6_controller_independent`; its README defines scope and historical references. Owner scripts are retained as historical provenance and are not advertised as the final portable runner. The final standalone device fixture is part of `tools/verify_nov6.py` and the actual-PCK packaging gates.

Synthetic Godot input, not physical controller hardware. Direct action-name injection is not mirrored to aliases; explicit campaign input_override remains supported unchanged.
