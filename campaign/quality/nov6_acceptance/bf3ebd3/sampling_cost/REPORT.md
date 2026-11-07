# Frozen controller sampler: bounded performance comparison

## Finding

No material absolute sampler burden or call-dependent retained-memory growth was found in this bounded shared-cloud test. There is a clear relative slowdown in the tiny raw-device method: about 9× baseline, but only about 38–39 microseconds added per call. Playing HUD snapshots add about 37–41 microseconds. The explicit input-override control is effectively unchanged. These measurements do not justify changing the frozen runtime.

This is a headless raw-input/HUD microbenchmark, not full renderer or campaign performance, FPS, controller hardware, Windows, audible output, or target-machine validation. There is no pre-agreed performance budget, so “material” here refers only to the observed small absolute cost in this environment.

## Sources and isolation

- Baseline: `b2e7f352b96b11e9a5137145416ddeaf4a974e27`.
- Candidate: `bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5`.
- Exact `git archive` copies under `baseline/` and `candidate/`. Production tree was not edited or run by this comparison. Per-file SHA-256 manifests are in `source_manifest.json`; all archived tracked files remained byte-identical after import and measurement.
- The only non-test/non-document runtime differences are the new `campaign/input/controller_bindings.gd` and the small `campaign/logic/campaign.gd` changes.
- Godot 4.6.3.stable.official.7d41c59c4, headless, Dummy audio, fresh private HOME/XDG directories for every process, `save_enabled = false`, no real connected joypads.

## Method

The external harness creates the real campaign scene and first district, then stops unrelated process/physics callbacks while retaining the actual host, player, room, goals and HUD. It calls the exact archived `_raw_campaign_input()` and `_hud_snapshot()` methods. `_input_tick_active` is false and the default source is null, so the tested HUD path really samples raw devices rather than bypassing through a scripted override. Input states and HUD snapshots are checked unchanged after each measurement.

Five matched scenarios cover neutral defaults, device-0 stick/guard held, modal-blocked stick/guard, stick/guard held before host construction (candidate initial-hold branch), and an explicit Dictionary override as a negative control. Synthetic device 0 is intentional: both revisions support it and must return matching data. There are no physical devices. Multi-device functional support was not inferred from timing.

Six independent baseline/candidate pairs use balanced AB, BA, AB, BA, AB, BA process order. Every scenario warms up with 1,000 raw calls and 300 HUD calls, then measures four batches of 4,000 raw calls and 1,000 HUD calls; raw/HUD batch order alternates. Results include loop/result-size bookkeeping equally on both sides, without empty-loop subtraction. This yields 24 timed batches per revision/scenario/path and 1,200,000 timed top-level calls in total.

Each process is sequential and runs at nice +10. Godot Time.get_ticks_usec measures wall-clock elapsed time, including scheduling delays, not isolated process CPU cycles. CPU cost is inferred only cautiously from interleaved comparisons. Scene construction and warmup are excluded from the per-call timings.

All 12 timed processes completed without engine errors/warnings; 402 harness checks passed. Raw snapshots, HUD guidance and HUD key counts matched between revisions in all 30 scenario/pair comparisons. The two pilot processes are preserved but excluded from the reported statistics.

## Timing results

Times are microseconds per top-level call. Medians and p10–p90 use 24 batch averages per revision; paired deltas use six pairs of within-process four-batch medians.

| Scenario | Path | Baseline median | Candidate median | Candidate p10–p90 | Paired delta median | Paired delta min–max |
|---|---|---:|---:|---:|---:|---:|
| neutral | raw | 4.861 | 43.192 | 41.310–55.140 | +37.858 | +36.740–+53.952 |
| neutral | hud | 31.529 | 69.651 | 67.539–107.741 | +37.095 | +27.956–+92.204 |
| held_device0 | raw | 4.850 | 43.409 | 41.344–51.108 | +38.714 | +34.769–+50.190 |
| held_device0 | hud | 33.443 | 69.486 | 66.830–98.071 | +36.798 | +20.642–+56.276 |
| blocked_device0 | raw | 4.846 | 44.746 | 41.530–52.008 | +38.641 | +37.177–+43.993 |
| blocked_device0 | hud | 34.085 | 71.870 | 68.166–91.652 | +39.327 | +22.737–+42.464 |
| initial_held_device0 | raw | 4.974 | 45.012 | 42.733–53.504 | +39.150 | +38.447–+46.436 |
| initial_held_device0 | hud | 33.009 | 76.288 | 69.152–88.725 | +41.179 | +36.771–+51.980 |
| explicit_override | raw | 0.774 | 0.745 | 0.706–0.819 | -0.016 | -0.101–+0.049 |
| explicit_override | hud | 25.396 | 25.753 | 24.500–27.767 | -0.012 | -1.985–+1.882 |

One extra raw sample plus one playing HUD snapshot therefore adds roughly 0.08 ms at the typical observed rates. Purely illustrative arithmetic at 60 raw and 60 HUD calls per second is around 4.5–4.8 ms of additional sampled work per second, about 0.5% of one CPU second; actual process/render rates and hardware performance were not measured. This must not be converted into an FPS claim.

The candidate’s neutral HUD pair-delta outlier reached +92.2 µs, illustrating why pooled ratios alone would be misleading. The full per-batch min/max, standard deviation, process medians and paired statistics are preserved in `summary.json`. No statistical equivalence or target-platform guarantee is claimed.

## Retained memory and object counts

Every timed batch had zero object-count and resource-count change in both revisions. Candidate monitoring consistently showed 4,162 objects and 274 resources. Baseline showed 4,085 or 4,099 objects and 273 resources, depending on setup/queued lifetime timing; these whole-fixture counts are not an isolated attribution of every added object to the adapter.

A separate recorder-preallocated retention harness ran two more balanced AB/BA pairs. For each of five scenarios, it took seven checkpoints around six consecutive blocks of 4,000 raw and 1,000 HUD calls without retaining any per-call output. This adds 600,000 top-level calls. All 20 scenario runs had exactly flat native static-memory usage at every checkpoint, and zero object/resource growth. All four processes passed without engine errors/warnings.

The timing harness itself retains telemetry, producing 596–724 bytes between its before/after memory snapshots and about 19 KB across a full scenario. The pattern is identical in both revisions and is why the separate allocation-neutral recorder is provided.

Flat retained memory does not mean zero temporary allocations. Object/resource counters do not count all Array, Dictionary or String temporaries, and OS.get_static_memory_usage is current native allocation size rather than an allocation-event or peak-churn counter. The adapter calls InputMap.action_get_events for eight alias checks per ordinary sample. Transient work is included in elapsed timing, but allocation counts were not instrumented.

## Environment and limits

- Shared Linux cloud VM; reported CPU is AMD EPYC 9V74. 9 logical CPUs / 9 affinity CPUs visible. No exclusive CPU, pinning or frequency control.
- Other campaign checks were in progress. One-minute load observations during timed runs ranged 3.41–4.24. Timed process wall durations totalled 59.3 seconds, including setup/warmup; Godot microbenchmark samples are a subset.
- First district and frozen scene state only. No rendering, moving-actor simulation, full-campaign frame budget, resource-streaming latency, alias startup/teardown cost, large connected-device populations, or actual USB/Bluetooth controller event-rate measurement.
- Initial-held scenario uses native Godot synthetic device-0 state and no physically connected devices; it is not a hardware hotplug stress benchmark.
- All source hashes were rechecked after measurements. No runtime patch, optimization, commit or release artifact was made.

## Reproduce and inspect

From this directory, with Godot 4.6.3 installed:

```sh
python3 harness/run_bench.py
python3 harness/run_retention.py
python3 harness/analyze.py
```

Use new output/home locations before rerunning if preserving the original evidence. The checked-in external harnesses and raw logs are the record; do not move them into production without review.

- `summary.json`: aggregate timings, cross-version checks, retention data, source integrity.
- `raw/pair*.json` and `.log`: all six timed pairs and exact commands/load observations.
- `raw/retention*.json` and `.log`: independent flat-memory checkpoints.
- `raw/pilot-*.json`, `raw/*import.log`: excluded pilots and isolated imports.
- `harness/`: reproducible GDScript/Python measurement and analysis programs.
- `environment.json`: binary hash, OS/CPU/load details and limitations.
- `source_manifest.json`: every archived tracked-file SHA-256.
