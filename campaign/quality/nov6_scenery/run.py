#!/usr/bin/env python3
"""Fail-closed focused scenery verification. Headless success is not pixel approval."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
CASES = [
    ("district_contract", "campaign/quality/nov6_scenery/scenery_contract.gd", "NOV6_SCENERY_CONTRACT_PASS", []),
    ("input_parity", "campaign/quality/nov6_scenery/input_parity.gd", "NOV6_SCENERY_INPUT_PARITY_PASS", ["--fixed-fps", "60"]),
    ("presentation_contract", "campaign/presentation/tests/presentation_contract.gd", "PRESENTATION_CONTRACT_PASS", []),
    ("runtime_sight", "campaign/presentation/tests/runtime_sight_contract.gd", "RUNTIME_SIGHT_CONTRACT_PASS", []),
]
ENGINE_ERROR = re.compile(r"(?im)^\s*(?:SCRIPT ERROR:|ERROR:)|ObjectDB instances leaked|resources still in use at exit")
SOURCES = [
    "campaign/presentation/campaign_scenery.gd", "campaign/presentation/scenery_backdrop.gd",
    "campaign/presentation/district_identity.gd", "campaign/presentation/district_landmark.gd",
    "campaign/presentation/campaign_scenery.tscn", "campaign/logic/campaign.gd",
    "campaign/logic/campaign_data.gd", *[f"campaign/layouts/level_{i:02}.gd" for i in range(1, 6)],
    *[case[1] for case in CASES],
]

def hashes():
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in SOURCES}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    before = hashes()
    report = {"scope": "32 district presentation contracts and bounded five-start input parity, not full campaign traversal or pixel approval", "sources": before, "tests": []}
    with tempfile.TemporaryDirectory(prefix="moksha-scenery-") as profile:
        env = dict(os.environ, HOME=profile, XDG_DATA_HOME=profile + "/data", XDG_CONFIG_HOME=profile + "/config", XDG_CACHE_HOME=profile + "/cache")
        for label, path, marker, flags in CASES:
            command = [args.godot, "--headless", *flags, "--path", str(ROOT), "--script", "res://" + path]
            started = time.monotonic()
            timed_out = False
            try:
                result = subprocess.run(command, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
                output, code = result.stdout, result.returncode
            except subprocess.TimeoutExpired as error:
                output = error.stdout or b""
                if isinstance(output, bytes): output = output.decode(errors="replace")
                code, timed_out = -1, True
            log = args.output / (label + ".log")
            log.write_text(output)
            errors = bool(ENGINE_ERROR.search(output))
            passed = code == 0 and marker in output and not errors and not timed_out
            report["tests"].append({"name": label, "passed": passed, "exit_code": code, "success_marker": marker in output, "engine_errors": errors, "timeout": timed_out, "seconds": round(time.monotonic() - started, 3), "log": log.name})
            print(f"{label}: {'PASS' if passed else 'FAIL'}", flush=True)
    report["source_changed_during_run"] = hashes() != before
    report["passed"] = all(case["passed"] for case in report["tests"]) and not report["source_changed_during_run"]
    (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["passed"] else 1

if __name__ == "__main__":
    raise SystemExit(main())
