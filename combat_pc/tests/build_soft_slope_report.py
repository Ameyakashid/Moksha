"""Validate complete, final M7 evidence before publishing either acceptance report.

This builder never runs Godot or modifies historical evidence. Run it only after
all fourteen final runs, their logs, and correction evidence have been collected.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / "combat_pc/tests"
RATES = (120, 60)
FILES = {
    "soft_slope": "soft_slope_results",
    **{f"{name}_compatibility": f"{name}_compat_m7_results" for name in
       ("movement", "combat", "traversal", "climb", "wall", "hard_landing")},
}
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
PINNED: dict[Path, str] = {}


class VerificationError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(str(message))


def sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def display(path):
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def pin(path, expected=None):
    path = Path(path).resolve()
    require(path.is_file(), f"Missing evidence: {path}")
    digest = sha(path)
    if expected is not None:
        require(isinstance(expected, str) and SHA256.fullmatch(expected), f"Invalid SHA-256 for {path}")
        require(digest == expected, f"Hash mismatch: {path}; expected {expected}, found {digest}")
    require(path not in PINNED or PINNED[path] == digest, f"Evidence changed while reading: {path}")
    PINNED[path] = digest
    return digest


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def read(path):
    path = Path(path).resolve()
    pin(path)
    def invalid(value):
        raise VerificationError(f"Non-finite JSON value {value} in {path}")
    return json.loads(path.read_text(), object_pairs_hook=unique_object, parse_constant=invalid)


def number(value, context):
    require(type(value) in (int, float) and math.isfinite(value), f"Expected finite number: {context}")
    return float(value)


def close(actual, expected, tolerance, context):
    require(abs(number(actual, context) - number(expected, context)) <= tolerance,
            f"{context}: expected {expected} ± {tolerance}, found {actual}")


def resource_path(path):
    require(isinstance(path, str) and path.startswith("res://"), f"Unexpected production path: {path}")
    result = (ROOT / path.removeprefix("res://")).resolve()
    require(result.is_relative_to(ROOT), f"Production path escapes project: {path}")
    return result


def verify_preservation():
    path = TESTS / "soft_slope_preserved_evidence.json"
    preserved = read(path)
    require(preserved.get("files") and preserved.get("archives"), "Historical preservation manifest is empty")
    # M7's manifest pins the current, already-accepted M6 documentation bytes.
    # It does not silently inherit exceptions from earlier report builders.
    require(not preserved.get("documentation_updates"), "M7 historical documentation exceptions require explicit review")
    for name, digest in preserved["files"].items():
        target = (ROOT / name).resolve()
        require(target.is_relative_to(ROOT), f"Historical path escapes project: {name}")
        pin(target, digest)
    for name, digest in preserved["archives"].items():
        require(Path(name).name == name, f"Unexpected archive name: {name}")
        pin(ROOT.parent / "moksha-backups" / name, digest)
    return preserved


def verify_continuity(scenario, suite, hz):
    context = f"{suite}/{hz}/{scenario['name']}"
    frames = scenario["frames"]
    require(frames, f"No samples: {context}")
    ticks = [frame["tick"] for frame in frames]
    require(all(type(tick) is int for tick in ticks), f"Non-integer sample ticks: {context}")
    require(ticks == list(range(1, len(frames) + 1)), f"Missing, duplicate or reordered actor samples: {context}")
    measurements = scenario["measurements"]
    if "physics_samples" in measurements:
        require(measurements["physics_samples"] == len(frames), f"Sample count mismatch: {context}")
    require(not measurements.get("sampling_gaps"), f"Recorded sampling gaps: {context}")
    for event in scenario["events"]:
        require(type(event.get("tick")) is int and 0 <= event["tick"] <= ticks[-1],
                f"Event outside sampled callback range: {context}/{event.get('event')}")
    if suite != "soft_slope":
        return {"actor_ticks": len(frames), "engine_ticks_and_deltas": False}
    engine_ticks = [frame["engine_tick"] for frame in frames]
    require(all(type(tick) is int and tick >= 0 for tick in engine_ticks), f"Invalid engine ticks: {context}")
    gaps = [b - a for a, b in zip(engine_ticks, engine_ticks[1:])]
    require(all(gap == 1 for gap in gaps), f"Actual physics callback discontinuity: {context}")
    require(measurements["engine_gaps"] == gaps, f"Engine-gap summary differs from samples: {context}")
    deltas = [frame["delta"] for frame in frames]
    require(measurements["callback_deltas"] == deltas, f"Delta summary differs from samples: {context}")
    for frame in frames:
        close(frame["delta"], 1 / hz, 1e-12, f"Actual callback delta: {context}/{frame['tick']}")
        require(isinstance(frame.get("before"), dict) and isinstance(frame.get("after"), dict),
                f"Missing immediate before/after observation: {context}")
        for side in ("before", "after"):
            for key in ("position", "velocity"):
                values = frame[side][key]
                require(len(values) == 2, f"Invalid {side}.{key}: {context}")
                for value in values:
                    number(value, f"{context}/{side}.{key}")
    return {"actor_ticks": len(frames), "engine_ticks_and_deltas": True}


def verify_run(run, suite, hz):
    context = f"{suite}/{hz}"
    require(run["physics_hz"] == hz, f"Wrong physics rate: {context}")
    if suite == "soft_slope":
        require(run.get("selected_group") == "", f"Filtered M7 run cannot establish acceptance: {context}")
    require(run["production_hash_stable_during_run"] is True, f"Unstable sources: {context}")
    require(run["starting_hashes"] and run["hashes"] and all(run["hashes"].get(name) == digest for name, digest in run["starting_hashes"].items()), f"Recorded start/end source mismatch: {context}")
    if suite not in ("movement_compatibility", "combat_compatibility"):
        require(run["starting_hashes"] == run["hashes"], f"Complete start/end inventory mismatch: {context}")
    for name, digest in run["hashes"].items():
        pin(resource_path(name), digest)
    for name in ("player.gd", "player.tscn", "resources/movement_profile.gd", "resources/movement_profile.tres"):
        require(f"res://combat_pc/{name}" in run["hashes"], f"Required production hash absent: {context}/{name}")
    require(run["failures"] == [], f"Reported failures: {context}: {run['failures']}")
    scenarios = run["scenarios"]
    require(scenarios and len({s["name"] for s in scenarios}) == len(scenarios), f"Empty/duplicate scenarios: {context}")
    total_checks = 0
    continuity = {}
    for scenario in scenarios:
        require(scenario["failures"] == 0, f"Scenario failure: {context}/{scenario['name']}")
        require(scenario["checks"] == len(scenario["assertions"]) > 0, f"Assertion count mismatch: {context}/{scenario['name']}")
        require(all(a["passed"] is True for a in scenario["assertions"]), f"Failed assertion: {context}/{scenario['name']}")
        total_checks += scenario["checks"]
        continuity[scenario["name"]] = verify_continuity(scenario, suite, hz)
    require(run["checks"] == total_checks, f"Run check count mismatch: {context}")
    short = suite.removesuffix("_compatibility")
    path = TESTS / f"m7_{short}_{hz}.log"
    pin(path)
    content = path.read_text()
    require(not re.search(r"SCRIPT ERROR|ERROR:|FAIL:|WARNING:", content), f"Engine diagnostic in {path}")
    completions = re.findall(r"MOKSHA [^\n]*?(\d+)Hz: (\d+) scenarios, (\d+) checks, (\d+) failures", content)
    require(len(completions) == 1, f"Expected exactly one completed run in {path}")
    require(tuple(map(int, completions[0])) == (hz, len(scenarios), total_checks, 0), f"Log/result mismatch: {path}")
    return continuity, {display(path): PINNED[path.resolve()]}


def minimum_m7_names(terminal):
    names = set()
    for magnitude in (1.0, .5):
        for mirror in (-1, 1):
            for vx in (-1, 0, 1):
                for vy in (300.0, terminal):
                    for intent in (-1, 0, 1):
                        names.add(f"plane {magnitude:.1f} mirror{mirror} vx{vx} vy{vy:.0f} input{intent}")
            names.add(f"long neutral {magnitude:.1f} mirror{mirror}")
    for direction in (-1, 1):
        for gap in (38, 40):
            for mode in ("stock", "instrumented"):
                names.add(f"zero-X phase mirror{direction} gap{gap} {mode}")
        for intent in (-1, 1):
            for mode in ("stock", "instrumented"):
                names.add(f"held observer mirror{direction} input{intent} {mode}")
        for shape in ("hill", "valley"):
            for magnitude in (.5, 1.0):
                names.add(f"continuous {shape} {magnitude:.1f} direction{direction}")
        for kind in ("flat", "slope"):
            names.add(f"discontinuous {kind} edge direction{direction}")
        for gap in (4, 38):
            names.add(f"floor wall component ordering direction{direction} gap{gap}")
        for prefix in ("separate slope flat seam", "slope jump departure", "uphill low ceiling",
                       "ceiling stops Y preserves X", "sidewall preserves upward jump",
                       "slope reverse brake and parsed jump", "moving slope pause transport"):
            names.add(f"{prefix} direction{direction}")
        for action in ("roll", "melee", "hurt", "hard"):
            names.add(f"shared slope movement {action} direction{direction}")
        for suffix in ("", " native origin"):
            names.add(f"actual lab slope course direction{direction}{suffix}")
        for prefix in ("supported huge host speed meets thin wall", "paused slope parsed tap and reset",
                       "removed slope during paused support", "explicit upward host departure",
                       "grounded uphill ceiling replacement"):
            names.add(f"{prefix} direction{direction}")
    names.add("one-way jump and targeted drop after slope approach")
    names.add("ceiling callback replacement keeps upward owner")
    return names


def first_event(scenario, name):
    matches = [event for event in scenario["events"] if event["event"] == name]
    require(matches, f"Missing {name} event: {scenario['name']}")
    return matches[0]


def verify_plane_measurements(scenario, hz):
    params = scenario.get("params", {})
    if "gradient" not in params:
        return
    frames = scenario["frames"]
    landed = [event for event in scenario["events"] if event["event"] == "landed"]
    require(len(landed) == 1, f"Expected one plane landing: {scenario['name']}/{hz}")
    tick = landed[0]["tick"]
    require(tick >= 1, f"Plane landing must be sampled: {scenario['name']}/{hz}")
    contact = frames[tick - 1]["after"]
    measured = scenario["measurements"]
    close(measured["entry_vx"], contact["velocity"][0], 1e-8, f"Plane entry VX: {scenario['name']}")
    post = frames[tick - 1:]
    losses = sum(not frame["after"]["grounded"] for frame in post)
    require(measured["support_loss_ticks"] == losses == 0, f"Plane support loss: {scenario['name']}/{hz}")
    settled = next(((frame["tick"] - tick) / hz for frame in post if abs(frame["after"]["velocity"][0]) <= .02), -1.0)
    close(measured["settle_seconds"], settled, 1e-8, f"Plane settle time: {scenario['name']}")
    for seconds in (.05, .10, .20, .40, .80, 1.0, 2.0):
        if seconds > params["post_contact_seconds"] + 1e-6:
            continue
        sample_tick = tick + round(seconds * hz)
        require(sample_tick <= len(frames), f"Truncated post-contact interval: {scenario['name']}/{hz}")
        sample = frames[sample_tick - 1]["after"]
        close(measured[f"travel_x_{seconds:.2f}"], sample["position"][0] - contact["position"][0],
              1e-7, f"Plane travel {seconds}: {scenario['name']}")
        close(measured[f"velocity_x_{seconds:.2f}"], sample["velocity"][0], 1e-7,
              f"Plane velocity {seconds}: {scenario['name']}")


def observation_signature(scenario):
    frames = []
    for frame in scenario["frames"]:
        row = {"tick": frame["tick"]}
        for side in ("before", "after"):
            row[side] = {key: value for key, value in frame[side].items() if key != "support_id"}
        frames.append(row)
    events = [{**event, "data": {key: value for key, value in event["data"].items() if key != "surface_id"}}
              for event in scenario["events"]]
    return {"frames": frames, "events": events}


def check_corrections(suites):
    path = TESTS / "soft_slope_correction_evidence.json"
    evidence = read(path)
    corrections = evidence["corrections"]
    require(corrections and len({item["id"] for item in corrections}) == len(corrections), "Empty/duplicate corrections")
    verified_artifacts = {}
    def artifacts(mapping):
        require(isinstance(mapping, dict), "artifact_hashes must be a path-to-SHA256 dictionary")
        for name, digest in mapping.items():
            target = Path(name)
            if not target.is_absolute():
                target = ROOT / target
            verified_artifacts[display(target)] = pin(target, digest)
    artifacts(evidence.get("artifact_hashes", {}))
    controller = suites["soft_slope"][120]["hashes"]["res://combat_pc/player.gd"]
    for item in corrections:
        require(item.get("issue") and item.get("evidence_kind") and item.get("final_cases"), f"Incomplete correction: {item['id']}")
        artifacts(item.get("artifact_hashes", {}))
        if "load_transform" in item:
            transform = item["load_transform"]
            original = (ROOT / transform["original"]).read_text()
            loaded = (ROOT / transform["loaded"]).read_text()
            removed = transform["remove_exact_once"]
            require(original.count(removed) == 1 and original.replace(removed, "", 1) == loaded, f"Unverified retained-source load transform: {item['id']}")
        if "final_controller_sha256" in item:
            require(item["final_controller_sha256"] == controller, f"Stale final correction source: {item['id']}")
        for case in item["final_cases"]:
            suite, name = ("soft_slope", case) if isinstance(case, str) else (case["suite"], case["name"])
            require(suite in suites, f"Unknown correction suite: {suite}")
            for hz in RATES:
                require(any(s["name"] == name for s in suites[suite][hz]["scenarios"]),
                        f"Correction final case absent at {hz} Hz: {item['id']}/{suite}/{name}")
    return corrections, verified_artifacts


def comparisons_for(suites):
    comparisons = []
    phase_comparisons = []
    indexes = {suite: {hz: {s["name"]: s for s in run["scenarios"]} for hz, run in pair.items()}
               for suite, pair in suites.items()}
    def compare(suite, label, metric, bound, reason, extract=None):
        values = {hz: number(extract(indexes[suite][hz][label], hz) if extract else
                             indexes[suite][hz][label]["measurements"][metric], f"{suite}/{label}/{metric}") for hz in RATES}
        row = {"suite": suite, "scenario": label, "metric": metric, "value_120hz": values[120],
               "value_60hz": values[60], "allowed_difference": bound, "tolerance_reason": reason,
               "passed": abs(values[120] - values[60]) <= bound + 1e-12}
        require(row["passed"], f"Cross-rate bound failed: {row}")
        comparisons.append(row)
    def top_seconds(scenario, hz):
        start = first_event(scenario, "climb_attached")["tick"]
        end = next(event["tick"] for event in scenario["events"] if event["event"] == "climb_detached" and event["data"].get("reason") == "top_exit")
        return (end - start) / hz
    previous = read(ROOT / "combat_pc/hard_landing_verification.json")["cross_rate_comparisons"]
    for old in previous:
        suite = "hard_landing_compatibility" if old["suite"] == "hard_landing" else old["suite"]
        compare(suite, old["scenario"], old["metric"], old["allowed_difference"], old["tolerance_reason"],
                top_seconds if old["metric"] == "top_exit_seconds" else None)
    profile = suites["soft_slope"][120]["movement_profile"]
    speed, skin = profile["run_speed"], profile["collision_margin"]
    for label, scenario in indexes["soft_slope"][120].items():
        params = scenario.get("params", {})
        if "gradient" in params:
            neutral = params["input_x"] == 0
            zero_x = neutral and params["initial_vx"] == 0
            for seconds in (.05, .10, .20, .40, .80, 1.0, 2.0):
                if seconds > params["post_contact_seconds"] + 1e-6:
                    continue
                bound = skin * 2 + .001 if zero_x else (speed / 60 + skin * 2 if neutral else 2 * speed / 60 + .1)
                reason = ("Zero horizontal input and momentum: only the existing collision skin may separate paired stationary roots" if zero_x else
                          "Post-contact neutral braking allows one 60 Hz run-speed displacement plus existing collision skin" if neutral else
                          "Contact-relative travel allows two 60 Hz run-speed steps for contact and acceleration sampling; no pre-impact path equality")
                compare("soft_slope", label, f"travel_x_{seconds:.2f}", bound, reason)
            if neutral:
                compare("soft_slope", label, "settle_seconds", 1 / 60 + profile["air_idle_drag"] / 60 / profile["ground_braking"] + 1e-9,
                        "One ground-braking endpoint sample plus one airborne-drag sample's effect on stopping time")
                compare("soft_slope", label, "velocity_x_0.80", .04, "Both neutral runs must finish at zero within their 0.02 px/s assertion tolerance")
            else:
                compare("soft_slope", label, "velocity_x_0.80", .04, "Both held directions reach the same authored X speed; sum of per-rate 0.02 px/s tolerance")
                compare("soft_slope", label, "steady_travel_x_0.40_to_0.80", .10,
                        "Same 0.4 s steady horizontal interval; sum of per-rate 0.05 px travel tolerance",
                        lambda s, _hz: s["measurements"]["travel_x_0.80"] - s["measurements"]["travel_x_0.40"])
        if "crossing_seconds" in scenario["measurements"]:
            compare("soft_slope", label, "crossing_seconds", 1 / 60 + .02,
                    "Continuous joins allow one 60 Hz endpoint tick plus 0.02 s contact/integration allowance")
        if label.startswith("shared slope movement "):
            action = label.split()[3]
            start, end = {"roll": ("roll_started", "roll_finished"), "melee": ("attack_started", "attack_finished"),
                          "hurt": ("hurt_started", "hurt_finished"), "hard": ("hard_land_started", "hard_land_finished")}[action]
            def duration(s, hz, start=start, end=end):
                first, last = first_event(s, start), first_event(s, end)
                require(last["tick"] >= first["tick"], f"Reversed action events: {s['name']}")
                measured = (last["tick"] - first["tick"]) / hz
                close(s["measurements"]["action_duration_seconds"], measured, 1e-8,
                      f"Action duration differs from actual events: {s['name']}/{hz}")
                return measured
            compare("soft_slope", label, "action_duration_seconds", 1 / 60 + 1e-9,
                    "Same finite action lifetime on a real slope, with one endpoint sample of quantization", duration)
    for hz in RATES:
        for mirror in (-1, 1):
            for mode in ("stock", "instrumented"):
                a = indexes["soft_slope"][hz][f"zero-X phase mirror{mirror} gap38 {mode}"]
                b = indexes["soft_slope"][hz][f"zero-X phase mirror{mirror} gap40 {mode}"]
                for metric in ("entry_vx", "travel_x_0.20", "travel_x_0.80", "travel_x_2.00", "velocity_x_0.80"):
                    values = [number(s["measurements"][metric], f"phase/{metric}") for s in (a, b)]
                    bound = .04 if "vx" in metric or "velocity" in metric else skin * 2 + .001
                    row = {"physics_hz": hz, "mirror": mirror, "mode": mode, "metric": metric,
                           "gap38": values[0], "gap40": values[1], "allowed_difference": bound,
                           "tolerance_reason": "A two-pixel approach phase change cannot manufacture horizontal momentum or sustained travel",
                           "passed": abs(values[0] - values[1]) <= bound + 1e-12}
                    require(row["passed"], f"Contact-phase sensitivity failed: {row}")
                    phase_comparisons.append(row)
    return comparisons, phase_comparisons, len(previous)


LIMITS = [
    "This is original MOKSHA contact and locomotion policy. Neither Dead Cells executable behavior, slope algorithm, numerical tuning nor exact feel was recovered or established.",
    "Ordinary floor response preserves the current horizontal velocity and remaining requested X at each floor collision. Actual walls and ceilings may remove blocked components; no report bound requires travel through geometry.",
    "Ground following uses confirmed support, tangent displacement and bounded short swept segments with the existing 2 px floor probe and a 32-segment work cap. It does not authorize an enlarged generic ledge snap. Explicit upward departures and accepted jumps must retire following.",
    "Paired plane metrics are measured from each run's actual first landing. Equal arbitrary pre-impact trajectories are not required. Neutral stop, steady X velocity/travel, approach-height sensitivity, continuous-join timing and preserved action timing have separate justified bounds.",
    "Exact full-shape queries can observe overlaps within the authored collision skin. Independent plane/rectangle clearance checks bound penetration; acceptance is not a strict zero-overlap or arbitrary concave-world proof.",
    "M7 records an immediate before/after sample around one production call in every real engine physics callback, including engine-frame and delta checks. Historical compatibility harnesses retain their original recorded actor ticks; older formats do not independently record engine-frame IDs/deltas. Continuous recorded actor ticks alone are not represented as that stronger proof.",
    "The original movement/combat harnesses start-pin a smaller file inventory than their final hash inventory. Every recorded start hash must match its final hash, every final hash must match current bytes, and the new M7 harness start/end-pins the full actor/production inventory. Earlier formats are not rewritten to imply they recorded additional start hashes.",
    "Compatibility covers existing hard/roll/hurt outcomes, M6 excursion history, input queues, targeted one-way cleanup, carrier ordering and synchronous callbacks within the preserved fixtures. New floor travel can change legitimate collision positions; old numerical paths are not asserted identical.",
    "Unavoidable continuing crush, arbitrary custom profile extremes, exhaustive collision meshes, NPC behavior, health/respawn and new gameplay scope are not established. Native presentation/feel and final packaged-project boot remain separate integration checks.",
]


def main():
    preserved = verify_preservation()
    redirects = read(TESTS / "soft_slope_compatibility_redirects.json")
    require(set(redirects) == {name.removesuffix("_compatibility") for name in FILES if name != "soft_slope"}, "Incomplete compatibility redirect provenance")
    for suite, row in redirects.items():
        original = ROOT / row["original_harness"]
        pin(original, row["original_sha256"])
        original_text = original.read_text()
        require(original_text.count(row["old_output"]) == 1, f"Ambiguous output-only redirect: {suite}")
        derived = original_text.replace(row["old_output"], row["new_output"]).encode()
        require(hashlib.sha256(derived).hexdigest() == row["redirected_sha256"], f"Redirect altered test logic: {suite}")
    suites, continuity, logs = {}, {}, {}
    for suite, prefix in FILES.items():
        suites[suite], continuity[suite] = {}, {}
        for hz in RATES:
            run = read(TESTS / f"{prefix}_{hz}hz.json")
            suites[suite][hz] = run
            continuity[suite][str(hz)], log = verify_run(run, suite, hz)
            logs.update(log)
            if suite != "soft_slope":
                short = suite.removesuffix("_compatibility")
                baseline = "hard_landing_results" if short == "hard_landing" else f"{short}_compat_m6_results"
                old = read(TESTS / f"{baseline}_{hz}hz.json")
                require([(s["name"], s["checks"]) for s in run["scenarios"]] ==
                        [(s["name"], s["checks"]) for s in old["scenarios"]], f"Compatibility coverage changed: {suite}/{hz}")
        pair = suites[suite]
        require(pair[120]["hashes"] == pair[60]["hashes"], f"Rate-pair source mismatch: {suite}")
        require([(s["name"], s.get("params", {}), s["checks"]) for s in pair[120]["scenarios"]] ==
                [(s["name"], s.get("params", {}), s["checks"]) for s in pair[60]["scenarios"]],
                f"Rate-pair scenario/parameter/order/count mismatch: {suite}")
    soft = suites["soft_slope"][120]
    require(soft["milestone"] == 7 and suites["soft_slope"][60]["milestone"] == 7, "Wrong M7 milestone")
    controller = soft["hashes"]["res://combat_pc/player.gd"]
    shared_hashes = {}
    for pair in suites.values():
        for run in pair.values():
            require(run["engine"] == soft["engine"], "Runs used different Godot builds")
            require(run["hashes"]["res://combat_pc/player.gd"] == controller, "Runs used different controller revisions")
            for path, digest in run["hashes"].items():
                require(path not in shared_hashes or shared_hashes[path] == digest, f"Cross-suite source mismatch: {path}")
                shared_hashes[path] = digest
            for key in ("movement_profile", "combat_profile"):
                if key in run:
                    require(run[key] == soft[key], f"Different serialized {key} between suites")
    required = minimum_m7_names(soft["movement_profile"]["terminal_fall_speed"])
    require(required.issubset({s["name"] for s in soft["scenarios"]}),
            f"Incomplete M7 run; missing scenarios: {sorted(required - {s['name'] for s in soft['scenarios']})}")
    observer_pairs = []
    for hz, run in suites["soft_slope"].items():
        index = {s["name"]: s for s in run["scenarios"]}
        for scenario in run["scenarios"]:
            verify_plane_measurements(scenario, hz)
            if scenario["name"].endswith(" instrumented"):
                stock = scenario["name"].removesuffix(" instrumented") + " stock"
                require(stock in index, f"Missing stock observer control: {scenario['name']}")
                require(observation_signature(scenario) == observation_signature(index[stock]),
                        f"Observer changed physical samples/events: {scenario['name']}/{hz}")
                observer_pairs.append({"physics_hz": hz, "stock": stock, "instrumented": scenario["name"], "exact_match": True})
    comparisons, phases, inherited_bounds = comparisons_for(suites)
    corrections, correction_artifacts = check_corrections(suites)
    contract_hash = pin(ROOT / "combat_pc/MOTOR_CONTRACT.md")
    builder_hash = pin(Path(__file__))
    report = {
        "title": "MOKSHA combat PC soft-slope verification", "milestone": 7, "status": "passed",
        "generated_utc": datetime.now(timezone.utc).isoformat(), "controller_sha256": controller,
        "engine": soft["engine"], "production_hashes": shared_hashes,
        "contract_sha256": contract_hash, "report_builder_sha256": builder_hash,
        "movement_profile": soft["movement_profile"], "combat_profile": soft["combat_profile"],
        "execution": soft["execution"], "suites": {}, "sample_continuity": continuity,
        "cross_rate_comparisons": comparisons, "inherited_comparison_count": inherited_bounds,
        "within_rate_contact_phase_comparisons": phases, "observer_equivalence": observer_pairs,
        "verified_corrections": corrections, "correction_artifacts_sha256": correction_artifacts,
        "correction_evidence_sha256": PINNED[(TESTS / "soft_slope_correction_evidence.json").resolve()],
        "console_logs_sha256": logs, "compatibility_redirects": redirects,
        "compatibility_redirects_sha256": PINNED[(TESTS / "soft_slope_compatibility_redirects.json").resolve()],
        "preserved_evidence": {"manifest_sha256": PINNED[(TESTS / "soft_slope_preserved_evidence.json").resolve()],
                               "file_count": len(preserved["files"]), "archive_count": len(preserved["archives"]),
                               "all_recorded_bytes_unchanged": True, **preserved},
        "compatibility_method": "The six original regression harnesses run against the same final source revision with only result filenames redirected to M7 outputs. Original M1–M6 traces, harnesses, reports and snapshots remain hash-pinned.",
        "scenarios": [], "limits": LIMITS,
    }
    for suite, pair in suites.items():
        report["suites"][suite] = {str(hz): {
            "scenarios": len(run["scenarios"]), "assertions": run["checks"], "failures": 0,
            "frames": sum(len(s["frames"]) for s in run["scenarios"]), "source_stable": True,
            "path": f"combat_pc/tests/{FILES[suite]}_{hz}hz.json",
            "sha256": PINNED[(TESTS / f"{FILES[suite]}_{hz}hz.json").resolve()],
        } for hz, run in pair.items()}
    for index, scenario in enumerate(soft["scenarios"]):
        report["scenarios"].append({"name": scenario["name"], "passed_at": list(RATES),
            "assertions": [a["label"] for a in scenario["assertions"]],
            "traces": {str(hz): {"path": f"combat_pc/tests/soft_slope_results_{hz}hz.json",
                                 "json_pointer": f"/scenarios/{index}"} for hz in RATES}})
    markdown = render_markdown(report)
    # Recheck every dependency after the complete audit. No passing artifact is
    # written if evidence/source changed concurrently during this invocation.
    for path, digest in PINNED.items():
        require(sha(path) == digest, f"Evidence changed during report generation: {path}")
    output = ROOT / "combat_pc/soft_slope_verification.json"
    output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    (ROOT / "combat_pc/soft_slope_verification.md").write_text(markdown)
    print(f"PASS: {len(soft['scenarios'])} slope scenarios; seven paired suites, {len(comparisons)} cross-rate bounds, "
          f"{len(phases)} contact-phase bounds, {len(preserved['files'])} preserved files and {len(preserved['archives'])} snapshots")


def render_markdown(report):
    primary = report["suites"]["soft_slope"]["120"]
    preservation = report["preserved_evidence"]
    lines = ["# Soft-slope verification", "",
        f"**Passed at 120 Hz and 60 Hz:** {primary['scenarios']} M7 scenarios / {primary['assertions']} assertions per rate. "
        "All six earlier movement, combat, drop/dive, climb, wall and hard-landing suites pass on the same final controller. Fourteen runs have zero failures and clean engine logs.", "",
        f"Controller SHA-256: `{report['controller_sha256']}`. [Detailed evidence](soft_slope_verification.json) pins sources, profiles, harnesses, traces, logs and preservation hashes.", "",
        "## Contact and connected movement", "",
        "- Mirrored 45° and 26.565° plane landings vary incoming X, downward speed and neutral/uphill/downhill intent; actual remaining X travel is checked separately from final velocity.",
        "- Neutral approach heights 38/40 px retain stock/instrumented equivalence over two seconds. Neutral stops, steady held speed/travel and exact recorded callback continuity are verified.",
        "- Continuous flats, hills, valleys, separate-body seams and the actual native-lab course at both fixture and native world origins retain contact. Disconnected gaps depart support; jumps, sidewalls, low ceilings, moving-support pause and targeted one-way drop remain collision-authoritative.",
        "- Oversized host motion reaches the finite segment cap without crossing a thin wall. Same-instance reset, paused parsed taps, removed support, explicit upward host motion and synchronous ceiling replacement preserve lifecycle authority. Mirrored grounded-uphill ceiling callbacks must retire old floor evidence when a newer airborne hurt owner takes over, including through pause and resumed ticks.",
        "- Shared roll, melee, hurt and hard recovery retain their finite action timing; preserved M6 scenarios cover history, queues, callbacks and landing ownership.", "",
        "## Run coverage", "",
        "| Suite | Scenarios per rate | Assertions per rate |", "|---|---:|---:|"]
    for suite, pair in report["suites"].items():
        lines.append(f"| {suite.replace('_', ' ')} | {pair['120']['scenarios']} | {pair['120']['assertions']} |")
    lines += ["", "## Corrections and evidence", ""]
    for item in report["verified_corrections"]:
        description = item["evidence_kind"].rstrip(".")
        lines.append(f"- **{item['issue']}** Evidence: {description}.")
    lines += ["", "The [correction record](tests/soft_slope_correction_evidence.json) retains the evidence category, exact final cases and available pre-fix artifacts. Physical pre-fix observations and static-review corrections are not treated as interchangeable proof.", "",
        "## Rate bounds and preservation", "",
        f"All {len(report['cross_rate_comparisons'])} cross-rate bounds pass, including the {report['inherited_comparison_count']} inherited M6 bounds. "
        f"All {len(report['within_rate_contact_phase_comparisons'])} within-rate approach-phase bounds and {len(report['observer_equivalence'])} complete stock/observer trace comparisons also pass. "
        "Continuous-join crossing times may differ by at most one 60 Hz tick plus 0.02 s. Plane comparisons start at each run's observed landing; they do not impose arbitrary pre-impact path equality.", "",
        f"All {preservation['file_count']} recorded historical acceptance artifacts and {preservation['archive_count']} milestone snapshots retain their recorded hashes. "
        "Counts come from the preserved-evidence manifest. M7 outputs use separate filenames and do not overwrite earlier results.", "",
        "## Scope and limitations", ""]
    lines += ["- " + item for item in report["limits"]]
    lines += ["", "## Reproduce", "",
        "From the project root, run the complete M7 harness at both rates without a `--group` filter. Save each console stream to `combat_pc/tests/m7_soft_slope_<rate>.log`:", "", "```sh",
        "XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/soft_slope_regression.gd -- --hz=120",
        "XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/soft_slope_regression.gd -- --hz=60", "```", "",
        "Run copies of the six original compatibility harnesses with only output filenames redirected to `<suite>_compat_m7_results_<rate>hz.json`, retaining the movement harness's extra output suffix placeholder. Save `m7_<suite>_<rate>.log`. "
        "After every final run and correction record is ready, run `python3 combat_pc/tests/build_soft_slope_report.py`. It rejects incomplete coverage, stale sources, failed assertions, mismatched logs, missing samples, changed historical bytes and exceeded bounds before writing reports.", "",
        "Historical re-audits require the original datasets and milestone ZIPs listed in the preservation manifest. They are not needed merely to play the project. "
        "Current traces are indexed by exact JSON pointers in the [detailed report](soft_slope_verification.json).", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    try:
        main()
    except (VerificationError, OSError, ValueError, KeyError, TypeError, StopIteration) as error:
        print(f"FAIL: M7 acceptance report not generated: {error}", file=sys.stderr)
        sys.exit(1)
