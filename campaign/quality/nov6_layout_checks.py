#!/usr/bin/env python3
"""Run focused November 6 layout fixtures without replacing historical evidence.

Usage: python3 campaign/quality/nov6_layout_checks.py [--negative-controls]
The default evidence directory is a new temporary folder. An explicit --output
must not already exist. These fixtures do not establish full-route or human timing.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
ERROR = re.compile(r"(?:SCRIPT ERROR|^ERROR:|Parse Error|Compile Error|signal 11)", re.M)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--negative-controls", action="store_true")
    parser.add_argument("--hz", type=int, choices=(60, 120), nargs="+", default=[60, 120])
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    if args.output:
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=False)
    else:
        output = Path(tempfile.mkdtemp(prefix="moksha-nov6-layout-"))
    cases = [(f"layout_{hz}", hz, "") for hz in dict.fromkeys(args.hz)]
    if args.negative_controls:
        cases += [("negative_preloaded_plate", 60, "preloaded_plate"),
                  ("negative_blocked_underpass", 60, "blocked_underpass"),
                  ("negative_unsafe_gate_staging", 60, "unsafe_gate_staging")]
    summary = {"passed": True, "cases": [], "full_campaign_evidence": False,
               "human_duration_validated": False, "output": str(output),
               "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
    for name, hz, fault in cases:
        folder = output / name
        folder.mkdir()
        env = os.environ.copy()
        for key, leaf in (("HOME", "home"), ("XDG_DATA_HOME", "data"),
                          ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")):
            (folder / leaf).mkdir()
            env[key] = str(folder / leaf)
        report_path = folder / "report.json"
        command = [godot, "--headless", "--path", str(ROOT), "--fixed-fps", str(hz),
                   "--script", "res://campaign/quality/nov6_layout_regression.gd", "--",
                   f"--hz={hz}", f"--output={report_path}"]
        if fault:
            command.append(f"--negative-control={fault}")
        run = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=180)
        log = run.stdout + run.stderr
        (folder / "engine.log").write_text(log)
        report = json.loads(report_path.read_text()) if report_path.exists() else {}
        ok = (not ERROR.search(log) and "NOV6_LAYOUT_REGRESSION" in log
              and report.get("hz") == hz and report.get("source_drift") == []
              and len(report.get("receipts", [])) == 12)
        if fault:
            needle = {"preloaded_plate": "plate starts loaded",
                      "blocked_underpass": "Rescued underpass still blocks",
                      "unsafe_gate_staging": "active hazard hit closed-gate staging"}[fault]
            ok = bool(ok and run.returncode == 1 and report.get("passed") is False
                      and any(needle in item for item in report.get("failures", [])))
        else:
            ok = bool(ok and run.returncode == 0 and report.get("passed") is True)
        summary["cases"].append({"name": name, "passed": ok, "returncode": run.returncode,
                                 "expected_regression_rejection": bool(fault),
                                 "report": str(report_path), "log": str(folder / "engine.log")})
        summary["passed"] = summary["passed"] and ok
        print(f"{name}: {'PASS' if ok else 'FAIL'}", flush=True)
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"Evidence: {output / 'summary.json'}")
    return 0 if summary["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
