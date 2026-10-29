"""Audit final M8 evidence before publishing either shield acceptance report.

This program does not run Godot, modify a harness, or rewrite historical evidence.
Run it after the complete eight-suite, two-rate capture and correction record are
ready. The frozen required-case inventory is independent of the result under
audit; a filtered exploratory run cannot become an acceptance report.
"""
from __future__ import annotations

from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / "combat_pc/tests"
RATES = (120, 60)
OLDER_SUITES = ("movement", "combat", "traversal", "climb", "wall", "hard_landing", "soft_slope")
FILES = {"shield": "shield_results", **{
    f"{name}_compatibility": f"{name}_compat_m8_results" for name in OLDER_SUITES}}
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
PINNED: dict[Path, str] = {}
# Reviewed against the frozen source groups and the complete 215-case run.
# This static inventory cannot shrink merely because a later result omits tests.
REQUIRED_M8_GROUPS: dict[str, tuple[str, ...]] = {
    'timing': (  # 18 cases
        'shield window before_open direction-1',
        'shield window first_open direction-1',
        'shield window last_open direction-1',
        'shield window first_closed direction-1',
        'shield window before_open direction1',
        'shield window first_open direction1',
        'shield window last_open direction1',
        'shield window first_closed direction1',
        'shield window before_open direction-1 aligned',
        'shield window first_open direction-1 aligned',
        'shield window last_open direction-1 aligned',
        'shield window first_closed direction-1 aligned',
        'shield window before_open direction1 aligned',
        'shield window first_open direction1 aligned',
        'shield window last_open direction1 aligned',
        'shield window first_closed direction1 aligned',
        'tap keeps one finite window and miss recovery',
        'held guard release and fresh next attempt',
    ),
    'physical_timing': (  # 8 cases
        'physical projectile window before_open direction-1',
        'physical projectile window first_open direction-1',
        'physical projectile window last_open direction-1',
        'physical projectile window first_closed direction-1',
        'physical projectile window before_open direction1',
        'physical projectile window first_open direction1',
        'physical projectile window last_open direction1',
        'physical projectile window first_closed direction1',
    ),
    'outcomes': (  # 5 cases
        'incoming outcome and same ID duplicate idle',
        'incoming outcome and same ID duplicate guard',
        'incoming outcome and same ID duplicate parry',
        'incoming outcome and same ID duplicate roll',
        'same local ID from distinct live sources',
    ),
    'geometry': (  # 40 cases
        'defense geometry front direction-1',
        'defense geometry back direction-1',
        'defense geometry above direction-1',
        'defense geometry below direction-1',
        'defense geometry equal_x direction-1',
        'defense geometry diagonal_inside direction-1',
        'defense geometry diagonal_outside direction-1',
        'defense geometry velocity_inside direction-1',
        'defense geometry velocity_outside direction-1',
        'defense geometry zero_melee direction-1',
        'defense geometry zero_projectile direction-1',
        'defense geometry remote_owner direction-1',
        'defense geometry contact_outside_body direction-1',
        'defense geometry contact_outside_band direction-1',
        'defense geometry occluded direction-1',
        'defense geometry front direction1',
        'defense geometry back direction1',
        'defense geometry above direction1',
        'defense geometry below direction1',
        'defense geometry equal_x direction1',
        'defense geometry diagonal_inside direction1',
        'defense geometry diagonal_outside direction1',
        'defense geometry velocity_inside direction1',
        'defense geometry velocity_outside direction1',
        'defense geometry zero_melee direction1',
        'defense geometry zero_projectile direction1',
        'defense geometry remote_owner direction1',
        'defense geometry contact_outside_body direction1',
        'defense geometry contact_outside_band direction1',
        'defense geometry occluded direction1',
        'eligibility block_only during parry',
        'eligibility parry_only during parry',
        'eligibility neither during parry',
        'eligibility area during parry',
        'eligibility projectile_no_reflect during parry',
        'eligibility block_only during hold',
        'eligibility parry_only during hold',
        'eligibility neither during hold',
        'eligibility area during hold',
        'eligibility projectile_no_reflect during hold',
    ),
    'cancels': (  # 42 cases
        'shield raise requests jump',
        'shield raise requests roll',
        'shield raise requests attack',
        'shield raise requests drop',
        'shield raise requests dive',
        'shield raise requests climb',
        'shield raise requests wall',
        'shield parry requests jump',
        'shield parry requests roll',
        'shield parry requests attack',
        'shield parry requests drop',
        'shield parry requests dive',
        'shield parry requests climb',
        'shield parry requests wall',
        'shield hold requests jump',
        'shield hold requests roll',
        'shield hold requests attack',
        'shield hold requests drop',
        'shield hold requests dive',
        'shield hold requests climb',
        'shield hold requests wall',
        'shield miss_recovery requests jump',
        'shield miss_recovery requests roll',
        'shield miss_recovery requests attack',
        'shield miss_recovery requests drop',
        'shield miss_recovery requests dive',
        'shield miss_recovery requests climb',
        'shield miss_recovery requests wall',
        'shield success_recovery requests jump',
        'shield success_recovery requests roll',
        'shield success_recovery requests attack',
        'shield success_recovery requests drop',
        'shield success_recovery requests dive',
        'shield success_recovery requests climb',
        'shield success_recovery requests wall',
        'shield release_recovery requests jump',
        'shield release_recovery requests roll',
        'shield release_recovery requests attack',
        'shield release_recovery requests drop',
        'shield release_recovery requests dive',
        'shield release_recovery requests climb',
        'shield release_recovery requests wall',
    ),
    'locks': (  # 15 cases
        'independent use lock survives roll',
        'independent use lock survives jump',
        'independent use lock survives forced',
        'shield admission gate ability',
        'shield admission gate main',
        'shield admission gate host',
        'shield admission gate inputs',
        'responsive shield facing raise',
        'responsive shield facing parry',
        'responsive shield facing hold',
        'responsive shield facing miss_recovery',
        'responsive shield facing success_recovery',
        'responsive shield facing release_recovery',
        'shield ground move scale and braking',
        'nonholdable profile cannot cancel committed attempt',
    ),
    'effects': (  # 20 cases
        'physical melee counter accepted direction-1',
        'physical melee counter receiver_rejects direction-1',
        'physical melee counter out_of_counter_range direction-1',
        'physical melee counter turn_after_defense direction-1',
        'physical melee counter reset_after_counter direction-1',
        'physical projectile effect reflected direction-1',
        'physical projectile effect remote_source_freed direction-1',
        'physical projectile effect carrier_disabled direction-1',
        'physical projectile effect carrier_removed direction-1',
        'physical projectile effect wall_before_actor direction-1',
        'physical melee counter accepted direction1',
        'physical melee counter receiver_rejects direction1',
        'physical melee counter out_of_counter_range direction1',
        'physical melee counter turn_after_defense direction1',
        'physical melee counter reset_after_counter direction1',
        'physical projectile effect reflected direction1',
        'physical projectile effect remote_source_freed direction1',
        'physical projectile effect carrier_disabled direction1',
        'physical projectile effect carrier_removed direction1',
        'physical projectile effect wall_before_actor direction1',
    ),
    'props': (  # 2 cases
        'real rigid prop reflection and noise direction-1',
        'real rigid prop reflection and noise direction1',
    ),
    'admission': (  # 14 cases
        'shield enters from melee_windup',
        'shield enters from melee_active',
        'shield enters from melee_recovery',
        'shield enters from early_roll',
        'shield enters from late_roll',
        'shield enters from climb',
        'shield enters from wall',
        'shield enters from ledge',
        'shield enters from dive_startup',
        'shield enters from dive_descent',
        'shield enters from dive_impact',
        'shield enters from dive_recovery',
        'shield enters from hurt',
        'shield enters from hard_land',
    ),
    'history': (  # 7 cases
        'bounded history reordered IDs duplicates and stale contact',
        'invalid far ID cannot advance history window',
        'identified descriptor rejection missing_source',
        'identified descriptor rejection removed_source',
        'identified descriptor rejection queued_source',
        'identified descriptor rejection fractional_id',
        'identified descriptor rejection negative_id',
    ),
    'native': (  # 6 cases
        'native press and release before one physics callback',
        'native shield tap captured wholly during local pause',
        'native tap then repress preserves old attempt latch',
        'native shield rearm gate before',
        'native shield rearm gate at',
        'native shield rearm gate after',
    ),
    'callbacks': (  # 14 cases
        'shield callback shield_started replaces with reset',
        'shield callback shield_started replaces with hurt',
        'shield callback parry_phase replaces with reset',
        'shield callback parry_phase replaces with hurt',
        'shield callback defense_resolved replaces with reset',
        'shield callback defense_resolved replaces with hurt',
        'shield callback parry_noise replaces with reset',
        'shield callback parry_noise replaces with hurt',
        'shield callback hitpause_started replaces with reset',
        'shield callback hitpause_started replaces with hurt',
        'structured hurt callback preserves newer owner action_changed',
        'structured hurt callback preserves newer owner hurt_started',
        'structured hurt callback preserves newer owner hurt_noise',
        'effect confirmation scope rejects delayed wrong and repeated callbacks',
    ),
    'air': (  # 9 cases
        'shield preserves spent airborne resources then soft landing',
        'shield preserves spent airborne resources then hard landing',
        'small body shield contact under low ceiling',
        'held shield survives ground_jump_soft completion direction-1',
        'held shield survives air_jump_soft completion direction-1',
        'held shield survives air_jump_hard completion direction-1',
        'held shield survives ground_jump_soft completion direction1',
        'held shield survives air_jump_soft completion direction1',
        'held shield survives air_jump_hard completion direction1',
    ),
    'intersections': (  # 12 cases
        'receive_hit Boolean legacy idle',
        'receive_hit Boolean legacy parry',
        'receive_hit Boolean legacy hold',
        'receive_hit Boolean legacy roll',
        'receive_hit Boolean identified idle',
        'receive_hit Boolean identified parry',
        'receive_hit Boolean identified hold',
        'receive_hit Boolean identified roll',
        'shield admission during targeted drop preserves cleanup',
        'moving shield support and local pause',
        'live shield gate withdrawal during pause ability',
        'live shield gate withdrawal during pause host',
    ),
    'priorities': (  # 3 cases
        'committed wall kick refuses shield admission',
        'simultaneous roll jump shield attack priority',
        'simultaneous shield attack priority',
    ),
}
REQUIRED_M8_CASES = tuple(name for names in REQUIRED_M8_GROUPS.values() for name in names)
PHASES = ("raise", "parry", "hold", "miss_recovery", "success_recovery", "release_recovery")
OUTCOMES = {"hurt", "evaded", "guarded", "parried", "duplicate", "rejected"}
TIMING_NAME = re.compile(r"(shield window|physical projectile window) (before_open|first_open|last_open|first_closed) direction(-?1)( aligned)?\Z")


class VerificationError(RuntimeError):
    pass


def require(condition, message):
    if not condition:
        raise VerificationError(str(message))


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def display(path):
    path = Path(path).resolve()
    return str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)


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


def project_path(name):
    require(isinstance(name, str), f"Invalid project path: {name}")
    target = (ROOT / name).resolve()
    require(target.is_relative_to(ROOT), f"Path escapes project: {name}")
    return target


def resource_path(name):
    require(isinstance(name, str) and name.startswith("res://"), f"Unexpected resource path: {name}")
    return project_path(name.removeprefix("res://"))


def verify_preservation():
    preserved = read(TESTS / "shield_preserved_evidence.json")
    require(preserved.get("milestone") == 8, "Wrong preservation milestone")
    require(preserved.get("files") and preserved.get("archives"), "Historical preservation manifest is empty")
    require(not preserved.get("documentation_updates"), "Historical exceptions require explicit review")
    for name, digest in preserved["files"].items():
        pin(project_path(name), digest)
    for name, digest in preserved["archives"].items():
        require(Path(name).name == name, f"Unexpected archive name: {name}")
        pin(ROOT.parent / "moksha-backups" / name, digest)
    return preserved


def load_m7_validator():
    """Reuse the preserved M7 numerical checks without invoking its writer."""
    path = TESTS / "build_soft_slope_report.py"
    pin(path)
    spec = importlib.util.spec_from_file_location("preserved_m7_acceptance", path)
    require(spec and spec.loader, "Cannot load the preserved M7 verifier")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # One read/hash ledger and exception type cover both sets of checks.
    for name in ("require", "pin", "read", "number", "close"):
        setattr(module, name, globals()[name])
    module.PINNED = PINNED
    return module


def verify_redirects():
    redirects = read(TESTS / "shield_compatibility_redirects.json")
    require(set(redirects) == set(OLDER_SUITES), "Incomplete compatibility redirect provenance")
    for suite, row in redirects.items():
        original = project_path(row["original_harness"])
        pin(original, row["original_sha256"])
        content = original.read_text()
        require(content.count(row["old_output"]) == 1, f"Ambiguous output-only redirect: {suite}")
        suffix = "%dhz%s.json" if suite == "movement" else "%dhz.json"
        expected_output = f"res://combat_pc/tests/{suite}_compat_m8_results_{suffix}"
        require(row["new_output"] == expected_output, f"Wrong M8 output destination: {suite}")
        changed = content.replace(row["old_output"], row["new_output"], 1).encode()
        require(hashlib.sha256(changed).hexdigest() == row["redirected_sha256"], f"Redirect altered test logic: {suite}")
        if "redirected_harness" in row:
            pin(project_path(row["redirected_harness"]), row["redirected_sha256"])
    return redirects


def verify_run(run, suite, hz, m7):
    context = f"{suite}/{hz}"
    require(run["physics_hz"] == hz, f"Wrong physics rate: {context}")
    if suite in ("shield", "soft_slope_compatibility"):
        require(run.get("selected_group") == "", f"Filtered run cannot establish acceptance: {context}")
        require(run.get("milestone") == (8 if suite == "shield" else 7), f"Wrong milestone: {context}")
    require(run["production_hash_stable_during_run"] is True, f"Unstable sources: {context}")
    start, end = run["starting_hashes"], run["hashes"]
    require(start and end and all(end.get(name) == digest for name, digest in start.items()),
            f"Recorded start/end source mismatch: {context}")
    if suite not in ("movement_compatibility", "combat_compatibility"):
        require(start == end, f"Complete start/end inventory mismatch: {context}")
    for name, digest in end.items():
        pin(resource_path(name), digest)
    required = ["player.gd", "player.tscn", "resources/movement_profile.gd", "resources/movement_profile.tres"]
    if suite == "shield":
        required += ["resources/shield_profile.gd", "resources/shield_profile.tres", "tests/shield_regression.gd",
                     "components/shield_contact_adapter.gd", "components/guard_prop_adapter.gd",
                     "fixtures/guard_melee_fixture.gd", "fixtures/guard_melee_fixture.tscn",
                     "fixtures/guard_projectile.gd", "fixtures/guard_projectile_fixture.gd",
                     "fixtures/guard_projectile_fixture.tscn", "fixtures/guard_prop_fixture.gd", "fixtures/guard_prop_fixture.tscn"]
    for name in required:
        require(f"res://combat_pc/{name}" in end, f"Required source hash absent: {context}/{name}")
    require(run["failures"] == [], f"Reported failures: {context}: {run['failures']}")
    scenarios = run["scenarios"]
    require(scenarios and len({s["name"] for s in scenarios}) == len(scenarios), f"Empty/duplicate scenarios: {context}")
    total, continuity = 0, {}
    for scenario in scenarios:
        label = f"{context}/{scenario['name']}"
        require(scenario["failures"] == 0, f"Scenario failure: {label}")
        require(type(scenario["checks"]) is int and scenario["checks"] == len(scenario["assertions"]) > 0,
                f"Assertion count mismatch: {label}")
        require(all(a["passed"] is True and a.get("label") for a in scenario["assertions"]), f"Failed/unlabelled assertion: {label}")
        total += scenario["checks"]
        # M8 inherits the actual callback recorder, not merely an actor-tick counter.
        continuity[scenario["name"]] = m7.verify_continuity(
            scenario, "soft_slope" if suite in ("shield", "soft_slope_compatibility") else suite, hz)
    require(run["checks"] == total, f"Run check count mismatch: {context}")
    path = TESTS / f"m8_{suite.removesuffix('_compatibility')}_{hz}.log"
    pin(path)
    content = path.read_text()
    require(not re.search(r"SCRIPT ERROR|ERROR:|FAIL:|WARNING:", content), f"Engine diagnostic in {path}")
    completions = re.findall(r"MOKSHA [^\n]*?(\d+)Hz: (\d+) scenarios, (\d+) checks, (\d+) failures", content)
    require(len(completions) == 1 and tuple(map(int, completions[0])) == (hz, len(scenarios), total, 0),
            f"Missing, repeated or mismatched completion line: {path}")
    return continuity, {display(path): PINNED[path.resolve()]}


def paired_signature(scenario, suite):
    params = dict(scenario.get("params", {}))
    if suite == "shield" and TIMING_NAME.fullmatch(scenario["name"]):
        # This one field explicitly records rate-quantized time, not fixed setup.
        params.pop("intended_attempt_seconds", None)
    return scenario["name"], params, scenario["checks"], scenario.get("shield_profile")


def verify_compatibility(suites, m7):
    for suite in OLDER_SUITES:
        for hz in RATES:
            prefix = "soft_slope_results" if suite == "soft_slope" else f"{suite}_compat_m7_results"
            old = read(TESTS / f"{prefix}_{hz}hz.json")
            current = suites[f"{suite}_compatibility"][hz]
            require([(s["name"], s.get("params", {}), s["checks"]) for s in current["scenarios"]] ==
                    [(s["name"], s.get("params", {}), s["checks"]) for s in old["scenarios"]],
                    f"Historical compatibility coverage changed: {suite}/{hz}")
    mapped = {("soft_slope" if suite == "soft_slope_compatibility" else suite): pair
              for suite, pair in suites.items() if suite != "shield"}
    observers = []
    for hz, run in mapped["soft_slope"].items():
        index = {s["name"]: s for s in run["scenarios"]}
        required = m7.minimum_m7_names(run["movement_profile"]["terminal_fall_speed"])
        require(required.issubset(index), f"Incomplete inherited M7 coverage at {hz} Hz")
        for scenario in run["scenarios"]:
            m7.verify_plane_measurements(scenario, hz)
            if scenario["name"].endswith(" instrumented"):
                stock = scenario["name"].removesuffix(" instrumented") + " stock"
                require(stock in index and m7.observation_signature(scenario) == m7.observation_signature(index[stock]),
                        f"Observer changed physical samples/events: {scenario['name']}/{hz}")
                observers.append({"physics_hz": hz, "stock": stock, "instrumented": scenario["name"], "exact_match": True})
    comparisons, phases, _ = m7.comparisons_for(mapped)
    previous = read(ROOT / "combat_pc/soft_slope_verification.json")
    fields = ("suite", "scenario", "metric", "allowed_difference", "tolerance_reason")
    require([[row[key] for key in fields] for row in comparisons] ==
            [[row[key] for key in fields] for row in previous["cross_rate_comparisons"]],
            "Inherited M7 numerical acceptance bounds changed")
    fields = ("physics_hz", "mirror", "mode", "metric", "allowed_difference", "tolerance_reason")
    require([[row[key] for key in fields] for row in phases] ==
            [[row[key] for key in fields] for row in previous["within_rate_contact_phase_comparisons"]],
            "Inherited M7 contact-phase bounds changed")
    for row in comparisons:
        if row["suite"] == "soft_slope":
            row["suite"] = "soft_slope_compatibility"
    return comparisons, phases, observers


def contact_route(scenario, incoming):
    route = incoming.get("route")
    if route is None:
        require("payload" in incoming, f"Unclassified incoming record: {scenario['name']}")
        return "direct incoming API descriptor probe"
    if route == "production swept projectile":
        return "actual swept projectile contact"
    if route == "production passive fixture contact":
        if scenario["name"].startswith("physical melee counter "):
            return "actual telescoping blade contact"
        if scenario["name"].startswith("real rigid prop "):
            return "actual rigid-body solver contact"
    raise VerificationError(f"Unreviewed incoming contact route: {scenario['name']}/{route}")


def verify_incoming(scenario, hz):
    """Keep resolved defense, adapter application and acknowledgement separate."""
    context = f"shield/{hz}/{scenario['name']}"
    summary = {"routes": Counter(), "outcomes": Counter(), "effects_applied": Counter(), "effects_confirmed": Counter(),
               "applied_without_confirmation": 0, "rigid_return_receiver_contacts": 0}
    frames = scenario["frames"]
    for frame in frames:
        for side in ("before", "after"):
            state = frame[side]
            entries, sources, window = (state[key] for key in ("incoming_history_entries", "incoming_history_sources", "incoming_history_window"))
            require(all(type(value) is int and value >= 0 for value in (entries, sources, window)), f"Invalid history telemetry: {context}")
            require(entries <= sources * max(1, window), f"History exceeds per-authenticator/per-kind bound: {context}")
    for incoming in scenario["incoming"]:
        tick = incoming["tick"]
        require(type(tick) is int and 0 <= tick <= len(frames), f"Incoming contact outside sampled range: {context}")
        result = incoming["result"]
        # The prop fixture reuses attack_resolved for the reflected body's later
        # receiver collision. This is outgoing physical evidence, not another
        # incoming defense result or a second solver contact on the player.
        if "outcome" not in result:
            require(scenario["name"].startswith("real rigid prop ") and
                    incoming.get("route") == "production passive fixture contact" and
                    set(result) == {"accepted", "damage_applied", "returned"},
                    f"Unknown physical receiver-result schema: {context}")
            require(result["accepted"] is True and result["returned"] == 1 and
                    number(result["damage_applied"], context) > 0,
                    f"Rigid return receiver did not accept its physical contact: {context}")
            require(tick >= 1 and incoming["engine_tick"] == frames[tick - 1]["engine_tick"],
                    f"Rigid return contact lacks its actual engine callback: {context}")
            summary["rigid_return_receiver_contacts"] += 1
            continue
        route = contact_route(scenario, incoming)
        summary["routes"][route] += 1
        if route != "direct incoming API descriptor probe":
            require(tick >= 1 and incoming["engine_tick"] == frames[tick - 1]["engine_tick"],
                    f"Physical contact is not tied to the recorded engine callback: {context}")
        outcome = result["outcome"]
        require(outcome in OUTCOMES, f"Unknown defense outcome: {context}/{outcome}")
        summary["outcomes"][outcome] += 1
        require(all(type(result[key]) is bool for key in ("consumed", "counter_confirmed", "reflection_confirmed", "hurt_applied")),
                f"Ambiguous incoming result flags: {context}")
        require(not (result["counter_confirmed"] and result["reflection_confirmed"]), f"One contact fabricated both outgoing routes: {context}")
        require(number(result["residual_damage"], context) >= 0, f"Negative residual damage: {context}")
        if outcome in ("parried", "guarded", "evaded"):
            require(not result["hurt_applied"], f"Defense also applied normal hurt: {context}")
        if outcome in ("parried", "evaded"):
            close(result["residual_damage"], 0, 1e-12, f"Damage-negating outcome: {context}")
        if outcome in ("duplicate", "rejected"):
            require(not any(result[key] for key in ("consumed", "counter_confirmed", "reflection_confirmed", "hurt_applied")),
                    f"Rejected/duplicate contact produced an effect: {context}")
            close(result["residual_damage"], 0, 1e-12, f"Rejected/duplicate contact residual: {context}")
        if outcome != "parried":
            require(not result["counter_confirmed"] and not result["reflection_confirmed"], f"Non-parry fabricated outgoing success: {context}")
        if outcome == "guarded" and "payload" in incoming:
            expected = max(0, number(incoming["payload"].get("amount", 1), context)) * (1 - min(1, max(0, scenario["shield_profile"]["guard_absorption"])))
            close(result["residual_damage"], expected, 1e-8, f"Guard residual is applied once: {context}")
        for effect, field, event_name in (("counter", "counter_confirmed", "shield_counter_confirmed"),
                                           ("reflect", "reflection_confirmed", "shield_reflection_confirmed")):
            if result[field]:
                require(any(event["event"] == event_name and event["data"].get("attack_key") == result["attack_key"]
                            for event in scenario["events"]), f"Incoming success lacks a current-scope confirmation event: {context}/{effect}")
    seen_confirmations = set()
    for entry in scenario["effect_reports"]:
        report = entry["report"]
        key = (entry["tick"], report["attack_key"], report["effect"], report["target_id"])
        require(report["effect"] in ("counter", "reflect"), f"Unknown outgoing effect: {context}")
        require(type(report["applied"]) is bool and type(report["confirmed"]) is bool, f"Ambiguous adapter result: {context}")
        require(any((r["tick"], r["request"]["attack_key"], r["request"]["effect"], r["request"]["target_id"]) == key
                    for r in scenario["effect_requests"]), f"Adapter result has no synchronous request: {context}")
        if report["applied"]:
            summary["effects_applied"][report["effect"]] += 1
        if report["confirmed"]:
            require(report["applied"] and key not in seen_confirmations, f"Duplicate/unapplied outgoing confirmation: {context}")
            event_name = "shield_counter_confirmed" if report["effect"] == "counter" else "shield_reflection_confirmed"
            require(any(event["event"] == event_name and event["tick"] == entry["tick"] and
                        event["data"].get("attack_key") == report["attack_key"] and
                        event["data"].get("target_id") == report["target_id"] for event in scenario["events"]),
                    f"Adapter acknowledgement has no matching current-scope event: {context}")
            seen_confirmations.add(key)
            summary["effects_confirmed"][report["effect"]] += 1
        elif report["applied"]:
            summary["applied_without_confirmation"] += 1
    name = scenario["name"]
    if name.startswith("physical melee counter "):
        require(summary["routes"] == {"actual telescoping blade contact": 1}, f"Missing/extra physical blade contact: {context}")
    elif name.startswith("real rigid prop "):
        require(summary["routes"] == {"actual rigid-body solver contact": 1}, f"Missing/extra rigid solver contact: {context}")
        require(summary["rigid_return_receiver_contacts"] == 1, f"Missing/extra reflected rigid return contact: {context}")
    elif name.startswith("physical projectile effect "):
        expected = {} if "wall_before_actor" in name else {"actual swept projectile contact": 1}
        require(summary["routes"] == expected, f"Wrong swept-projectile contact record: {context}")
    return {key: dict(value) if isinstance(value, Counter) else value for key, value in summary.items()}


def active_seconds(scenario, first_tick, last_tick):
    require(0 <= first_tick <= last_tick <= len(scenario["frames"]), f"Invalid timing interval: {scenario['name']}")
    # A callback which starts in actor-local pause does no action-clock work,
    # even if the pause remainder reaches zero during that callback.
    return sum(frame["delta"] for frame in scenario["frames"][first_tick:last_tick]
               if frame["before"]["hitpause_remaining"] <= 0)


def timing_rows(scenario, hz):
    context = f"shield/{hz}/{scenario['name']}"
    profile = scenario.get("shield_profile")
    require(isinstance(profile, dict) and profile, f"Effective per-case shield profile missing: {context}")
    for key in ("parry_window_from", "parry_window_until", "miss_recovery_seconds", "success_recovery_seconds",
                "release_recovery_seconds", "use_lock_seconds"):
        require(number(profile[key], context) >= 0, f"Negative timing profile: {context}/{key}")
    result = []
    def add(metric, measured, expected, tolerance, reason):
        close(measured, expected, tolerance, f"{context}/{metric}")
        result.append({"physics_hz": hz, "scenario": scenario["name"], "metric": metric,
                       "observed_seconds": measured, "profile_seconds": expected, "allowed_error": tolerance,
                       "tolerance_reason": reason, "passed": True})
    match = TIMING_NAME.fullmatch(scenario["name"])
    if match:
        prefix, edge, _, _ = match.groups()
        opening, closing = profile["parry_window_from"], profile["parry_window_until"]
        opening_tick, closing_tick = math.ceil((opening - 1e-9) * hz), math.ceil((closing - 1e-9) * hz)
        expected_tick = {"before_open": math.floor((opening - 1e-9) * hz), "first_open": opening_tick,
                         "last_open": closing_tick - 1, "first_closed": closing_tick}[edge]
        require(len(scenario["incoming"]) == 1, f"Timing edge needs one actual dispatch: {context}")
        incoming = scenario["incoming"][0]
        measured = number(incoming["before"]["shield_elapsed"], context)
        close(scenario["measurements"]["contact_attempt_seconds"], measured, 1e-8, f"Timing metric differs from contact snapshot: {context}")
        if "requested_boundary_seconds" in scenario["measurements"]:
            close(scenario["measurements"]["requested_boundary_seconds"], expected_tick / hz, 1e-8, context)
        if "intended_attempt_seconds" in scenario.get("params", {}):
            close(scenario["params"]["intended_attempt_seconds"], expected_tick / hz, 1e-8, context)
        expected_outcome = "parried" if edge in ("first_open", "last_open") else "guarded" if edge == "first_closed" else "hurt"
        require(incoming["result"]["outcome"] == expected_outcome, f"Wrong half-open boundary outcome: {context}")
        expected_route = "actual swept projectile contact" if prefix.startswith("physical") else "direct incoming API descriptor probe"
        require(contact_route(scenario, incoming) == expected_route, f"Timing edge mislabeled its contact route: {context}")
        add("contact_attempt_seconds", measured, expected_tick / hz, 1e-8,
            "Contact snapshot must equal the first/last open or adjacent closed callback derived from this case's actual profile")
    for event in scenario["events"]:
        if event["event"] != "shield_finished" or event["data"].get("reason") != "finished":
            continue
        phase, serial = event["data"].get("phase"), event["data"].get("serial")
        if phase not in ("miss_recovery", "success_recovery", "release_recovery"):
            continue
        starts = [candidate for candidate in scenario["events"] if candidate["event"] == "shield_phase_changed"
                  and candidate["data"].get("phase") == phase and candidate["data"].get("serial") == serial
                  and candidate["tick"] <= event["tick"]]
        require(len(starts) == 1, f"Natural recovery has no unique opening event: {context}/{serial}")
        measured = active_seconds(scenario, starts[0]["tick"], event["tick"])
        add(f"{phase}_serial{serial}_active_seconds", measured, profile[f"{phase}_seconds"], 1 / hz + 1e-8,
            "Real event endpoints count only unpaused actor callbacks; one tick covers endpoint quantization and carried miss-window overshoot")
    starts = [event for event in scenario["events"] if event["event"] == "shield_started"]
    for start in starts:
        serial, tick = start["data"]["serial"], start["tick"]
        if tick < 1:
            continue
        eligible = [frame for frame in scenario["frames"][tick:] if frame["after"]["shield_serial"] == serial]
        zero = next((frame for frame in eligible if frame["after"]["shield_lock_remaining"] <= 0), None)
        if zero is None:
            continue
        lifecycle = [event for event in scenario["events"] if tick <= event["tick"] <= zero["tick"] and
                     (event["event"] in ("reset", "hurt_started") or
                      (event["event"] == "shield_cancelled" and event["data"].get("reason") in ("reset", "damage")))]
        if lifecycle:
            continue  # Intentional hurt/reset clearing is not natural expiry.
        measured = active_seconds(scenario, tick, zero["tick"])
        add(f"use_lock_serial{serial}_active_seconds", measured, profile["use_lock_seconds"], 1 / hz + 1e-8,
            "The independently incurred use lock runs on unpaused actor time through ordinary action replacement")
    return result


def shield_comparisons(suites):
    pair = suites["shield"]
    indexes = {hz: {s["name"]: s for s in run["scenarios"]} for hz, run in pair.items()}
    audits, contacts = [], {str(hz): {} for hz in RATES}
    for hz in RATES:
        for scenario in pair[hz]["scenarios"]:
            audits.extend(timing_rows(scenario, hz))
            contacts[str(hz)][scenario["name"]] = verify_incoming(scenario, hz)
    indexed = {hz: {(row["scenario"], row["metric"]): row for row in audits if row["physics_hz"] == hz} for hz in RATES}
    comparisons = []
    # Some lifecycle replacements intentionally prevent completion at one rate.
    # Only actual completed measurements on both sides are paired; each observed
    # timing is independently checked against the effective per-case profile.
    for key in sorted(indexed[120].keys() & indexed[60].keys()):
        a, b = indexed[120][key], indexed[60][key]
        bound = 1 / 60 + 1e-8
        require(abs(a["observed_seconds"] - b["observed_seconds"]) <= bound, f"Shield timing differs beyond a coarse callback: {key}")
        comparisons.append({"suite": "shield", "scenario": key[0], "metric": key[1],
                            "value_120hz": a["observed_seconds"], "value_60hz": b["observed_seconds"],
                            "allowed_difference": bound, "passed": True,
                            "tolerance_reason": "Same authored actor-time rule with at most one 60 Hz callback of endpoint quantization; paused callbacks are excluded"})
    phases = []
    for hz in RATES:
        for direction in (-1, 1):
            for edge in ("before_open", "first_open", "last_open", "first_closed"):
                api = f"shield window {edge} direction{direction}"
                physical = f"physical projectile window {edge} direction{direction}"
                require(api in indexes[hz] and physical in indexes[hz], f"Missing paired API/physical timing edge: {hz}/{edge}/{direction}")
                values = [indexes[hz][name]["measurements"]["contact_attempt_seconds"] for name in (api, physical)]
                close(values[0], values[1], 1e-8, f"API/physical phase alignment: {hz}/{edge}/{direction}")
                phases.append({"physics_hz": hz, "direction": direction, "edge": edge, "api_scenario": api,
                               "physical_scenario": physical, "api_attempt_seconds": values[0], "physical_attempt_seconds": values[1],
                               "allowed_difference": 1e-8, "passed": True,
                               "tolerance_reason": "Independently sampled descriptor and swept-projectile contact are explicitly placed on the same profile-derived callback; this comparison does not cover unscheduled rigid-body impacts"})
    require(any("miss_recovery" in row["metric"] for row in audits) and
            any("success_recovery" in row["metric"] for row in audits) and
            any("release_recovery" in row["metric"] for row in audits) and
            any("use_lock" in row["metric"] for row in audits), "Missing naturally completed recovery/use-lock timing evidence")
    return comparisons, phases, audits, contacts


def verify_corrections(suites):
    evidence = read(TESTS / "shield_correction_evidence.json")
    require(evidence.get("milestone") == 8, "Wrong correction-evidence milestone")
    corrections = evidence["corrections"]
    require(corrections and len({item["id"] for item in corrections}) == len(corrections), "Empty/duplicate correction record")
    artifacts = {}
    def verify_artifacts(mapping):
        require(isinstance(mapping, dict), "artifact_hashes must be a path-to-SHA256 dictionary")
        for name, digest in mapping.items():
            target = Path(name) if Path(name).is_absolute() else project_path(name)
            artifacts[display(target)] = pin(target, digest)
    verify_artifacts(evidence.get("artifact_hashes", {}))
    controller = suites["shield"][120]["hashes"]["res://combat_pc/player.gd"]
    for item in corrections:
        require(item.get("issue") and item.get("evidence_kind") and item.get("final_cases"), f"Incomplete correction: {item['id']}")
        verify_artifacts(item.get("artifact_hashes", {}))
        if "final_controller_sha256" in item:
            require(item["final_controller_sha256"] == controller, f"Stale final correction source: {item['id']}")
        if item.get("evidence_type") == "physical_pre_fix":
            recorded = item.get("artifact_hashes", {})
            require(any(name.endswith((".json", ".log", "_output.txt")) for name in recorded),
                    f"Physical pre-fix claim has no pinned recorded result: {item['id']}")
            require(any(name.endswith(".gd.txt") for name in recorded),
                    f"Physical pre-fix claim has no retained tested source: {item['id']}")
            if "before_trace" in item:
                require(display(project_path(item["before_trace"])) in artifacts,
                        f"Explicit pre-fix trace is not pinned: {item['id']}")
            if "before_controller_sha256" in item:
                require(any(name.endswith(".gd.txt") and digest == item["before_controller_sha256"]
                            for name, digest in recorded.items()), f"Pre-fix controller is not among retained sources: {item['id']}")
        for case in item["final_cases"]:
            suite, name = ("shield", case) if isinstance(case, str) else (case["suite"], case["name"])
            require(suite in suites, f"Unknown correction suite: {suite}")
            for hz in RATES:
                require(any(s["name"] == name for s in suites[suite][hz]["scenarios"]),
                        f"Correction final case absent: {item['id']}/{suite}/{hz}/{name}")
    return corrections, artifacts


LIMITS = [
    "The shield lifecycle, input policy, phase permissions, geometry, damage, impulses, timing and feedback are authored MOKSHA rules. The source audit establishes bounded concepts and historical developer statements, not recovered Dead Cells v35 executable parity or exact feel.",
    "Direct incoming-API descriptor probes exercise resolver contracts against actual actor geometry. They do not independently prove a projectile sweep, blade collision, or rigid-body solver contact. Those physical routes are counted and identified separately in the detailed report.",
    "An incoming parry is resolved before outgoing work. Adapter application and current-scope counter/redirect acknowledgement are separate evidence. A physical operation may have occurred before a synchronous callback resets its owner; that operation is retained as applied without a stale success acknowledgement.",
    "Incoming history is bounded per live authenticator and attack kind by an authored recent-ID window. It is not a fixed global memory cap: total entries depend on active buckets. Nearby out-of-order identities remain eligible; stale identities cannot regain eligibility through pruning. Projectile carriers authenticate independently of remote sources.",
    "M8 and inherited M7 samples include actual consecutive engine-frame IDs and callback deltas. Older compatibility formats only record consecutive actor ticks; they are not presented as independent engine-callback continuity proof.",
    "The original movement/combat harnesses start-pin smaller inventories than they end-pin. Every recorded start hash must match its end hash, every end hash must match current bytes, and the M8 harness pins its full recorded inventory at both ends. Historical formats are not rewritten to imply additional observations.",
    "Timing checks use each case's effective profile and actual contact/event samples. Local hitpause excludes whole paused callbacks from actor-time recovery and use-lock measurements. Rigid contacts are evaluated at their observed phase; equal spawn placement at different rates does not establish equal impact timing or require arbitrary pre-impact trajectory equality.",
    "Callback/lifecycle acceptance covers the exact recorded synchronous owner, gate, target, reset and delayed-confirmation cases. It does not authorize effects after request scope closes or prove arbitrary external adapter implementations safe.",
    "The shield remains within the existing shared movement/contact motor. No health, universal stamina, shield energy, grenade/fuse simulation, NPC behavior, progression or newly recovered source system is established. Native presentation/feel and packaged-project boot remain separate integration checks.",
]


def main():
    require(REQUIRED_M8_CASES, "Final M8 required-case inventory has not yet been reviewed; acceptance gate remains closed")
    preserved = verify_preservation()
    m7 = load_m7_validator()
    redirects = verify_redirects()
    suites, continuity, logs = {}, {}, {}
    for suite, prefix in FILES.items():
        suites[suite], continuity[suite] = {}, {}
        for hz in RATES:
            run = read(TESTS / f"{prefix}_{hz}hz.json")
            suites[suite][hz] = run
            continuity[suite][str(hz)], found_logs = verify_run(run, suite, hz, m7)
            logs.update(found_logs)
        pair = suites[suite]
        require(pair[120]["hashes"] == pair[60]["hashes"], f"Rate-pair source mismatch: {suite}")
        require([paired_signature(s, suite) for s in pair[120]["scenarios"]] ==
                [paired_signature(s, suite) for s in pair[60]["scenarios"]], f"Rate-pair scenario/parameter/order/count mismatch: {suite}")
    primary = suites["shield"][120]
    names = [scenario["name"] for scenario in primary["scenarios"]]
    require(tuple(names) == REQUIRED_M8_CASES, "M8 case inventory/order differs from the reviewed 215-case matrix")
    shared_hashes = {}
    controller = primary["hashes"]["res://combat_pc/player.gd"]
    for pair in suites.values():
        for run in pair.values():
            require(run["engine"] == primary["engine"], "Runs used different Godot builds")
            require(run["hashes"]["res://combat_pc/player.gd"] == controller, "Runs used different controller revisions")
            for name, digest in run["hashes"].items():
                require(name not in shared_hashes or shared_hashes[name] == digest, f"Cross-suite source mismatch: {name}")
                shared_hashes[name] = digest
            for key in ("movement_profile", "combat_profile", "shield_profile"):
                if key in run:
                    require(run[key] == primary[key], f"Different serialized {key} between suites")
    inherited, inherited_phases, observers = verify_compatibility(suites, m7)
    comparisons, phases, timing, contacts = shield_comparisons(suites)
    corrections, correction_artifacts = verify_corrections(suites)
    contract_hash = pin(ROOT / "combat_pc/MOTOR_CONTRACT.md")
    audit_hash = pin(ROOT / "combat_pc/reference/SHIELD_PARRY_EVIDENCE.md")
    builder_hash = pin(Path(__file__))
    report = {
        "title": "MOKSHA combat PC shield verification", "milestone": 8, "status": "passed",
        "generated_utc": datetime.now(timezone.utc).isoformat(), "controller_sha256": controller,
        "engine": primary["engine"], "production_hashes": shared_hashes, "contract_sha256": contract_hash,
        "source_audit_sha256": audit_hash, "report_builder_sha256": builder_hash,
        "movement_profile": primary["movement_profile"], "combat_profile": primary["combat_profile"], "shield_profile": primary["shield_profile"],
        "execution": primary["execution"], "suites": {}, "sample_continuity": continuity,
        "cross_rate_comparisons": inherited + comparisons, "inherited_comparison_count": len(inherited),
        "within_rate_contact_phase_comparisons": inherited_phases + phases, "inherited_contact_phase_count": len(inherited_phases),
        "profile_timing_audit": timing, "incoming_and_effect_evidence": contacts, "observer_equivalence": observers,
        "required_m8_cases": list(REQUIRED_M8_CASES), "required_m8_group_counts": {name: len(cases) for name, cases in REQUIRED_M8_GROUPS.items()},
        "verified_corrections": corrections,
        "correction_artifacts_sha256": correction_artifacts, "console_logs_sha256": logs,
        "correction_evidence_sha256": PINNED[(TESTS / "shield_correction_evidence.json").resolve()],
        "compatibility_redirects": redirects, "compatibility_redirects_sha256": PINNED[(TESTS / "shield_compatibility_redirects.json").resolve()],
        "preserved_evidence": {"manifest_sha256": PINNED[(TESTS / "shield_preserved_evidence.json").resolve()],
                               "file_count": len(preserved["files"]), "archive_count": len(preserved["archives"]),
                               "all_recorded_bytes_unchanged": True, **preserved},
        "compatibility_method": "Seven original regression harnesses run against the same final controller with only output filenames redirected to M8 paths. Their prior scenario order, parameters and assertion counts, M7 numerical bounds, historical evidence and milestone snapshots remain pinned.",
        "scenarios": [], "limits": LIMITS,
    }
    for suite, pair in suites.items():
        report["suites"][suite] = {str(hz): {
            "scenarios": len(run["scenarios"]), "assertions": run["checks"], "failures": 0,
            "frames": sum(len(s["frames"]) for s in run["scenarios"]), "source_stable": True,
            "path": f"combat_pc/tests/{FILES[suite]}_{hz}hz.json", "sha256": PINNED[(TESTS / f"{FILES[suite]}_{hz}hz.json").resolve()],
        } for hz, run in pair.items()}
    for index, scenario in enumerate(primary["scenarios"]):
        report["scenarios"].append({"name": scenario["name"], "passed_at": list(RATES),
            "assertions": [assertion["label"] for assertion in scenario["assertions"]],
            "traces": {str(hz): {"path": f"combat_pc/tests/shield_results_{hz}hz.json", "json_pointer": f"/scenarios/{index}"} for hz in RATES}})
    markdown = render_markdown(report)
    # Validate all dependencies again before writing either passing artifact.
    for path, digest in PINNED.items():
        require(sha(path) == digest, f"Evidence changed during report generation: {path}")
    (ROOT / "combat_pc/shield_verification.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    (ROOT / "combat_pc/shield_verification.md").write_text(markdown)
    print(f"PASS: {len(primary['scenarios'])} shield scenarios; eight paired suites, {len(inherited) + len(comparisons)} cross-rate bounds, "
          f"{len(timing)} profile timing checks, {len(preserved['files'])} unchanged recorded historical acceptance artifacts and {len(preserved['archives'])} snapshots")


def render_markdown(report):
    primary = report["suites"]["shield"]["120"]
    preserved = report["preserved_evidence"]
    lines = ["# Shield verification", "",
        f"**Passed at 120 Hz and 60 Hz:** {primary['scenarios']} M8 scenarios and {primary['assertions']} assertions per rate. "
        "All seven earlier movement, combat, drop/dive, climb, wall, hard-landing and soft-slope suites pass against the same final controller. All sixteen runs have zero failed assertions and clean engine logs.", "",
        f"Controller SHA-256: `{report['controller_sha256']}`. The [detailed report](shield_verification.json) pins profiles, harnesses, traces, logs, source evidence and historical preservation.", "",
        "## Defense, physical effects and ownership", "",
        "A finite accepted shield attempt has separate raise, parry, hold and recovery phases. Guard reports residual damage once; a full incoming parry closes its window before synchronous callbacks. Independent use-lock timing survives ordinary cancellation and pauses with actor time.", "",
        "Direct incoming descriptor probes test resolver geometry, categories, identity and permissions. Separate fixtures establish actual swept-projectile, telescoping-blade and rigid-body solver contact. Counts below describe observed records rather than turning API calls into physical collision claims.", "",
        "| Incoming route | Records at 120 Hz | Records at 60 Hz |", "|---|---:|---:|"]
    totals = {str(hz): Counter() for hz in RATES}
    for hz in RATES:
        for evidence in report["incoming_and_effect_evidence"][str(hz)].values():
            totals[str(hz)].update(evidence["routes"])
    for route in sorted(totals["120"].keys() | totals["60"].keys()):
        lines.append(f"| {route} | {totals['120'][route]} | {totals['60'][route]} |")
    lines += ["", "Incoming defense success does not imply a successful counter or redirect. Physical adapter results distinguish actual application from current-scope acknowledgement:", "",
        "| Physics rate | Counters applied / confirmed | Redirects applied / confirmed | Later rigid return contacts | Applied without acknowledgement |",
        "|---|---:|---:|---:|---:|"]
    for hz in RATES:
        applied, confirmed = Counter(), Counter()
        returns, unconfirmed = 0, 0
        for evidence in report["incoming_and_effect_evidence"][str(hz)].values():
            applied.update(evidence["effects_applied"])
            confirmed.update(evidence["effects_confirmed"])
            returns += evidence["rigid_return_receiver_contacts"]
            unconfirmed += evidence["applied_without_confirmation"]
        lines.append(f"| {hz} Hz | {applied['counter']} / {confirmed['counter']} | {applied['reflect']} / {confirmed['reflect']} | {returns} | {unconfirmed} |")
    lines += ["", "The applied-but-unacknowledged counter operations occurred before synchronous reset invalidated the request owner. They remain recorded as physical applications; the controller does not publish stale success. Later rigid return contacts are outgoing receiver collisions, not additional incoming parries. Frozen geometry and request scope govern outgoing effects.", "",
        "Incoming history retains a bounded recent-ID range for each live authenticator and attack kind. Reset, freed carriers, reordered arrivals, stale IDs and callback ownership are assessed only within the exact recorded scenarios; the bound is not a global cap on every possible emitter.", "",
        "## Timing and compatibility", "",
        f"All {len(report['profile_timing_audit'])} profile-based timing checks and {len(report['cross_rate_comparisons'])} cross-rate bounds pass. "
        f"The latter retain all {report['inherited_comparison_count']} M7 bounds without widening. "
        f"All {len(report['within_rate_contact_phase_comparisons'])} contact-phase comparisons and {len(report['observer_equivalence'])} inherited stock/observer comparisons pass.", "",
        "Shield opening and closing compare actual incoming snapshots with the effective per-case profile. Natural recovery and lock expiry use observed events and unpaused callback time. Explicitly scheduled projectile edges compare with descriptor probes at the same phase; rigid impacts are evaluated at their observed phase without assuming equal impact times from equal spawn positions.", "",
        "| Suite | Scenarios per rate | Assertions per rate |", "|---|---:|---:|"]
    for suite, pair in report["suites"].items():
        lines.append(f"| {suite.replace('_', ' ')} | {pair['120']['scenarios']} | {pair['120']['assertions']} |")
    lines += ["", "## Corrections and preserved evidence", ""]
    for item in report["verified_corrections"]:
        lines.append(f"- **{item['issue']}** Evidence: {item['evidence_kind'].rstrip('.')}.")
    lines += ["", "The [correction record](tests/shield_correction_evidence.json) identifies the precise final cases and available before evidence. Static review and recorded physical pre-fix failures are distinct evidence categories.", "",
        f"All {preserved['file_count']} recorded historical acceptance artifacts and {preserved['archive_count']} milestone ZIPs retain their manifest hashes. "
        "These counts are computed from the preservation manifest. M8 compatibility files use separate output paths; prior reports and traces are unchanged.", "",
        "## Scope", ""]
    lines += ["- " + item for item in report["limits"]]
    lines += ["", "## Reproduce", "",
        "From the project root, run the complete shield suite at both rates, without a group filter, and save each console stream as `combat_pc/tests/m8_shield_<rate>.log`:", "", "```sh",
        "XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/shield_regression.gd -- --hz=120",
        "XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/shield_regression.gd -- --hz=60", "```", "",
        "Run the seven original compatibility harnesses with only output paths redirected to `<suite>_compat_m8_results_<rate>hz.json`, preserving movement's extra suffix placeholder. Save `m8_<suite>_<rate>.log`. "
        "After all final runs, redirect provenance and correction evidence are ready, run `python3 combat_pc/tests/build_shield_report.py`. It rejects filtered or incomplete runs, stale sources, failed assertions, unclean logs, changed historical bytes, missing callback samples and exceeded bounds before publishing either report.", "",
        "Historical re-audits require the original evidence files and milestone ZIPs listed in the preservation manifest. They are not required to play the project. Each current scenario has exact JSON-pointer trace links in the detailed report.", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    try:
        main()
    except (VerificationError, OSError, ValueError, KeyError, TypeError, StopIteration) as error:
        print(f"FAIL: M8 acceptance report not generated: {error}", file=sys.stderr)
        sys.exit(1)
