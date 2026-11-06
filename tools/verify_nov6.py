#!/usr/bin/env python3
"""Fail-closed acceptance for the November 6 changes, with isolated user data.

This is a focused fixture matrix, not a complete campaign or native-device
acceptance claim. Full routes, inherited regression suites, native screenshots
and packaged-runtime checks are separate evidence. Every output must be new.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"^\s*(?:SCRIPT ERROR:|ERROR:|FAIL\b|Parse Error|Compile Error)", re.M)
SCRIPTS = [
    ("gameplay_input", "nov6_gameplay_input.gd", "NOV6_GAMEPLAY_INPUT_RESULT "),
    ("input_guidance", "nov6_input_guidance.gd", "NOV6_INPUT_GUIDANCE_RESULT "),
    ("gameplay_objectives", "nov6_gameplay_objectives.gd", "NOV6_GAMEPLAY_OBJECTIVES_RESULT "),
    ("gameplay_build", "nov6_gameplay_build.gd", "NOV6_GAMEPLAY_BUILD_RESULT "),
    ("save_feedback", "nov6_gameplay_save_feedback.gd", "NOV6_GAMEPLAY_SAVE_FEEDBACK_RESULT "),
    ("gamepad_navigation", "nov6_gamepad_navigation.gd", "NOV6_GAMEPAD_NAVIGATION_RESULT "),
    ("independent_review", "nov6_independent_review.gd", "NOV6_INDEPENDENT_RESULT "),
    ("independent_controller", "nov6_independent_controller.gd", "NOV6_INDEPENDENT_CONTROLLER "),
    ("independent_focus_upgrade", "nov6_independent_focus_upgrade.gd", "NOV6_INDEPENDENT_FOCUS_UPGRADE "),
    ("independent_paused_release", "nov6_independent_paused_release.gd", "NOV6_INDEPENDENT_PAUSED_RELEASE "),
    ("independent_hud_pipeline", "nov6_independent_hud_pipeline.gd", "NOV6_INDEPENDENT_HUD_PIPELINE "),
    ("camera", "nov6_camera/camera_contract.gd", "CAMERA_CONTRACT_RESULT "),
    ("runtime_lifecycle", "nov6_runtime_lifecycle.gd", "NOV6_RUNTIME_LIFECYCLE_RESULT "),
    ("audio_contract", "nov6_audio/contract.gd", "NOV6_AUDIO_CONTRACT_RESULT "),
    ("audio_routing", "nov6_audio/event_routing.gd", "NOV6_AUDIO_ROUTING_RESULT "),
    ("route_modal_observer", "nov6_modal_route_observer_test.gd", "NOV6_MODAL_ROUTE_OBSERVER_RESULT "),
    ("route_freight_observer", "nov6_freight_observer_test.gd", "NOV6_FREIGHT_OBSERVER_RESULT "),
    ("audio_rejected_noise", "nov6_audio/rejected_noise.gd", "NOV6_AUDIO_REJECTED_NOISE_RESULT "),
]


def source_hashes() -> dict[str, str]:
    result = {}
    for path in sorted(ROOT.rglob("*")):
        relative = path.relative_to(ROOT)
        if {".git", ".godot", "__pycache__", "results"}.intersection(relative.parts) or not path.is_file():
            continue
        if path.suffix in {".gd", ".tscn", ".tres", ".gdshader", ".py", ".png", ".wav", ".ogg"} or path.name == "project.godot":
            result[str(relative)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def parse_receipt(log: str, marker: str) -> dict:
    receipts = [line[len(marker):] for line in log.splitlines() if line.startswith(marker)]
    if len(receipts) != 1:
        return {"passed": False, "failure": "Expected exactly one completion receipt", "receipt_count": len(receipts)}
    try:
        value = json.loads(receipts[0])
    except json.JSONDecodeError as error:
        return {"passed": False, "failure": str(error)}
    if (not isinstance(value, dict) or value.get("passed") is not True or value.get("failures") != []
            or type(value.get("checks")) is not int or value["checks"] <= 0):
        return {"passed": False, "failure": "Completion receipt rejects acceptance", "receipt": value}
    return {"passed": True, "receipt": value}


def run_case(name: str, command: list[str], output: Path, marker: str | None, timeout: int = 240) -> dict:
    folder = output / name
    folder.mkdir()
    env = dict(os.environ, MOKSHA_QUALITY_ISOLATED="1")
    for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        location = folder / key.lower()
        location.mkdir()
        env[key] = str(location)
    started = time.monotonic()
    try:
        process = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)
        code, log = process.returncode, process.stdout + process.stderr
    except (subprocess.TimeoutExpired, OSError) as error:
        code, log = 124 if isinstance(error, subprocess.TimeoutExpired) else 127, str(error)
    log = re.sub(r"\x1b\[[0-9;]*m", "", log)
    (folder / "engine.log").write_text(log)
    receipt = parse_receipt(log, marker) if marker else {"passed": True}
    if name.startswith("presentation_"):
        matches = re.findall(r"^NOV6_PRESENTATION checks=(\d+) failures=\[\] ", log, re.M)
        receipt = {"passed": len(matches) == 1 and int(matches[0]) > 0,
                   "checks": int(matches[0]) if len(matches) == 1 else 0}
    elif name.startswith("caption_overlap_"):
        receipt = {"passed": len(re.findall(r"^NOV6_CAPTION_OVERLAP \[\]$", log, re.M)) == 1}
    errors = [line for line in log.splitlines() if ERROR.search(line)]
    result = {"name": name, "command": command, "exit_code": code, "errors": errors,
              "passed": code == 0 and not errors and receipt["passed"], "validation": receipt,
              "wall_seconds": round(time.monotonic() - started, 3), "log": str(folder / "engine.log")}
    (folder / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{name}: {'PASS' if result['passed'] else 'FAIL'} ({result['wall_seconds']}s)", flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents:
        parser.error("Use an evidence directory outside the source tree")
    output.mkdir(parents=True, exist_ok=False)
    before = source_hashes()
    version = subprocess.run([args.godot, "--version"], capture_output=True, text=True).stdout.strip()
    rows = [run_case("import", [args.godot, "--headless", "--editor", "--import", "--path", str(ROOT)], output, None, 300)]
    if rows[0]["passed"]:
        rows.append(run_case("runner_negative_controls", [sys.executable, "campaign/quality/nov6_independent_runner_test.py"], output, "NOV6_INDEPENDENT_RUNNER "))
        for hz in (60, 120):
            base = [args.godot, "--headless", "--path", str(ROOT), "--fixed-fps", str(hz), "--script"]
            for name, script, marker in SCRIPTS:
                command = base + ["res://campaign/quality/" + script, "--", f"--hz={hz}"]
                if name == "save_feedback":
                    command.append("--isolated-save-tests")
                rows.append(run_case(f"{name}_{hz}", command, output, marker))
            for name, script in (("presentation", "nov6_presentation_contract.gd"), ("caption_overlap", "nov6_independent_caption_overlap.gd")):
                rows.append(run_case(f"{name}_{hz}", base + ["res://campaign/quality/" + script, "--", f"--hz={hz}"], output, None))
        rows.append(run_case("layout_negative_controls", [sys.executable, "campaign/quality/nov6_layout_checks.py", "--godot", args.godot, "--negative-controls", "--output", str(output / "layout_receipts")], output, None, 900))
        layout_path = output / "layout_receipts/summary.json"
        layout = json.loads(layout_path.read_text()) if layout_path.exists() else {}
        rows[-1]["passed"] = rows[-1]["passed"] and layout.get("passed") is True and len(layout.get("cases", [])) == 5
        rows[-1]["nested_report"] = str(layout_path)
        (output / "layout_negative_controls/result.json").write_text(json.dumps(rows[-1], indent=2) + "\n")
        rows.append(run_case("scenery_contracts", [sys.executable, "campaign/quality/nov6_scenery/run.py", "--godot", args.godot, "--output", str(output / "scenery_receipts")], output, None, 600))
        scenery_path = output / "scenery_receipts/report.json"
        scenery = json.loads(scenery_path.read_text()) if scenery_path.exists() else {}
        rows[-1]["passed"] = rows[-1]["passed"] and scenery.get("passed") is True and len(scenery.get("tests", [])) == 4
        rows[-1]["nested_report"] = str(scenery_path)
        (output / "scenery_contracts/result.json").write_text(json.dumps(rows[-1], indent=2) + "\n")
    after = source_hashes()
    drift = sorted(path for path in before.keys() | after.keys() if before.get(path) != after.get(path))
    summary = {"scope": __doc__, "godot_version": version, "source_sha256": before, "source_drift": drift,
               "stages": rows, "passed": not drift and all(row["passed"] for row in rows)}
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Report: {output / 'summary.json'}", flush=True)
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
