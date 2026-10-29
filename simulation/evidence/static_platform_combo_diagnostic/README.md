# Full combo120 diagnostic

Both the candidate and sealed backdrop pass the identical unchanged full combo120 test after cold tmpfs copies were relocated to disk. Each executes 295 scenarios and 1,360 checks with zero failures or error log lines, in approximately 56 seconds and a measured peak resident footprint of 2.56 GiB. Both source manifests match their expected frozen baselines. This closes the isolated diagnostic only; aggregate acceptance remains separate.

The earlier two aggregate combo120 SIGKILL causes remain unproven. Static source inspection identified accumulated per-tick telemetry, deep copies and final whole-report serialization as a large-memory workload. This is consistent with the measured footprint, not proof of an OOM kill. No thresholds, timeouts, source or test selection were weakened.

The first fresh baseline import crashed in Godot. Its subsequent test returned exit 0 but emitted missing-resource errors and is explicitly rejected. The failed import/test artifacts remain preserved at the paths and hashes recorded in diagnostic_summary.json. Import retry succeeded, followed by the accepted full baseline run.

The 208 MiB full trace reports remain outside the delivery package in the recorded scratch locations. Bounded measurement files retain exact commands, hashes, test counts, timing and RSS. Logs and their hashes support the stated error checks.
