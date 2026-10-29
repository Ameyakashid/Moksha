"""Audit final M9 chained-melee evidence before publishing acceptance reports.

This builder is read-only with respect to production, harnesses and historical
acceptance artifacts. It imports preserved numerical verifiers without invoking
their writers. The frozen M9 inventory, profile/identity/contact oracles and
source identity are independent of the result files under audit.
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

# Loading prior verifiers must not rewrite even incidental historical bytecode.
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / "combat_pc/tests"
RATES = (120, 60)
OLDER_SUITES = ("movement", "combat", "traversal", "climb", "wall", "hard_landing", "soft_slope", "shield")
FILES = {"combo": "combo_results", **{
    f"{name}_compatibility": f"{name}_compat_m9_results" for name in OLDER_SUITES}}
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
PINNED: dict[Path, str] = {}
M8_ARCHIVE_SHA256 = "7f3b9e617619704c1104340ee360bbbc547f4869a785b5454c04c4c33e3fe755"
PRESERVED_FILE_COUNT = 384
PRESERVED_ARCHIVE_COUNT = 8

# Static matrix transcribed from the reviewed complete harness, independent of
# the result files. Explicit Cartesian products preserve its execution order.
REQUIRED_M9_GROUPS: dict[str, tuple[str, ...]] = {
    "identity": tuple(f"three distinct strikes {route} direction{direction}"
        for direction in (-1, 1) for route in ("whiff", "one_target", "two_targets", "occluded")) + (
        "one held edge legacy fallback", "one held edge chain"),
    "queue": tuple(f"queue {edge} step{step} {window}" for step in (0, 1)
        for window in ("default_window", "short_window")
        for edge in ("before_open", "first_open", "last_open", "first_closed")) + (
        "first queued edge owns slot without refresh from rapid presses",
        "queued request temporary host denial unlocks", "queued request temporary host denial expires") +
        tuple(f"finisher rejects fresh follow-up during {phase}" for phase in ("windup", "active", "recovery")),
    "retention": tuple(f"natural idle retention {edge} deadline after step{step}"
        for step in (0, 1) for edge in ("before", "at", "after")),
    "cancels": tuple(f"step{step} {window} requests {action}" for step in (0, 1, 2)
        for window in ("windup", "active", "recovery_entry", "recovery_open")
        if not (step == 0 and window == "recovery_entry")
        for action in ("roll", "jump", "air_jump", "shield", "drop", "dive", "climb", "wall")) +
        tuple(f"step{step} {phase} forced retirement {action}" for step in (0, 1, 2)
        for phase in ("windup", "active", "recovery") for action in ("hurt", "forced", "reset")),
    "callbacks": tuple(f"{mode} callback {trigger} replaces {replacement}" for mode in ("fallback", "chain")
        for trigger in ("attack_started", "active_phase", "strike_noise", "strike_confirmed", "hitpause_started", "receiver", "contact_confirmed")
        for replacement in ("reset", "hurt", "forced")),
    "resources": (
        "independent reuse lock and pending deadline freeze through local pause",
        "idle retention freezes during pause before a retained fresh press",
        "episode snapshots all steps and later episode reads edited resource",
        "replacing chain resource immediately withdraws old strike",
        "independent melee reuse lock survives roll", "independent melee reuse lock survives jump",
        "independent melee reuse lock survives forced",
        "M8 shield lock remains authoritative for a queued chain start",
        "melee reuse lock explicit clearing by hurt", "melee reuse lock explicit clearing by reset"),
    "native": ("parsed follow-up tap across local hitpause",
        "parsed follow-up tap across local hitpause with rejected second press",
        "disabled native held input cannot manufacture a chain edge") +
        tuple(f"simultaneous fresh {action} and melee" for action in ("roll", "jump", "shield")),
    "motion": tuple(f"connected chain on slope {gradient:.1f} direction{direction}"
        for gradient in (-1.0, -.5, .5, 1.0) for direction in (-1, 1)) +
        tuple(f"high-speed chain meets thin wall direction{direction}" for direction in (-1, 1)) + (
        "complete chain retains safe small body under a low roof",
        "airborne full chain reaches soft floor", "airborne full chain reaches hard floor",
        "natural jump completion preserves an accepted aerial follow-up"),
    "props": tuple(f"real crate step{step} impulse and noise direction{direction}"
        for step in (0, 1, 2) for direction in (-1, 1)),
    "facing": tuple(f"direction edge {edge} step{step} direction{direction}"
        for step in (0, 1, 2) for direction in (-1, 1) for edge in ("last_windup", "active_entry")) +
        tuple(f"step{step} windup active recovery reversal direction{direction}"
        for step in (0, 1, 2) for direction in (-1, 1)) +
        tuple(f"configured active body turn retains strike latch direction{direction}" for direction in (-1, 1)) +
        tuple(f"step{step} host move and turn permission intersection" for step in (0, 1, 2)),
    "contact_lifetime": tuple(f"resolved physical contact callback {change}"
        for change in ("source_relocation", "target_relocation", "target_removed", "target_queued_delete")) + (
        "live prop becomes ineligible inside strike confirmation",
        "stale step snapshot and old confirmation cannot hit a new target"),
    "air_carrier": ("chain preserves spent air budgets and actual fall excursion",) +
        tuple(f"paused moving carrier cannot sweep chain through skipped target direction{direction}" for direction in (-1, 1)),
    "host_lifetime": ("recursive public tick refuses extra simulation and later fresh attack remains usable",) +
        tuple(f"admission withdrawal preserves committed step{step} {phase}"
        for step in (0, 1, 2) for phase in ("windup", "active", "recovery")) + (
        "synchronous host denial at queued boundary", "synchronous host denial at finished boundary",
        "ground versus air cancellation entry ground", "ground versus air cancellation entry air",
        "late retained idle request survives retention expiry under host lock"),
    "profile_limits": ("same-value chain assignment is inert during a live strike",
        "chain reconfiguration without melee context preserves active shield",
        "configuration assignment round trip in one callback pending",
        "configuration assignment round trip in one callback active",
        "minimum active phase retains contact after strike_noise pause",
        "minimum active phase retains contact after active_phase pause",
        "fallback pending intent is retired across a configuration round trip",
        "short phase resource below minimum", "short phase resource at minimum",
        "same actor reset cycles preserve identity without sharing runtime resource state"),
    "intersections": ("one-way drop cleanup survives replacement by a complete chain",
        "removed support during paused active step resumes ordinary fall",
        "ledge geometry idle physical control", "ledge geometry refuses automatic catch during chain",
        "airborne chain entry during rising", "airborne chain entry during apex", "airborne chain entry during falling"),
}
REQUIRED_M9_CASES = tuple(case for cases in REQUIRED_M9_GROUPS.values() for case in cases)
REVIEWED_M9_HARNESS_SHA256 = "515e6b1baf93601ea535ab283c1fc51aa500881dd276654058ab881a4256485c"
# Final output-only redirect provenance and correction evidence.
REDIRECT_MANIFEST = "combo_compatibility_redirects.json"
CORRECTION_MANIFEST = "combo_correction_evidence.json"


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
        require(isinstance(expected, str) and SHA256.fullmatch(expected), f"Invalid SHA-256: {path}")
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
    path = (ROOT / name).resolve()
    require(path.is_relative_to(ROOT), f"Path escapes project: {name}")
    return path


def resource_path(name):
    require(isinstance(name, str) and name.startswith("res://"), f"Invalid resource path: {name}")
    return project_path(name.removeprefix("res://"))


def verify_preservation():
    preserved = read(TESTS / "combo_preserved_evidence.json")
    require(preserved.get("milestone") == "M9 chained melee", "Wrong preservation milestone")
    require(len(preserved["files"]) == PRESERVED_FILE_COUNT, "Historical file inventory changed")
    require(len(preserved["archives"]) == PRESERVED_ARCHIVE_COUNT, "Historical snapshot inventory changed")
    require(not preserved.get("documentation_updates") and not preserved.get("prior_m8_preservation_drift"),
            "Historical preservation exceptions require explicit review")
    require(preserved["archives"].get("MOKSHA-Combat-PC-M8-20261004.zip") == M8_ARCHIVE_SHA256,
            "Preserved M8 snapshot identity changed")
    for name, digest in preserved["files"].items():
        pin(project_path(name), digest)
    for name, digest in preserved["archives"].items():
        require(Path(name).name == name, f"Unexpected archive name: {name}")
        pin(ROOT.parent / "moksha-backups" / name, digest)
    for name, digest in preserved.get("evidence_archive_sha256", {}).items():
        pin(project_path(name), digest)
    return preserved


def load_preserved_validators():
    """Share one hash ledger; never call an imported historical report writer."""
    path = TESTS / "build_shield_report.py"
    pin(path)
    spec = importlib.util.spec_from_file_location("preserved_m8_acceptance", path)
    require(spec and spec.loader, "Cannot load preserved M8 verifier")
    m8 = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m8)
    for name in ("require", "sha", "pin", "read", "number", "close", "project_path", "resource_path"):
        setattr(m8, name, globals()[name])
    m8.PINNED = PINNED
    m8.VerificationError = VerificationError
    m7 = m8.load_m7_validator()
    m7.VerificationError = VerificationError
    return m8, m7


def verify_redirects():
    redirects = read(TESTS / REDIRECT_MANIFEST)
    require(set(redirects) == set(OLDER_SUITES), "Incomplete output-only redirect provenance")
    for suite, row in redirects.items():
        original = project_path(row["original_harness"])
        pin(original, row["original_sha256"])
        content = original.read_text()
        require(content.count(row["old_output"]) == 1, f"Ambiguous output-only redirect: {suite}")
        suffix = "%dhz%s.json" if suite == "movement" else "%dhz.json"
        expected = f"res://combat_pc/tests/{suite}_compat_m9_results_{suffix}"
        require(row["new_output"] == expected, f"Wrong M9 output destination: {suite}")
        redirected = content.replace(row["old_output"], expected, 1).encode()
        require(hashlib.sha256(redirected).hexdigest() == row["redirected_sha256"],
                f"Compatibility redirect changed test logic: {suite}")
        if "redirected_harness" in row:
            pin(project_path(row["redirected_harness"]), row["redirected_sha256"])
    return redirects


def verify_run(run, suite, hz, m7):
    context = f"{suite}/{hz}"
    require(type(run["physics_hz"]) is int and run["physics_hz"] == hz, f"Wrong physics rate: {context}")
    milestones = {"combo": 9, "shield_compatibility": 8, "soft_slope_compatibility": 7}
    if suite in milestones:
        require(run.get("selected_group") == "", f"Filtered run cannot establish acceptance: {context}")
        require(run.get("milestone") == milestones[suite], f"Wrong milestone: {context}")
    require(run["production_hash_stable_during_run"] is True, f"Unstable sources: {context}")
    start, end = run["starting_hashes"], run["hashes"]
    require(start and end and all(end.get(name) == digest for name, digest in start.items()),
            f"Recorded start/end source mismatch: {context}")
    if suite not in ("movement_compatibility", "combat_compatibility"):
        require(start == end, f"Complete start/end source inventory mismatch: {context}")
    for name, digest in end.items():
        pin(resource_path(name), digest)
    required = ["player.gd", "player.tscn", "resources/movement_profile.gd", "resources/movement_profile.tres"]
    if suite == "combo":
        required += ["resources/combat_profile.gd", "resources/combat_profile.tres",
                     "resources/shield_profile.gd", "resources/shield_profile.tres",
                     "resources/melee_chain.gd", "resources/melee_step.gd", "resources/light_chain.tres",
                     "components/contact_adapter.gd", "components/shield_contact_adapter.gd",
                     "fixtures/contact_target.gd", "fixtures/contact_target.tscn",
                     "tests/combo_regression.gd", "tests/shield_regression.gd"]
    for name in required:
        require(f"res://combat_pc/{name}" in end, f"Required source hash absent: {context}/{name}")
    require(run["failures"] == [], f"Reported failures: {context}: {run['failures']}")
    scenarios = run["scenarios"]
    require(scenarios and len({s["name"] for s in scenarios}) == len(scenarios), f"Empty/duplicate scenarios: {context}")
    total, continuity = 0, {}
    for scenario in scenarios:
        label = f"{context}/{scenario['name']}"
        require(type(scenario["failures"]) is int and scenario["failures"] == 0, f"Scenario failure: {label}")
        require(type(scenario["checks"]) is int and scenario["checks"] == len(scenario["assertions"]) > 0,
                f"Assertion count mismatch: {label}")
        require(all(a["passed"] is True and a.get("label") for a in scenario["assertions"]),
                f"Failed/unlabelled assertion: {label}")
        total += scenario["checks"]
        sampled_kind = "soft_slope" if suite in milestones else suite
        continuity[scenario["name"]] = m7.verify_continuity(scenario, sampled_kind, hz)
    require(type(run["checks"]) is int and run["checks"] == total, f"Run check count mismatch: {context}")
    path = TESTS / f"m9_{suite.removesuffix('_compatibility')}_{hz}.log"
    pin(path)
    content = path.read_text()
    require(not re.search(r"SCRIPT ERROR|ERROR:|FAIL:|WARNING:", content), f"Engine diagnostic: {path}")
    completed = re.findall(r"MOKSHA [^\n]*?(\d+)Hz: (\d+) scenarios, (\d+) checks, (\d+) failures", content)
    require(len(completed) == 1 and tuple(map(int, completed[0])) == (hz, len(scenarios), total, 0),
            f"Missing, repeated or mismatched completion line: {path}")
    return continuity, {display(path): PINNED[path.resolve()]}


def paired_signature(scenario, suite, m8):
    if suite == "shield_compatibility":
        return m8.paired_signature(scenario, "shield")
    params = dict(scenario.get("params", {}))
    if suite == "combo":
        # These are observed rate-quantized states, independently recomputed by
        # verify_boundary_oracles; they are not arbitrary setup exemptions.
        if scenario["name"].startswith("queue "):
            for key in ("sample_age", "sample_live", "expected_queue_acceptance"): params.pop(key, None)
        elif " requests " in scenario["name"]:
            for key in ("phase_age_before", "expected_cancel"): params.pop(key, None)
        elif scenario["name"].startswith("natural idle retention "):
            for key in ("idle_ticks", "retention_before_press"): params.pop(key, None)
        elif scenario["name"].startswith("direction edge "):
            params.pop("pre_age", None)
        elif scenario["name"].startswith("airborne chain entry during "):
            params.pop("entry_vertical_speed", None)
        # Conditional accepted-cancel checks intentionally differ by rate.
        return scenario["name"], params, scenario.get("shield_profile"), scenario.get("melee_chain")
    return (scenario["name"], params, scenario["checks"], scenario.get("shield_profile"))


def verify_compatibility(suites, m8, m7):
    """Run every inherited numerical rule and require its prior bound unchanged."""
    for suite in OLDER_SUITES:
        for hz in RATES:
            prefix = "shield_results" if suite == "shield" else f"{suite}_compat_m8_results"
            old = read(TESTS / f"{prefix}_{hz}hz.json")
            current = suites[f"{suite}_compatibility"][hz]
            fields = lambda run: [(s["name"], s.get("params", {}), s["checks"]) for s in run["scenarios"]]
            require(fields(current) == fields(old), f"Historical scenario coverage/order/count changed: {suite}/{hz}")
    mapped = {( "shield" if key == "shield_compatibility" else key): pair
              for key, pair in suites.items() if key != "combo"}
    names = tuple(s["name"] for s in mapped["shield"][120]["scenarios"])
    require(names == m8.REQUIRED_M8_CASES, "Inherited shield case inventory changed")
    older, slope_phases, observers = m8.verify_compatibility(mapped, m7)
    shield, shield_phases, timing, contacts = m8.shield_comparisons(mapped)
    previous = read(ROOT / "combat_pc/shield_verification.json")
    fields = ("suite", "scenario", "metric", "allowed_difference", "tolerance_reason")
    actual = older + shield
    require([[row[key] for key in fields] for row in actual] ==
            [[row[key] for key in fields] for row in previous["cross_rate_comparisons"]],
            "Inherited M8 numerical acceptance bounds changed or were omitted")
    phases = slope_phases + shield_phases
    # Values are new observations; the identities, tolerance and reason remain fixed.
    value_fields = {"gap38", "gap40", "api_attempt_seconds", "physical_attempt_seconds", "passed"}
    specification = lambda row: {key: value for key, value in row.items() if key not in value_fields}
    require([specification(row) for row in phases] ==
            [specification(row) for row in previous["within_rate_contact_phase_comparisons"]],
            "Inherited within-rate contact-phase bounds changed or were omitted")
    for row in actual:
        if row["suite"] == "shield":
            row["suite"] = "shield_compatibility"
    return actual, phases, observers, timing, contacts


def observed_callback(scenario, entry, context):
    """Require a physical receipt to identify an actually recorded callback."""
    tick = entry["tick"]
    require(type(tick) is int and 1 <= tick <= len(scenario["frames"]),
            f"Physical record outside sampled callback range: {context}")
    require(entry["engine_tick"] == scenario["frames"][tick - 1]["engine_tick"],
            f"Physical record does not identify its observed engine callback: {context}")


def active_seconds(scenario, first_tick, last_tick):
    require(type(first_tick) is int and type(last_tick) is int and
            0 <= first_tick <= last_tick <= len(scenario["frames"]),
            f"Invalid observed actor-clock interval: {scenario['name']}")
    # The complete callback which begins paused performs no actor-clock work.
    return sum(frame["delta"] for frame in scenario["frames"][first_tick:last_tick]
               if number(frame["before"]["hitpause_remaining"], scenario["name"]) <= 0)


def event_rows(scenario, label):
    return [row for row in scenario["events"] if row["event"] == label]


def attack_identity(data):
    return tuple(data[key] for key in ("serial", "chain_serial", "step_index", "input_id", "attack_pose_id"))


def phase_definition(scenario, start, primary):
    index = start["data"]["step_index"]
    if index < 0:
        profile = primary["combat_profile"]
        return {"windup_seconds": profile["attack_windup_seconds"],
                "active_seconds": profile["attack_active_seconds"],
                "recovery_seconds": profile["attack_recovery_seconds"]}
    profile = scenario["melee_chain"]
    # The final editable Resource is intentionally not the admitted snapshot.
    if scenario["name"] == "episode snapshots all steps and later episode reads edited resource" and start["data"]["serial"] <= 2:
        profile = primary["melee_chain"]
    require(profile and 0 <= index < len(profile["steps"]), f"Started step has no profile: {scenario['name']}")
    return profile["steps"][index]


def verify_identities_and_contacts(scenario, hz, primary):
    context = f"combo/{hz}/{scenario['name']}"
    starts = event_rows(scenario, "attack_started")
    for key in ("serial", "input_id"):
        values = [row["data"][key] for row in starts]
        require(all(type(value) is int and value > 0 for value in values) and
                all(a < b for a, b in zip(values, values[1:])), f"Reused/nonmonotonic {key}: {context}")
    by_serial = {row["data"]["serial"]: row for row in starts}
    queued = event_rows(scenario, "chain_input_queued")
    require(len({row["data"]["input_id"] for row in queued}) == len(queued), f"One edge queued repeatedly: {context}")
    for start in starts:
        data = start["data"]
        require(type(data["chain_serial"]) is int and data["chain_serial"] >= 0 and
                type(data["step_index"]) is int and data["step_index"] >= -1 and
                isinstance(data["attack_pose_id"], str), f"Invalid chain/step/pose metadata: {context}")
        frame = scenario["frames"][start["tick"] - 1]
        require(data["input_id"] <= frame["after"]["attack_input_id"], f"Uncaptured input committed: {context}")
        if data["step_index"] >= 0:
            candidates = [row for row in queued if row["data"]["input_id"] == data["input_id"]]
            require(len(candidates) == 1 and candidates[0]["tick"] <= start["tick"] and
                    candidates[0]["data"]["step_index"] == data["step_index"], f"Chain commit has no unique matching request: {context}")
            request = candidates[0]["data"]
            require(request["chain_serial"] in (0, data["chain_serial"]), f"Queue episode changed during commit: {context}")
            definition = phase_definition(scenario, start, primary)
            require(data["attack_pose_id"] == definition["pose_id"] and data["step_label"] == definition["step_label"],
                    f"Committed step/pose identity disagrees with its profile: {context}")
    terminal = set()
    phases = {}
    confirmations = set()
    for row in scenario["events"]:
        kind, data = row["event"], row["data"]
        if kind not in ("attack_started", "attack_phase_changed", "attack_finished", "attack_cancelled", "strike_confirmed"):
            continue
        serial = data["serial"]
        require(serial in by_serial, f"Attack event has no admitted strike: {context}/{kind}")
        expected_identity = attack_identity(by_serial[serial]["data"]) if serial in by_serial else None
        actual_identity = attack_identity(data)
        if kind == "attack_cancelled" and data.get("reason") == "reset":
            require(data["input_id"] == 0, f"Reset cancellation did not record its cleared-input sentinel: {context}")
            actual_identity = actual_identity[:3] + (expected_identity[3],) + actual_identity[4:]
        require(serial in by_serial and actual_identity == expected_identity,
                f"Attack event borrowed a different strike/input/episode: {context}/{kind}")
        if kind == "attack_started": continue
        require(serial not in terminal, f"Attack event after prior strike retirement: {context}/{kind}/{serial}")
        if kind in ("attack_finished", "attack_cancelled"):
            terminal.add(serial)
        elif kind == "attack_phase_changed":
            history = phases.setdefault(serial, [])
            history.append(data["phase"])
            require(history == ["windup", "active", "recovery"][:len(history)], f"Repeated/skipped phase event: {context}/{serial}")
        elif kind == "strike_confirmed":
            identity = (serial, data["target_id"])
            require(identity not in confirmations, f"Duplicate per-strike target confirmation: {context}")
            confirmations.add(identity)
    samples = scenario["strike_samples"]
    for row in samples:
        observed_callback(scenario, row, context)
        snapshot = row["snapshot"]
        serial = snapshot["serial"]
        require(type(snapshot["eligible"]) is bool and snapshot["phase"] == "active" and serial in by_serial,
                f"Malformed or unknown sampled strike: {context}")
        if not snapshot["eligible"]:
            require(scenario["name"].startswith("minimum active phase retains contact after ") and
                    row["after_callbacks"]["hitpause_remaining"] > 0,
                    f"Unreviewed ineligible strike notification: {context}")
        require(attack_identity(snapshot) == attack_identity(by_serial[serial]["data"]), f"Sample lost strike identity: {context}")
        require(scenario["frames"][row["tick"] - 1]["before"]["hitpause_remaining"] <= 0,
                f"Actor-local pause emitted a contact sample: {context}")
        for key in ("center", "previous_center", "origin", "size", "impulse"):
            require(len(snapshot[key]) == 2, f"Invalid strike vector: {context}/{key}")
            for value in snapshot[key]: number(value, context)
        require(snapshot["facing"] in (-1, 1), f"Invalid committed facing: {context}")
        active = [event for event in event_rows(scenario, "attack_phase_changed")
                  if event["data"]["serial"] == serial and event["data"]["phase"] == "active"]
        require(len(active) == 1 and snapshot["facing"] == active[0]["data"]["facing"],
                f"Sample rotated the committed contact-facing latch: {context}")
        if snapshot["step_index"] >= 0:
            definition = phase_definition(scenario, by_serial[serial], primary)
            require(snapshot["size"] == definition["strike_size"], f"Strike geometry changed after admission: {context}")
            close(snapshot["damage"], definition["damage"], 1e-8, context)
            close(snapshot["prop_launch_scale"], definition["prop_launch_scale"], 1e-8, context)
            close(snapshot["impulse"][0], definition["impulse"][0] * snapshot["facing"], 1e-8, context)
            close(snapshot["impulse"][1], definition["impulse"][1], 1e-8, context)
    receipts, targets = scenario["physical_contact_receipts"], scenario["physical_target_receipts"]
    applied = set()
    for row in targets:
        observed_callback(scenario, row, context)
        payload = row["payload"]
        identity = (payload["serial"], row["target_name"])
        require(identity not in applied, f"Target received two applications of the same strike: {context}")
        applied.add(identity)
        require(any(sample["tick"] == row["tick"] and all(payload[key] == sample["snapshot"][key]
                    for key in sample["snapshot"]) for sample in samples),
                f"Target application has no actual eligible sample with its frozen payload: {context}")
        require(any(event["tick"] == row["tick"] and event["data"]["serial"] == payload["serial"] and
                    event["data"]["contact_position"] == payload["contact_position"]
                    for event in event_rows(scenario, "strike_confirmed")), f"Target application has no contact admission: {context}")
    receipt_keys = set()
    for row in receipts:
        observed_callback(scenario, row, context)
        identity = (row["serial"], row["target"]["object_id"])
        require(identity not in receipt_keys and identity in confirmations, f"Duplicate/unconfirmed adapter receipt: {context}")
        receipt_keys.add(identity)
        require(row["kind"] in ("fixture", "prop"), f"Unreviewed contact route: {context}")
        if row["kind"] == "fixture":
            require(any(target["tick"] == row["tick"] and target["target_name"] == row["target"]["name"] and
                        target["payload"]["serial"] == row["serial"] for target in targets),
                    f"Fixture receipt without actual target application: {context}")
        else:
            require(scenario["name"].startswith("real crate step"), f"Unclassified real prop launch: {context}")
    unacknowledged = sum(not any(receipt["kind"] == "fixture" and receipt["tick"] == target["tick"] and
            receipt["serial"] == target["payload"]["serial"] and receipt["target"]["name"] == target["target_name"]
            for receipt in receipts) for target in targets)
    if unacknowledged:
        require(" callback receiver replaces " in scenario["name"] and unacknowledged == 1,
                f"Unreviewed target application without later acknowledgement: {context}")
    clock_checks = Counter()
    for frame in scenario["frames"]:
        before, after = frame["before"], frame["after"]
        require(after["attack_input_id"] - before["attack_input_id"] in (0, 1), f"One callback captured multiple/reversed input identities: {context}")
        for key in ("attack_serial", "chain_serial"):
            require(after[key] >= before[key], f"Identity recycled during a callback: {context}/{key}")
        require(0 <= number(after["weapon_phase_progress"], context) <= 1, f"Unbounded presentation progress: {context}")
        same_owner = before["weapon_generation"] == after["weapon_generation"]
        clearing = any(row["tick"] == frame["tick"] and row["event"] in ("reset", "hurt_started") for row in scenario["events"])
        paused = before["hitpause_remaining"] > 0
        if same_owner and not clearing:
            for key in ("melee_reuse_lock_remaining", "shield_lock_remaining"):
                if before[key] > 0:
                    close(after[key], before[key] if paused else max(0, before[key] - frame["delta"]), 1e-8,
                          f"Independent lock advancement: {context}/{key}")
                    clock_checks[key] += 1
            if before["chain_pending_input_id"] > 0 and before["chain_pending_input_id"] == after["chain_pending_input_id"]:
                frozen = paused or before["main_action"] == "hard_land"
                close(after["chain_pending_remaining"], before["chain_pending_remaining"] if frozen else max(0, before["chain_pending_remaining"] - frame["delta"]),
                      1e-8, f"Independent pending deadline: {context}")
                clock_checks["chain_pending_remaining"] += 1
            if before["chain_retention_remaining"] > 0 and before["weapon_phase"] == after["weapon_phase"] == "idle":
                close(after["chain_retention_remaining"], before["chain_retention_remaining"] if paused else max(0, before["chain_retention_remaining"] - frame["delta"]),
                      1e-8, f"Independent retention advancement: {context}")
                clock_checks["chain_retention_remaining"] += 1
        if paused and same_owner:
            close(after["attack_step_elapsed"], before["attack_step_elapsed"], 1e-8, f"Paused step clock: {context}")
            close(after["weapon_elapsed"], before["weapon_elapsed"], 1e-8, f"Paused phase clock: {context}")
            for key in ("melee_reuse_lock_remaining", "shield_lock_remaining", "chain_retention_remaining"):
                close(after[key], before[key], 1e-8, f"Paused independent clock: {context}/{key}")
            if before["chain_pending_input_id"] > 0 and before["chain_pending_input_id"] == after["chain_pending_input_id"]:
                close(after["chain_pending_remaining"], before["chain_pending_remaining"], 1e-8, f"Paused queue clock: {context}")
    return {"committed_strikes": len(starts), "strike_notifications": len(samples),
            "eligible_strike_samples": sum(row["snapshot"]["eligible"] for row in samples),
            "ineligible_entry_pause_notifications": sum(not row["snapshot"]["eligible"] for row in samples),
            "unique_actor_contact_admissions": len(confirmations), "passive_target_applications": len(targets),
            "passive_target_acknowledgements": sum(row["kind"] == "fixture" for row in receipts),
            "prop_launch_acknowledgements": sum(row["kind"] == "prop" for row in receipts),
            "applied_target_effects_without_later_acknowledgement": unacknowledged,
            "independent_clock_transition_checks": dict(clock_checks),
            "direct_authority_probes": "Assertion-backed direct API rejection checks remain separate from the recorded physical receipts"}


def verify_boundary_oracles(scenario, hz):
    name, params, frames = scenario["name"], scenario["params"], scenario["frames"]
    context = f"combo/{hz}/{name}"
    starts = event_rows(scenario, "attack_started")
    input_frames = [frame for frame in frames if frame["after"]["attack_input_id"] > frame["before"]["attack_input_id"]]
    if name.startswith("queue "):
        request = input_frames[-1]
        before = request["before"]
        definition = scenario["melee_chain"]["steps"][params["step"]]
        boundary = definition["followup_open_seconds"] if params["edge"] in ("before_open", "first_open") else definition["followup_close_seconds"]
        tick = math.ceil((boundary - 1e-9) * hz) - (1 if params["edge"] in ("before_open", "last_open") else 0)
        close(params["sample_age"], tick / hz, 1e-8, context)
        close(before["attack_step_elapsed"], params["sample_age"], 1e-8, context)
        live = before["weapon_phase"] != "idle"
        accepted = live and definition["followup_open_seconds"] <= params["sample_age"] + 1e-9 < definition["followup_close_seconds"]
        require(params["sample_live"] == live and params["expected_queue_acceptance"] == accepted, f"Queue oracle disagrees with observed pre-advance phase: {context}")
        pending = [row for row in event_rows(scenario, "chain_input_queued") if row["tick"] == request["tick"]]
        require(len(pending) == int(accepted or not live), f"Queue boundary admitted wrong number of requests: {context}")
        if pending:
            require(pending[0]["data"]["kind"] == ("followup" if live else "retained"), f"Queue/retention kind conflated: {context}")
        uses = [row for row in starts if row["data"]["input_id"] == request["after"]["attack_input_id"]]
        require(len(uses) == int(accepted or not live), f"Boundary edge repeated or leaked after rejection: {context}")
    elif " requests " in name:
        definition = scenario["melee_chain"]["steps"][params["step"]]
        phase = params["phase_before"]
        accepted = params["action"] in definition[f"{phase}_cancels"] and (
            phase != "recovery" or params["phase_age_before"] + 1 / hz + 1e-9 >= definition["recovery_cancel_after"])
        require(params["expected_cancel"] is accepted, f"Cancel outcome not derived from the reached phase/profile: {context}")
        candidates = [frame for frame in frames if frame["before"]["attack_step_index"] == params["step"] and
            frame["before"]["weapon_phase"] == phase and abs(frame["before"]["weapon_elapsed"] - params["phase_age_before"]) < 1e-8]
        require(len(candidates) == 1, f"Cancel request lacks its exact pre-advance sample: {context}")
        state = candidates[0]["after"]
        actual = state["shield_phase"] != "idle" if params["action"] == "shield" else state["main_action"] == params["action"]
        require(actual == accepted and (state["weapon_phase"] == "idle") == accepted, f"Cancel mutation differs from profile oracle: {context}")
        require(scenario["checks"] == (8 if accepted else 5), f"Conditional cancel assertions missing: {context}")
    elif name.startswith("natural idle retention "):
        request = input_frames[-1]
        retention = request["before"]["chain_retention_remaining"]
        close(retention, params["retention_before_press"], 1e-8, context)
        expected_ticks = math.ceil((scenario["melee_chain"]["idle_retention_seconds"] - 1e-9) * hz)
        expected_ticks += {"before": -1, "at": 0, "after": 1}[params["edge"]]
        require(params["idle_ticks"] == expected_ticks, f"Retention boundary setup differs from profile: {context}")
        expected = params["step"] + 1 if retention > 1e-9 else scenario["melee_chain"]["start_step"]
        require(starts[-1]["data"]["step_index"] == expected, f"Expired retention reused old progress: {context}")
    elif name.startswith("direction edge "):
        definition = scenario["melee_chain"]["steps"][params["step"]]
        entry = math.ceil((definition["windup_seconds"] - 1e-9) * hz)
        expected_age = max(0, entry - (2 if params["edge"] == "last_windup" else 1)) / hz
        close(params["pre_age"], expected_age, 1e-8, context)
        matching = [frame for frame in frames if frame["before"]["attack_step_index"] == params["step"] and
                    abs(frame["before"]["attack_step_elapsed"] - expected_age) < 1e-8]
        require(len(matching) == 1, f"Facing boundary has no unique observed callback: {context}")
        expected = -params["direction"] if params["edge"] == "last_windup" else params["direction"]
        require(matching[0]["after"]["facing"] == expected, f"Facing ignored post-advance phase: {context}")
    elif name.startswith("airborne chain entry during "):
        # The attack_started event pins the actual entry rather than any guessed
        # relationship between fresh jump and attack edges.
        before = frames[starts[0]["tick"] - 1]["before"]
        close(params["entry_vertical_speed"], before["velocity"][1], 1e-6, context)
        speed = params["entry_vertical_speed"]
        require(speed < 0 if name.endswith("rising") else abs(speed) <= 45 if name.endswith("apex") else speed >= 100,
                f"Air-entry case did not reach its declared phase: {context}")
        require(number(scenario["measurements"]["maximum_fall_velocity_error"], context) <= .002,
                f"Chain modified ordinary falling gravity: {context}")
    if "recursive_api_probe" in scenario["measurements"]:
        probe = scenario["measurements"]["recursive_api_probe"]
        require(probe["called"] is True and probe["before"] == probe["after"], f"Recursive API changed actor state: {context}")


def combo_timing_rows(scenario, hz, primary):
    rows = []
    for start in event_rows(scenario, "attack_started"):
        serial = start["data"]["serial"]
        definition = phase_definition(scenario, start, primary)
        durations = [number(definition[f"{phase}_seconds"], scenario["name"]) for phase in ("windup", "active", "recovery")]
        short = min(durations) < 1 / hz
        for event in scenario["events"]:
            if event["data"].get("serial") != serial: continue
            if event["event"] == "attack_phase_changed" and event["data"].get("phase") in ("active", "recovery"):
                phase = event["data"]["phase"]
                expected = durations[0] if phase == "active" else sum(durations[:2])
                metric = f"strike{serial}_{phase}_entry"
            elif event["event"] == "attack_finished" and not event["data"].get("early_chain", False):
                expected = sum(durations)
                metric = f"strike{serial}_natural_completion"
            elif event["event"] == "attack_finished" and event["data"].get("early_chain", False):
                expected = sum(durations[:2]) + definition["followup_commit_recovery_seconds"]
                measured = active_seconds(scenario, start["tick"], event["tick"])
                require(measured + 1e-8 >= expected, f"Follow-up committed before its independent recovery gate: {scenario['name']}/{hz}/{serial}")
                if not scenario["name"].startswith("three distinct strikes "):
                    continue  # Host denial or late captured edges can legitimately delay admission.
                metric = f"strike{serial}_earliest_followup_commit"
            else: continue
            measured = active_seconds(scenario, start["tick"], event["tick"])
            # Short phases explicitly preserve at least one active contact
            # opportunity. Entry-pause resume can require one additional live
            # callback before recovery; up to three endpoint callbacks cover it.
            allowance = (3 if short else 1) / hz + 1e-8
            require(expected - 1e-8 <= measured <= expected + allowance,
                    f"Observed phase clock exceeds its documented profile bound: {scenario['name']}/{hz}/{metric}: {measured} vs {expected} + {allowance}")
            rows.append({"physics_hz": hz, "scenario": scenario["name"], "metric": metric,
                "observed_seconds": measured, "profile_seconds": expected, "allowed_error": allowance,
                "short_phase_contact_preservation": short, "passed": True,
                "tolerance_reason": "Cumulative unpaused actor time; one endpoint callback for ordinary phases, three for sub-callback phases retaining a contact opportunity across entry pause"})
    return rows


def verify_combo_semantics(suites):
    pair = suites["combo"]
    timing, contacts = [], {str(hz): {} for hz in RATES}
    for hz, run in pair.items():
        require(run["checks"] == {120: 1360, 60: 1384}[hz], f"Reviewed M9 assertion inventory changed at {hz} Hz")
        for scenario in run["scenarios"]:
            contacts[str(hz)][scenario["name"]] = verify_identities_and_contacts(scenario, hz, run)
            verify_boundary_oracles(scenario, hz)
            timing.extend(combo_timing_rows(scenario, hz, run))
            name = scenario["name"]
            if name.startswith("three distinct strikes "):
                starts = event_rows(scenario, "attack_started")
                require([row["data"]["step_index"] for row in starts] == [0, 1, 2], f"Incomplete authored chain: {hz}/{name}")
                require(len({row["data"]["chain_serial"] for row in starts}) == 1, f"Connected chain episode replaced: {hz}/{name}")
                expected = 6 if "two_targets" in name else 3 if "one_target" in name else 0
                require(len(scenario["physical_target_receipts"]) == expected and len(scenario["physical_contact_receipts"]) == expected,
                        f"Actual hit/whiff/occlusion applications differ: {hz}/{name}")
                require(len(event_rows(scenario, "hitpause_started")) == (3 if expected else 0), f"Hitpause multiplicity differs from one per eligible strike: {hz}/{name}")
            if " callback " in name and " replaces " in name:
                expected = int(" callback receiver " in name or " callback contact_confirmed " in name)
                require(len(scenario["physical_target_receipts"]) == expected and scenario["measurements"]["target_hits"] == expected,
                        f"Callback ownership leaked or erased actual target applications: {hz}/{name}")
            if name.startswith("real crate step"):
                require(contacts[str(hz)][name]["prop_launch_acknowledgements"] == 1 and not scenario["physical_target_receipts"],
                        f"Real prop evidence conflated with passive targets: {hz}/{name}")
                direction = int(name.rsplit("direction", 1)[1])
                values = scenario["measurements"]
                require(number(values["prop_velocity"][0], name) * direction > number(values["expected_launch_speed"], name) * .5,
                        f"Actual prop momentum misses profile-derived floor: {hz}/{name}")
    indexes = {hz: {(row["scenario"], row["metric"]): row for row in timing if row["physics_hz"] == hz} for hz in RATES}
    comparisons = []
    require(indexes[120].keys() == indexes[60].keys(), "One rate omitted an observed M9 phase-clock measurement")
    for key in sorted(indexes[120]):
        a, b = indexes[120][key], indexes[60][key]
        bound = (3 if a["short_phase_contact_preservation"] or b["short_phase_contact_preservation"] else 1) / 60 + 1e-8
        close(a["observed_seconds"], b["observed_seconds"], bound, f"M9 cross-rate phase timing: {key}")
        comparisons.append({"suite": "combo", "scenario": key[0], "metric": key[1],
            "value_120hz": a["observed_seconds"], "value_60hz": b["observed_seconds"],
            "allowed_difference": bound, "passed": True,
            "tolerance_reason": "Same cumulative authored actor clock; endpoint quantization and explicitly retained sub-callback contact opportunities, with paused callbacks excluded"})
    # Exact structural counts are useful comparisons; physical object IDs and
    # absolute engine-frame IDs intentionally differ between independent runs.
    for name in REQUIRED_M9_CASES:
        for key in ("passive_target_applications", "passive_target_acknowledgements", "prop_launch_acknowledgements",
                    "applied_target_effects_without_later_acknowledgement"):
            a, b = contacts["120"][name][key], contacts["60"][name][key]
            require(a == b, f"Cross-rate physical effect population differs: {name}/{key}")
    require(timing and comparisons, "Missing M9 timing/cross-rate evidence")
    return comparisons, timing, contacts


def prop_scale_rows(suites):
    rows = []
    for hz, run in suites["combo"].items():
        index = {scenario["name"]: scenario for scenario in run["scenarios"]}
        for direction in (-1, 1):
            baseline = index[f"real crate step0 impulse and noise direction{direction}"]
            base_speed = abs(number(baseline["measurements"]["prop_velocity"][0], "prop baseline"))
            base_scale = baseline["melee_chain"]["steps"][0]["prop_launch_scale"]
            require(base_speed > 0 and base_scale > 0, "Missing actual baseline prop momentum")
            for step in (1, 2):
                scenario = index[f"real crate step{step} impulse and noise direction{direction}"]
                measured = abs(number(scenario["measurements"]["prop_velocity"][0], "prop velocity")) / base_speed
                expected = scenario["melee_chain"]["steps"][step]["prop_launch_scale"] / base_scale
                close(measured, expected, .002, f"Actual per-step prop launch scaling: {hz}/{direction}/{step}")
                rows.append({"physics_hz": hz, "direction": direction, "step": step,
                    "baseline_scenario": baseline["name"], "scenario": scenario["name"],
                    "observed_horizontal_speed_ratio": measured, "profile_launch_scale_ratio": expected,
                    "allowed_difference": .002, "passed": True,
                    "tolerance_reason": "Same-rate mirrored production crate, identical tuning and zero spin, sampled two solver callbacks after each launch; ratio isolates authored step scaling while allowing floating-point integration differences"})
    return rows


def verify_corrections(suites):
    evidence = read(TESTS / CORRECTION_MANIFEST)
    require(evidence.get("milestone") == 9, "Wrong correction milestone")
    corrections = evidence["corrections"]
    require(corrections and len({row["id"] for row in corrections}) == len(corrections),
            "Empty/duplicate correction record")
    controller = suites["combo"][120]["hashes"]["res://combat_pc/player.gd"]
    artifacts = {}
    for row in corrections:
        require(row.get("issue") and row.get("evidence_kind") and row.get("final_cases"),
                f"Correction lacks final reviewed evidence: {row['id']}")
        require(row.get("final_controller_sha256") == controller, f"Stale correction source: {row['id']}")
        recorded = row.get("artifacts_sha256", row.get("artifact_hashes", {}))
        require(isinstance(recorded, dict) and recorded, f"Missing retained correction artifacts: {row['id']}")
        for name, digest in recorded.items():
            artifacts[name] = pin(project_path(name), digest)
        if row.get("before_controller_sha256"):
            require(any(name.endswith(".gd.txt") and digest == row["before_controller_sha256"]
                        for name, digest in recorded.items()), f"Before-source snapshot absent: {row['id']}")
        for case in row["final_cases"]:
            suite, name = ("combo", case) if isinstance(case, str) else (case["suite"], case["name"])
            require(suite in suites, f"Unknown final correction suite: {suite}")
            for hz in RATES:
                require(any(s["name"] == name for s in suites[suite][hz]["scenarios"]),
                        f"Final correction case absent: {row['id']}/{suite}/{hz}/{name}")
    return corrections, artifacts


LIMITS = [
    "Step count, timing, queues, cancellation, geometry, movement, damage, impulses and feedback are original MOKSHA policy. The source study does not establish recovered reference-game values, executable equivalence or exact feel.",
    "Direct strike-authority API probes, production-adapter passive target contacts and actual prop applications are separate evidence categories. A confirmed actor event alone does not establish that a receiver applied an effect.",
    "Reset clears consumed-input telemetry before its cancellation event, which therefore carries input_id zero. The cancellation keeps its prior strike, chain, step and pose; its original fresh edge is established by the matching attack_started event. Ordinary scheduled callbacks and the explicit recursive-API refusal probe are reported separately.",
    "An entry feedback pause may emit an ineligible active-phase notification. It is not an eligible contact sample or a target application. The finite short phase must retain a later eligible sample after pause.",
    "Actor clocks are measured from actual events and recorded callbacks. A callback beginning in local hitpause contributes no action-clock time. Unrelated shield locks retain their own observed lifetime.",
    "M9, M8 and M7 record consecutive actual engine-frame IDs and callback deltas. Older compatibility formats record consecutive actor ticks only and do not establish the stronger engine-callback observation.",
    "The original movement/combat suites start-pin smaller source inventories than they end-pin. Their recorded start hashes must match end hashes, and every end hash must match current bytes; historical formats are not rewritten.",
    "Acceptance covers the recorded passive fixtures and synchronous ownership replacements. It does not establish arbitrary custom profiles, adapters, collision meshes, NPC systems, health, progression or reference-game parity. Native presentation and packaged-project boot remain separate integration checks.",
]


def main():
    require(REQUIRED_M9_CASES, "Final independent M9 required-case inventory is pending; acceptance gate remains closed")
    require(len(set(REQUIRED_M9_CASES)) == len(REQUIRED_M9_CASES), "Duplicate required M9 case names")
    pin(TESTS / "combo_regression.gd", REVIEWED_M9_HARNESS_SHA256)
    preserved = verify_preservation()
    m8, m7 = load_preserved_validators()
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
        require([paired_signature(s, suite, m8) for s in pair[120]["scenarios"]] ==
                [paired_signature(s, suite, m8) for s in pair[60]["scenarios"]],
                f"Rate-pair scenario/parameter/order/count mismatch: {suite}")
    primary = suites["combo"][120]
    require(tuple(s["name"] for s in primary["scenarios"]) == REQUIRED_M9_CASES,
            "M9 coverage/order differs from the independent reviewed inventory")
    controller = primary["hashes"]["res://combat_pc/player.gd"]
    shared_hashes = {}
    for pair in suites.values():
        for run in pair.values():
            require(run["engine"] == primary["engine"], "Different Godot builds across runs")
            require(run["hashes"]["res://combat_pc/player.gd"] == controller, "Different controller revisions across runs")
            for name, digest in run["hashes"].items():
                require(name not in shared_hashes or shared_hashes[name] == digest, f"Cross-suite source mismatch: {name}")
                shared_hashes[name] = digest
            for key in ("movement_profile", "combat_profile", "shield_profile", "melee_chain"):
                if key in run:
                    require(run[key] == primary[key], f"Different serialized {key} across suites")
    inherited, phases, observers, shield_timing, shield_contacts = verify_compatibility(suites, m8, m7)
    comparisons, timing, contacts = verify_combo_semantics(suites)
    prop_scaling = prop_scale_rows(suites)
    corrections, correction_artifacts = verify_corrections(suites)
    report = {
        "title": "MOKSHA combat PC chained-melee verification", "milestone": 9, "status": "passed",
        "generated_utc": datetime.now(timezone.utc).isoformat(), "controller_sha256": controller,
        "engine": primary["engine"], "production_hashes": shared_hashes,
        "contract_sha256": pin(ROOT / "combat_pc/MOTOR_CONTRACT.md"),
        "source_audit_sha256": pin(ROOT / "combat_pc/reference/MELEE_COMBO_CHARGE_EVIDENCE.md"),
        "source_facts_sha256": pin(ROOT / "combat_pc/reference/MELEE_COMBO_SOURCE_FACTS.json"),
        "report_builder_sha256": pin(Path(__file__)), "execution": primary["execution"],
        **{key: primary[key] for key in ("movement_profile", "combat_profile", "shield_profile", "melee_chain")},
        "required_m9_cases": list(REQUIRED_M9_CASES),
        "required_m9_group_counts": {key: len(value) for key, value in REQUIRED_M9_GROUPS.items()},
        "suites": {}, "sample_continuity": continuity, "cross_rate_comparisons": inherited + comparisons,
        "inherited_comparison_count": len(inherited), "within_rate_contact_phase_comparisons": phases,
        "profile_timing_audit": timing, "inherited_shield_profile_timing_audit": shield_timing,
        "prop_scale_comparisons": prop_scaling,
        "strike_and_contact_evidence": contacts, "inherited_shield_contact_evidence": shield_contacts,
        "observer_equivalence": observers, "verified_corrections": corrections,
        "correction_artifacts_sha256": correction_artifacts, "console_logs_sha256": logs,
        "correction_evidence_sha256": PINNED[(TESTS / CORRECTION_MANIFEST).resolve()],
        "compatibility_redirects": redirects,
        "compatibility_redirects_sha256": PINNED[(TESTS / REDIRECT_MANIFEST).resolve()],
        "preserved_evidence": {"manifest_sha256": PINNED[(TESTS / "combo_preserved_evidence.json").resolve()],
            "file_count": len(preserved["files"]), "archive_count": len(preserved["archives"]),
            "all_recorded_bytes_unchanged": True, **preserved},
        "compatibility_method": "Eight unchanged earlier harnesses run against the same final sources with only output paths redirected. Historical case order, parameters, assertion counts and all M8 numerical bounds remain pinned.",
        "scenarios": [], "limits": LIMITS,
    }
    for suite, pair in suites.items():
        report["suites"][suite] = {str(hz): {
            "scenarios": len(run["scenarios"]), "assertions": run["checks"], "failures": 0,
            "frames": sum(len(s["frames"]) for s in run["scenarios"]), "source_stable": True,
            "path": f"combat_pc/tests/{FILES[suite]}_{hz}hz.json",
            "sha256": PINNED[(TESTS / f"{FILES[suite]}_{hz}hz.json").resolve()],
        } for hz, run in pair.items()}
    for index, scenario in enumerate(primary["scenarios"]):
        report["scenarios"].append({"name": scenario["name"], "passed_at": list(RATES),
            "assertions_by_rate": {str(hz): [item["label"] for item in suites["combo"][hz]["scenarios"][index]["assertions"]] for hz in RATES},
            "parameters_by_rate": {str(hz): suites["combo"][hz]["scenarios"][index]["params"] for hz in RATES},
            "traces": {str(hz): {"path": f"combat_pc/tests/combo_results_{hz}hz.json",
                "json_pointer": f"/scenarios/{index}"} for hz in RATES}})
    markdown = render_markdown(report)
    for path, digest in PINNED.items():
        require(sha(path) == digest, f"Evidence changed during report generation: {path}")
    if "--check-only" in sys.argv:
        print(f"PASS (read-only): {len(primary['scenarios'])} M9 cases, {len(inherited) + len(comparisons)} cross-rate bounds, {len(timing)} profile timing checks, {len(prop_scaling)} prop scale comparisons")
        return
    (ROOT / "combat_pc/combo_verification.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    (ROOT / "combat_pc/combo_verification.md").write_text(markdown)
    print(f"PASS: {len(primary['scenarios'])} chained-melee scenarios; nine paired suites; "
          f"{len(inherited) + len(comparisons)} cross-rate bounds; historical evidence unchanged")


def render_markdown(report):
    primary = report["suites"]["combo"]
    preserved = report["preserved_evidence"]
    totals, clocks = {}, {}
    for hz in ("120", "60"):
        totals[hz], clocks[hz] = Counter(), Counter()
        for row in report["strike_and_contact_evidence"][hz].values():
            totals[hz].update({key: value for key, value in row.items() if type(value) is int})
            clocks[hz].update(row["independent_clock_transition_checks"])
    lines = ["# Chained-melee verification", "",
        f"**Passed at 120 Hz and 60 Hz:** {primary['120']['scenarios']} M9 scenarios at each rate; "
        f"{primary['120']['assertions']:,} assertions at 120 Hz and {primary['60']['assertions']:,} at 60 Hz. "
        "All eight earlier suites pass against the same final controller. All eighteen runs have zero failed assertions and clean engine logs.", "",
        f"Controller SHA-256: `{report['controller_sha256']}`. The [detailed report](combo_verification.json) pins the production sources, authored profiles, harnesses, traces, logs, source study and historical evidence.", "",
        "## Authored chain and input ownership", "",
        "The optional chain has three distinct step identities and original pose keys. Each accepted fresh edge commits one new strike serial and is consumed once. A single pending slot keeps the first accepted request without refreshing its deadline when extra presses arrive. The default policy has no automatic hold-repeat or charged branch. A null chain retains the single-swing fallback.", "",
        "Every value below is authored MOKSHA tuning. Per-case profile overrides and admitted-episode snapshots are retained in the detailed evidence.", "",
        "| Step | Pose | Windup / active / recovery, seconds | Next step | Prop launch scale |",
        "|---|---|---|---|---:|"]
    for index, step in enumerate(report["melee_chain"]["steps"]):
        following = str(step["next_step"] + 1) if step["next_step"] >= 0 else "ends chain"
        lines.append(f"| {index + 1}: {step['step_label']} | {step['pose_id']} | {step['windup_seconds']:.3f} / {step['active_seconds']:.3f} / {step['recovery_seconds']:.3f} | {following} | {step['prop_launch_scale']:.2f} |")
    lines += ["",
        "Queue boundaries are evaluated at the observed pre-advance step age. Movement cancellation and turning use the phase reached after that callback advances. Idle retention, pending-input expiry, phase time, melee reuse lock and shield lock are distinct clocks. Host denial can defer a still-valid request; expiry and retirement prevent delayed unwanted attacks.", "",
        "The eight step-2 recovery-entry cancellation cases deliberately differ by rate: their 0.020-second gate remains closed after the 120 Hz request tick but is open after the 60 Hz request tick. Each accepted transition adds three cleanup checks, explaining the 24-assertion difference. The builder independently reconstructs both outcomes from each profile and recorded pre-request sample.", "",
        "## Actual contacts, payloads and callbacks", "",
        "Physical receipts are tied to recorded Godot engine callbacks and eligible production-adapter strike samples. The builder checks strike, input, episode and pose identity; committed facing; shape; damage; impulse; and prop launch scale against the admitted step. In-place resource edits use the earlier episode snapshot until a new episode starts.", "",
        "| Observed population | 120 Hz | 60 Hz |", "|---|---:|---:|"]
    for label, key in (
        ("Actor contact admissions", "unique_actor_contact_admissions"),
        ("Passive target effects applied", "passive_target_applications"),
        ("Passive target effects acknowledged afterward", "passive_target_acknowledgements"),
        ("Already-applied target effects without later acknowledgement", "applied_target_effects_without_later_acknowledgement"),
        ("Actual prop launches acknowledged", "prop_launch_acknowledgements"),
        ("Ineligible notifications caused by active-entry pause", "ineligible_entry_pause_notifications")):
        lines.append(f"| {label} | {totals['120'][key]} | {totals['60'][key]} |")
    lines += ["",
        "The 37 target applications and 37 combined adapter receipts are different populations: adapter receipts include six prop launches, while target applications include six receiver callbacks that apply their effect before replacing the owner. Those six effects remain counted, but no stale later acknowledgement is claimed. An actor admission by itself does not establish an applied receiver effect. Direct stale-serial/snapshot API probes and the recursive-tick refusal probe remain separate from actual physical contacts.", "",
        "Mirrored hit, two-target, whiff and occlusion cases verify once-per-target-per-step behavior, later-step eligibility and once-per-strike contact pause. Reset/hurt/forced replacements at attack start, phase entry, noise, confirmation, pause, receiver and contact acknowledgement stop unapplied work. Resolved contact points remain frozen across relocation; removed or withdrawn targets cannot receive pending effects, and transport cannot create a sweep across a skipped world path.", "",
        f"All {len(report['prop_scale_comparisons'])} same-rate prop-scaling checks pass. Backhand/Slash and Finisher/Slash horizontal-speed ratios match their profile ratios within 0.002 after the same two solver callbacks. Identical crate tuning and zero spin isolate the step-dependent launch strength; a merely positive impulse is insufficient.", "",
        "## Clocks, movement and compatibility", "",
        f"All {len(report['profile_timing_audit']):,} M9 profile timing checks and {len(report['cross_rate_comparisons']):,} cross-rate numerical bounds pass. "
        f"The latter retain all {report['inherited_comparison_count']} inherited bounds without widening. "
        f"All {len(report['within_rate_contact_phase_comparisons'])} inherited contact-phase comparisons, {len(report['observer_equivalence'])} stock/observer pairs and {len(report['inherited_shield_profile_timing_audit'])} shield timing checks pass.", "",
        "Phase timings use cumulative unpaused actor time. Ordinary endpoints permit one callback of quantization. Valid sub-callback phases retain a real active sample even when entry feedback pauses them; their separately identified bound allows up to three endpoint callbacks. Ineligible entry notifications cannot stand in for that later eligible sample. Sampled pending deadlines, retention, melee locks and shield locks are independently recomputed, including their paused intervals.", "",
        "The connected chain also covers mirrored slopes, thin-wall collision at high authored speed, a low roof, rising/apex/falling entry, soft and hard floor contact, spent air budgets, moving and removed supports, targeted one-way cleanup and ledge geometry. The falling cases retain ordinary gravity and airborne resources. Compatibility retains the earlier movement, combat, traversal, climb, wall, hard-landing, soft-slope and shield contracts.", "",
        "| Suite | Scenarios at each rate | Assertions at 120 Hz | Assertions at 60 Hz |", "|---|---:|---:|---:|"]
    for suite, pair in report["suites"].items():
        lines.append(f"| {suite.replace('_', ' ')} | {pair['120']['scenarios']} | {pair['120']['assertions']} | {pair['60']['assertions']} |")
    lines += ["", "## Corrections and preservation", ""]
    for item in report["verified_corrections"]:
        lines.append(f"- **{item['issue'].rstrip('.')}** Evidence: {item['evidence_kind'].rstrip('.')}.")
    lines += ["",
        "The [correction record](tests/combo_correction_evidence.json) retains exact before-source hashes and final replay cases. The short-active-phase issue has implementation-sourced physical before evidence and an independently observed fixed checkpoint; it is not presented as an independent failing before replay.", "",
        f"All {preserved['file_count']} recorded historical acceptance artifacts and {preserved['archive_count']} milestone ZIPs retain their recorded hashes. "
        "M9 compatibility traces use separate output filenames. The builder verifies that each redirected harness changes only its output path and that earlier scenario order, parameters and assertion totals remain intact.", "",
        "## Scope and limitations", ""]
    lines += ["- " + item for item in report["limits"]]
    lines += ["", "## Reproduce", "",
        "From the project root, run the complete M9 suite without a group filter and save each console stream to `combat_pc/tests/m9_combo_<rate>.log`:", "", "```sh",
        "XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/combo_regression.gd -- --hz=120",
        "XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/combo_regression.gd -- --hz=60", "```", "",
        "Run the eight original compatibility harnesses with only output filenames redirected to `<suite>_compat_m9_results_<rate>hz.json`, retaining movement's extra suffix placeholder. Save `m9_<suite>_<rate>.log`. The exact redirect identities are recorded in `tests/combo_compatibility_redirects.json`.", "",
        "After all final evidence is ready, run `python3 combat_pc/tests/build_combo_report.py`. Add `--check-only` for the identical audit without writing reports. It rejects incomplete or filtered runs, stale sources, failed assertions, diagnostic logs, missing callback samples, changed historical bytes and exceeded bounds before publishing either report.", "",
        "Historical re-audits require the original evidence files and milestone ZIPs listed in the preservation manifest. They are not required merely to play the project. Every M9 scenario has exact JSON-pointer trace links, per-rate assertions and per-rate parameters in the detailed report.", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    try:
        main()
    except (VerificationError, OSError, ValueError, KeyError, TypeError, StopIteration) as error:
        print(f"FAIL: M9 acceptance report not generated: {error}", file=sys.stderr)
        sys.exit(1)
