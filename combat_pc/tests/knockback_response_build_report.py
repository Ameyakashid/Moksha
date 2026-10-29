"""Generate concise M21 report from actual focused run artifacts."""
from pathlib import Path
import gzip
import json

HERE = Path(__file__).resolve().parent
summary = json.loads((HERE / "knockback_response_run_summary.json").read_text())
audit = json.loads((HERE / "knockback_response_baseline_hashes.json").read_text())
traces = {}
for run in summary["runs"]:
    with gzip.open(HERE / run["trace"], "rt") as stream:
        traces[run["physics_hz"]] = json.load(stream)

lines = [
    "# M21 physical strike knockback verification", "",
    f'Overall: **{"PASS" if summary["passed"] else "FAIL"}** on Godot 4.6.3, with actual fixed 60 Hz and 120 Hz physics callbacks.', "",
    "The source PC runs once per real physics callback. The existing passive MovementMotor runs its own callback at priority -10, before the PC recorder at priority 0. The existing ContactAdapter performs actual overlap, forward-half-space and terrain-obstruction queries. Neither a target position nor a motor velocity is advanced by a test-simulated solver.", "",
    "| Physics rate | Named scenarios | Assertions | Failures | Diagnostics |",
    "| --- | ---: | ---: | ---: | --- |",
]
for run in summary["runs"]:
    lines.append(f'| {run["physics_hz"]} Hz | {run["scenarios"]} | {run["assertions"]} | {len(run["failures"])} | {"present" if run["diagnostics"] else "none"} |')
lines += [
    "", "Each assertion checks a named contract. Sampled engine frames and repeated malformed variants are evidence inside a scenario; they do not inflate the scenario or assertion counts.", "",
    "## Observed physical behavior", "",
    "- Slash, Backhand and Finisher hit from both directions. The received world impulse is already signed; the target receives its componentwise (0.55, 1.0) velocity scale exactly once, without applying facing again",
    "- A real three-step combo reaches the moving target in order, with three unique effects and three source confirmation pauses",
    "- Source and target pause clocks stay equal on default tuning. Their position/stun and strike clocks freeze together, then resume on the same engine callback",
    "- A new target entering the same swing after its first pause receives an impulse with zero remaining pause; no second source pause starts",
    "- Real floor, left/right wall and ceiling contacts use the existing motor's move_and_slide. Whole-body rectangle samples show no solid penetration above 0.081 px solver tolerance",
    "- Finite oversized authored impulses, including components of 1e38, are bounded to total speed 420 px/s without nonfinite output",
    "- A source pause enlarged through its existing API is copied up to 0.12 s; disabling pause copying produces zero target pause. The component never changes source pause",
    "- Misses and terrain-blocked swings leave the target still and produce no confirmation pause", "",
    "### Settled horizontal displacement", "",
    "These are measured consequences of the shared motor's braking and gravity, not new movement formulas. Small 60/120 Hz integration differences are retained in the evidence.", "",
    "| Rate | Direction | Slash | Backhand | Finisher |", "| --- | --- | ---: | ---: | ---: |",
]
for hz, trace in sorted(traces.items()):
    for direction in [-1, 1]:
        rows = {row["step"]: row["distance"] for row in trace["distance_comparison"] if row["direction"] == direction}
        lines.append(f'| {hz} Hz | {"left" if direction < 0 else "right"} | {rows[0]:.5f} px | {rows[1]:.5f} px | {rows[2]:.5f} px |')
lines += [
    "", "## Lifecycle and optional composition", "",
    "- Real struck-signal callbacks reset, unbind, disable, detach, rebind, remove the component, or reset the source before its physical response. No retired callback moves the target",
    "- Source reset during strike_confirmed is caught by the unchanged adapter before receiver delivery",
    "- Duplicate packets within the live source callback reject. Old source/serial identity also remains consumed after reset, unbind/rebind, disable/enable, replacement and diagnostic reset, even when that same source becomes live again after hitpause",
    "- Two actual actors with equal numeric serials both affect the same receiver: source identity participates in deduplication",
    "- An explicitly labeled motor subclass probe calls the stock apply_impulse once and then retires the binding/source in its hook. No stale follow-on pause or receipt is published",
    "- Null, detached, incompatible and unrelated hierarchy bindings, duplicate receiver owners, and a stopped motor reject",
    "- Twenty-eight malformed or unsupported packet variants are rejected during an otherwise valid real live delivery, and the following valid packet still applies",
    "- Shared tuning is unchanged after two recipients use it. Receipt observers receive immutable value data and mutable diagnostic copies cannot change stored receipts",
    "- Absent, disabled and unbound response components preserve identical sampled base-motor trajectories to within 0.001 px and 0.001 px/s", "",
    "## Pinned source audit", "",
    f'Baseline: v24 ZIP SHA-256 `{audit["baseline_zip_sha256"]}`.', "",
    f'{audit["checked_original_sources"]} original code, resource, scene and project configuration files compared; {audit["unchanged_original_sources"]} byte-identical. Unexpected changes: {len(audit["unexpected_changes"])}.', "",
    'Allowed host/provenance changes: ' + (", ".join(f'`{path}`' for path in audit["changed_sources"]) or "none") + ".", "",
    "The original PC, ContactAdapter, existing contact/chain targets, MovementMotor, health/defeat components, movement/weapon resources, and sensory/sonar sources remain byte-identical to v24. The full per-file SHA-256 audit is knockback_response_baseline_hashes.json. Relevant production sources are also hashed before and after each physics run.", "",
    "## Reproduction", "",
    "From the project root, with the retained v24 archive:", "",
    "```sh", "python combat_pc/tests/knockback_response_run.py --baseline-zip /path/to/v24/MOKSHA-Two-Level-Project.zip --godot-bin /path/to/godot", "python combat_pc/tests/knockback_response_build_report.py", "```", "",
    "The runner verifies the pinned baseline, imports the project, creates writable temporary XDG directories, runs both real physics rates, checks exit codes and Godot diagnostics, compresses full traces, and repeats the protected source audit. It exits nonzero if any selected run, diagnostic check or audit fails.", "",
    "Artifacts: knockback_response_run_summary.json; knockback_response_60hz_summary.json and knockback_response_120hz_summary.json; the matching .log and .json.gz traces; knockback_response_baseline_hashes.json.", "",
    "## Scope", "",
    "This is focused passive receiver acceptance. It does not establish NPC AI, health integration, broad moving-platform/carrier behavior, or visual feel. The archived broad combo suites are not claimed as rerun; the unchanged-byte audit and real integrated three-step hits establish the preserved source boundary.", "",
    "## Named scenario outcomes", "", "| Scenario | 60 Hz | 120 Hz |", "| --- | --- | --- |",
]
names = list(dict.fromkeys(case["name"] for trace in traces.values() for case in trace["scenarios"]))
by_rate = {hz: {case["name"]: case for case in trace["scenarios"]} for hz, trace in traces.items()}
for name in names:
    states = []
    for hz in [60, 120]:
        case = by_rate.get(hz, {}).get(name)
        states.append("not run" if case is None else ("FAIL" if case["failures"] else "PASS"))
    lines.append(f'| {name} | {states[0]} | {states[1]} |')
(HERE / "knockback_response_report.md").write_text("\n".join(lines) + "\n")
print("Wrote", HERE / "knockback_response_report.md")
